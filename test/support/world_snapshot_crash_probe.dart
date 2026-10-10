import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/features/my_world/repositories/world_source_snapshot_repository.dart';

Future<void> main(List<String> args) async {
  Hive.init(args[0]);
  await WorldSourceSnapshotRepository.open(Hive);
  final bundle = LocalSourceBundle.fromMap(
    jsonDecode(await File(args[1]).readAsString()),
  );
  await WorldSourceSnapshotRepository(
    Hive.box<dynamic>(WorldSourceSnapshotRepository.boxName),
  ).prepare(bundle, afterStage: () async => exit(73));
}
