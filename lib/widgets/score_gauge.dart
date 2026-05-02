import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/driver_score.dart';
import '../theme/app_theme.dart';

/// Gauge circular animado que exibe a pontuação do condutor (0–100).
///
/// O arco vai de -150° a +150° (270° total) centrado na parte inferior.
/// A cor muda progressivamente: vermelho → laranja → amarelo → verde.
class ScoreGauge extends StatefulWidget {
  final int score;
  final double size;
  final bool showLabel;

  const ScoreGauge({
    super.key,
    required this.score,
    this.size = 160,
    this.showLabel = true,
  });

  @override
  State<ScoreGauge> createState() => _ScoreGaugeState();
}

class _ScoreGaugeState extends State<ScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0, end: widget.score / 100.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(ScoreGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.score / 100.0,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = ScoreCategoryX.fromValue(widget.score);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return SizedBox(
          width: widget.size,
          height: widget.size * 0.85,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size * 0.85),
                painter: _GaugePainter(progress: _anim.value),
              ),
              if (widget.showLabel)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_anim.value * 100).round()}',
                      style: TextStyle(
                        fontSize: widget.size * 0.26,
                        fontWeight: FontWeight.w900,
                        color: _scoreColor(_anim.value),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: widget.size * 0.085,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

Color _scoreColor(double progress) {
  // Interpola: vermelho (0) → laranja (0.45) → amarelo (0.60) → verde (1.0)
  if (progress >= 0.75) {
    return Color.lerp(AppColors.warning, AppColors.success,
        (progress - 0.75) / 0.25)!;
  } else if (progress >= 0.45) {
    return Color.lerp(AppColors.accent, AppColors.warning,
        (progress - 0.45) / 0.30)!;
  } else {
    return Color.lerp(AppColors.danger, AppColors.accent, progress / 0.45)!;
  }
}

class _GaugePainter extends CustomPainter {
  final double progress; // 0.0 – 1.0

  const _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = 150 * math.pi / 180;  // começa em baixo-esquerda
    const sweepTotal = 240 * math.pi / 180;  // 240° de arco

    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = size.width * 0.44;
    final strokeW = size.width * 0.065;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Trilha (fundo)
    final trackPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepTotal, false, trackPaint);

    // Progresso
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = _scoreColor(progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
          rect, startAngle, sweepTotal * progress, false, progressPaint);
    }

    // Marcações nos limites das categorias (45, 60, 75, 90)
    for (final threshold in [45, 60, 75, 90]) {
      final angle = startAngle + sweepTotal * (threshold / 100.0);
      final tickStart = Offset(
        center.dx + (radius - strokeW * 0.7) * math.cos(angle),
        center.dy + (radius - strokeW * 0.7) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + (radius + strokeW * 0.7) * math.cos(angle),
        center.dy + (radius + strokeW * 0.7) * math.sin(angle),
      );
      canvas.drawLine(
        tickStart,
        tickEnd,
        Paint()
          ..color = AppColors.background
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}
