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

  group('weeklySummaries', () {
    test('includes the Monday of every week', () {
      // Regression: week boundaries used to be computed by subtracting a
      // Duration from a wall-clock `now`, so a week's Monday (00:00) fell
      // *before* the computed start (12:00) and was silently dropped.
      final store = FocusStatsStore(clock: clock);
      store.record(DateTime(2024, 1, 15), 25); // Monday, the week start
      store.record(DateTime(2024, 1, 21), 25); // Sunday, the week end

      final weeks = store.weeklySummaries(count: 2);

      expect(weeks[0].start, DateTime(2024, 1, 15));
      expect(weeks[0].summary.pomodoroCount, 2);
      expect(weeks[0].summary.focusMinutes, 50);
    });

    test('every bucket starts on a Monday', () {
      final store = FocusStatsStore(clock: clock);
      for (final week in store.weeklySummaries(count: 8)) {
        expect(week.start.weekday, DateTime.monday);
        expect(week.start, DateTime(week.start.year, week.start.month, week.start.day));
      }
    });

    test('returns count buckets newest-first including empty ones', () {
      final store = FocusStatsStore(clock: clock);
      store.record(DateTime(2024, 1, 15), 25);

      final weeks = store.weeklySummaries(count: 4);

      expect(weeks, hasLength(4));
      expect(weeks[0].summary.pomodoroCount, 1);
      for (final week in weeks.skip(1)) {
        expect(week.summary.pomodoroCount, 0);
      }
      // Newest first: each bucket is exactly 7 days before the previous one.
      expect(weeks[1].start, weeks[0].start.subtract(const Duration(days: 7)));
    });

    test('does not leak a day into two adjacent weeks', () {
      // now is Monday 2024-01-15, so bucket 0 is Jan 15–21 and bucket 1 is
      // Jan 8–14. The Sunday/Monday boundary is where an off-by-one would
      // double-count or drop a day.
      final store = FocusStatsStore(clock: clock);
      store.record(DateTime(2024, 1, 14), 25); // Sunday, closes bucket 1
      store.record(DateTime(2024, 1, 15), 25); // Monday, opens bucket 0

      final weeks = store.weeklySummaries(count: 2);

      expect(weeks[0].start, DateTime(2024, 1, 15));
      expect(weeks[0].summary.pomodoroCount, 1);
      expect(weeks[1].start, DateTime(2024, 1, 8));
      expect(weeks[1].summary.pomodoroCount, 1);
    });
  });

  group('monthlySummaries', () {
    test('buckets span whole calendar months newest-first', () {
      // now is 2024-01-15, so bucket 0 is January and bucket 1 is December.
      final store = FocusStatsStore(clock: clock);
      store.record(DateTime(2023, 12, 31), 25); // last day of December
      store.record(DateTime(2024, 1, 1), 25); // first day of January

      final months = store.monthlySummaries(count: 2);

      expect(months[0].start, DateTime(2024, 1, 1));
      expect(months[0].summary.pomodoroCount, 1);
      expect(months[1].start, DateTime(2023, 12, 1));
      expect(months[1].summary.pomodoroCount, 1);
    });

    test('includes the first day of the month', () {
      final store = FocusStatsStore(clock: clock);
      store.record(DateTime(2024, 1, 1), 25);

      final months = store.monthlySummaries(count: 1);

      expect(months.single.start, DateTime(2024, 1, 1));
      expect(months.single.summary.pomodoroCount, 1);
    });

    test('returns count buckets including empty ones', () {
      final store = FocusStatsStore(clock: clock);
      store.record(DateTime(2024, 1, 15), 25);

      final months = store.monthlySummaries(count: 3);

      expect(months, hasLength(3));
      expect(months[0].summary.pomodoroCount, 1);
      expect(months[1].summary.pomodoroCount, 0);
      expect(months[2].summary.pomodoroCount, 0);
    });
  });
}
