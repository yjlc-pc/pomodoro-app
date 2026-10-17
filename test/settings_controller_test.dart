import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/settings/settings_controller.dart';
import 'package:pomodoro_app/src/timer/pomodoro_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> emptyPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  group('load', () {
    test('falls back to defaults when nothing is stored', () async {
      final controller = SettingsController();
      await controller.load(await emptyPrefs());

      expect(controller.settings, const PomodoroSettings());
    });

    test('reads every persisted value', () async {
      SharedPreferences.setMockInitialValues({
        'focus_minutes': 45,
        'short_break_minutes': 8,
        'long_break_minutes': 20,
        'sessions_before_long_break': 3,
        'auto_start_breaks': true,
        'auto_start_focus': true,
        'sound_enabled': false,
      });
      final controller = SettingsController();

      await controller.load(await SharedPreferences.getInstance());

      expect(controller.settings.focusMinutes, 45);
      expect(controller.settings.shortBreakMinutes, 8);
      expect(controller.settings.longBreakMinutes, 20);
      expect(controller.settings.sessionsBeforeLongBreak, 3);
      expect(controller.settings.autoStartBreaks, isTrue);
      expect(controller.settings.autoStartFocus, isTrue);
      expect(controller.settings.soundEnabled, isFalse);
    });

    test('drops the orphaned always_on_screen key', () async {
      SharedPreferences.setMockInitialValues({'always_on_screen': true});
      final prefs = await SharedPreferences.getInstance();

      await SettingsController().load(prefs);

      expect(prefs.containsKey('always_on_screen'), isFalse);
    });
  });

  group('update', () {
    test('replaces the live value and notifies listeners', () async {
      final controller = SettingsController();
      await controller.load(await emptyPrefs());
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.update(
        controller.settings.copyWith(focusMinutes: 50),
      );

      expect(controller.settings.focusMinutes, 50);
      expect(notified, 1);
    });

    test('is a no-op when nothing actually changed', () async {
      final controller = SettingsController();
      await controller.load(await emptyPrefs());
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.update(controller.settings.copyWith(focusMinutes: 26));
      await controller.update(controller.settings);

      expect(notified, 1, reason: 'only the real change should notify');
    });

    test('writes through to storage', () async {
      final prefs = await emptyPrefs();
      final controller = SettingsController();
      await controller.load(prefs);

      await controller.update(
        controller.settings.copyWith(
          focusMinutes: 40,
          longBreakMinutes: 30,
          soundEnabled: false,
        ),
      );

      expect(prefs.getInt('focus_minutes'), 40);
      expect(prefs.getInt('long_break_minutes'), 30);
      expect(prefs.getBool('sound_enabled'), isFalse);
    });

    test('round-trips through a fresh controller', () async {
      final prefs = await emptyPrefs();
      final first = SettingsController();
      await first.load(prefs);
      await first.update(
        first.settings.copyWith(sessionsBeforeLongBreak: 6),
      );

      final second = SettingsController();
      await second.load(prefs);

      expect(second.settings.sessionsBeforeLongBreak, 6);
    });

    test('does not persist before load has run', () async {
      final prefs = await emptyPrefs();
      final controller = SettingsController();

      await controller.update(
        controller.settings.copyWith(focusMinutes: 33),
      );

      expect(controller.settings.focusMinutes, 33);
      expect(prefs.getInt('focus_minutes'), isNull);
    });
  });

  group('timer wiring', () {
    test('a controller listener can push settings into a live consumer',
        () async {
      final controller = SettingsController();
      await controller.load(await emptyPrefs());
      final seen = <int>[];
      controller.addListener(() => seen.add(controller.settings.focusMinutes));

      await controller.update(controller.settings.copyWith(focusMinutes: 60));
      await controller.update(controller.settings.copyWith(focusMinutes: 15));

      expect(seen, [60, 15]);
    });
  });
}