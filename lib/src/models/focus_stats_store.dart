import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single day's aggregate of naturally-completed focus sessions.
///
/// [date] is normalized to midnight (local). One [DailyStat] exists per day
/// that had at least one completed focus; empty days are simply absent.
@immutable
class DailyStat {
  const DailyStat({
    required this.date,
    required this.pomodoroCount,
    required this.focusMinutes,
  });

  /// The day this stat belongs to, normalized to midnight (local).
  final DateTime date;

  /// Number of naturally-completed focus sessions that day.
  final int pomodoroCount;

  /// Total focused minutes that day.
  final int focusMinutes;
}

/// Aggregate of completed focus sessions over a period (week / month).
@immutable
class PeriodSummary {
  const PeriodSummary({required this.pomodoroCount, required this.focusMinutes});

  const PeriodSummary.empty()
      : pomodoroCount = 0,
        focusMinutes = 0;

  final int pomodoroCount;
  final int focusMinutes;
}

/// Persists naturally-completed focus sessions and derives statistics.
///
/// Data is pre-aggregated per day into a [Map] keyed by a normalized
/// [DateTime], stored as a single JSON blob under one SharedPreferences key.
/// On every write buckets older than [FocusStatsStore.retentionDays] are pruned
/// so storage never grows unbounded. Streak, week and month figures are all
/// derived from the (at most 90) retained daily buckets.
///
/// Only sessions that completed naturally are recorded ([record]); skipped or
/// reset focuses never reach this store.
class FocusStatsStore extends ChangeNotifier {
  FocusStatsStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const String _storageKey = 'focus_stats_v1';

  /// How many days of history are retained. Buckets older than this are pruned.
  static const int retentionDays = 90;

  final DateTime Function() _clock;
  final Map<DateTime, DailyStat> _buckets = {};
  List<DailyStat>? _cachedDailyStats;
  SharedPreferences? _prefs;

  /// Day buckets sorted by date ascending. Only days with ≥1 completed focus.
  List<DailyStat> get dailyStats =>
      _cachedDailyStats ??= (_buckets.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date)));

  /// Direct O(1) lookup for a specific day's stat, or null if no focus
  /// was completed on that day.
  DailyStat? statForDate(DateTime date) => _buckets[_dayOf(date)];

  /// Total completed pomodoros across all retained days.
  int get totalPomodoroCount =>
      _buckets.values.fold(0, (sum, s) => sum + s.pomodoroCount);

  /// Total focused minutes across all retained days.
  int get totalFocusMinutes =>
      _buckets.values.fold(0, (sum, s) => sum + s.focusMinutes);

  /// Records one naturally-completed focus of [focusMinutes] minutes on [date].
  /// Adds to that day's bucket, prunes old buckets, then persists.
  Future<void> record(DateTime date, int focusMinutes) async {
    final day = _dayOf(date);
    final existing = _buckets[day];
    _buckets[day] = DailyStat(
      date: day,
      pomodoroCount: (existing?.pomodoroCount ?? 0) + 1,
      focusMinutes: (existing?.focusMinutes ?? 0) + focusMinutes,
    );
    _cachedDailyStats = null;
    _prune();
    notifyListeners();
    await _persist();
  }

  /// Consecutive natural days ending today with ≥1 completed focus.
  ///
  /// A day is "active" if it has a non-zero pomodoro count. If today has not
  /// completed a focus yet the streak is measured from yesterday, so an
  /// unfinished today does NOT break the streak.
  int get currentStreak {
    final active = _buckets.values
        .where((s) => s.pomodoroCount > 0)
        .map((s) => s.date)
        .toSet();
    var cursor = _dayOf(_clock());
    if (!active.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (active.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Summary for the rolling 7 days ending today (inclusive).
  PeriodSummary weekSummary({DateTime? now}) =>
      _rollingPeriod((now ?? _clock()), 7, 0);

  /// Summary for the 7 days immediately before the current week.
  PeriodSummary previousWeekSummary({DateTime? now}) =>
      _rollingPeriod((now ?? _clock()), 7, 7);

  /// Summary for the current calendar month.
  PeriodSummary monthSummary({DateTime? now}) {
    final today = _dayOf(now ?? _clock());
    var count = 0;
    var minutes = 0;
    for (final s in _buckets.values) {
      if (s.date.year == today.year && s.date.month == today.month) {
        count += s.pomodoroCount;
        minutes += s.focusMinutes;
      }
    }
    return PeriodSummary(pomodoroCount: count, focusMinutes: minutes);
  }

  /// Summary for the calendar month before the current one.
  PeriodSummary previousMonthSummary({DateTime? now}) {
    final today = _dayOf(now ?? _clock());
    final prev = DateTime(today.year, today.month - 1, 1);
    var count = 0;
    var minutes = 0;
    for (final s in _buckets.values) {
      if (s.date.year == prev.year && s.date.month == prev.month) {
        count += s.pomodoroCount;
        minutes += s.focusMinutes;
      }
    }
    return PeriodSummary(pomodoroCount: count, focusMinutes: minutes);
  }

  /// Percentage change of [current] vs [previous] focus minutes, or null when
  /// there is no meaningful baseline (previous period was empty).
  static double? changePercent(PeriodSummary current, PeriodSummary previous) {
    if (previous.focusMinutes <= 0) return null;
    return (current.focusMinutes - previous.focusMinutes) /
        previous.focusMinutes *
        100;
  }

  PeriodSummary _rollingPeriod(DateTime ref, int days, int offset) {
    final today = _dayOf(ref);
    var count = 0;
    var minutes = 0;
    for (var i = offset; i < offset + days; i++) {
      final s = _buckets[today.subtract(Duration(days: i))];
      if (s != null) {
        count += s.pomodoroCount;
        minutes += s.focusMinutes;
      }
    }
    return PeriodSummary(pomodoroCount: count, focusMinutes: minutes);
  }

  /// Loads persisted stats, tolerating missing or corrupted data.
  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _buckets.clear();
      _cachedDailyStats = null;
      decoded.forEach((key, value) {
        final map = value as Map<String, dynamic>;
        final date = DateTime.parse(key);
        _buckets[date] = DailyStat(
          date: date,
          pomodoroCount: (map['count'] as num).toInt(),
          focusMinutes: (map['minutes'] as num).toInt(),
        );
      });
      _prune();
      notifyListeners();
    } catch (_) {
      // Corrupted storage: fall back to empty statistics rather than crash.
      _buckets.clear();
    }
  }

  /// Persists the whole map under a single JSON key. Failures are swallowed so
  /// the in-memory state keeps working.
  Future<void> save([SharedPreferences? prefs]) async {
    try {
      final target = prefs ?? _prefs;
      if (target == null) return;
      final raw = jsonEncode({
        for (final e in _buckets.entries)
          _keyOf(e.key): {'count': e.value.pomodoroCount, 'minutes': e.value.focusMinutes},
      });
      await target.setString(_storageKey, raw);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<void> _persist() => save();

  /// Removes buckets older than [retentionDays] relative to today.
  void _prune() {
    final today = _dayOf(_clock());
    final before = _buckets.length;
    _buckets.removeWhere(
      (day, _) => today.difference(day).inDays >= retentionDays,
    );
    if (_buckets.length != before) _cachedDailyStats = null;
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
