import 'package:shared_preferences/shared_preferences.dart';
import '../audio/ambient_player.dart';
import '../timer/pomodoro_settings.dart';

/// Persisted audio playback preferences for the ambient player.
class AudioPrefs {
  const AudioPrefs({
    this.track,
    this.volume = 0.7,
    this.enabled = false,
  });

  /// Selected ambient track, or null when nothing is selected.
  final AmbientTrack? track;

  /// Playback volume in 0..1.
  final double volume;

  /// Whether playback should auto-start on app launch.
  final bool enabled;

  AudioPrefs copyWith({AmbientTrack? track, double? volume, bool? enabled}) {
    return AudioPrefs(
      track: track ?? this.track,
      volume: volume ?? this.volume,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Persists [PomodoroSettings] using [SharedPreferences].
class SettingsStore {
  static const _kFocus = 'focus_minutes';
  static const _kShortBreak = 'short_break_minutes';
  static const _kLongBreak = 'long_break_minutes';
  static const _kSessions = 'sessions_before_long_break';
  static const _kAutoBreaks = 'auto_start_breaks';
  static const _kAutoFocus = 'auto_start_focus';
  static const _kSound = 'sound_enabled';
  static const _kAlwaysOnScreen = 'always_on_screen';
  static const _kAudioTrack = 'audio_track';
  static const _kAudioVolume = 'audio_volume';
  static const _kAudioEnabled = 'audio_enabled';

  Future<PomodoroSettings> load(SharedPreferences prefs) async {
    return PomodoroSettings(
      focusMinutes: prefs.getInt(_kFocus) ?? 25,
      shortBreakMinutes: prefs.getInt(_kShortBreak) ?? 5,
      longBreakMinutes: prefs.getInt(_kLongBreak) ?? 15,
      sessionsBeforeLongBreak: prefs.getInt(_kSessions) ?? 4,
      autoStartBreaks: prefs.getBool(_kAutoBreaks) ?? false,
      autoStartFocus: prefs.getBool(_kAutoFocus) ?? false,
      soundEnabled: prefs.getBool(_kSound) ?? true,
      alwaysOnScreen: prefs.getBool(_kAlwaysOnScreen) ?? false,
    );
  }

  Future<void> save(SharedPreferences prefs, PomodoroSettings s) async {
    await prefs.setInt(_kFocus, s.focusMinutes);
    await prefs.setInt(_kShortBreak, s.shortBreakMinutes);
    await prefs.setInt(_kLongBreak, s.longBreakMinutes);
    await prefs.setInt(_kSessions, s.sessionsBeforeLongBreak);
    await prefs.setBool(_kAutoBreaks, s.autoStartBreaks);
    await prefs.setBool(_kAutoFocus, s.autoStartFocus);
    await prefs.setBool(_kSound, s.soundEnabled);
    await prefs.setBool(_kAlwaysOnScreen, s.alwaysOnScreen);
  }

  AudioPrefs loadAudioPrefs(SharedPreferences prefs) {
    final trackName = prefs.getString(_kAudioTrack);
    AmbientTrack? track;
    for (final t in AmbientTrack.values) {
      if (t.name == trackName) {
        track = t;
        break;
      }
    }
    return AudioPrefs(
      track: track,
      volume: (prefs.getDouble(_kAudioVolume) ?? 0.7).clamp(0.0, 1.0),
      enabled: prefs.getBool(_kAudioEnabled) ?? false,
    );
  }

  Future<void> saveAudioPrefs(SharedPreferences prefs, AudioPrefs prefs2) async {
    if (prefs2.track != null) {
      await prefs.setString(_kAudioTrack, prefs2.track!.name);
    } else {
      await prefs.remove(_kAudioTrack);
    }
    await prefs.setDouble(_kAudioVolume, prefs2.volume);
    await prefs.setBool(_kAudioEnabled, prefs2.enabled);
  }
}
