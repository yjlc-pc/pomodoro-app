/// Settings that control the Pomodoro timer behaviour.
///
/// Immutable value object: two instances with the same fields are equal, so
/// callers (and `SettingsController`'s no-op check) can compare settings
/// directly instead of comparing identity.
class PomodoroSettings {
  const PomodoroSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStartBreaks = false,
    this.autoStartFocus = false,
    this.soundEnabled = true,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoStartBreaks;
  final bool autoStartFocus;
  final bool soundEnabled;

  PomodoroSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? sessionsBeforeLongBreak,
    bool? autoStartBreaks,
    bool? autoStartFocus,
    bool? soundEnabled,
  }) {
    return PomodoroSettings(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      sessionsBeforeLongBreak:
          sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartFocus: autoStartFocus ?? this.autoStartFocus,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PomodoroSettings &&
          other.focusMinutes == focusMinutes &&
          other.shortBreakMinutes == shortBreakMinutes &&
          other.longBreakMinutes == longBreakMinutes &&
          other.sessionsBeforeLongBreak == sessionsBeforeLongBreak &&
          other.autoStartBreaks == autoStartBreaks &&
          other.autoStartFocus == autoStartFocus &&
          other.soundEnabled == soundEnabled;

  @override
  int get hashCode => Object.hash(
        focusMinutes,
        shortBreakMinutes,
        longBreakMinutes,
        sessionsBeforeLongBreak,
        autoStartBreaks,
        autoStartFocus,
        soundEnabled,
      );
}
