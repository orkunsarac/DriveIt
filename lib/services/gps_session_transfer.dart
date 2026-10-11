import 'dart:convert';
import '../models/canonical_telemetry_point.dart';
import 'gps_failure.dart';
import 'gps_session_store.dart';
import 'drive_route_projection.dart';

abstract interface class GpsTransferSink {
  Future<Map<String, dynamic>?> readDrive(String id);
  Future<List<CanonicalTelemetryPoint>?> readTelemetry(String id);
  Future<void> writeDrive(String id, Map<String, dynamic> manifest);
  Future<void> writeTelemetry(
    String id,
    List<CanonicalTelemetryPoint> points,
    Map<String, dynamic> metadata,
  );
  Future<void> flush();
}

/// Optional contract used only by controlled owner-scoped transfers. Legacy
/// sinks and historical records do not acquire identity by inference.
abstract interface class ProvenanceGpsTransferSink implements GpsTransferSink {
  Future<String?> readSourceIdentity(String id);
  Future<void> persistSourceIdentity(String id, String sourceIdentity);
}

/// SQLite is the durable recovery authority. Independent Hive boxes are NOT a
/// transaction: a durable intent, stable ID, read-back and verification receipt
/// make partial writes restartable. Never deletes either source or partial sink.
class GpsSessionTransfer {
  GpsSessionTransfer(this.store, this.sink);
  final GpsSessionStore store;
  final GpsTransferSink sink;
  static final Map<String, Future<Map<String, dynamic>>> _inFlight = {};
  Future<Map<String, dynamic>> save(
    String sessionId,
    Map<String, dynamic> proposed, {
    String? sourceIdentity,
    Future<void> Function(Map<String, dynamic>)? beforeAcknowledgement,
  }) {
    if (sourceIdentity != null &&
        (sink is! ProvenanceGpsTransferSink || !_isUuid(sourceIdentity))) {
      throw StateError('Provenance transfer contract unavailable');
    }
    final key = '${store.db.path}:$sessionId';
    return _inFlight.putIfAbsent(
      key,
      () =>
          _save(
            sessionId,
            proposed,
            sourceIdentity: sourceIdentity,
            beforeAcknowledgement: beforeAcknowledgement,
          ).whenComplete(() {
            _inFlight.remove(key);
          }),
    );
  }

  static Map<String, dynamic> pointContent(CanonicalTelemetryPoint p) => {
    ...p.toMap(),
    'timeMicros': p.timestamp.microsecondsSinceEpoch,
    'timeIsUtc': p.timestamp.isUtc,
  };

