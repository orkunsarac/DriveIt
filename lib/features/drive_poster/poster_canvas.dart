import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/drive_session.dart';
import '../../models/route_point.dart';
import 'poster_layout.dart';
import 'poster_theme.dart';

const posterSize = Size(360, 640);
const posterRouteRect = Rect.fromLTWH(24, 176, 312, 310);
const posterBlue = Color(0xff248fff);
const posterBadgeColumnWidth = 54.0;
const posterBadgeRightMargin = 7.2;
const posterBadgeTopMargin = 32.0;
const posterLogoAlphaTrimScale = 1.16;
const posterBadgePinSize = 11.0;
const posterStartPinColor = Color(0xff54e5a1);
const posterEndPinColor = Color(0xffff637d);

void _paintPosterPin(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(center, radius, Paint()..color = color);
}

String posterDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  return '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Projects persisted geometry for presentation without changing point order.
List<Offset> projectPosterRoute(List<RoutePoint> route) {
  final valid = route
      .where(
        (point) =>
            point.latitude.isFinite &&
            point.longitude.isFinite &&
            point.latitude.abs() <= 85 &&
            point.longitude.abs() <= 180,
      )
      .toList();
  if (valid.isEmpty) return const [];
  final projected = valid
      .map((point) {
        var longitude = point.longitude;
        while (longitude - valid.first.longitude > 180) {
          longitude -= 360;
        }
        while (longitude - valid.first.longitude < -180) {
          longitude += 360;
        }
        final latitude = point.latitude * math.pi / 180;
        return Offset(
          longitude * math.pi / 180,
          -math.log(math.tan(math.pi / 4 + latitude / 2)),
        );
      })
      .toList(growable: false);
  final minX = projected.map((point) => point.dx).reduce(math.min);
  final maxX = projected.map((point) => point.dx).reduce(math.max);
  final minY = projected.map((point) => point.dy).reduce(math.min);
  final maxY = projected.map((point) => point.dy).reduce(math.max);
  final scale = math.min(
    (posterRouteRect.width - 34) / math.max(maxX - minX, 1e-9),
    (posterRouteRect.height - 80) / math.max(maxY - minY, 1e-9),
  );
  final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
  return projected
      .map(
        (point) => Offset(
          posterRouteRect.center.dx + (point.dx - center.dx) * scale,
          posterRouteRect.center.dy + (point.dy - center.dy) * scale,
        ),
      )
      .toList(growable: false);
}

List<Rect> posterLocationLabelRects(List<Offset> points) {
  if (points.isEmpty) return const [];
  final selected = <Rect>[];
  for (var endpoint = 0; endpoint < 2; endpoint++) {
    final marker = endpoint == 0 ? points.first : points.last;
    final routeDirection = _endpointRouteDirection(
      points,
      isStart: endpoint == 0,
    );
    final preferredDirection = -routeDirection;
    const width = 108.0;
    const height = 34.0;
    const gap = 7.0;
    final candidates = <Rect>[
      Rect.fromLTWH(
        marker.dx - width - gap,
        marker.dy - height - gap,
        width,
        height,
      ),
      Rect.fromLTWH(marker.dx - width - gap, marker.dy + gap, width, height),
      Rect.fromLTWH(marker.dx + gap, marker.dy - height - gap, width, height),
      Rect.fromLTWH(marker.dx + gap, marker.dy + gap, width, height),
      Rect.fromLTWH(
        marker.dx - width - gap,
        marker.dy - height / 2,
        width,
        height,
      ),
      Rect.fromLTWH(marker.dx + gap, marker.dy - height / 2, width, height),
      Rect.fromLTWH(
        marker.dx - width / 2,
        marker.dy - height - gap,
        width,
        height,
      ),
      Rect.fromLTWH(marker.dx - width / 2, marker.dy + gap, width, height),
    ].map(_clampLabelRect);
    selected.add(
      candidates.reduce((best, candidate) {
        final bestPenalty = _labelPenalty(
          best,
          marker,
          preferredDirection,
          points,
          selected,
        );
        final candidatePenalty = _labelPenalty(
          candidate,
          marker,
          preferredDirection,
          points,
          selected,
        );
        return candidatePenalty < bestPenalty ? candidate : best;
      }),
    );
  }
  return selected;
}

