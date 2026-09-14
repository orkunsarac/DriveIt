import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'poster_background.dart';
import 'poster_layout.dart';

class SavedDrivePoster {
  const SavedDrivePoster({
    required this.id,
    required this.driveId,
    required this.createdAt,
    required this.fileName,
    required this.backgroundSourceType,
    required this.startLabel,
    required this.endLabel,
    required this.showMaxSpeed,
    this.showLocation = true,
    this.showDate = true,
    this.showScore = true,
    this.showRoute = true,
    this.backgroundFileName,
    this.aiVehicle,
    this.layout,
  });
  final String id;
  final String driveId;
  final DateTime createdAt;
  final String fileName;
  final PosterBackgroundSourceType backgroundSourceType;
  final String? backgroundFileName;
  final Map<String, String>? aiVehicle;
  final String startLabel;
  final String endLabel;
  final bool showMaxSpeed;
  final bool showLocation;
  final bool showDate;
  final bool showScore;
  final bool showRoute;
  final PosterLayout? layout;

  Map<String, Object?> toMap() => {
    'id': id,
    'driveId': driveId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'fileName': fileName,
    'exportedPosterPath': fileName,
    'backgroundSourceType': backgroundSourceType.name,
    'backgroundFileName': backgroundFileName,
    'backgroundReference': backgroundFileName,
    'aiVehicle': aiVehicle,
    'startLabel': startLabel,
    'endLabel': endLabel,
    'showMaxSpeed': showMaxSpeed,
    'showLocation': showLocation,
    'showDate': showDate,
    'showScore': showScore,
    'showRoute': showRoute,
    'templateVersion': 2,
    'layout': layout?.toMap(),
  };

  factory SavedDrivePoster.fromMap(Map value) {
    final sourceName = value['backgroundSourceType'] as String?;
    final matches = PosterBackgroundSourceType.values.where(
      (candidate) => candidate.name == sourceName,
    );
    final rawAi = value['aiVehicle'];
    return SavedDrivePoster(
      id: value['id'] as String? ?? '',
      driveId: value['driveId'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        value['createdAt'] as int? ?? 0,
      ),
      fileName:
          value['exportedPosterPath'] as String? ??
          value['fileName'] as String? ??
          '',
      backgroundSourceType: matches.isEmpty
          ? PosterBackgroundSourceType.customImage
          : matches.first,
      backgroundFileName:
          value['backgroundReference'] as String? ??
          value['backgroundFileName'] as String?,
      aiVehicle: rawAi is Map
          ? rawAi.map((key, item) => MapEntry('$key', '$item'))
          : null,
      startLabel: value['startLabel'] as String? ?? '',
      endLabel: value['endLabel'] as String? ?? '',
      showMaxSpeed: value['showMaxSpeed'] as bool? ?? true,
      showLocation: value['showLocation'] as bool? ?? true,
      showDate: value['showDate'] as bool? ?? true,
      showScore: value['showScore'] as bool? ?? true,
      showRoute: value['showRoute'] as bool? ?? true,
      layout: value['layout'] is Map
          ? PosterLayout.fromMap(value['layout'] as Map)
          : null,
    );
  }
}

class PosterSaveRequest {
  const PosterSaveRequest({
    required this.driveId,
    required this.png,
    required this.backgroundSourceType,
    required this.startLabel,
    required this.endLabel,
    required this.showMaxSpeed,
    this.showLocation = true,
    this.showDate = true,
    this.showScore = true,
    this.showRoute = true,
    this.backgroundPath,
    this.aiVehicle,
    this.layout,
  });
  final String driveId;
  final Uint8List png;
  final PosterBackgroundSourceType backgroundSourceType;
  final String? backgroundPath;
  final Map<String, String>? aiVehicle;
  final String startLabel;
  final String endLabel;
  final bool showMaxSpeed;
  final bool showLocation;
  final bool showDate;
  final bool showScore;
  final bool showRoute;
  final PosterLayout? layout;
}

/// Poster metadata stays in its own untyped Hive box, avoiding typeId changes.
class PosterStore {
  PosterStore(this.box, this.directory, {this.temporaryDirectory});
  static const boxName = 'drive_posters';
  static const channel = MethodChannel('driveit/posters');
  final Box<dynamic> box;
  final Directory directory;
  final Directory? temporaryDirectory;

