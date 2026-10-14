import 'dart:convert';
import 'dart:io';

import 'drive_source_provenance.dart';
import 'gps_session_ownership.dart';

/// Persistent, device-local Guest identity. It is never an Auth UID and stays
/// outside legacy Hive so the new owner store cannot relabel old records.
abstract final class DeviceGuestOwnerIdentity {
  static const _fileName = 'guest_owner_identity_v1.json';

  static Future<GpsOwner> loadOrCreate(Directory appSupportDirectory) async {
    final support = await appSupportDirectory.resolveSymbolicLinks();
    final file = File('$support${Platform.pathSeparator}$_fileName');
    if (await file.exists()) return _read(file);

    final identity = DriveSourceProvenance.newUuidV4();
    final temporary = File('${file.path}.pending');
    await temporary.writeAsString(
      jsonEncode({'version': 1, 'guestIdentity': identity}),
      flush: true,
    );
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      // A second app startup may win the create race. Never overwrite the
      // winning identity; validate and reuse it.
      if (!await file.exists()) rethrow;
      await temporary.delete().catchError((_) => temporary);
    }
    return _read(file);
  }

  static Future<GpsOwner> _read(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['version'] != 1) {
      throw StateError('Device Guest identity file is invalid');
    }
    final identity = decoded['guestIdentity'];
    if (identity is! String) {
      throw StateError('Device Guest identity is missing');
    }
    try {
      return GpsOwner.deviceGuest(identity);
    } on ArgumentError {
      throw StateError('Device Guest identity is invalid');
    }
  }
}