Offset _endpointRouteDirection(List<Offset> points, {required bool isStart}) {
  final marker = isStart ? points.first : points.last;
  final indices = isStart
      ? Iterable<int>.generate(points.length - 1, (index) => index + 1)
      : Iterable<int>.generate(
          points.length - 1,
          (index) => points.length - 2 - index,
        );
  for (final index in indices) {
    final delta = isStart ? points[index] - marker : marker - points[index];
    if (delta.distance > 1) return delta / delta.distance;
  }
  return const Offset(1, 0);
}

Rect posterRouteContentRect(List<Offset> points, List<Rect> labels) {
  if (points.isEmpty) return posterRouteRect;
  var bounds = Rect.fromPoints(points.first, points.first);
  for (final point in points.skip(1)) {
    bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
  }
  for (final label in labels) {
    bounds = bounds.expandToInclude(label);
  }
  return bounds.inflate(10).intersect(Offset.zero & posterSize);
}

Rect _clampLabelRect(Rect rect) => Rect.fromLTWH(
  rect.left.clamp(8, posterSize.width - rect.width - 8),
  rect.top.clamp(8, posterSize.height - rect.height - 8),
  rect.width,
  rect.height,
);

double _labelPenalty(
  Rect candidate,
  Offset marker,
  Offset preferredDirection,
  List<Offset> route,
  List<Rect> occupied,
) {
  var penalty = 0.0;
  if (candidate.inflate(2).contains(marker)) penalty += 5000;
  final candidateDirection = candidate.center - marker;
  if (candidateDirection.distance > 0) {
    final alignment =
        (candidateDirection / candidateDirection.distance).dx *
            preferredDirection.dx +
        (candidateDirection / candidateDirection.distance).dy *
            preferredDirection.dy;
    penalty += (1 - alignment) * 60;
  }
  for (final rect in occupied) {
    if (candidate.inflate(5).overlaps(rect)) penalty += 10000;
  }
  for (final point in route) {
    if ((point - marker).distance > 4 && candidate.inflate(2).contains(point)) {
      penalty += 400;
    }
  }
  for (var index = 1; index < route.length; index++) {
    if (Rect.fromPoints(
      route[index - 1],
      route[index],
    ).inflate(2).overlaps(candidate)) {
      penalty += 500;
    }
  }
  return penalty;
}

Rect posterScoreRect(List<Offset> points) {
  const candidates = [
    Rect.fromLTWH(24, 176, 116, 72),
    Rect.fromLTWH(220, 176, 116, 72),
    Rect.fromLTWH(24, 350, 116, 72),
    Rect.fromLTWH(220, 350, 116, 72),
  ];
  final obstacles = posterLocationLabelRects(points);
  Rect? best;
  var bestPenalty = double.infinity;
  for (final candidate in candidates) {
    var penalty = 0.0;
    for (final label in obstacles) {
      if (label.inflate(5).overlaps(candidate)) penalty += 1000;
    }
    for (var index = 0; index < points.length; index++) {
      if (candidate.inflate(9).contains(points[index])) penalty += 20;
      if (index > 0 &&
          Rect.fromPoints(
            points[index - 1],
            points[index],
          ).inflate(5).overlaps(candidate.inflate(9))) {
        penalty += 8;
      }
    }
    if (penalty < bestPenalty) {
      best = candidate;
      bestPenalty = penalty;
    }
  }
  return best ?? candidates.first;
}

