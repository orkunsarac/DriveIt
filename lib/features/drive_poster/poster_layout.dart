import 'dart:math' as math;
import 'package:flutter/material.dart';

// Route editing uses the full poster canvas; fixed presentation layers may be
// overlapped while a minimum part of the route remains recoverable.
const posterEditArea = Rect.fromLTWH(0, 0, 360, 640);
const posterMinimumScale = .35;
const posterMaximumScale = 3.0;
const posterMinimumVisibleFraction = .15;

enum PosterElement { score, route }

/// Positions are normalized centers within the editable area, never GPS data.
class PosterTransform {
  const PosterTransform({this.x = .5, this.y = .5, this.scale = 1});
  final double x;
  final double y;
  final double scale;

  Rect rect(Size base) {
    final safe = constrained(base);
    return Rect.fromCenter(
      center: Offset(
        posterEditArea.left + safe.x * posterEditArea.width,
        posterEditArea.top + safe.y * posterEditArea.height,
      ),
      width: base.width * safe.scale,
      height: base.height * safe.scale,
    );
  }

  PosterTransform constrained(Size base) {
    final s = (scale.isFinite ? scale : 1.0).clamp(
      posterMinimumScale,
      posterMaximumScale,
    );
    final width = base.width * s;
    final height = base.height * s;
    final halfWidth = width / 2;
    final halfHeight = height / 2;
    final visibleWidth =
        math.min(width, posterEditArea.width) * posterMinimumVisibleFraction;
    final visibleHeight =
        math.min(height, posterEditArea.height) * posterMinimumVisibleFraction;
    final minCenterX = visibleWidth - halfWidth;
    final maxCenterX = posterEditArea.width - visibleWidth + halfWidth;
    final minCenterY = visibleHeight - halfHeight;
    final maxCenterY = posterEditArea.height - visibleHeight + halfHeight;
    final centerX =
        posterEditArea.left + (x.isFinite ? x : .5) * posterEditArea.width;
    final centerY =
        posterEditArea.top + (y.isFinite ? y : .5) * posterEditArea.height;
    return PosterTransform(
      x: centerX.clamp(minCenterX, maxCenterX) / posterEditArea.width,
      y: centerY.clamp(minCenterY, maxCenterY) / posterEditArea.height,
      scale: s,
    );
  }

  Map<String, double> toMap() => {'x': x, 'y': y, 'scale': scale};
  factory PosterTransform.fromMap(Map value) => PosterTransform(
    x: (value['x'] as num?)?.toDouble() ?? .5,
    y: (value['y'] as num?)?.toDouble() ?? .5,
    scale: (value['scale'] as num?)?.toDouble() ?? 1,
  );
}

class PosterLayout {
  const PosterLayout({
    required this.score,
    this.route = const PosterTransform(scale: .85),
  });
  final PosterTransform score;
  final PosterTransform route;
  Map<String, Object> toMap() => {
    'score': score.toMap(),
    'route': route.toMap(),
  };
  factory PosterLayout.fromMap(Map value) => PosterLayout(
    score: PosterTransform.fromMap(
      value['score'] is Map ? value['score'] as Map : {},
    ),
    route: PosterTransform.fromMap(
      value['route'] is Map ? value['route'] as Map : {},
    ),
  );
}

String posterDistrict(String value) {
  final text = value.trim();
  if (RegExp(r'^[-\d.,\s]+$').hasMatch(text)) return '—';
  final part = text.split(',').last.trim();
  if (RegExp(
    r'\b(caddesi|sokak|mahallesi|yolu)\b',
    caseSensitive: false,
  ).hasMatch(part)) {
    return '—';
  }
  return part.isEmpty ? '—' : part;
}
