import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../timer/pomodoro_timer.dart';

/// Global floating capsule that shows the running timer while the user is on
/// another page.
///
/// Renders nothing when the timer is not running. When running it shows the
/// current phase + remaining time as a compact Material pill.
/// Tapping it jumps back to the timer page via [onTap].
class ActiveTimerCapsule extends StatelessWidget {
  const ActiveTimerCapsule({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<PomodoroTimer>();
    if (!timer.running) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

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
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: scheme.onInverseSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  '${timer.phase.label} ${timer.formattedTime}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: scheme.onInverseSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
