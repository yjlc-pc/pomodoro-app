import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'src/audio/ambient_player.dart';
import 'src/models/focus_stats_store.dart';
import 'src/models/todo_store.dart';
import 'src/screens/main_shell.dart';
import 'src/settings/settings_controller.dart';
import 'src/theme/app_theme.dart';
import 'src/timer/pomodoro_timer.dart';
import 'src/widgets/window_title_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureWindow();
  final prefs = await SharedPreferences.getInstance();
  final settingsController = SettingsController();
  await settingsController.load(prefs);
  final timer = PomodoroTimer(settingsController.settings);
  // The controller is the single source of truth; the timer follows it. Neither
  // side holds a reference to the other beyond this listener.
  settingsController.addListener(
    () => timer.applySettings(settingsController.settings),
  );
  final todoStore = TodoStore();
  await todoStore.load(prefs);
  final statsStore = FocusStatsStore();
  await statsStore.load(prefs);
  // Persist every naturally-completed focus into the daily stats store.
  timer.onFocusCompleted = (completed) {
    statsStore.record(DateTime.now(), completed.inMinutes);
  };
  final ambientPlayer = AmbientPlayer();
  await ambientPlayer.init();
  // Audio owns its own persisted state, so restoring is a single call with no
  // snapshot reassembly at the call site.
  await ambientPlayer.restore(prefs);
  // Announce every phase transition — completed or skipped — so the chime the
  // settings screen offers is really wired to the timer.
  timer.onPhaseChanged = (_) {
    if (settingsController.settings.soundEnabled) ambientPlayer.playChime();
  };

  runApp(PomodoroApp(
    timer: timer,
    settingsController: settingsController,
    todoStore: todoStore,
    statsStore: statsStore,
    ambientPlayer: ambientPlayer,
  ));
}

/// Removes the OS-drawn title bar on desktop so the in-app [WindowTitleBar]
/// can render it in the app's own (M3) theme. No-op on web/mobile/tests.
Future<void> _configureWindow() async {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows)) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(560, 640),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.show();
    });
  }
}

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({
    super.key,
    required this.timer,
    required this.settingsController,
    required this.todoStore,
    required this.statsStore,
    required this.ambientPlayer,
  });

  final PomodoroTimer timer;
  final SettingsController settingsController;
  final TodoStore todoStore;
  final FocusStatsStore statsStore;
  final AmbientPlayer ambientPlayer;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: timer),
        ChangeNotifierProvider.value(value: todoStore),
        ChangeNotifierProvider.value(value: statsStore),
        ChangeNotifierProvider.value(value: ambientPlayer),
        ChangeNotifierProvider.value(value: settingsController),
      ],
      child: MaterialApp(
        title: '番茄钟',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _DesktopRoot(),
      ),
    );
  }
}

/// Root widget shown on desktop: a slim self-drawn [WindowTitleBar] pinned on
/// top of the app's normal content ([MainShell]). On web/mobile/test the bar
/// is still rendered (with no-op window controls) so layouts stay consistent.
class _DesktopRoot extends StatelessWidget {
  const _DesktopRoot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const [
          WindowTitleBar(),
          Expanded(child: MainShell()),
        ],
      ),
    );
  }
}
