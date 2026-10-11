import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/services/career_contribution_repository.dart';
import 'package:driveit_project/services/drive_source_provenance.dart';
import 'package:driveit_project/services/local_source_bundle.dart';

const ownerA = 'local_account_store_v1-account-a';
const identityA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const identityB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

DriveSession _drive([String id = 'same-local-drive']) => DriveSession(
  id: id,
  date: DateTime.utc(2026),
  distance: 6200,
  durationSeconds: 900,
  averageSpeed: 24,
  maxSpeed: 35,
  mapImagePath: '',
  route: const [],
);

LocalSourceBundle _bundle(String sourceIdentity) => LocalSourceBundle(
  drive: _drive(),
  ownerScope: ownerA,
  sourceProvenance: DriveSourceProvenance.proven(
    sourceIdentity: sourceIdentity,
    ownerScope: ownerA,
  ),
);

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('drive_source_provenance_');
    Hive.init(root.path);
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  test('opaque source identity is independent from drive and owner', () {
    final a = DriveSourceProvenance.proven(
      sourceIdentity: identityA,
      ownerScope: ownerA,
    );
    final moved = DriveSourceProvenance.proven(
      sourceIdentity: identityA,
      ownerScope: 'local_account_store_v1-account-b',
    );
    expect(a.sourceIdentity, isNot('same-local-drive'));
    expect(moved.sourceIdentity, a.sourceIdentity);
    expect(moved.ownerScope, isNot(a.ownerScope));
    expect(moved.revisionSourceIdentity, a.revisionSourceIdentity);
  });

  test('old LocalSourceBundle v1 remains explicitly without provenance', () {
    final old = _bundle(identityA).toMap()
      ..remove('sourceProvenance')
      ..['version'] = 1;
    final decoded = LocalSourceBundle.fromMap(old);
    decoded.validate();
    expect(decoded.sourceProvenance, isNull);
    expect(decoded.toMap()['version'], 1);
  });

  test('archive fingerprint is not promoted to source identity', () {
    final fingerprint = DriveSourceProvenance.fingerprint([1, 2, 3, 4]);
    final legacy = DriveSourceProvenance.unproven(
      ownerScope: 'legacy_unassigned',
      archiveNamespace: 'legacy_hive_v1',
      archiveFingerprint: fingerprint,
    );
    expect(legacy.status, DriveProvenanceStatus.unproven);
    expect(legacy.sourceIdentity, isNull);
    expect(legacy.isProven, isFalse);
  });

  test('invalid provenance namespace is rejected, not normalized', () {
    final value = DriveSourceProvenance.proven(
      sourceIdentity: identityA,
      ownerScope: ownerA,
    ).toMap()
      ..['sourceNamespace'] = 'drive:$identityA';
    expect(() => DriveSourceProvenance.fromMap(value), throwsStateError);
  });

  test('partial transfer evidence is conflict, absence remains unproven', () {
    expect(
      DriveSourceProvenance.fromTransferMetadata(
        const {},
        ownerScope: ownerA,
      ).status,
      DriveProvenanceStatus.unproven,
    );
    expect(
      DriveSourceProvenance.fromTransferMetadata(
        {'sourceIdentity': identityA},
        ownerScope: ownerA,
      ).status,
      DriveProvenanceStatus.conflict,
    );
  });

  test('proven source metadata round-trips and validates owner boundary', () {
    final original = _bundle(identityA);
    final decoded = LocalSourceBundle.fromMap(original.toMap());
    decoded.validate();
    expect(decoded.sourceProvenance!.status, DriveProvenanceStatus.proven);
    expect(decoded.sourceProvenance!.sourceIdentity, identityA);
    final wrongOwner = LocalSourceBundle(
      drive: _drive(),
      ownerScope: 'owner-b',
      sourceProvenance: original.sourceProvenance,
    );
    expect(wrongOwner.validate, throwsStateError);
  });

  test('career source identity exactly-once ignores colliding local IDs', () async {
    await CareerContributionRepository.open(Hive);
    final repository = CareerContributionRepository(
      Hive.box<dynamic>(CareerContributionRepository.boxName),
    );
    await repository.add(_bundle(identityA));
    await repository.add(_bundle(identityA));
    await repository.add(_bundle(identityB));
    final keys = Hive.box<dynamic>(CareerContributionRepository.boxName)
        .keys
        .whereType<String>()
        .where((key) => key.startsWith('source:'))
        .toSet();
    expect(keys, {'source:$identityA', 'source:$identityB'});
    expect(repository.provenContributions(), hasLength(2));
  });

  test('same source identity with different contribution is rejected', () async {
    await CareerContributionRepository.open(Hive);
    final repository = CareerContributionRepository(
      Hive.box<dynamic>(CareerContributionRepository.boxName),
    );
    await repository.add(_bundle(identityA));
    final changed = LocalSourceBundle(
      drive: _drive()..distance = 9000,
      ownerScope: ownerA,
      sourceProvenance: DriveSourceProvenance.proven(
        sourceIdentity: identityA,
        ownerScope: ownerA,
      ),
    );
    await expectLater(repository.add(changed), throwsStateError);
    expect(repository.provenContributions(), hasLength(1));
  });
}
