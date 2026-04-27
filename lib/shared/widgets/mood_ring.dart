import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Flat circular wellness score ring.
/// Shows score as an arc with solid fill and center stat display.
class MoodRing extends StatelessWidget {
  final double score; // 0–100
  final double size;
  final bool showLabel;
  final bool animate; // Ignored now
  final VoidCallback? onTap;

  const MoodRing({
    super.key,
    required this.score,
    this.size = 120,
    this.showLabel = true,
    this.animate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final band = WellnessTokens.bandFor(score);
    final color = WellnessTokens.colorFor(band);
    final strokeWidth = size * 0.12;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background track
            CustomPaint(
              size: Size(size, size),
              painter: _RingTrackPainter(
                strokeWidth: strokeWidth,
                trackColor: theme.colorScheme.surfaceContainerHighest,
                borderColor: theme.colorScheme.onSurface,
              ),
            ),
            // Solid filled arc
            CustomPaint(
              size: Size(size, size),
              painter: _RingFillPainter(
                progress: score / 100,
                strokeWidth: strokeWidth,
                color: color,
                borderColor: theme.colorScheme.onSurface,
              ),
            ),
            // Center content
            if (showLabel) _buildCenterContent(context, band),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterContent(BuildContext context, WellnessBand band) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          score.toInt().toString(),
          style: TextStyle(
            fontSize: size * 0.25,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            height: 1,
          ),
        ),
        Text(
          WellnessTokens.labelFor(band).toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.08,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RingTrackPainter extends CustomPainter {
  final double strokeWidth;
  final Color trackColor;
  final Color borderColor;

  _RingTrackPainter({
    required this.strokeWidth,
    required this.trackColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track Fill
    final paint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweepAngle,
      false,
      paint,
    );

    // Track Borders
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + strokeWidth / 2),
      _startAngle,
      _sweepAngle,
      false,
      borderPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      _startAngle,
      _sweepAngle,
      false,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RingFillPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color borderColor;

  static const _startAngle = -pi / 2 + 0.3;
  static const _maxSweep = 2 * pi - 0.6;

  _RingFillPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepAngle = _maxSweep * progress;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(rect, _startAngle, sweepAngle, false, paint);

    // Borders for the fill arc
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + strokeWidth / 2),
      _startAngle,
      sweepAngle,
      false,
      borderPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      _startAngle,
      sweepAngle,
      false,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingFillPainter old) =>
      old.progress != progress || old.color != color;
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
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
      ),
      child: Center(
        child: Text(
          moodScore.toString(),
          style: TextStyle(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
