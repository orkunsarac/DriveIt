import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/route_point.dart';
import 'poster_canvas.dart';

/// A small, non-interactive preview of a drive's persisted route.
///
/// The projection is calculated once when the widget is created; scrolling the
/// poster selection list therefore does not rebuild a map or re-project GPS
/// points every frame.
class DriveRouteThumbnail extends StatelessWidget {
  DriveRouteThumbnail({super.key, required List<RoutePoint> route})
    : _projected = _project(route);

  final List<Offset> _projected;

  static List<Offset> _project(List<RoutePoint> route) =>
      List<Offset>.unmodifiable(projectPosterRoute(route));

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DriveRouteThumbnailPainter(_projected),
    child: const SizedBox.expand(),
  );
}

class _DriveRouteThumbnailPainter extends CustomPainter {
  const _DriveRouteThumbnailPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      final paint = Paint()
        ..color = const Color(0x33248fff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(size.width * .34, size.height * .5),
        Offset(size.width * .66, size.height * .5),
        paint,
      );
      return;
    }

    final minX = points.map((p) => p.dx).reduce(math.min);
    final maxX = points.map((p) => p.dx).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min);
    final maxY = points.map((p) => p.dy).reduce(math.max);
    final rangeX = math.max(maxX - minX, 1e-9);
    final rangeY = math.max(maxY - minY, 1e-9);
    const padding = 10.0;
    final scale = math.min(
      (size.width - padding * 2) / rangeX,
      (size.height - padding * 2) / rangeY,
    );
    final drawWidth = rangeX * scale;
    final drawHeight = rangeY * scale;
    final left = (size.width - drawWidth) / 2;
    final top = (size.height - drawHeight) / 2;
    final fitted = points
        .map(
          (p) => Offset(
            left + (p.dx - minX) * scale,
            top + (p.dy - minY) * scale,
          ),
        )
        .toList(growable: false);

    final path = Path()..moveTo(fitted.first.dx, fitted.first.dy);
    for (final point in fitted.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0x55248fff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xff59d9ff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(fitted.first, 2.7, Paint()..color = const Color(0xff54e5a1))
      ..drawCircle(fitted.last, 2.7, Paint()..color = const Color(0xffff637d));
  }

  @override
  bool shouldRepaint(covariant _DriveRouteThumbnailPainter oldDelegate) =>
      !identical(points, oldDelegate.points);
}
