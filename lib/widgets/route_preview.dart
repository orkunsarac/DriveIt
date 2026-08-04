import 'package:flutter/material.dart';
import '../models/route_point.dart';

class RoutePreview extends StatelessWidget {
  final List<RoutePoint> route;

  const RoutePreview({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RoutePainter(route),
      child: const SizedBox(width: double.infinity, height: 150),
    );
  }
}

class RoutePainter extends CustomPainter {
  final List<RoutePoint> route;

  RoutePainter(this.route);

  @override
  void paint(Canvas canvas, Size size) {
    // Arka plan
    final bgPaint = Paint()..color = const Color(0xFFF3F5F7);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Izgara
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;

    const grid = 30.0;

    for (double x = 0; x < size.width; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 0; y < size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (route.length < 2) {
      final tp = TextPainter(
        text: const TextSpan(
          text: "Rota bulunamadı",
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
        textDirection: TextDirection.ltr,
      );

      tp.layout();

      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );

      return;
    }

    final minLat = route.map((e) => e.latitude).reduce((a, b) => a < b ? a : b);

    final maxLat = route.map((e) => e.latitude).reduce((a, b) => a > b ? a : b);

    final minLng = route
        .map((e) => e.longitude)
        .reduce((a, b) => a < b ? a : b);

    final maxLng = route
        .map((e) => e.longitude)
        .reduce((a, b) => a > b ? a : b);

    const padding = 15.0;

    Offset convert(RoutePoint p) {
      final x =
          ((p.longitude - minLng) /
                  ((maxLng - minLng) == 0 ? 1 : (maxLng - minLng))) *
              (size.width - padding * 2) +
          padding;

      final y =
          ((p.latitude - minLat) /
                  ((maxLat - minLat) == 0 ? 1 : (maxLat - minLat))) *
              (size.height - padding * 2) +
          padding;

      return Offset(x, size.height - y);
    }

    final path = Path();

    path.moveTo(convert(route.first).dx, convert(route.first).dy);

    for (final point in route.skip(1)) {
      final p = convert(point);
      path.lineTo(p.dx, p.dy);
    }

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, shadowPaint);

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    final start = convert(route.first);
    final finish = convert(route.last);

    canvas.drawCircle(start, 8, Paint()..color = const Color(0xff2f9bff));

    canvas.drawCircle(finish, 8, Paint()..color = const Color(0xffef405d));

    canvas.drawCircle(start, 3, Paint()..color = const Color(0xffd9f3ff));

    canvas.drawCircle(finish, 3, Paint()..color = const Color(0xffffd9df));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
