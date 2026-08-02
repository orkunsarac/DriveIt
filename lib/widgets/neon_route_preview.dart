import 'package:flutter/material.dart';
import '../models/route_point.dart';

class NeonRoutePreview extends StatelessWidget {
  final List<RoutePoint> route;
  const NeonRoutePreview({super.key, required this.route});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _NeonRoutePainter(route), child: const SizedBox.expand());
}

class _NeonRoutePainter extends CustomPainter {
  final List<RoutePoint> route;
  _NeonRoutePainter(this.route);
  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;
    final minLat = route.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = route.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = route.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = route.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    final dx = (maxLng - minLng).abs() < .00001 ? 1 : maxLng - minLng;
    final dy = (maxLat - minLat).abs() < .00001 ? 1 : maxLat - minLat;
    final path = Path();
    for (var i = 0; i < route.length; i++) {
      final p = route[i];
      final point = Offset(12 + (p.longitude - minLng) / dx * (size.width - 24), size.height - 12 - (p.latitude - minLat) / dy * (size.height - 24));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round..color = const Color(0x66218dff)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = const Color(0xff53a9ff));
    final first = Offset(12, size.height - 12); final last = Offset(size.width - 12, 12);
    canvas.drawCircle(first, 5, Paint()..color = const Color(0xff4fffc0));
    canvas.drawCircle(last, 5, Paint()..color = const Color(0xffb785ff));
  }
  @override bool shouldRepaint(covariant _NeonRoutePainter old) => old.route != route;
}
