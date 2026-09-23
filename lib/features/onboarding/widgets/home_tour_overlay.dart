import 'dart:ui';

import 'package:flutter/material.dart';

class HomeTourStep {
  const HomeTourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.radius,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final double radius;
}

class HomeTourOverlay extends StatefulWidget {
  const HomeTourOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  final List<HomeTourStep> steps;
  final Future<void> Function() onComplete;

  @override
  State<HomeTourOverlay> createState() => _HomeTourOverlayState();
}

class _HomeTourOverlayState extends State<HomeTourOverlay> {
  final _overlayKey = GlobalKey();
  var _stepIndex = 0;
  Rect? _targetRect;
  bool _busy = false;

  HomeTourStep get _step => widget.steps[_stepIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  void _measureTarget() {
    if (!mounted) return;
    final targetContext = _step.targetKey.currentContext;
    final overlayContext = _overlayKey.currentContext;
    final targetBox = targetContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlayContext?.findRenderObject() as RenderBox?;
    if (targetBox == null || overlayBox == null || !targetBox.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
      return;
    }
    final globalOrigin = targetBox.localToGlobal(Offset.zero);
    final localOrigin = overlayBox.globalToLocal(globalOrigin);
    final padding = _stepIndex == 0 ? 11.0 : 9.0;
    final rect = (localOrigin & targetBox.size).inflate(padding);
    if (_targetRect != rect) setState(() => _targetRect = rect);
  }

  Future<void> _advance() async {
    if (_busy || _targetRect == null) return;
    if (_stepIndex == widget.steps.length - 1) {
      setState(() => _busy = true);
      try {
        await widget.onComplete();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    setState(() {
      _busy = true;
      _stepIndex++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureTarget();
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted) setState(() => _busy = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: SizedBox.expand(
          key: _overlayKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (rect == null) {
                return const ColoredBox(color: Color(0xB8000610));
              }
              return TweenAnimationBuilder<Rect?>(
                tween: RectTween(begin: rect, end: rect),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, animatedRect, _) {
                  final spotlight = animatedRect ?? rect;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SpotlightPainter(
                            rect: spotlight,
                            radius: _step.radius,
                          ),
                        ),
                      ),
                      _descriptionBubble(constraints.biggest, spotlight),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _descriptionBubble(Size size, Rect spotlight) {
    const horizontalMargin = 22.0;
    const gap = 18.0;
    const estimatedHeight = 190.0;
    final belowTop = spotlight.bottom + gap;
    final fitsBelow = size.height - belowTop >= estimatedHeight + 20;
    final top = fitsBelow ? belowTop : null;
    final bottom = fitsBelow ? null : size.height - spotlight.top + gap;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: horizontalMargin,
      right: horizontalMargin,
      top: top,
      bottom: bottom,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: ClipRRect(
          key: ValueKey(_stepIndex),
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xE6081728),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xCC248FFF)),
                boxShadow: const [
                  BoxShadow(color: Color(0x55248FFF), blurRadius: 20),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _step.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _step.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .76),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Text(
                        '${_stepIndex + 1} / ${widget.steps.length}',
                        style: const TextStyle(
                          color: Color(0xFF43B4FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _stepIndex == widget.steps.length - 1
                              ? "DriveIt'ı keşfetmek için dokun"
                              : 'Devam etmek için ekrana dokun',
                          maxLines: 2,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .52),
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.rect, required this.radius});

  final Rect rect;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final cutout = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = const Color(0xB8000610));
    canvas.drawRRect(
      cutout,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      cutout,
      Paint()
        ..color = const Color(0xCC2AA8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.radius != radius;
}
