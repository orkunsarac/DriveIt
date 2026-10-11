import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum OwnerRevisionOrigin { owner, legacy }

typedef OwnerRevisionProvenanceResolver =
    String? Function(String group, Object logicalKey, Object? value);

/// Adapter-preserving row input. The key is logical; source identity is
/// provenance. Equal keys from different proven sources remain distinct.
class OwnerRevisionRecord {
  OwnerRevisionRecord({
    required this.group,
    required this.logicalKey,
    required this.sourceIdentity,
    required this.origin,
    required List<int> payload,
    this.sourceNamespace,
    this.sourceFingerprint,
    this.tombstoneTargetIdentity,
    this.unresolvedCode,
  }) : payload = Uint8List.fromList(payload);

  final String group;
  final String logicalKey;
  final String sourceIdentity;
  final OwnerRevisionOrigin origin;
  final Uint8List payload;
  final String? sourceNamespace;
  final String? sourceFingerprint;
  final String? tombstoneTargetIdentity;
  final String? unresolvedCode;
  String get sha256 => revisionSha256(payload);
  String get id => revisionSha256(
    utf8.encode(jsonEncode([group, sourceIdentity, logicalKey])),
  );
}

class OwnerRevisionAsset {
  const OwnerRevisionAsset({
    required this.sourceNamespace,
    required this.id,
    required this.sha256,
    required this.bytes,
    required this.relativePath,
    this.origin = OwnerRevisionAssetOrigin.owner,
  });
  final String sourceNamespace;
  final String id;
  final String sha256;
  final int bytes;
  final String relativePath;
  final OwnerRevisionAssetOrigin origin;
}

enum OwnerRevisionAssetOrigin { owner, legacyImport }

class OwnerRevisionSnapshot {
  OwnerRevisionSnapshot({
    required this.ownerUuid,
    required this.expectedBaseRevisionId,
    required this.sourceRevision,
    required this.sourceFingerprint,
    required this.importNamespace,
    required this.importFingerprint,
    required Set<String> coveredGroups,
    required List<OwnerRevisionRecord> records,
    required List<OwnerRevisionAsset> assets,
  }) : coveredGroups = Set.unmodifiable(coveredGroups),
       records = List.unmodifiable(records),
       assets = List.unmodifiable(assets);

  final String ownerUuid;
  final String? expectedBaseRevisionId;
  final String sourceRevision;
  final String sourceFingerprint;
  final String importNamespace;
  final String importFingerprint;
  final Set<String> coveredGroups;
  final List<OwnerRevisionRecord> records;
  final List<OwnerRevisionAsset> assets;
}

String revisionSha256(List<int> value) => sha256.convert(value).toString();
