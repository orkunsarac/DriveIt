import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class ImportFailure implements Exception {
  const ImportFailure(this.code);
  final String code;
  @override
  String toString() => 'Local import: $code'; // No paths or source contents.
}

abstract interface class ImportDisk {
  Future<int> availableBytes(Directory destination);
  Future<void> syncDirectory(Directory directory);
}

/// Unknown platform/plugin/permission is a failure, never an assumed capacity.
class AndroidImportDisk implements ImportDisk {
  static const channel = MethodChannel('driveit/local_import_storage');
  @override
  Future<int> availableBytes(Directory destination) async {
    final value = await channel.invokeMethod<int>('availableBytes', {
      'path': destination.path,
    });
    if (value == null || value < 0) {
      throw const ImportFailure('disk_unavailable');
    }
    return value;
  }

  @override
  Future<void> syncDirectory(Directory directory) =>
      channel.invokeMethod<void>('syncDirectory', {'path': directory.path});
}

class ImportDigestSink implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest value) {
    digest = value;
  }

  @override
  void close() {}
}

class ImportAsset {
  const ImportAsset({
    required this.id,
    required this.sourcePath,
    required this.hash,
    required this.bytes,
    required this.extension,
  });
  final String id;
  final String sourcePath;
  final String hash;
  final int bytes;
  final String extension;
  String get relativePath =>
      'assets/${sha256.convert(utf8.encode(id))}.$extension';
  Map<String, Object> get evidence => {
    'id': id,
    'sha256': hash,
    'bytes': bytes,
    'relativePath': relativePath,
  };
}

class OwnerAssetTransfer {
  OwnerAssetTransfer({required this.root, required this.disk, this.onChunk});
  final Directory root;
  final ImportDisk disk;

  /// Synthetic interruption seam; never supplied by Android bootstrap.
  final Future<void> Function(int totalBytes)? onChunk;
  static const chunkBytes = 64 * 1024;
  int largestChunk = 0;

  static bool within(String root, String candidate) {
    final base = Platform.isWindows ? root.toLowerCase() : root;
    final file = Platform.isWindows ? candidate.toLowerCase() : candidate;
    return file.startsWith('$base${Platform.pathSeparator}');
  }

  static void validatePath(String path) {
    if (path.isEmpty ||
        path.contains('\u0000') ||
        path.split(RegExp(r'[/\\]')).contains('..')) {
      throw const ImportFailure('unsafe_path');
    }
    final uri = Uri.tryParse(path);
    if (uri != null &&
        uri.hasScheme &&
        !RegExp(r'^[A-Za-z]:[/\\]').hasMatch(path)) {
      throw const ImportFailure('unsupported_file_uri');
    }
  }

  /// Reject links in every existing component, not only the final filename.
  static Future<void> noLinks(String path) async {
    var current = path;
    while (true) {
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const ImportFailure('unsafe_symlink');
      }
      final parent = Directory(current).parent.path;
      if (parent == current) break;
      current = parent;
    }
  }

  static Future<String> resolveSource(
    String reference,
    Directory base,
    List<Directory> allowedRoots,
  ) async {
    validatePath(reference);
    final file = File(
      File(reference).isAbsolute
          ? reference
          : '${base.path}${Platform.pathSeparator}$reference',
    );
    await noLinks(file.absolute.path);
    if (!await file.exists()) throw const ImportFailure('source_file_missing');
    final canonical = await file.resolveSymbolicLinks();
    var allowed = false;
    for (final root in allowedRoots) {
      final resolved = await root.resolveSymbolicLinks();
      if (within(resolved, canonical)) allowed = true;
    }
    if (!allowed) throw const ImportFailure('source_outside_app_roots');
    return canonical;
  }

  static Future<(String, int)> hashFile(File file) async {
    final output = ImportDigestSink();
    final input = sha256.startChunkedConversion(output);
    final handle = await file.open();
    var count = 0;
    try {
      while (true) {
        final chunk = await handle.read(chunkBytes);
        if (chunk.isEmpty) break;
        count += chunk.length;
        input.add(chunk);
      }
      input.close();
      return (output.digest!.toString(), count);
    } finally {
      await handle.close();
    }
  }

  Future<void> capacity(int requiredBytes) async {
    if (requiredBytes < 0) throw const ImportFailure('invalid_size');
    if (await disk.availableBytes(root) < requiredBytes) {
      throw const ImportFailure('insufficient_disk_space');
    }
  }

  Future<File> fileFor(ImportAsset asset) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.id) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.hash) ||
        !RegExp(r'^[a-z0-9]{1,8}$').hasMatch(asset.extension) ||
        asset.bytes < 0) {
      throw const ImportFailure('unsafe_asset_descriptor');
    }
    await noLinks(root.absolute.path);
    final canonical = await root.resolveSymbolicLinks();
    final file = File(
      '$canonical${Platform.pathSeparator}${asset.relativePath}',
    );
    await noLinks(file.path);
    if (!within(canonical, file.absolute.path)) {
      throw const ImportFailure('destination_outside_owner');
    }
    return file;
  }

  Future<void> verify(ImportAsset asset) async {
    final file = await fileFor(asset);
    if (!await file.exists()) throw const ImportFailure('target_file_missing');
    final digest = await hashFile(file);
    if (digest.$1 != asset.hash || digest.$2 != asset.bytes) {
      throw const ImportFailure('file_hash_mismatch');
    }
  }

  Future<File> copy(ImportAsset asset) async {
    final finalFile = await fileFor(asset);
    await finalFile.parent.create(recursive: true);
    await noLinks(finalFile.parent.path);
    if (await finalFile.exists()) {
      await verify(asset); // A different existing file is never overwritten.
      await disk.syncDirectory(finalFile.parent);
      return finalFile;
    }
    await capacity(asset.bytes + 8 * 1024 * 1024);
    final source = File(asset.sourcePath);
    await noLinks(source.path);
    final temporary = File('${finalFile.path}.part');
    await noLinks(temporary.path);
    // Only an importer-owned partial file is truncated on same-operation retry.
    final input = await source.open();
    RandomAccessFile? output;
    final digestSink = ImportDigestSink();
    final hash = sha256.startChunkedConversion(digestSink);
    var count = 0;
    try {
      output = await temporary.open(mode: FileMode.write);
      while (true) {
        final chunk = await input.read(chunkBytes);
        if (chunk.isEmpty) break;
        largestChunk = chunk.length > largestChunk
            ? chunk.length
            : largestChunk;
        await output.writeFrom(chunk);
        hash.add(chunk);
        count += chunk.length;
        await onChunk?.call(count);
      }
      hash.close();
      await output.flush();
      await output.close();
      output = null;
      if (count != asset.bytes || digestSink.digest.toString() != asset.hash) {
        throw const ImportFailure('source_changed_or_hash_mismatch');
      }
      final written = await hashFile(temporary);
      if (written.$1 != asset.hash || written.$2 != asset.bytes) {
        throw const ImportFailure('file_hash_mismatch');
      }
      if (await finalFile.exists()) {
        throw const ImportFailure('target_file_conflict');
      }
      await temporary.rename(finalFile.path);
      await disk.syncDirectory(finalFile.parent);
      await verify(asset);
      return finalFile;
    } finally {
      await input.close();
      await output?.close();
    }
  }
}
