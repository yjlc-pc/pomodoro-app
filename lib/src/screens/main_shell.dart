import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layout/breakpoints.dart';
import '../timer/pomodoro_timer.dart';
import '../widgets/active_timer_capsule.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'timer_screen.dart';
import 'todo_screen.dart';

/// Hosts the three destinations (timer / todo / stats) behind an
/// [IndexedStack] so switching pages never interrupts the running timer.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final List<Widget> _screens = [
    TimerScreen(onOpenSettings: _openSettings),
    const TodoScreen(),
    const StatsScreen(),
    const HistoryScreen(),
  ];

  /// Drives the fade-in of whichever page is on top.
  ///
  /// Only the incoming page animates: the IndexedStack paints a single child at
  /// a time, so fading the stack makes the new page fade in while the previous
  /// one is already gone. An `AnimatedSwitcher` would cross-fade, which means
  /// keeping both pages mounted for the duration — duplicating their State and
  /// resetting scroll positions on every switch.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    value: 1,
  );

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _fade.value = 0;
    _fade.forward();
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.timer_outlined),
      selectedIcon: Icon(Icons.timer),
      label: '计时',
    ),
    NavigationDestination(
      icon: Icon(Icons.checklist_outlined),
      selectedIcon: Icon(Icons.checklist),
      label: '待办',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: '统计',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: '历史',
    ),
  ];

  static const _railDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.timer_outlined),
      selectedIcon: Icon(Icons.timer),
      label: Text('计时'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.checklist_outlined),
      selectedIcon: Icon(Icons.checklist),
      label: Text('待办'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: Text('统计'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: Text('历史'),
    ),
  ];

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useRail = width >= kExpandedBreakpoint;

        return Scaffold(
          // fit: expand is load-bearing. Once _PhaseAnnouncer below is a
          // non-positioned child, a Stack would otherwise size itself to that
          // child (SizedBox.shrink -> 0x0) instead of the incoming constraints,
          // and every Positioned child would then be laid out inside nothing.
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                // Fade only the incoming page. Because an IndexedStack paints a
                // single child at a time, fading it means the new page fades in
                // while the old one is already gone. The IndexedStack itself
                // stays a single mounted instance, so no page is duplicated and
                // no scroll position is lost.
                child: FadeTransition(
                  opacity: _fade,
                  child: Row(
                    children: [
                      if (useRail) ...[
                        NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: _select,
                          labelType: NavigationRailLabelType.all,
                          destinations: _railDestinations,
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                      ],
                      Expanded(
                        child: IndexedStack(
                          index: _index,
                          children: _screens,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Floating capsule above the navigation while the timer runs and
              // the user is NOT already on the timer page (it would be redundant
              // and obscure the ring). Offset it by the NavigationBar height
              // (~80dp) so it doesn't overlap.
              if (useRail || _index != 0) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: useRail ? 16 : 96,
                  child: Center(
                    child: ActiveTimerCapsule(onTap: () => _select(0)),
                  ),
                ),
              ],
              // Inside the Scaffold's body, so it can reach the
              // ScaffoldMessenger this Scaffold installs.
              const _PhaseAnnouncer(),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  destinations: _destinations,
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }
}

/// Announces a phase change with a SnackBar.
///
/// The chime covers users who are looking at the app; this covers the ones who
/// are not — the countdown runs on the timer page's own ticker, and when the
/// user is on another page the only sign of it finishing is this bar.
class _PhaseAnnouncer extends StatefulWidget {
  const _PhaseAnnouncer();

  @override
  State<_PhaseAnnouncer> createState() => _PhaseAnnouncerState();
}

class _PhaseAnnouncerState extends State<_PhaseAnnouncer> {
  PomodoroPhase? _previous;

  /// Held as a field because [dispose] may not look up ancestors: by then the
  /// element is deactivated and `context.read` throws.
  PomodoroTimer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timer = context.read<PomodoroTimer>();
    if (identical(timer, _timer)) return;
    _timer?.removeListener(_onTimerChanged);
    _timer = timer;
    _previous = timer.phase;
    timer.addListener(_onTimerChanged);
  }

  @override
  void dispose() {
    _timer?.removeListener(_onTimerChanged);
    super.dispose();
  }

  void _onTimerChanged() {
    final timer = _timer;
    if (timer == null) return;
    final phase = timer.phase;
    final previous = _previous;
    _previous = phase;
    // Nothing to announce on the first tick: that is just the initial state.
    if (previous == null || previous == phase) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${phase.label} · ${timer.formattedTime}'),
        duration: const Duration(seconds: 4),
      ));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