  static Future<PosterStore> open() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = await Directory(
      '${root.path}/posters',
    ).create(recursive: true);
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
    debugPrint(
      '[POSTER_SAVE] storage.ready directory=${directory.path} '
      'box=$boxName open=${box.isOpen}',
    );
    return PosterStore(box, directory);
  }

  List<SavedDrivePoster> get all {
    final result = box.values
        .whereType<Map>()
        .map(SavedDrivePoster.fromMap)
        .where((poster) => poster.id.isNotEmpty && poster.fileName.isNotEmpty)
        .toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  File file(SavedDrivePoster poster) {
    final reference = poster.fileName;
    return File(
      File(reference).isAbsolute ? reference : '${directory.path}/$reference',
    );
  }

  File? backgroundFile(SavedDrivePoster poster) {
    final reference = poster.backgroundFileName;
    if (reference == null || reference.isEmpty) return null;
    return File(
      File(reference).isAbsolute ? reference : '${directory.path}/$reference',
    );
  }

  /// Removes only the app-private poster record and its local files.
  /// MediaStore/gallery copies are intentionally not referenced here.
  Future<void> delete(SavedDrivePoster poster) async {
    final posterFile = file(poster);
    final localBackground = backgroundFile(poster);
    debugPrint(
      '[POSTER_DELETE] start id=${poster.id} '
      'posterPath=${posterFile.path} '
      'backgroundPath=${localBackground?.path ?? 'none'}',
    );
    Object? fileError;
    for (final candidate in [posterFile, localBackground]) {
      if (candidate == null || !await candidate.exists()) {
        if (candidate != null) {
          debugPrint(
            '[POSTER_DELETE] file.skip_missing id=${poster.id} '
            'path=${candidate.path}',
          );
        }
        continue;
      }
      try {
        await candidate.delete();
        debugPrint(
          '[POSTER_DELETE] file.deleted id=${poster.id} path=${candidate.path}',
        );
      } catch (error, stackTrace) {
        fileError ??= error;
        debugPrint(
          '[POSTER_DELETE] file.failed id=${poster.id} '
          'path=${candidate.path} error=$error',
        );
        debugPrintStack(
          label: '[POSTER_DELETE] file.stack',
          stackTrace: stackTrace,
        );
      }
    }
    if (fileError != null) {
      throw FileSystemException('Poster dosyası silinemedi.', posterFile.path);
    }
    try {
      await box.delete(poster.id);
      await box.flush();
      if (box.containsKey(poster.id)) {
        throw StateError('Poster Hive kaydı silinemedi: ${poster.id}');
      }
      debugPrint('[POSTER_DELETE] hive.deleted id=${poster.id}');
    } catch (error, stackTrace) {
      debugPrint(
        '[POSTER_DELETE] hive.failed id=${poster.id} error=$error '
        'filesAlreadyDeleted=true',
      );
      debugPrintStack(
        label: '[POSTER_DELETE] hive.stack',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<SavedDrivePoster> save(PosterSaveRequest request) async {
    final png = request.png;
    if (png.length < 8 || png[0] != 137 || png[1] != 80) {
      throw ArgumentError('PNG bekleniyor.');
    }
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final outputName = '$id.png';
    String? backgroundName;
    final sourcePath = request.backgroundPath;
    if (sourcePath != null && await File(sourcePath).exists()) {
      final extension = sourcePath.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';
      backgroundName = '$id-background.$extension';
    }
    final poster = SavedDrivePoster(
      id: id,
      driveId: request.driveId,
      createdAt: now,
      fileName: outputName,
      backgroundSourceType: request.backgroundSourceType,
      backgroundFileName: backgroundName,
      aiVehicle: request.aiVehicle,
      startLabel: request.startLabel,
      endLabel: request.endLabel,
      showMaxSpeed: request.showMaxSpeed,
      showLocation: request.showLocation,
      showDate: request.showDate,
      showScore: request.showScore,
      showRoute: request.showRoute,
      layout: request.layout,
    );
    final output = file(poster);
    final temporary = File('${output.path}.tmp');
    File? backgroundOutput;
    try {
      debugPrint(
        '[POSTER_SAVE] file.write.start temp=${temporary.path} bytes=${png.length}',
      );
      await temporary.writeAsBytes(png, flush: true);
      await _requireValidPngFile(temporary, expectedLength: png.length);
      debugPrint(
        '[POSTER_SAVE] file.write.done temp=${temporary.path} '
        'size=${await temporary.length()}',
      );
      if (backgroundName != null) {
        backgroundOutput = File('${directory.path}/$backgroundName');
        await File(sourcePath!).copy(backgroundOutput.path);
        debugPrint(
          '[POSTER_SAVE] background.copy.done path=${backgroundOutput.path}',
        );
      }
      await temporary.rename(output.path);
      final outputLength = await _requireValidPngFile(
        output,
        expectedLength: png.length,
      );
      debugPrint(
        '[POSTER_SAVE] file.commit.done path=${output.path} '
        'exists=true size=$outputLength',
      );
      await box.put(id, poster.toMap());
      debugPrint('[POSTER_SAVE] hive.put.done id=$id');
      await box.flush();
      final stored = box.get(id);
      if (stored is! Map) {
        throw StateError('Poster Hive kaydı doğrulanamadı: $id');
      }
      final restored = SavedDrivePoster.fromMap(stored);
      if (restored.fileName != outputName || !await file(restored).exists()) {
        throw StateError('Poster Hive dosya referansı geçersiz: $id');
      }
      debugPrint(
        '[POSTER_SAVE] hive.flush.done id=$id exists=${box.containsKey(id)} '
        'reference=${restored.fileName} resolvedPath=${file(restored).path}',
      );
      return poster;
    } catch (error, stackTrace) {
      debugPrint('[POSTER_SAVE] storage.failed id=$id error=$error');
      debugPrintStack(
        label: '[POSTER_SAVE] storage.stack',
        stackTrace: stackTrace,
      );
      if (await temporary.exists()) await temporary.delete();
      if (box.containsKey(id)) await box.delete(id);
      if (await output.exists()) await output.delete();
      if (backgroundOutput != null && await backgroundOutput.exists()) {
        await backgroundOutput.delete();
      }
      rethrow;
    }
  }

  Future<String> savePngToGallery(Uint8List png) async {
    _requirePngBytes(png);
    final tempRoot = temporaryDirectory ?? await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final temporary = File('${tempRoot.path}/DriveIt_Poster_$timestamp.png');
    try {
      debugPrint(
        '[POSTER_SAVE] gallery.temp.write.start path=${temporary.path} '
        'bytes=${png.length}',
      );
      await temporary.writeAsBytes(png, flush: true);
      final length = await _requireValidPngFile(
        temporary,
        expectedLength: png.length,
      );
      debugPrint(
        '[POSTER_SAVE] gallery.temp.write.done path=${temporary.path} '
        'exists=true size=$length',
      );
      return await _saveFileToGallery(
        temporary,
        'DriveIt_Poster_$timestamp.png',
      );
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<String> saveToGallery(SavedDrivePoster poster) async {
    final source = file(poster);
    await _requireValidPngFile(source);
    return _saveFileToGallery(source, 'DriveIt_Poster_${poster.id}.png');
  }

  Future<String> _saveFileToGallery(File source, String name) async {
    debugPrint(
      '[POSTER_SAVE] android.gallery.start path=${source.path} name=$name',
    );
    final uri = await channel.invokeMethod<String>('saveToGallery', {
      'path': source.path,
      'name': name,
    });
    if (uri == null || !uri.startsWith('content://')) {
      throw StateError('MediaStore geçerli bir URI döndürmedi: $uri');
    }
    debugPrint('[POSTER_SAVE] android.gallery.done uri=$uri');
    return uri;
  }

  Future<void> share(SavedDrivePoster poster) async {
    final source = file(poster);
    await _requireValidPngFile(source);
    debugPrint('[POSTER_SAVE] android.share.start path=${source.path}');
    await channel.invokeMethod<void>('sharePng', {
      'path': source.path,
      'name': 'DriveIt_Poster_${poster.id}.png',
    });
    debugPrint('[POSTER_SAVE] android.share.done path=${source.path}');
  }

  static void _requirePngBytes(Uint8List png) {
    if (png.length < 8 ||
        png[0] != 137 ||
        png[1] != 80 ||
        png[2] != 78 ||
        png[3] != 71) {
      throw StateError('PNG byte verisi boş veya geçersiz.');
    }
  }

  static Future<int> _requireValidPngFile(
    File file, {
    int? expectedLength,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('Poster dosyası oluşturulamadı.', file.path);
    }
    final length = await file.length();
    if (length <= 0 || (expectedLength != null && length != expectedLength)) {
      throw FileSystemException(
        'Poster dosyası boş veya eksik yazıldı ($length byte).',
        file.path,
      );
    }
    final header = await file
        .openRead(0, 8)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    _requirePngBytes(Uint8List.fromList(header));
    return length;
  }
}
