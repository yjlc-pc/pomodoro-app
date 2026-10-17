import 'dart:math';

import 'package:flutter/material.dart';

/// A circular countdown ring: a full track with the remaining time drawn on top.
///
/// The ring is *consuming* rather than accumulating — it starts full when the
/// phase begins and empties as time runs out. That matters because the number
/// in the middle counts **down**: a ring that fills up while its number shrinks
/// makes the two read as contradicting each other. Callers pass
/// [PomodoroTimer.remainingFraction] so the ring and the digits always agree.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.remainingFraction,
    required this.progressColor,
    required this.durationLabel,
    required this.phaseLabel,
    this.size = 260,
    this.strokeColor,
  });

  /// Fraction of the phase still to go, 1.0 → 0.0.
  final double remainingFraction;

  /// Color of the remaining arc. Callers pass a semantic color role so the ring
  /// distinguishes the focus / short-break / long-break phases.
  final Color progressColor;

  /// The remaining time, formatted for display, e.g. "24:31".
  final String durationLabel;

  /// The current phase's name, e.g. "专注".
  final String phaseLabel;

  final double size;

  /// Color of the emptied track behind the arc. Defaults to
  /// `surfaceContainerHighest`.
  final Color? strokeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strokeWidth = size * 0.045;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: remainingFraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(
            remaining: value,
            trackColor: strokeColor ?? scheme.surfaceContainerHighest,
            progressColor: progressColor,
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  durationLabel,
                  // displayLarge + w600: this is the app's focal point and the
                  // M3 display roles are all regular weight. tabular figures
                  // come from the theme, so the digits never shift sideways as
                  // they tick.
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  phaseLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.remaining,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double remaining;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    final sweep = 2 * pi * remaining.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      // Start at 12 o'clock and sweep clockwise, so time reads like a clock
      // face draining rather than a pie filling up.
      -pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = progressColor,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.remaining != remaining ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.strokeWidth != strokeWidth;
}