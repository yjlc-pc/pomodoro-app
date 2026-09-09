import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/timer/pomodoro_settings.dart';
import 'package:pomodoro_app/src/timer/pomodoro_timer.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  const baseSettings = PomodoroSettings(
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
  );

  setUp(() {
    now = DateTime(2024, 1, 1, 12, 0, 0);
  });

  group('initial state', () {
    test('starts in focus phase at full duration', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      expect(t.phase, PomodoroPhase.focus);
      expect(t.remaining, const Duration(minutes: 25));
      expect(t.running, isFalse);
      expect(t.formattedTime, '25:00');
    });

    test('progress is zero at start and grows', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      expect(t.progress, 0);
      t.start();
      now = now.add(const Duration(seconds: 5));
      t.tick();
      expect(t.progress, greaterThan(0));
      expect(t.progress, lessThan(1));
    });
  });

  group('ticking', () {
    test('tick decreases remaining time', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      t.start();
      expect(t.running, isTrue);
      now = now.add(const Duration(seconds: 10));
      t.tick();
      expect(t.remaining, const Duration(minutes: 24, seconds: 50));
      expect(t.formattedTime, '24:50');
    });

    test('pause stops the countdown', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      t.start();
      now = now.add(const Duration(seconds: 10));
      t.tick();
      t.pause();
      expect(t.running, isFalse);
      final frozen = t.remaining;
      now = now.add(const Duration(seconds: 10));
      t.tick();
      expect(t.remaining, frozen);
    });

    test('reset restores full duration', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      t.start();
      now = now.add(const Duration(seconds: 30));
      t.tick();
      t.reset();
      expect(t.remaining, const Duration(minutes: 25));
      expect(t.running, isFalse);
    });
  });

  group('phase transitions', () {
    test('completing focus advances to short break and increments sessions', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      t.start();
      now = now.add(const Duration(minutes: 25));
      t.tick();
      expect(t.phase, PomodoroPhase.shortBreak);
      expect(t.completedFocusSessions, 1);
      expect(t.remaining, const Duration(minutes: 5));
    });

    test('long break after configured sessions', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      // Run three full focus+break cycles.
      for (var i = 0; i < 3; i++) {
        t.start();
        now = now.add(const Duration(minutes: 25));
        t.tick();
        t.start();
        now = now.add(const Duration(minutes: 5));
        t.tick();
      }
      expect(t.completedFocusSessions, 3);
      // The fourth focus session triggers the long break.
      t.start();
      now = now.add(const Duration(minutes: 25));
      t.tick();
      expect(t.completedFocusSessions, 4);
      expect(t.phase, PomodoroPhase.longBreak);
      expect(t.remaining, const Duration(minutes: 15));
    });

    test('autoStartBreaks starts the break automatically', () {
      final t = PomodoroTimer(
        const PomodoroSettings(autoStartBreaks: true),
        clock: clock,
      );
      t.start();
      now = now.add(const Duration(minutes: 25));
      t.tick();
      expect(t.phase, PomodoroPhase.shortBreak);
      expect(t.running, isTrue);
    });

    test('autoStartFocus starts next focus automatically after a break', () {
      final t = PomodoroTimer(
        const PomodoroSettings(autoStartFocus: true),
        clock: clock,
      );
      // Focus completes -> short break (not auto-started, autoStartBreaks off).
      t.start();
      now = now.add(const Duration(minutes: 25));
      t.tick();
      expect(t.phase, PomodoroPhase.shortBreak);
      expect(t.running, isFalse);

      // Start the break; when it ends, focus should auto-start.
      t.start();
      now = now.add(const Duration(minutes: 5));
      t.tick();
      expect(t.phase, PomodoroPhase.focus);
      expect(t.running, isTrue);
    });

    test('skip moves from focus to break without counting session', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      t.skip();
      expect(t.phase, PomodoroPhase.shortBreak);
      expect(t.completedFocusSessions, 0);
    });

    test('phase completion notifies listeners even without autoStart', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      final phases = <PomodoroPhase>[];
      t.addListener(() => phases.add(t.phase));
      t.start();
      now = now.add(const Duration(minutes: 25));
      t.tick();
      expect(t.phase, PomodoroPhase.shortBreak);
      expect(phases.last, PomodoroPhase.shortBreak,
          reason: 'a listener (the UI) must observe the phase change');
    });

    test('skip with autoStartBreaks auto-starts the break', () {
      final t = PomodoroTimer(
        const PomodoroSettings(autoStartBreaks: true),
        clock: clock,
      );
      t.skip();
      expect(t.phase, PomodoroPhase.shortBreak);
      expect(t.running, isTrue,
          reason: 'skipping focus ends it early; autoStartBreaks must apply');
    });
  });

  group('onFocusCompleted', () {
    test('invoked once with the full focus duration on natural completion',
        () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      final completed = <Duration>[];
      t.onFocusCompleted = completed.add;
      t.start();
      now = now.add(const Duration(minutes: 25));
      t.tick();
      expect(completed, const [Duration(minutes: 25)]);
    });

    test('NOT invoked when the focus is skipped', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      var called = false;
      t.onFocusCompleted = (_) => called = true;
      t.skip();
      expect(called, isFalse);
    });

    test('NOT invoked when the focus is reset', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      var called = false;
      t.onFocusCompleted = (_) => called = true;
      t.start();
      t.reset();
      expect(called, isFalse);
    });

    test('does not fire during a short-break completion', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      var called = false;
      t.onFocusCompleted = (_) => called = true;
      t.start();
      now = now.add(const Duration(minutes: 25));
      t.tick();
      expect(t.phase, PomodoroPhase.shortBreak);
      // Reset after the focus so we can assert the break does not fire it.
      called = false;
      t.start();
      now = now.add(const Duration(minutes: 5));
      t.tick();
      expect(t.phase, PomodoroPhase.focus);
      expect(called, isFalse);
    });
  });

  group('settings', () {
    test('applySettings updates durations without resetting a running timer',
        () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      t.start();
      now = now.add(const Duration(minutes: 2));
      t.tick();
      t.applySettings(const PomodoroSettings(focusMinutes: 50));
      expect(t.phase, PomodoroPhase.focus);
      expect(t.running, isTrue,
          reason: 'applySettings must not interrupt a running session');
      // Remaining should still reflect the original 25min minus 2 elapsed.
      expect(t.remaining, const Duration(minutes: 23));
    });

    test('applySettings resets remaining when timer is paused', () {
      final t = PomodoroTimer(baseSettings, clock: clock);
      t.start();
      now = now.add(const Duration(minutes: 2));
      t.tick();
      t.pause();
      t.applySettings(const PomodoroSettings(focusMinutes: 50));
      expect(t.remaining, const Duration(minutes: 50));
      expect(t.running, isFalse);
    });
  });
}
