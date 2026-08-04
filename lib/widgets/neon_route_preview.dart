import 'package:flutter/material.dart';
import '../models/route_point.dart';

class NeonRoutePreview extends StatelessWidget {
  final List<RoutePoint> route;
  const NeonRoutePreview({super.key, required this.route});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _NeonRoutePainter(route),
    child: const SizedBox.expand(),
  );
}

class _NeonRoutePainter extends CustomPainter {
  final List<RoutePoint> route;
  _NeonRoutePainter(this.route);
  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;
    final minLat = route.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = route.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = route
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = route
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);
    final dx = (maxLng - minLng).abs() < .00001 ? 1 : maxLng - minLng;
    final dy = (maxLat - minLat).abs() < .00001 ? 1 : maxLat - minLat;
    final points = <Offset>[];
    for (var i = 0; i < route.length; i++) {
      final p = route[i];
      final point = Offset(
        12 + (p.longitude - minLng) / dx * (size.width - 24),
        size.height - 12 - (p.latitude - minLat) / dy * (size.height - 24),
      );
      points.add(point);
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x88218dff)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xff42d8ff), Color(0xff7b8cff), Color(0xffbd5cff)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
    // Keep endpoint pins attached to the actual transformed route points.
    // Fixed corners caused the pins to drift away from the rendered route.
    final first = points.first;
    final last = points.last;
    canvas.drawCircle(first, 6, Paint()..color = const Color(0xff2f9bff));
    canvas.drawCircle(last, 6, Paint()..color = const Color(0xffef405d));
    canvas.drawCircle(first, 2.5, Paint()..color = const Color(0xffd9f3ff));
    canvas.drawCircle(last, 2.5, Paint()..color = const Color(0xffffd9df));
  }

  @override
  bool shouldRepaint(covariant _NeonRoutePainter old) => old.route != route;
}
