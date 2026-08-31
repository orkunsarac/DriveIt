import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Shared map visuals used by the live drive, drive details and replay.
class DriveMapVisuals {
  const DriveMapVisuals._();

  static const background = Color(0xff020c1d);
  static const activeRouteColor = Color(0xff3b93ff);
  static const pendingRouteColor = Color(0x663b93ff);
  static const activeRouteWidth = 6;

  static const darkMapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#0b172b"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#91a4c2"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#0b172b"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1d3150"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#12233d"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#061124"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]}
  ]''';

  static Future<BitmapDescriptor> createNavigationArrow({
    double scale = 1,
  }) async {
    const pixelRatio = 4.0;
    final logicalSize = 36.0 * scale;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(pixelRatio);
    final path = ui.Path()
      ..moveTo(logicalSize / 2, 4)
      ..lineTo(logicalSize - 9, logicalSize - 11)
      ..lineTo(logicalSize / 2, logicalSize - 19)
      ..lineTo(9, logicalSize - 11)
      ..close();
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = const ui.Color(0x99ff1744)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(logicalSize, logicalSize),
          const [ui.Color(0xffff4d6d), ui.Color(0xffd50032)],
        ),
    );
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const ui.Color(0xffffc1cc),
    );
    final image = await recorder.endRecording().toImage(
      (logicalSize * pixelRatio).round(),
      (logicalSize * pixelRatio).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      Uint8List.view(data!.buffer),
      imagePixelRatio: pixelRatio,
    );
  }

  /// Tiny trace-integrated flow tick. Unlike the live navigation arrow this
  /// is only two short wing strokes and never reads as a vehicle marker.
  static Future<BitmapDescriptor> createWorldFlowTick({
    required Color color,
    double scale = 1,
  }) async {
    const pixelRatio = 4.0;
    final logicalSize = 16.0 * scale;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(pixelRatio);
    final center = logicalSize / 2;
    final path = ui.Path()
      ..moveTo(center - 4.5, center - 2.5)
      ..lineTo(center, center + 1.5)
      ..lineTo(center + 4.5, center - 2.5)
      ..moveTo(center - 3, center)
      ..lineTo(center, center + 3)
      ..lineTo(center + 3, center);
    final glow = ui.Paint()
      ..color = color.withAlpha(110)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = ui.StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5);
    final stroke = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, stroke);
    final image = await recorder.endRecording().toImage(
      (logicalSize * pixelRatio).round(),
      (logicalSize * pixelRatio).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      Uint8List.view(data!.buffer),
      imagePixelRatio: pixelRatio,
    );
  }
}
