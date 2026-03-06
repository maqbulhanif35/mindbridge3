import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/design_tokens.dart';

/// Animated circular wellness score ring.
/// Shows score as an arc with gradient fill and center stat display.
class MoodRing extends StatefulWidget {
  final double score; // 0–100
  final double size;
  final bool showLabel;
  final bool animate;
  final VoidCallback? onTap;

  const MoodRing({
    super.key,
    required this.score,
    this.size = 120,
    this.showLabel = true,
    this.animate = true,
    this.onTap,
  });

  @override
  State<MoodRing> createState() => _MoodRingState();
}

class _MoodRingState extends State<MoodRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: widget.score / 100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MoodRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _scoreAnim = Tween<double>(
        begin: oldWidget.score / 100,
        end: widget.score / 100,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band = WellnessTokens.bandFor(widget.score);
    final gradient = WellnessTokens.gradientFor(band);
    final strokeWidth = widget.size * 0.085;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scoreAnim,
        builder: (context, child) => SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingTrackPainter(
                  strokeWidth: strokeWidth,
                  trackColor: context.tokenSurfaceVariant,
                ),
              ),
              // Gradient filled arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingFillPainter(
                  progress: _scoreAnim.value,
                  strokeWidth: strokeWidth,
                  gradient: gradient,
                ),
              ),
              // Center content
              if (widget.showLabel) _buildCenterContent(context, band),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterContent(BuildContext context, WellnessBand band) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.score.toInt().toString(),
          style: TextStyle(
            fontSize: widget.size * 0.22,
            fontWeight: FontWeight.w800,
            color: WellnessTokens.colorFor(band),
            height: 1,
          ),
        ),
        Text(
          WellnessTokens.labelFor(band),
          style: TextStyle(
            fontSize: widget.size * 0.09,
            fontWeight: FontWeight.w600,
            color: context.tokenTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 600.ms);
  }
}

class _RingTrackPainter extends CustomPainter {
  final double strokeWidth;
  final Color trackColor;

  _RingTrackPainter({required this.strokeWidth, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RingFillPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final LinearGradient gradient;

  static const _startAngle = -pi / 2 + 0.3;
  static const _maxSweep = 2 * pi - 0.6;

  _RingFillPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepAngle = _maxSweep * progress;

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, sweepAngle, false, paint);

    // Glow effect at the tip
    if (progress > 0.05) {
      final tipAngle = _startAngle + sweepAngle;
      final tipX = center.dx + radius * cos(tipAngle);
      final tipY = center.dy + radius * sin(tipAngle);

      final glowPaint = Paint()
        ..color = gradient.colors.last.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset(tipX, tipY), strokeWidth / 2 + 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingFillPainter old) =>
      old.progress != progress;
}

const _startAngle = -pi / 2 + 0.3;
const _sweepAngle = 2 * pi - 0.6;


// ─── Mini Mood Ring ───────────────────────────────────────

/// Compact version for use in list items and cards.
class MiniMoodRing extends StatelessWidget {
  final double score;
  final double size;

  const MiniMoodRing({super.key, required this.score, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return MoodRing(
      score: score,
      size: size,
      showLabel: false,
      animate: false,
    );
  }
}

// ─── Mood Score Badge ─────────────────────────────────────

/// Simple number badge showing a mood score (1–10) with color.
class MoodScoreBadge extends StatelessWidget {
  final int moodScore;
  final double size;

  const MoodScoreBadge({super.key, required this.moodScore, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = MoodTokens.colorFor(moodScore);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: MoodTokens.gradientFor(moodScore),
        shape: BoxShape.circle,
        boxShadow: AppShadow.coloredSm(color),
      ),
      child: Center(
        child: Text(
          moodScore.toString(),
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
