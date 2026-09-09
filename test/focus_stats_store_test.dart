import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/models/focus_stats_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() {
    now = DateTime(2024, 1, 15, 12, 0, 0);
  });

  DateTime day(int offset) => DateTime(2024, 1, 15 + offset);
  DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  group('record', () {
    test('accumulates pomodoro count and focus minutes per day', () {
      final store = FocusStatsStore(clock: clock);
      store.record(day(0), 25);
      store.record(day(0), 25);
      store.record(day(-1), 50);

      expect(store.totalPomodoroCount, 3);
      expect(store.totalFocusMinutes, 100);

      final today =
          store.dailyStats.singleWhere((s) => s.date == dayOf(day(0)));
      expect(today.pomodoroCount, 2);
      expect(today.focusMinutes, 50);
    });
  });

  group('persistence', () {
    test('round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final a = FocusStatsStore(clock: clock);
      await a.load(prefs);
      a.record(day(0), 25);
      a.record(day(-1), 50);
      await a.save(prefs);

      final b = FocusStatsStore(clock: clock);
      await b.load(prefs);
      expect(b.totalPomodoroCount, 2);
      expect(b.totalFocusMinutes, 75);
    });

    test('load tolerates corrupted JSON and falls back to empty', () async {
      SharedPreferences.setMockInitialValues({
        'focus_stats_v1': '{{{ not json',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = FocusStatsStore();
      await store.load(prefs);
      expect(store.totalPomodoroCount, 0);
      expect(store.dailyStats, isEmpty);
    });
  });

  group('retention (90 days)', () {
    test('record prunes buckets older than 90 days immediately', () {
      final store = FocusStatsStore(clock: clock);
      store.record(day(0), 25);
      store.record(day(-100), 25);
      expect(store.dailyStats.map((s) => s.date), [dayOf(day(0))]);
    });

    test('load prunes pre-existing old buckets', () async {
      final raw = jsonEncode({
        '2023-01-01': {'count': 5, 'minutes': 100},
        '2024-01-15': {'count': 1, 'minutes': 25},
      });
      SharedPreferences.setMockInitialValues({'focus_stats_v1': raw});
      final prefs = await SharedPreferences.getInstance();
      final store = FocusStatsStore(clock: clock);
      await store.load(prefs);
      expect(store.totalPomodoroCount, 1);
      expect(store.totalFocusMinutes, 25);
    });
  });

  group('streak', () {
    test('counts consecutive active days ending today', () {
      final store = FocusStatsStore(clock: clock);
      store.record(day(0), 25);
      store.record(day(-1), 25);
      store.record(day(-2), 25);
      expect(store.currentStreak, 3);
    });

    test('today not yet done does not break the streak (measured from '
        'yesterday)', () {
      final store = FocusStatsStore(clock: clock);
      store.record(day(-1), 25);
      store.record(day(-2), 25);
      expect(store.currentStreak, 2);
    });

    test('an interruption resets the streak', () {
      final store = FocusStatsStore(clock: clock);
      store.record(day(0), 25);
      store.record(day(-1), 25);
      store.record(day(-3), 25); // gap on day -2
      expect(store.currentStreak, 2);
    });

    test('returns zero when there is no activity', () {
      final store = FocusStatsStore(clock: clock);
      expect(store.currentStreak, 0);
    });
  });

  group('week / month summaries', () {
    test('week and previous week are rolling 7-day windows', () {
      final store = FocusStatsStore(clock: clock);
      // day(0)=today, day(-7) is just outside the current window.
      store.record(day(0), 25);
      store.record(day(-1), 25);
      store.record(day(-6), 25);
      store.record(day(-7), 25);
      store.record(day(-14), 50);

      final week = store.weekSummary();
      final prev = store.previousWeekSummary();

      expect(week.pomodoroCount, 3); // today, -1, -6
      expect(prev.pomodoroCount, 1); // only -7
      expect(prev.focusMinutes, 25);
    });

    test('month and previous month are calendar windows', () {
      final store = FocusStatsStore(clock: clock);
      store.record(DateTime(2024, 1, 31), 25);
      store.record(DateTime(2024, 1, 15), 25);
      store.record(DateTime(2023, 12, 31), 50);

      expect(store.monthSummary().pomodoroCount, 2);
      expect(store.monthSummary().focusMinutes, 50);
      expect(store.previousMonthSummary().pomodoroCount, 1);
      expect(store.previousMonthSummary().focusMinutes, 50);
    });

    test('changePercent is null when previous period is empty', () {
      expect(
        FocusStatsStore.changePercent(
          const PeriodSummary(pomodoroCount: 4, focusMinutes: 100),
          const PeriodSummary.empty(),
        ),
        isNull,
      );
    });

    test('changePercent reports relative focus-minute change', () {
      final pct = FocusStatsStore.changePercent(
        const PeriodSummary(pomodoroCount: 2, focusMinutes: 100),
        const PeriodSummary(pomodoroCount: 1, focusMinutes: 50),
      );
      expect(pct, 100.0);
    });
  });
}
