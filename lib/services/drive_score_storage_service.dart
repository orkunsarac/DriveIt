import 'package:hive/hive.dart';

import '../models/drive_score_record.dart';

class DriveScoreHive {
  static const String boxName = 'drive_scores';
  static const int recordTypeId = 4;

  static void registerAdapters(HiveInterface hive) {
    if (!hive.isAdapterRegistered(recordTypeId)) {
      hive.registerAdapter(DriveScoreRecordAdapter());
    }
  }

  static Future<void> openBox(HiveInterface hive) =>
      hive.openBox<DriveScoreRecord>(boxName);
}

class DriveScoreStorageService {
  static Box<DriveScoreRecord> get _box =>
      Hive.box<DriveScoreRecord>(DriveScoreHive.boxName);

  static String keyFor(String driveId, int algorithmVersion) =>
      '$driveId:v$algorithmVersion';

  static DriveScoreRecord? get({
    required String driveId,
    int algorithmVersion = DriveScoreRecord.currentAlgorithmVersion,
  }) => Hive.isBoxOpen(DriveScoreHive.boxName)
      ? _box.get(keyFor(driveId, algorithmVersion))
      : null;

  static List<DriveScoreRecord> getAll() =>
      Hive.isBoxOpen(DriveScoreHive.boxName)
          ? _box.values.toList(growable: false)
          : const <DriveScoreRecord>[];

  static bool exists({
    required String driveId,
    int algorithmVersion = DriveScoreRecord.currentAlgorithmVersion,
  }) => get(driveId: driveId, algorithmVersion: algorithmVersion) != null;

  static Future<void> save(DriveScoreRecord record) async {
    _validate(record);
    await _box.put(keyFor(record.driveId, record.algorithmVersion), record);
  }

  static Future<void> deleteForDrive(String driveId) async {
    if (!Hive.isBoxOpen(DriveScoreHive.boxName)) return;
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith('$driveId:v'))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }

  static void _validate(DriveScoreRecord record) {
    if (record.driveId.trim().isEmpty) {
      throw ArgumentError.value(record.driveId, 'driveId', 'Must not be empty.');
    }
    if (record.algorithmVersion != DriveScoreRecord.currentAlgorithmVersion) {
      throw ArgumentError.value(
        record.algorithmVersion,
        'algorithmVersion',
        'Only Drive Score v1 can be stored by this service.',
      );
    }
    if (record.telemetryDataVersion <= 0 ||
        !record.totalScore.isFinite ||
        !record.overallConfidence.isFinite ||
        record.totalScore < 0 ||
        record.totalScore > 1000 ||
        record.overallConfidence < 0 ||
        record.overallConfidence > 1 ||
        record.categories.isEmpty) {
      throw ArgumentError('Invalid Drive Score record.');
    }
    var contributionTotal = 0.0;
    for (final category in record.categories) {
      if (category.categoryKey.trim().isEmpty ||
          !category.rawScore.isFinite ||
          !category.maximum.isFinite ||
          !category.contributionUsed.isFinite ||
          category.maximum <= 0 ||
          category.rawScore < 0 ||
          category.rawScore > category.maximum ||
          category.contributionUsed < 0 ||
          category.contributionUsed > category.maximum) {
        throw ArgumentError('Invalid Drive Score category record.');
      }
      contributionTotal += category.contributionUsed;
    }
    if ((contributionTotal - record.totalScore).abs() > 0.01) {
      throw ArgumentError('Category contributions do not match total score.');
    }
  }
}

class DriveScoreRecordAdapter extends TypeAdapter<DriveScoreRecord> {
  @override
  final int typeId = DriveScoreHive.recordTypeId;

  @override
  DriveScoreRecord read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };
    final categories = (fields[6] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map(DriveScoreCategoryRecord.fromMap)
        .toList(growable: false);
    return DriveScoreRecord(
      driveId: fields[0] as String? ?? '',
      algorithmVersion: fields[1] as int? ?? 0,
      telemetryDataVersion: fields[2] as int? ?? 0,
      calculatedAt:
          fields[3] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
      totalScore: (fields[4] as num?)?.toDouble() ?? 0,
      overallConfidence: (fields[5] as num?)?.toDouble() ?? 0,
      categories: List.unmodifiable(categories),
    );
  }

  @override
  void write(BinaryWriter writer, DriveScoreRecord object) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(object.driveId)
      ..writeByte(1)
      ..write(object.algorithmVersion)
      ..writeByte(2)
      ..write(object.telemetryDataVersion)
      ..writeByte(3)
      ..write(object.calculatedAt)
      ..writeByte(4)
      ..write(object.totalScore)
      ..writeByte(5)
      ..write(object.overallConfidence)
      ..writeByte(6)
      ..write(object.categories.map((category) => category.toMap()).toList());
  }
}
