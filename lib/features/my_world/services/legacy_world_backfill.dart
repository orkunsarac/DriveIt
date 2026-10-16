import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../models/drive_session.dart';
import 'geo_distance.dart';
import '../../../services/gps_session_ownership.dart';
import '../../../services/owner_scoped_local_store.dart';
import '../config/my_world_rules.dart';
import '../models/world_index_snapshot.dart';

/// Read-only preview for explicit, owner-scoped recovery of already-imported
/// legacy routes. It never treats the old World projection as validation.
class LegacyWorldBackfillPreview {
  const LegacyWorldBackfillPreview({
    required this.inspected,
    required this.candidates,
    required this.alreadyProcessed,
    required this.ineligible,
  });

  final int inspected;
  final List<LegacyWorldBackfillCandidate> candidates;
  final int alreadyProcessed;
  final int ineligible;
  int get eligibleCount => candidates.length;
}

class LegacyWorldBackfillCandidate {
  const LegacyWorldBackfillCandidate({
    required this.driveId,
    required this.routeFingerprint,
  });

  final String driveId;
  final String routeFingerprint;
}

class LegacyWorldBackfillResult {
  const LegacyWorldBackfillResult({
    required this.processed,
    required this.alreadyProcessed,
    required this.ineligible,
    required this.failed,
  });

  final int processed;
  final int alreadyProcessed;
  final int ineligible;
  final int failed;
}

abstract final class LegacyWorldBackfill {
  static const markerBox = 'legacy_world_backfill_v1';
  static const minimumRouteMeters = MyWorldRules.minimumValidDistanceMeters;

  static String routeFingerprint(DriveSession drive) => sha256
      .convert(
        utf8.encode(
          jsonEncode(
            drive.route
                .map(
                  (point) => [
                    point.latitude,
                    point.longitude,
                    point.breakBefore,
                  ],
                )
                .toList(growable: false),
          ),
        ),
      )
      .toString();

  /// Raw distance is only a preflight threshold, never World validation.
  static double routeDistanceMeters(DriveSession drive) {
    if (drive.route.length < 2 || !_validRoute(drive)) return 0;
    var distance = 0.0;
    for (var i = 1; i < drive.route.length; i++) {
      final previous = drive.route[i - 1];
      final current = drive.route[i];
      if (current.breakBefore) continue;
      distance += GeoDistance.between(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
    }
    return distance;
  }

  static bool _validRoute(DriveSession drive) => drive.route.every(
    (point) =>
        point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude.abs() <= 90 &&
        point.longitude.abs() <= 180,
  );

  static bool hasVerifiedLegacyTransfer(
    OwnerScopedLocalStore store,
    GpsOwner owner,
    String driveId,
  ) {
    final details = store.read<Map>(owner, 'drive_details_v1', driveId);
    final proof = store.read<Map>(owner, 'drive_source_provenance_v1', driveId);
    final finalization = store.read<Map>(
      owner,
      'owned_drive_finalization_v1',
      driveId,
    );
    final fingerprint = proof?['archiveFingerprint'];
    return owner.kind == GpsOwnerKind.account &&
        driveId.startsWith('transfer_') &&
        details?['accountTransfer'] == 'legacy' &&
        details?['localOnly'] == true &&
        proof?['status'] == 'unproven' &&
        proof?['ownerScope'] == store.scope &&
        proof?['archiveNamespace'] == 'legacy' &&
        fingerprint is String &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint) &&
        finalization?['state'] == 'completed' &&
        finalization?['localOnlyImport'] == true &&
        finalization?['transferClaim'] is String &&
        (finalization!['transferClaim'] as String).startsWith(
          'account_transfer_v1:',
        );
  }

  static bool markerMatches(
    OwnerScopedLocalStore store,
    GpsOwner owner,
    DriveSession drive,
  ) {
    if (!hasVerifiedLegacyTransfer(store, owner, drive.id)) return false;
    final marker = store.read<Map>(owner, markerBox, drive.id);
    return marker?['version'] == 1 &&
        marker?['ownerScope'] == store.scope &&
        marker?['routeFingerprint'] == routeFingerprint(drive) &&
        (marker?['status'] == 'validated' || marker?['status'] == 'processed');
  }

  static LegacyWorldBackfillPreview inspect({
    required OwnerScopedLocalStore store,
    required GpsOwner owner,
    required Iterable<DriveSession> drives,
    required WorldIndexSnapshot snapshot,
  }) {
    if (owner.kind != GpsOwnerKind.account) {
      return const LegacyWorldBackfillPreview(
        inspected: 0,
        candidates: [],
        alreadyProcessed: 0,
        ineligible: 0,
      );
    }
    var inspected = 0;
    var already = 0;
    var ineligible = 0;
    final processedIds = snapshot.processedDriveSessionIds.toSet();
    final candidates = <LegacyWorldBackfillCandidate>[];
    for (final drive in drives) {
      if (!hasVerifiedLegacyTransfer(store, owner, drive.id)) continue;
      inspected++;
      final marker = store.read<Map>(owner, markerBox, drive.id);
      final markerCurrent =
          marker?['version'] == 1 &&
          marker?['ownerScope'] == store.scope &&
          marker?['routeFingerprint'] == routeFingerprint(drive);
      if (processedIds.contains(drive.id) ||
          (markerCurrent && marker?['status'] == 'processed')) {
        already++;
        continue;
      }
      final distance = routeDistanceMeters(drive);
      if (distance < minimumRouteMeters) {
        ineligible++;
        continue;
      }
      candidates.add(
        LegacyWorldBackfillCandidate(
          driveId: drive.id,
          routeFingerprint: routeFingerprint(drive),
        ),
      );
    }
    return LegacyWorldBackfillPreview(
      inspected: inspected,
      candidates: List.unmodifiable(candidates),
      alreadyProcessed: already,
      ineligible: ineligible,
    );
  }
}
