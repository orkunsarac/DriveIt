import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'group_drive_models.dart';

/// Stable server slots. Blue is reserved for the viewing account on each device.
const groupMemberPalette = <Color>[
  Color(0xffff8066),
  Color(0xfff8c555),
  Color(0xff8fd46c),
  Color(0xff35d1b6),
  Color(0xffc28bff),
  Color(0xffff80bd),
  Color(0xffe6e6ed),
  Color(0xffc8a475),
  Color(0xffd7e85b),
  Color(0xffa8a6ff),
];
Color groupMemberColor(GroupDriveMember member, String? viewer) =>
    member.accountId == viewer
    ? const Color(0xff2997ff)
    : groupMemberPalette[member.colorIndex];

String groupMemberInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  return (words.length == 1
          ? words.first.characters.take(2).join()
          : '${words.first.characters.first}${words.last.characters.first}')
      .toUpperCase();
}

/// Derive motion only when two accepted real fixes establish displacement
/// beyond their combined uncertainty. No invented speed/heading enters GPS.
class GroupMotion {
  const GroupMotion({this.moving = false, this.heading = 0});
  final bool moving;
  final double heading;
  static GroupMotion between(GroupLocationPoint? from, GroupLocationPoint to) {
    if (from == null ||
        from.origin != GroupLocationOrigin.deviceGps ||
        to.origin != GroupLocationOrigin.deviceGps) {
      return const GroupMotion();
    }
    final dt = to.recordedAt.difference(from.recordedAt);
    if (dt <= Duration.zero || dt > groupGpsMaximumAge) {
      return const GroupMotion();
    }
    const rad = math.pi / 180;
    final a = from.latitude * rad, b = to.latitude * rad;
    final dy = (to.latitude - from.latitude) * rad;
    final dx = (to.longitude - from.longitude) * rad;
    final h =
        math.pow(math.sin(dy / 2), 2) +
        math.cos(a) * math.cos(b) * math.pow(math.sin(dx / 2), 2);
    final distance = 6371000 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
    if (distance <=
        math.max(4, (from.accuracyMeters ?? 75) + (to.accuracyMeters ?? 75))) {
      return const GroupMotion();
    }
    final heading = math.atan2(
      math.sin(dx) * math.cos(b),
      math.cos(a) * math.sin(b) - math.sin(a) * math.cos(b) * math.cos(dx),
    );
    return GroupMotion(moving: true, heading: (heading / rad + 360) % 360);
  }
}

/// Tiny cached PNGs drawn in code. No platform default marker, network asset,
/// image decoding Future, or icon regeneration on each GPS update.
class GroupMarkerIcons {
  static const double hitTargetSize = 36;
  static const double visualScale = 22 / 36;
  static final _cache = <String, BitmapDescriptor>{};
  static BitmapDescriptor icon(Color color, {required bool moving}) {
    final key = '${color.toARGB32()}:$moving';
    return _cache.putIfAbsent(
      key,
      () => BitmapDescriptor.bytes(
        _png(color, moving),
        width: hitTargetSize,
        height: hitTargetSize,
      ),
    );
  }

  static Uint8List _png(Color color, bool arrow) {
    const size = 64;
    final raw = BytesBuilder();
    final argb = color.toARGB32();
    for (var y = 0; y < size; y++) {
      raw.addByte(0);
      for (var x = 0; x < size; x++) {
        // Shrink artwork by 39%, retaining transparent padding and the native
        // marker's original hit canvas for selection on a small screen.
        final dx = (x - 31.5) / visualScale, dy = (y - 31.5) / visualScale;
        final inside = arrow
            ? (dy >= -25 &&
                  dy <= 22 &&
                  dx.abs() <= (dy + 25) * .52 &&
                  (dy <= 8 || dx.abs() >= (dy - 8) * .45))
            : dx * dx + dy * dy <= 19 * 19;
        final ring = !arrow && dx * dx + dy * dy <= 24 * 24;
        raw.add([
          argb >> 16 & 255,
          argb >> 8 & 255,
          argb & 255,
          inside ? 255 : (ring ? 65 : 0),
        ]);
      }
    }
    final png = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
    void chunk(String type, List<int> data) {
      final body = <int>[...type.codeUnits, ...data];
      var crc = 0xffffffff;
      for (final byte in body) {
        crc ^= byte;
        for (var i = 0; i < 8; i++) {
          crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
        }
      }
      final length = ByteData(4)..setUint32(0, data.length);
      final checksum = ByteData(4)..setUint32(0, crc ^ 0xffffffff);
      png
        ..add(length.buffer.asUint8List())
        ..add(body)
        ..add(checksum.buffer.asUint8List());
    }

    final header = ByteData(13)
      ..setUint32(0, size)
      ..setUint32(4, size)
      ..setUint8(8, 8)
      ..setUint8(9, 6);
    chunk('IHDR', header.buffer.asUint8List());
    chunk('IDAT', zlib.encode(raw.takeBytes()));
    chunk('IEND', const []);
    return png.takeBytes();
  }
}
