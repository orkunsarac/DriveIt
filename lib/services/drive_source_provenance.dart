import 'dart:math';
import 'dart:convert';

import 'package:crypto/crypto.dart';

enum DriveProvenanceStatus { proven, unproven, conflict }

/// Evidence about the identity of one archived drive. The opaque source ID is
/// intentionally independent from both the local drive key and owner scope.
/// Missing legacy evidence remains unproven; fingerprints identify an archive
/// snapshot, not proof that two archives describe the same real-world drive.
class DriveSourceProvenance {
  static String newUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  const DriveSourceProvenance._({
    required this.status,
    required this.ownerScope,
    this.sourceIdentity,
    this.identityVersion,
    this.sourceNamespace,
  }) : archiveNamespace = null,
       archiveFingerprint = null,
       conflictCode = null;

  factory DriveSourceProvenance.proven({
    required String sourceIdentity,
    required String ownerScope,
    int identityVersion = 1,
  }) {
    if (!_isUuid(sourceIdentity) || ownerScope.isEmpty || identityVersion != 1) {
      throw ArgumentError('Invalid source provenance');
    }
    return DriveSourceProvenance._(
      status: DriveProvenanceStatus.proven,
      sourceIdentity: sourceIdentity.toLowerCase(),
      identityVersion: identityVersion,
      ownerScope: ownerScope,
      sourceNamespace: 'drive_source_v1',
    );
  }

  const DriveSourceProvenance.unproven({
    required this.ownerScope,
    this.archiveNamespace,
    this.archiveFingerprint,
    this.sourceNamespace,
  }) : status = DriveProvenanceStatus.unproven,
       sourceIdentity = null,
       identityVersion = null,
       conflictCode = null;

  const DriveSourceProvenance.conflict({
    required this.ownerScope,
    required this.conflictCode,
    this.archiveNamespace,
    this.archiveFingerprint,
    this.sourceNamespace,
  }) : status = DriveProvenanceStatus.conflict,
       sourceIdentity = null,
       identityVersion = null;

  static DriveSourceProvenance fromTransferMetadata(
    Map<String, dynamic> metadata, {
    required String ownerScope,
  }) {
    const keys = [
      'sourceIdentity',
      'sourceIdentityVersion',
      'sourceNamespace',
      'provenanceStatus',
    ];
    if (!keys.any(metadata.containsKey)) {
      return DriveSourceProvenance.unproven(ownerScope: ownerScope);
    }
    final identity = metadata['sourceIdentity'];
    if (metadata['provenanceStatus'] != 'proven' ||
        identity is! String ||
        metadata['sourceIdentityVersion'] != 1 ||
        metadata['sourceNamespace'] != 'drive_source_v1') {
      return DriveSourceProvenance.conflict(
        ownerScope: ownerScope,
        conflictCode: 'transfer_provenance_incomplete',
      );
    }
    try {
      return DriveSourceProvenance.proven(
        sourceIdentity: identity,
        ownerScope: ownerScope,
      );
    } on ArgumentError {
      return DriveSourceProvenance.conflict(
        ownerScope: ownerScope,
        conflictCode: 'transfer_source_identity_invalid',
      );
    }
  }

  final DriveProvenanceStatus status;
  final String? sourceIdentity;
  final int? identityVersion;
  final String ownerScope;
  final String? archiveNamespace;
  final String? archiveFingerprint;
  final String? sourceNamespace;
  final String? conflictCode;
  String? get revisionSourceIdentity => isProven
      ? jsonEncode([sourceNamespace, sourceIdentity])
      : null;

  bool get isProven =>
      status == DriveProvenanceStatus.proven &&
      sourceIdentity != null &&
      identityVersion == 1 &&
      sourceNamespace == 'drive_source_v1' &&
      _isUuid(sourceIdentity!);

  Map<String, Object?> toMap() => {
    'version': 1,
    'status': status.name,
    'sourceIdentity': sourceIdentity,
    'identityVersion': identityVersion,
    'ownerScope': ownerScope,
    'sourceNamespace': sourceNamespace,
    'archiveNamespace': archiveNamespace,
    'archiveFingerprint': archiveFingerprint,
    'conflictCode': conflictCode,
  };

  factory DriveSourceProvenance.fromMap(Map value) {
    if (value['version'] != 1 || value['ownerScope'] is! String) {
      throw StateError('Unsupported source provenance format');
    }
    final status = DriveProvenanceStatus.values.byName(value['status'] as String);
    final sourceIdentity = value['sourceIdentity'] as String?;
    final identityVersion = value['identityVersion'] as int?;
    final result = switch (status) {
      DriveProvenanceStatus.proven => DriveSourceProvenance.proven(
        sourceIdentity: sourceIdentity ?? '',
        ownerScope: value['ownerScope'] as String,
        identityVersion: identityVersion ?? -1,
      ),
      DriveProvenanceStatus.unproven => DriveSourceProvenance.unproven(
        ownerScope: value['ownerScope'] as String,
        archiveNamespace: value['archiveNamespace'] as String?,
        archiveFingerprint: value['archiveFingerprint'] as String?,
        sourceNamespace: value['sourceNamespace'] as String?,
      ),
      DriveProvenanceStatus.conflict => DriveSourceProvenance.conflict(
        ownerScope: value['ownerScope'] as String,
        conflictCode: value['conflictCode'] as String? ?? 'unknown_conflict',
        archiveNamespace: value['archiveNamespace'] as String?,
        archiveFingerprint: value['archiveFingerprint'] as String?,
        sourceNamespace: value['sourceNamespace'] as String?,
      ),
    };
    if (status == DriveProvenanceStatus.proven && !result.isProven) {
      throw StateError('Invalid proven source identity');
    }
    if (status == DriveProvenanceStatus.proven &&
        value['sourceNamespace'] != 'drive_source_v1') {
      throw StateError('Invalid provenance namespace');
    }
    return result;
  }

  /// Archive fingerprint is not an identity claim. It only makes a particular
  /// legacy snapshot recognizable for retry/import bookkeeping.
  static String fingerprint(List<int> canonicalArchiveBytes) =>
      sha256.convert(canonicalArchiveBytes).toString();

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