  Future<Map<String, dynamic>> _save(
    String id,
    Map<String, dynamic> proposed, {
    String? sourceIdentity,
    Future<void> Function(Map<String, dynamic>)? beforeAcknowledgement,
  }) async {
    if (proposed['id'] != id) throw GpsFailure(GpsErrorCode.recovery);
    final priorIntent = await store.transferFor(id);
    final priorDrive = await sink.readDrive(id);
    // Earlier app versions may have written Hive before an acknowledgement.
    // Keep its original date/summary, but only if full journal projection and
    // telemetry content below prove this exact session. Never rewrite it.
    final intent = await store.beginTransfer(
      id,
      id,
      jsonEncode(
        priorIntent == null && priorDrive != null ? priorDrive : proposed,
      ),
    );
    final manifest = Map<String, dynamic>.from(
      jsonDecode(intent['manifest'] as String) as Map,
    );
    final journal = await store.read(id, includeCheckpoints: false);
    if (journal.length != intent['final_sequence']) {
      throw GpsFailure(GpsErrorCode.recovery);
    }
    for (var i = 0; i < journal.length; i++) {
      if (journal[i].sessionId != id || journal[i].sequence != i + 1) {
        throw GpsFailure(GpsErrorCode.recovery);
      }
    }
    final points = journal.map((p) => p.point).toList();
    final route = <Map<String, dynamic>>[];
    var distance = 0.0;
    for (final p in points) {
      if (route.isEmpty || p.breakBefore || p.distanceFromPreviousMeters > 0) {
        route.add({
          'latitude': p.latitude,
          'longitude': p.longitude,
          'breakBefore': p.breakBefore,
        });
        if (route.length > 1 && !p.breakBefore) {
          distance += p.distanceFromPreviousMeters;
        }
      }
    }
    final safeProjection = DriveRouteProjection(points);
    final matchesSafe =
        jsonEncode(safeProjection.encodedRoute) ==
            jsonEncode(manifest['route']) &&
        safeProjection.distanceMeters == manifest['distance'];
    // An already durable old intent/Hive snapshot must remain byte-for-byte
    // recoverable. New transfers use the shared quality-qualified projection.
    final matchesExistingLegacy =
        (priorIntent != null || priorDrive != null) &&
        jsonEncode(route) == jsonEncode(manifest['route']) &&
        distance == manifest['distance'];
    if (!matchesSafe && !matchesExistingLegacy) {
      throw GpsFailure(GpsErrorCode.recovery);
    }
    final existing = await sink.readDrive(id);
    if (existing != null && jsonEncode(existing) != jsonEncode(manifest)) {
      throw GpsFailure(GpsErrorCode.recovery);
    }
    final telemetry = await sink.readTelemetry(id);
    if (telemetry != null && !_samePoints(points, telemetry)) {
      throw GpsFailure(GpsErrorCode.recovery);
    }
    if (sourceIdentity != null &&
        telemetry != null &&
        await (sink as ProvenanceGpsTransferSink).readSourceIdentity(id) !=
            sourceIdentity) {
      throw StateError('Existing telemetry provenance conflicts');
    }
    if (telemetry == null) {
      final session = (await store.session(id))!;
      await sink.writeTelemetry(id, points, {
        'sessionId': id,
        'reliabilityPolicyVersion': 1,
        'finalSequence': intent['final_sequence'],
        'startedAtMicros': session.startedAt.microsecondsSinceEpoch,
        'stopRequestedAtMicros': session.stoppedAt?.microsecondsSinceEpoch,
        'events': await store.events(id),
        if (sourceIdentity != null) ...{
          'sourceIdentity': sourceIdentity,
          'sourceIdentityVersion': 1,
          'sourceNamespace': 'drive_source_v1',
          'provenanceStatus': 'proven',
        },
      });
    }
    if (existing == null) await sink.writeDrive(id, manifest);
    if (sourceIdentity != null) {
      await (sink as ProvenanceGpsTransferSink).persistSourceIdentity(
        id,
        sourceIdentity,
      );
    }
    await sink.flush();
    if (!await verify(id, sourceIdentity: sourceIdentity)) {
      throw GpsFailure(GpsErrorCode.recovery);
    }
    // Controlled finalization can keep the stopped journal recoverable until
    // its secondary owner-local consumers are durable. Legacy callers have no
    // hook and retain precisely the existing acknowledgement behavior.
    await beforeAcknowledgement?.call(manifest);
    await store.acknowledgeSaved(id, id, verified: true);
    return manifest;
  }

  Future<bool> verify(String id, {String? sourceIdentity}) async {
    final receipt = await store.transferFor(id);
    if (receipt == null) return false;
    final drive = await sink.readDrive(receipt['drive_id'] as String);
    final telemetry = await sink.readTelemetry(receipt['drive_id'] as String);
    final journal = await store.read(id, includeCheckpoints: false);
    return drive != null &&
        telemetry != null &&
        jsonEncode(drive) == receipt['manifest'] &&
        journal.length == receipt['final_sequence'] &&
        _samePoints(journal.map((p) => p.point).toList(), telemetry) &&
        (sourceIdentity == null ||
            (sink is ProvenanceGpsTransferSink &&
                await (sink as ProvenanceGpsTransferSink).readSourceIdentity(
                      receipt['drive_id'] as String,
                    ) ==
                    sourceIdentity));
  }

  static bool _samePoints(
    List<CanonicalTelemetryPoint> a,
    List<CanonicalTelemetryPoint> b,
  ) =>
      a.length == b.length &&
      jsonEncode(a.map(pointContent).toList()) ==
          jsonEncode(b.map(pointContent).toList());

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(value);
}
