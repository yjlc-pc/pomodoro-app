import 'package:flutter/material.dart';
import '../widgets/active_timer_capsule.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'timer_screen.dart';
import 'todo_screen.dart';

/// M3 window-class boundary: below is Compact, at/above is Medium.
/// Screens switch their content layout (margins 16 → 24, single → multi-pane)
/// at this width.
const double kCompactBreakpoint = 600;

/// Navigation switch: below is a bottom [NavigationBar], at/above is a labeled
/// left [NavigationRail] (Expanded desktop class).
const double kExpandedBreakpoint = 840;

/// Hosts the three destinations (timer / todo / stats) behind an
/// [IndexedStack] so switching pages never interrupts the running timer.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final List<Widget> _screens = [
    TimerScreen(onOpenSettings: _openSettings),
    const TodoScreen(),
    const StatsScreen(),
    const HistoryScreen(),
  ];

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
          body: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    if (useRail) ...[
                      NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: (i) =>
                            setState(() => _index = i),
                        labelType: NavigationRailLabelType.all,
                        destinations: _railDestinations,
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                    ],
                    Expanded(
                      child: IndexedStack(index: _index, children: _screens),
                    ),
                  ],
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
                    child: ActiveTimerCapsule(
                      onTap: () => setState(() => _index = 0),
                    ),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: _destinations,
                ),
        );
      },
    );
  }
}
