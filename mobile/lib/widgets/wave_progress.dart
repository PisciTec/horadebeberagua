import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Círculo com água animada em ondas (.wave-circle do PWA).
class WaveProgress extends StatefulWidget {
  final int percent; // 0..100
  final int total;
  final int goal;
  final double size;

  const WaveProgress({
    super.key,
    required this.percent,
    required this.total,
    required this.goal,
    this.size = 240,
  });

  @override
  State<WaveProgress> createState() => _WaveProgressState();
}

class _WaveProgressState extends State<WaveProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progresso: ${widget.percent}% da meta, ${widget.total} de ${widget.goal} ml',
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgSecondary,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 4),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 40),
          ],
        ),
        child: ClipOval(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.percent / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, level, _) => AnimatedBuilder(
              animation: _wave,
              builder: (context, _) => CustomPaint(
                painter: _WavePainter(level: level, phase: _wave.value * 2 * math.pi),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${widget.percent}%',
                        style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black38, blurRadius: 12)])),
                    Text('${widget.total} / ${widget.goal} ml',
                        style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            shadows: [Shadow(color: Colors.black38, blurRadius: 8)])),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double level; // 0..1
  final double phase;
  _WavePainter({required this.level, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;
    final baseY = size.height * (1 - level);
    final amp = level >= 1 ? 0.0 : 8.0;

    Path wave(double shift) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final y = baseY + math.sin((x / size.width * 2 * math.pi) + phase + shift) * amp;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      return path;
    }

    final rect = Offset.zero & size;
    canvas.drawPath(
      wave(math.pi),
      Paint()..color = AppColors.accent.withValues(alpha: 0.45),
    );
    canvas.drawPath(
      wave(0),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent, AppColors.primary],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.level != level || old.phase != phase;
}