class PosterCanvas extends StatelessWidget {
  const PosterCanvas({
    super.key,
    required this.drive,
    required this.score,
    required this.startName,
    required this.endName,
    required this.showMaxSpeed,
    required this.backgroundPath,
    this.showLocation = true,
    this.showDate = true,
    this.showScore = true,
    this.showRoute = true,
    this.themeId = PosterThemeId.classic,
    this.logoVariant = PosterLogoVariant.symbol,
    this.layout,
    this.selectedElement,
    this.onTransform,
    this.onInteraction,
    this.onRouteTap,
    this.onCanvasTap,
  });

  final DriveSession drive;
  final double? score;
  final String startName;
  final String endName;
  final bool showMaxSpeed;
  final String backgroundPath;
  final bool showLocation;
  final bool showDate;
  final bool showScore;
  final bool showRoute;
  final PosterThemeId themeId;
  final PosterLogoVariant logoVariant;
  final PosterLayout? layout;
  final PosterElement? selectedElement;
  final void Function(PosterElement, PosterTransform)? onTransform;
  final void Function(bool active)? onInteraction;
  final VoidCallback? onRouteTap;
  final VoidCallback? onCanvasTap;

  @override
  Widget build(BuildContext context) {
    final theme = PosterThemeData.values.firstWhere(
      (candidate) => candidate.id == themeId,
    );
    final route = projectPosterRoute(drive.route);
    // Keep the established transform footprint so existing saved route
    // transforms reopen identically after route labels are removed.
    final labelRects = posterLocationLabelRects(route);
    final routeContentRect = posterRouteContentRect(route, labelRects);
    final arrangement = layout ?? automaticPosterLayout(route);
    final badgeGap = posterSize.height * .011;
    final badges = <Widget>[];
    TextStyle fittedStyle(
      String text,
      TextStyle style, {
      double horizontalSafety = 0,
    }) {
      final measuredStyle = style.copyWith(
        fontFamily: style.fontFamily ?? 'Roboto',
      );
      final painter = TextPainter(
        text: TextSpan(text: text, style: measuredStyle),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final baseSize = measuredStyle.fontSize ?? 14;
      final targetWidth = posterBadgeColumnWidth - horizontalSafety;
      final scale = targetWidth / math.max(painter.width, 1);
      return measuredStyle.copyWith(fontSize: baseSize * scale);
    }

    Widget module(String key, Widget child) => SizedBox(
      key: ValueKey(key),
      width: double.infinity,
      child: Center(child: child),
    );
    void addBadge(String key, Widget child) {
      if (badges.isNotEmpty) badges.add(SizedBox(height: badgeGap));
      badges.add(SizedBox(width: double.infinity, child: module(key, child)));
    }

    final logo = Image.asset(
      logoVariant == PosterLogoVariant.symbol
          ? 'assets/branding/driveit_logo_current.png'
          : 'assets/onboarding/driveit_wordmark.png',
      key: const Key('poster_fixed_logo'),
      width: posterBadgeColumnWidth,
      height: posterBadgeColumnWidth,
      fit: BoxFit.contain,
    );
    addBadge(
      'badge_logo',
      SizedBox(
        width: double.infinity,
        height: posterBadgeColumnWidth,
        child: ClipRect(
          child: Transform.scale(
            scale: posterLogoAlphaTrimScale,
            child: Opacity(
              opacity: .9,
              child: theme.tintLogo
                  ? ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        theme.logoTintColor,
                        BlendMode.srcIn,
                      ),
                      child: logo,
                    )
                  : logo,
            ),
          ),
        ),
      ),
    );
    if (showLocation) {
      addBadge(
        'badge_location_start',
        _PosterLocationBadge(
          key: const ValueKey('poster_start_badge'),
          pinKey: const ValueKey('poster_start_badge_pin'),
          helper: 'Başlangıç',
          location: posterDistrict(startName),
          color: theme.startPinColor,
          theme: theme,
        ),
      );
      addBadge(
        'badge_location_end',
        _PosterLocationBadge(
          key: const ValueKey('poster_end_badge'),
          pinKey: const ValueKey('poster_end_badge_pin'),
          helper: 'Bitiş',
          location: posterDistrict(endName),
          color: theme.endPinColor,
          theme: theme,
        ),
      );
    }
    if (showDate) {
      addBadge(
        'badge_date',
        Text(
          DateFormat('dd.MM.yyyy').format(drive.date),
          maxLines: 1,
          textAlign: TextAlign.center,
          style: fittedStyle(
            DateFormat('dd.MM.yyyy').format(drive.date),
            TextStyle(color: theme.secondaryTextColor, fontSize: 8),
          ),
        ),
      );
    }
    if (showScore) {
      addBadge(
        'badge_score',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              score?.round().toString() ?? '—',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: fittedStyle(
                score?.round().toString() ?? '—',
                TextStyle(
                  color: theme.scoreColor,
                  fontSize: 28,
                  height: .95,
                  fontWeight: FontWeight.w800,
                  shadows: theme.scoreGlowIntensity <= 0
                      ? const []
                      : [
                          Shadow(
                            color: theme.scoreGlowColor.withValues(
                              alpha: theme.scoreGlowIntensity,
                            ),
                            blurRadius: 8,
                          ),
                        ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              score == null ? 'DRIVE SCORE · VERİ YOK' : 'DRIVE SCORE / 1000',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: fittedStyle(
                score == null ? 'DRIVE SCORE · VERİ YOK' : 'DRIVE SCORE / 1000',
                TextStyle(
                  fontSize: 7,
                  height: 1.2,
                  letterSpacing: .35,
                  color: theme.secondaryTextColor,
                ),
                horizontalSafety: 2,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox.fromSize(
      size: posterSize,
      child: DefaultTextStyle(
        style: TextStyle(color: theme.primaryTextColor, fontFamily: 'Roboto'),
        child: GestureDetector(
          key: const ValueKey('poster_canvas_tap_area'),
          behavior: HitTestBehavior.opaque,
          onTap: onCanvasTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(backgroundPath),
                fit: BoxFit.cover,
                cacheWidth: 1440,
                errorBuilder: (_, _, _) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xff102842), Color(0xff020812)],
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xf2050c18),
                      Color(0x82050c18),
                      Color(0x22050c18),
                      Color(0x9e050c18),
                      Color(0xf5050c18),
                    ],
                    stops: [0, .19, .48, .78, 1],
                  ),
                ),
              ),
              if (showRoute)
                _PosterEditableLayer(
                  element: PosterElement.route,
                  transform: arrangement.route,
                  baseSize: routeContentRect.size,
                  selected: selectedElement == PosterElement.route,
                  onTransform: onTransform,
                  onInteraction: onInteraction,
                  onSelect: onRouteTap,
                  child: ClipRect(
                    key: const ValueKey('poster_route_visual'),
                    child: Transform.translate(
                      offset: -routeContentRect.topLeft,
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: 360,
                        maxWidth: 360,
                        minHeight: 640,
                        maxHeight: 640,
                        child: SizedBox.fromSize(
                          size: posterSize,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: PosterRoutePainter(
                                  route,
                                  theme: theme,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: posterBadgeRightMargin,
                top: posterBadgeTopMargin,
                width: posterBadgeColumnWidth,
                child: Column(
                  key: const ValueKey('poster_badge_column'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: badges,
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 42,
                child: Row(
                  children: [
                    _metric(
                      '${(drive.distance / 1000).toStringAsFixed(1)} km',
                      'MESAFE',
                      theme: theme,
                    ),
                    _metric(
                      posterDuration(drive.durationSeconds),
                      'SÜRE',
                      theme: theme,
                    ),
                    _metric(
                      drive.averageSpeed.toStringAsFixed(1),
                      'ORT. HIZ',
                      theme: theme,
                    ),
                    if (showMaxSpeed)
                      _metric(
                        drive.maxSpeed.toStringAsFixed(1),
                        'MAKS. HIZ',
                        theme: theme,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(
    String value,
    String label, {
    required PosterThemeData theme,
  }) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: theme.primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 7,
            letterSpacing: .5,
          ),
        ),
      ],
    ),
  );
}

class _PosterLocationBadge extends StatelessWidget {
  const _PosterLocationBadge({
    super.key,
    required this.pinKey,
    required this.helper,
    required this.location,
    required this.color,
    required this.theme,
  });
  final Key pinKey;
  final String helper;
  final String location;
  final Color color;
  final PosterThemeData theme;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          key: pinKey,
          size: const Size.square(posterBadgePinSize),
          painter: _PosterPinPainter(color),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 6.5,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.primaryTextColor,
                      fontSize: 8.25,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PosterPinPainter extends CustomPainter {
  const _PosterPinPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => _paintPosterPin(
    canvas,
    size.center(Offset.zero),
    math.min(size.width, size.height) / 2,
    color,
  );

  @override
  bool shouldRepaint(covariant _PosterPinPainter oldDelegate) =>
      oldDelegate.color != color;
}

class PosterRoutePainter extends CustomPainter {
  const PosterRoutePainter(this.points, {this.theme = PosterThemeData.classic});
  final List<Offset> points;
  final PosterThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      path.lineTo(points[index].dx, points[index].dy);
    }
    if (theme.routeGlowIntensity > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.routeGlowColor.withValues(
            alpha: theme.routeGlowIntensity,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.routeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (theme.id == PosterThemeId.blackout) {
      // Keep the charcoal route visible on dark photos with a restrained
      // smoke-gray edge, without reintroducing the neon palette.
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.routeGlowColor.withValues(alpha: .58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.routeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    _paintPosterPin(canvas, points.first, 4.2, theme.startPinColor);
    _paintPosterPin(canvas, points.last, 4.2, theme.endPinColor);
  }

  @override
  bool shouldRepaint(covariant PosterRoutePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.theme != theme;
}

PosterLayout automaticPosterLayout(List<Offset> points) {
  const route = PosterTransform(scale: .85);
  final score = posterScoreRect(
    points
        .map(
          (point) =>
              posterEditArea.center +
              (point - posterEditArea.center) * route.scale,
        )
        .toList(),
  );
  return PosterLayout(
    score: PosterTransform(
      x: (score.center.dx - posterEditArea.left) / posterEditArea.width,
      y: (score.center.dy - posterEditArea.top) / posterEditArea.height,
    ),
  );
}

class _PosterEditableLayer extends StatefulWidget {
  const _PosterEditableLayer({
    required this.element,
    required this.transform,
    required this.baseSize,
    required this.selected,
    required this.child,
    this.onTransform,
    this.onInteraction,
    this.onSelect,
  });
  final PosterElement element;
  final PosterTransform transform;
  final Size baseSize;
  final bool selected;
  final Widget child;
  final void Function(PosterElement, PosterTransform)? onTransform;
  final void Function(bool active)? onInteraction;
  final VoidCallback? onSelect;
  @override
  State<_PosterEditableLayer> createState() => _PosterEditableLayerState();
}

class _PosterEditableLayerState extends State<_PosterEditableLayer> {
  late PosterTransform _origin;
  final Map<int, Offset> _pointers = {};
  final Map<int, Offset> _starts = {};
  double _initialDistance = 0;
  bool _scaleHandleMode = false;

  void _begin(PointerDownEvent event) {
    if (_pointers.isEmpty) {
      _origin = widget.transform.constrained(widget.baseSize);
      const handleOverlap = 22.0;
      final frameWidth = widget.baseSize.width * _origin.scale;
      final frameHeight = widget.baseSize.height * _origin.scale;
      _scaleHandleMode =
          event.localPosition.dx >= frameWidth - handleOverlap &&
          event.localPosition.dy >= frameHeight - handleOverlap;
    }
    _pointers[event.pointer] = event.position;
    _starts[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _origin = widget.transform.constrained(widget.baseSize);
      for (final entry in _pointers.entries) {
        _starts[entry.key] = entry.value;
      }
      _initialDistance = (_starts.values.first - _starts.values.last).distance;
    }
    widget.onInteraction?.call(true);
  }

  void _update(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final startCenter = _average(_starts.values);
    final currentCenter = _average(_pointers.values);
    final delta = currentCenter - startCenter;
    final renderBox = context.findRenderObject() as RenderBox?;
    final globalScaleX = renderBox == null
        ? 1.0
        : (renderBox.localToGlobal(const Offset(1, 0)) -
                  renderBox.localToGlobal(Offset.zero))
              .distance;
    final globalScaleY = renderBox == null
        ? 1.0
        : (renderBox.localToGlobal(const Offset(0, 1)) -
                  renderBox.localToGlobal(Offset.zero))
              .distance;
    final posterDelta = Offset(
      delta.dx / math.max(globalScaleX, .0001),
      delta.dy / math.max(globalScaleY, .0001),
    );
    var scale = _origin.scale;
    if (_pointers.length >= 2 && _initialDistance > 0) {
      final distance =
          (_pointers.values.first - _pointers.values.last).distance;
      scale *= distance / _initialDistance;
    } else if (_scaleHandleMode) {
      final diagonal = math.max(
        widget.baseSize.width * _origin.scale * globalScaleX +
            widget.baseSize.height * _origin.scale * globalScaleY,
        1,
      );
      scale *= 1 + (delta.dx + delta.dy) / diagonal;
    }
    widget.onTransform!(
      widget.element,
      PosterTransform(
        x:
            _origin.x +
            (_scaleHandleMode ? 0 : posterDelta.dx / posterSize.width),
        y:
            _origin.y +
            (_scaleHandleMode ? 0 : posterDelta.dy / posterSize.height),
        scale: scale,
      ).constrained(widget.baseSize),
    );
  }

  Offset _average(Iterable<Offset> values) {
    var result = Offset.zero;
    var count = 0;
    for (final value in values) {
      result += value;
      count++;
    }
    return count == 0 ? Offset.zero : result / count.toDouble();
  }

  void _end(PointerEvent event) {
    _pointers.remove(event.pointer);
    _starts.remove(event.pointer);
    if (_pointers.isEmpty) widget.onInteraction?.call(false);
  }

  Widget _handle({required IconData icon, required Key key}) => Container(
    key: key,
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xcc07182b),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Color(0x77248fff), blurRadius: 7)],
    ),
    child: Icon(icon, size: 18, color: Color(0xff63dcff)),
  );

  @override
  Widget build(BuildContext context) {
    final rect = widget.transform.rect(widget.baseSize);
    const handleSize = 44.0;
    const handleOutside = handleSize / 2;
    Widget content = FittedBox(
      fit: BoxFit.fill,
      child: SizedBox.fromSize(size: widget.baseSize, child: widget.child),
    );
    if (widget.selected && widget.onTransform != null) {
      content = RawGestureDetector(
        gestures: {
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (_) {},
              ),
        },
        behavior: HitTestBehavior.opaque,
        child: Listener(
          key: ValueKey('poster_edit_${widget.element.name}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: _begin,
          onPointerMove: _update,
          onPointerUp: _end,
          onPointerCancel: _end,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: rect.width,
                height: rect.height,
                child: DecoratedBox(
                  key: const ValueKey('poster_route_selection_frame'),
                  decoration: BoxDecoration(
                    border: Border.all(color: posterBlue),
                  ),
                  child: content,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _handle(
                  key: const ValueKey('poster_route_scale_handle'),
                  icon: Icons.zoom_out_map_rounded,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (widget.onSelect != null) {
      content = GestureDetector(
        key: ValueKey('poster_select_${widget.element.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: content,
      );
    } else {
      content = IgnorePointer(child: content);
    }
    final presentationRect = widget.selected && widget.onTransform != null
        ? Rect.fromLTRB(
            rect.left,
            rect.top,
            rect.right + handleOutside,
            rect.bottom + handleOutside,
          )
        : rect;
    return Positioned.fromRect(rect: presentationRect, child: content);
  }
}
