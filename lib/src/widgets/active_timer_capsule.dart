import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../timer/pomodoro_timer.dart';

/// Global floating capsule that shows the running timer while the user is on
/// another page.
///
/// Renders nothing when the timer is not running. When running it shows a small
/// consuming progress ring, the phase and the remaining time as a compact
/// Material pill. Tapping it jumps back to the timer page via [onTap].
class ActiveTimerCapsule extends StatelessWidget {
  const ActiveTimerCapsule({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double _radius = 16.0;

  /// Diameter of the inline ring. Deliberately small: the capsule is a
  /// persistent overlay and must not compete with the countdown ring on the
  /// timer page — it just makes the pill's state readable at a glance.
  static const double _ringSize = 20;

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<PomodoroTimer>();
    if (!timer.running) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final foreground = scheme.onInverseSurface;

    return Container(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _ringSize,
                  height: _ringSize,
                  child: CircularProgressIndicator(
                    // Same direction as the main ring, so the two read as one
                    // clock at different scales.
                    value: timer.remainingFraction,
                    strokeWidth: 2,
                    backgroundColor: foreground.withValues(alpha: 0.24),
                    valueColor: AlwaysStoppedAnimation(foreground),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${timer.phase.label} ${timer.formattedTime}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
