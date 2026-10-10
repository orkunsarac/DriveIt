import 'dart:convert';
import 'package:hive/hive.dart';
import 'planet_segment.dart';
import '../../my_world/config/my_world_rules.dart';

enum SegmentDeliveryState {
  queued,
  sending,
  awaitingValidation,
  accepted,
  rejected,
  retryableFailure,
}

enum SegmentRemoteState {
  absent,
  awaitingValidation,
  accepted,
  rejected,
  retryableFailure,
}

class SegmentRemoteReceipt {
  const SegmentRemoteReceipt(
    this.state, {
    this.remoteId,
    this.validDistanceMeters,
  });
  final SegmentRemoteState state;
  final String? remoteId;
  final double? validDistanceMeters;
}

/// Implement only when server supports stable segment identity + reconciliation.
/// No secret credentials belong here. Disabled in the shipped local-only phase.
abstract interface class PlanetSegmentGateway {
  bool get enabled;
  Future<SegmentRemoteReceipt> lookup(String ownerScope, String segmentId);
  Future<SegmentRemoteReceipt> submit(
    String ownerScope,
    Map<String, dynamic> payload,
  );
}

class DisabledPlanetSegmentGateway implements PlanetSegmentGateway {
  const DisabledPlanetSegmentGateway();
  @override
  bool get enabled => false;
  @override
  Future<SegmentRemoteReceipt> lookup(String ownerScope, String segmentId) =>
      Future.error(StateError('Segment backend disabled'));
  @override
  Future<SegmentRemoteReceipt> submit(
    String ownerScope,
    Map<String, dynamic> payload,
  ) => Future.error(StateError('Segment backend disabled'));
}

/// Independent of History/World deletion. Contains private local evidence only.
/// Persisted sending means "response unknown": ALWAYS reconcile before submit.
class PlanetSegmentOutbox {
  PlanetSegmentOutbox(
    this.box, {
    this.gateway = const DisabledPlanetSegmentGateway(),
  });
  static const boxName = 'planet_segment_outbox_v1';
  static Future<void> open(HiveInterface hive) =>
      hive.openBox<dynamic>(boxName);
  final Box<dynamic> box;
  final PlanetSegmentGateway gateway;
  static final Map<String, Future<void>> _inFlight = {};
  static final Map<String, Future<void>> _writes = {};
  String _key(String owner, String id) => jsonEncode([owner, id]);
  Map<String, dynamic>? entry(String owner, String id) {
    final value = box.get(_key(owner, id));
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value as String));
  }

  List<Map<String, dynamic>> entries(String owner, String driveId) => box.values
      .map((v) => Map<String, dynamic>.from(jsonDecode(v as String)))
      .where(
        (v) =>
            v['owner'] == owner &&
            (v['payload'] as Map)['sourceDriveId'] == driveId,
      )
      .toList();
  Future<void> _persist(String key, Map<String, dynamic> value) async {
    await box.put(key, jsonEncode(value));
    await box.flush();
  }

  Future<void> prepare(String owner, Iterable<PlanetSegment> segments) {
    if (owner.isEmpty) {
      return Future.error(ArgumentError('Owner scope required'));
    }
    final candidates = segments.where((s) => s.eligible).toList();
    final path = box.path ?? box.name;
    final prior = _writes[path];
    Future<void> write() async {
      if (prior != null) await prior;
      for (final s in candidates) {
        final old = entry(owner, s.id);
        if (old != null) {
          if (jsonEncode(old['payload']) != jsonEncode(s.toMap())) {
            throw StateError('Immutable segment payload conflict');
          }
          // Re-establish durability after a previous lost flush acknowledgement.
          await box.flush();
          continue;
        }
        await _persist(_key(owner, s.id), {
          'version': 1,
          'owner': owner,
          'payload': s.toMap(),
          'state': SegmentDeliveryState.queued.name,
        });
      }
    }

    late Future<void> operation;
    operation = write().whenComplete(() {
      if (identical(_writes[path], operation)) _writes.remove(path);
    });
    _writes[path] = operation;
    return operation;
  }

  Future<void> deliver(String owner, String id) {
    final key = '${box.path}:${_key(owner, id)}';
    return _inFlight.putIfAbsent(
      key,
      () => _deliver(owner, id).whenComplete(() {
        _inFlight.remove(key);
      }),
    );
  }

  Future<void> _deliver(String owner, String id) async {
    if (!gateway.enabled) return;
    final key = _key(owner, id);
    final row = entry(owner, id);
    if (row == null) throw StateError('Segment not prepared');
    final state = SegmentDeliveryState.values.byName(row['state'] as String);
    if (state == SegmentDeliveryState.accepted ||
        state == SegmentDeliveryState.rejected) {
      return;
    }
    // Before ANY network operation, commit a restart-safe uncertainty marker.
    row['state'] = SegmentDeliveryState.sending.name;
    await _persist(key, row);
    try {
      var receipt = await gateway.lookup(owner, id);
      if (receipt.state == SegmentRemoteState.absent) {
        receipt = await gateway.submit(
          owner,
          Map<String, dynamic>.from(row['payload']),
        );
      }
      if (receipt.state == SegmentRemoteState.absent) {
        throw StateError('Missing server receipt');
      }
      if (receipt.state == SegmentRemoteState.accepted &&
          (receipt.remoteId == null ||
              receipt.validDistanceMeters == null ||
              !receipt.validDistanceMeters!.isFinite ||
              receipt.validDistanceMeters! <
                  MyWorldRules.minimumValidDistanceMeters)) {
        throw StateError('Invalid authoritative receipt');
      }
      row['state'] = switch (receipt.state) {
        SegmentRemoteState.awaitingValidation =>
          SegmentDeliveryState.awaitingValidation.name,
        SegmentRemoteState.accepted => SegmentDeliveryState.accepted.name,
        SegmentRemoteState.rejected => SegmentDeliveryState.rejected.name,
        _ => SegmentDeliveryState.retryableFailure.name,
      };
      row['remoteId'] = receipt.remoteId;
      row['validDistanceMeters'] = receipt.validDistanceMeters;
    } catch (_) {
      // No raw exception strings/credentials persisted. Retry reconciles first.
      row['state'] = SegmentDeliveryState.retryableFailure.name;
    }
    await _persist(key, row);
  }

  /// Total accepted publication distance, NOT unique road discovery.
  double acceptedDistance(String owner) => !gateway.enabled
      ? 0
      : box.values
            .map((v) => Map<String, dynamic>.from(jsonDecode(v as String)))
            .where(
              (v) =>
                  v['owner'] == owner &&
                  v['state'] == SegmentDeliveryState.accepted.name,
            )
            .fold(
              0,
              (sum, v) => sum + (v['validDistanceMeters'] as num).toDouble(),
            );
}
