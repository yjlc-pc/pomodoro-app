import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../timer/pomodoro_settings.dart';

/// Owns the live [PomodoroSettings] and persists every change.
///
/// This replaces the former `SettingsStore`, which was a stateless pair of
/// load/save helpers that each caller had to wire up itself. That setup made it
/// easy to update the timer without persisting (or the reverse), and it left
/// [PomodoroSettings.soundEnabled] as a write-only flag nothing ever read.
///
/// [update] is the only way to change settings: it swaps the live value,
/// notifies listeners, then writes through to storage. [main] connects a
/// listener that forwards the new value to the running timer, so neither side
/// knows about the other.
class SettingsController extends ChangeNotifier {
  SettingsController({PomodoroSettings? initial})
      : _settings = initial ?? const PomodoroSettings();

  static const _kFocus = 'focus_minutes';
  static const _kShortBreak = 'short_break_minutes';
  static const _kLongBreak = 'long_break_minutes';
  static const _kSessions = 'sessions_before_long_break';
  static const _kAutoBreaks = 'auto_start_breaks';
  static const _kAutoFocus = 'auto_start_focus';
  static const _kSound = 'sound_enabled';

  PomodoroSettings _settings;
  SharedPreferences? _prefs;

  /// The settings currently in effect.
  PomodoroSettings get settings => _settings;

  /// Reads persisted settings, falling back to defaults for missing or
  /// malformed values. Safe to call before [update]; persistence only becomes
  /// active once [load] has run.
  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    _settings = PomodoroSettings(
      focusMinutes: prefs.getInt(_kFocus) ?? 25,
      shortBreakMinutes: prefs.getInt(_kShortBreak) ?? 5,
      longBreakMinutes: prefs.getInt(_kLongBreak) ?? 15,
      sessionsBeforeLongBreak: prefs.getInt(_kSessions) ?? 4,
      autoStartBreaks: prefs.getBool(_kAutoBreaks) ?? false,
      autoStartFocus: prefs.getBool(_kAutoFocus) ?? false,
      soundEnabled: prefs.getBool(_kSound) ?? true,
    );
    // `always_on_screen` backed a setting that had no UI and no consumer; drop
    // the stale key on read rather than leaving orphaned storage behind.
    try {
      await prefs.remove('always_on_screen');
    } catch (_) {
      // Best-effort cleanup.
    }
    notifyListeners();
  }

  /// Replaces the live settings, notifies listeners and writes through.
  ///
  /// A no-op when [next] is identical to the current value, so redundant calls
  /// (a slider re-emitting its value, for instance) do not churn storage.
  Future<void> update(PomodoroSettings next) async {
    if (next == _settings) return;
    _settings = next;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final s = _settings;
    try {
      await prefs.setInt(_kFocus, s.focusMinutes);
      await prefs.setInt(_kShortBreak, s.shortBreakMinutes);
      await prefs.setInt(_kLongBreak, s.longBreakMinutes);
      await prefs.setInt(_kSessions, s.sessionsBeforeLongBreak);
      await prefs.setBool(_kAutoBreaks, s.autoStartBreaks);
      await prefs.setBool(_kAutoFocus, s.autoStartFocus);
      await prefs.setBool(_kSound, s.soundEnabled);
    } catch (_) {
      // Best-effort persistence: the in-memory value stays authoritative.
    }
  }
}