import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// A circular countdown ring: a full track with the remaining time drawn on top.
///
/// The ring is *consuming* rather than accumulating — it starts full when the
/// phase begins and empties as time runs out. That matters because the number
/// in the middle counts **down**: a ring that fills up while its number shrinks
/// makes the two read as contradicting each other. Callers pass
/// [PomodoroTimer.remainingFraction] so the ring and the digits always agree.
class TimerRing extends StatefulWidget {
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
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing> {
  /// What the ring actually paints, which is not always
  /// [TimerRing.remainingFraction] — see [_drainHoldRefill].
  double _target = 1.0;
  bool _holding = false;
  Timer? _holdTimer;

  /// How long the emptied ring lingers before refilling. Long enough to read as
  /// a beat rather than a frame, short enough not to delay the next phase.
  static const Duration _holdDuration = Duration(milliseconds: 420);

  /// Smallest upward jump in [remainingFraction] that counts as "a fresh
  /// session started" rather than ordinary ticking.
  ///
  /// While a timer runs, this value falls by well under one thousandth per
  /// second (1/1500 for a 25-minute focus), so anything above this threshold is
  /// a phase change or a reset — both of which get the same beat.
  static const double _refillThreshold = 0.1;

  @override
  void initState() {
    super.initState();
    _target = widget.remainingFraction;
  }

  @override
  void didUpdateWidget(TimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_holding) return;
    final jump = widget.remainingFraction - oldWidget.remainingFraction;
    if (jump > _refillThreshold) _drainHoldRefill();
  }

  /// Empties the ring, holds it empty for a beat, then refills for the new
  /// phase.
  ///
  /// Whenever the timer starts over — a phase ending naturally, a skip, or a
  /// reset — [remainingFraction] snaps back to 1.0. Treated as a plain tween
  /// that reads as the ring springing back to full the instant it lands, with
  /// nowhere for the moment to rest. Draining first gives the end of a session
  /// a visible landing, and keeps one consistent gesture for all three ways of
  /// starting over.
  void _drainHoldRefill() {
    setState(() {
      _holding = true;
      _target = 0;
    });
    // A cancellable Timer, not Future.delayed: the hold outlives a test's widget
    // tree or a page switch, and an orphan future would fire into a disposed
    // State (and trip flutter_test's pending-timer assertion).
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDuration, () {
      if (!mounted) return;
      setState(() {
        _holding = false;
        _target = widget.remainingFraction;
      });
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strokeWidth = widget.size * 0.045;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _target.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(
            remaining: value,
            trackColor: widget.strokeColor ?? scheme.surfaceContainerHighest,
            progressColor: widget.progressColor,
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.durationLabel,
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
                  widget.phaseLabel,
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