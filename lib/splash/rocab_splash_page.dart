import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual layer of the splash: dark radial backdrop, drifting gold particles,
/// a golden route trace that forms the logo frame, the logo asset revealed
/// left-to-right, an orbiting dot that lands into the mark, a diagonal shine
/// sweep and a final ring pulse, with the brand wordmark below.
///
/// Startup/init/navigation stays in LoadingPage, which embeds this widget so
/// initialization runs in parallel with the animation and navigates when
/// [onAnimationCompleted] fires.
class RocabSplashVisual extends StatefulWidget {
  const RocabSplashVisual({super.key, this.onAnimationCompleted});

  final VoidCallback? onAnimationCompleted;

  @override
  State<RocabSplashVisual> createState() => _RocabSplashVisualState();
}

class _RocabSplashVisualState extends State<RocabSplashVisual>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _ambientController;

  late final Animation<double> _lineProgress;
  late final Animation<double> _markReveal;
  late final Animation<double> _markScale;
  late final Animation<double> _dotProgress;
  late final Animation<double> _shineProgress;
  late final Animation<double> _finalPulse;
  late final Animation<double> _contentExit;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4300),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _lineProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.25, curve: Curves.easeInOutCubic),
    );

    _markReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.48, curve: Curves.easeOutCubic),
    );

    _markScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.92, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.56),
      ),
    );

    _dotProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.62, curve: Curves.easeOutBack),
    );

    _shineProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 0.76, curve: Curves.easeInOut),
    );

    _finalPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 55),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.67, 0.89, curve: Curves.easeOut),
      ),
    );

    _contentExit = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.88, 1.00, curve: Curves.easeInCubic),
    );

    _controller.forward().whenCompleteOrCancel(() {
      if (mounted) widget.onAnimationCompleted?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = math.min(MediaQuery.sizeOf(context).width * 0.74, 330.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _ambientController]),
      builder: (context, _) {
        final exitScale = 1.0 + (_contentExit.value * 0.28);
        final exitOpacity = 1.0 - _contentExit.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.12),
                  radius: 1.05,
                  colors: [
                    Color(0xFF17120A),
                    Color(0xFF050505),
                    Colors.black,
                  ],
                ),
              ),
            ),
            CustomPaint(
              painter: _BackgroundParticlesPainter(
                progress: _ambientController.value,
              ),
            ),
            Center(
              child: Opacity(
                opacity: exitOpacity,
                child: Transform.scale(
                  scale: exitScale,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        _buildAmbientGlow(size),
                        CustomPaint(
                          size: Size.square(size),
                          painter: _LogoTracePainter(
                            progress: _lineProgress.value,
                          ),
                        ),
                        _buildLogoMark(size),
                        _buildDot(size),
                        _buildShine(size),
                        _buildPulse(size),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 70,
              child: Opacity(
                opacity: (_markReveal.value - _contentExit.value)
                    .clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - _markReveal.value)),
                  child: const Column(
                    children: [
                      Text(
                        'رُكّاب',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'مشوارك يبدأ بانسيابية',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAmbientGlow(double size) {
    final breathe = 0.85 + (_ambientController.value * 0.15);

    return Transform.scale(
      scale: breathe,
      child: Container(
        width: size * 0.88,
        height: size * 0.88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB900).withValues(alpha: 0.13),
              blurRadius: 80,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoMark(double size) {
    return Opacity(
      opacity: _markReveal.value,
      child: Transform.scale(
        scale: _markScale.value,
        child: ClipRect(
          clipper: _HorizontalRevealClipper(_markReveal.value),
          child: Image.asset(
            'assets/images/logo.png',
            width: size * 0.72,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildDot(double size) {
    final p = _dotProgress.value;
    final angle = math.pi * (1.9 - (1.9 * p));
    final radius = size * (0.52 * (1 - p));
    final target = Offset(size * 0.225, size * 0.22);
    final orbital = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    final current = Offset.lerp(orbital, target, p)!;
    final dotSize = size * 0.16 * (0.45 + (0.55 * p));

    return Transform.translate(
      offset: current,
      child: Opacity(
        opacity: p.clamp(0.0, 1.0),
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(color: const Color(0xFFFFB900), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB900).withValues(alpha: 0.5 * p),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShine(double size) {
    final x = -size + (_shineProgress.value * size * 2);

    return IgnorePointer(
      child: Opacity(
        opacity: _shineProgress.value > 0 && _shineProgress.value < 1 ? 1 : 0,
        child: ClipRect(
          child: SizedBox(
            width: size * 0.72,
            height: size * 0.72,
            child: Transform.translate(
              offset: Offset(x, 0),
              child: Transform.rotate(
                angle: -0.22,
                child: Container(
                  width: size * 0.13,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.72),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulse(double size) {
    final p = _finalPulse.value;

    return IgnorePointer(
      child: Opacity(
        opacity: p.clamp(0.0, 1.0),
        child: Container(
          width: size * (0.76 + p * 0.20),
          height: size * (0.76 + p * 0.20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFBE00).withValues(alpha: 1 - p),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFBE00).withValues(alpha: 0.25 * p),
                blurRadius: 48,
                spreadRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalRevealClipper extends CustomClipper<Rect> {
  const _HorizontalRevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(_HorizontalRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

class _LogoTracePainter extends CustomPainter {
  const _LogoTracePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // The warm-up frame can paint at 0x0; a zero-length path has no metrics.
    if (progress <= 0 || size.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..shader = const LinearGradient(
        colors: [
          Color(0x00FFB900),
          Color(0xFFFFD76B),
          Color(0xFFFFB900),
        ],
      ).createShader(Offset.zero & size);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15
      ..color = const Color(0xFFFFB900).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path()
      ..moveTo(size.width * 0.27, size.height * 0.77)
      ..lineTo(size.width * 0.27, size.height * 0.25)
      ..lineTo(size.width * 0.78, size.height * 0.25);

    final metric = path.computeMetrics().first;
    final segment = metric.extractPath(0, metric.length * progress);

    canvas.drawPath(segment, glow);
    canvas.drawPath(segment, paint);

    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent != null) {
      final dotPaint = Paint()
        ..color = const Color(0xFFFFE6A0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(tangent.position, 7, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_LogoTracePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _BackgroundParticlesPainter extends CustomPainter {
  const _BackgroundParticlesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // The warm-up frame can paint at 0x0; `% size.height` would produce NaN.
    if (size.isEmpty) return;

    final paint = Paint();

    for (var i = 0; i < 34; i++) {
      final seed = i * 19.73;
      final x = (math.sin(seed) * 0.5 + 0.5) * size.width;
      final baseY = (math.cos(seed * 0.77) * 0.5 + 0.5) * size.height;
      final y = (baseY - progress * (22 + (i % 5) * 5)) % size.height;
      final alpha = 0.025 + ((i % 4) * 0.012);

      paint.color = const Color(0xFFFFBE00).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 0.8 + (i % 3) * 0.45, paint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
