import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Built-in ambient tracks shipped as loopable assets.
enum AmbientTrack {
  rain('雨声', 'assets/audio/rain.ogg'),
  focus('白噪音', 'assets/audio/focus.ogg'),
  lofi('氛围', 'assets/audio/lofi.ogg');

  const AmbientTrack(this.label, this.assetPath);

  /// User-facing label.
  final String label;

  /// Flutter asset path of the loopable clip.
  final String assetPath;
}

/// Thin abstraction over the SoLoud engine so tests can inject a fake.
abstract interface class AmbientEngine {
  Future<void> init();
  Future<void> loadTrack(AmbientTrack track);
  void play();
  void pause();
  Future<void> stop();
  void setVolume(double volume);
  /// Plays the short phase-change chime. Implementations must not throw and
  /// should clean the synthesized source up on their own.
  Future<void> playChime();
  Future<void> dispose();
}

/// Real [AmbientEngine] backed by the flutter_soloud plugin.
class SoLoudAmbientEngine implements AmbientEngine {
  final SoLoud _soloud = SoLoud.instance;
  _LoadedSound? _current;

  @override
  Future<void> init() => _soloud.init();

  @override
  Future<void> loadTrack(AmbientTrack track) async {
    await stop();
    final source = await _soloud.loadAsset(track.assetPath);
    final handle = _soloud.play(source, looping: true, volume: 1);
    _current = _LoadedSound(source: source, handle: handle);
  }

  @override
  void play() {
    final current = _current;
    if (current == null) return;
    _soloud.setPause(current.handle, false);
  }

  @override
  void pause() {
    final current = _current;
    if (current == null) return;
    _soloud.setPause(current.handle, true);
  }

  @override
  Future<void> stop() async {
    final current = _current;
    if (current == null) return;
    await _soloud.stop(current.handle);
    await _soloud.disposeSource(current.source);
    _current = null;
  }

  @override
  void setVolume(double volume) {
    final current = _current;
    if (current == null) return;
    _soloud.setVolume(current.handle, volume);
  }

  /// Synthesizes the chime instead of shipping an audio asset.
  ///
  /// A pure sine is the softest waveform SoLoud offers — unlike square or saw
  /// it carries no upper harmonics — so a short blip reads as a "ding" rather
  /// than a buzzer. The source is generated per call and disposed once it has
  /// rung out, so no waveform buffer outlives the sound.
  ///
  /// The gain envelope matters as much as the pitch: cutting a sine dead
  /// produces an audible click at the tail, so the volume is stepped down
  /// before the handle is stopped.
  @override
  Future<void> playChime() async {
    AudioSource? source;
    SoundHandle? handle;
    try {
      source = await _soloud.loadWaveform(WaveForm.sin, false, 1.0, 0);
      handle = _soloud.play(source, volume: _chimePeak);
      for (final gain in _chimeEnvelope) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        _soloud.setVolume(handle, gain);
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await _soloud.stop(handle);
    } catch (_) {
      // A missing or busy audio device must not take the app down; the failure
      // is reported through the engine's caller instead.
    } finally {
      final pending = source;
      if (pending != null) {
        try {
          await _soloud.disposeSource(pending);
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }

  /// Peak gain of the chime. Deliberately modest, and independent of the
  /// ambient track [volume] — it is a notification, not a soundtrack.
  static const double _chimePeak = 0.45;

  /// Gain steps applied over the decay, reaching near-silence before stop.
  static const List<double> _chimeEnvelope = <double>[0.3, 0.16, 0.05];

  @override
  Future<void> dispose() async {
    await stop();
    _soloud.deinit();
  }
}

class _LoadedSound {
  const _LoadedSound({required this.source, required this.handle});

  final AudioSource source;
  final SoundHandle handle;
}

/// Plays a single looping ambient track with volume control, and owns the
/// persisted playback preferences for it.
///
/// A [ChangeNotifier] so the UI can react to track / playing / volume changes.
/// All engine calls are routed through an injectable [AmbientEngine] (the real
/// one is [SoLoudAmbientEngine]); failures are caught and surfaced via
/// [lastError] instead of crashing, and [available] flips to false so the UI
/// can render a disabled state.
///
/// Persistence used to live in `SettingsStore`, which meant every UI action
/// had to reassemble an [AudioPrefs] snapshot from the player's current getters
/// and hand it back. The player now writes through on its own, so those call
/// sites just call the mutator.
class AmbientPlayer extends ChangeNotifier {
  AmbientPlayer({AmbientEngine? engine})
      : _engine = engine ?? SoLoudAmbientEngine();

  static const _kAudioTrack = 'audio_track';
  static const _kAudioVolume = 'audio_volume';
  static const _kAudioEnabled = 'audio_enabled';

  final AmbientEngine _engine;

  AmbientTrack? _track;
  bool _playing = false;
  double _volume = 0.7;
  bool _available = false;
  String? _lastError;
  SharedPreferences? _prefs;

  AmbientTrack? get track => _track;
  bool get playing => _playing;
  double get volume => _volume;

  /// False when the audio engine failed to initialize (e.g. no audio device).
  bool get available => _available;

  /// Last non-fatal error message, cleared on next successful operation.
  String? get lastError => _lastError;

  /// Restores the persisted track / volume and resumes playback when the
  /// previous session was still playing on exit.
  ///
  /// The stored "was playing" flag is genuinely separate state: the live
  /// [playing] getter is always false at this point (nothing has been restored
  /// yet), so it cannot stand in for what the user had going last time. Must be
  /// called after [init]. A stored track name that no longer exists (the enum
  /// value was removed or renamed) is ignored rather than fatal.
  Future<void> restore(SharedPreferences prefs) async {
    _prefs = prefs;
    final storedName = prefs.getString(_kAudioTrack);
    AmbientTrack? storedTrack;
    for (final t in AmbientTrack.values) {
      if (t.name == storedName) {
        storedTrack = t;
        break;
      }
    }
    _volume = (prefs.getDouble(_kAudioVolume) ?? _volume).clamp(0.0, 1.0);
    if (_available &&
        (prefs.getBool(_kAudioEnabled) ?? false) &&
        storedTrack != null) {
      await playTrack(storedTrack);
    } else {
      notifyListeners();
    }
  }

  /// Plays the short phase-change chime. No-op when the engine is
  /// unavailable; never throws.
  Future<void> playChime() async {
    if (!_available) return;
    try {
      await _engine.playChime();
    } catch (e) {
      _lastError = '提示音播放失败: $e';
      notifyListeners();
    }
  }

  Future<void> _persist({AmbientTrack? track}) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final selected = track ?? _track;
      if (selected != null) {
        await prefs.setString(_kAudioTrack, selected.name);
      } else {
        await prefs.remove(_kAudioTrack);
      }
      await prefs.setDouble(_kAudioVolume, _volume);
      await prefs.setBool(_kAudioEnabled, _playing);
    } catch (_) {
      // Best-effort persistence; playback keeps working.
    }
  }

  /// Initializes the engine. Safe to call once at startup; on failure the
  /// player stays in a disabled state rather than throwing to the caller.
  Future<void> init() async {
    try {
      await _engine.init();
      _available = true;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _available = false;
      _lastError = '音频引擎不可用: $e';
      notifyListeners();
    }
  }

  /// Switches to [track] and starts looping playback. No-op when the engine
  /// is unavailable; a failed load marks the track as errored.
  Future<void> playTrack(AmbientTrack track) async {
    if (!_available) return;
    try {
      await _engine.loadTrack(track);
      _engine.setVolume(_volume);
      _engine.play();
      _track = track;
      _playing = true;
      _lastError = null;
      await _persist(track: track);
      notifyListeners();
    } catch (e) {
      _lastError = '无法播放「${track.label}」: $e';
      notifyListeners();
    }
  }

  /// Toggles play/pause for the current track.
  Future<void> toggle() async {
    if (!_available || _track == null) return;
    try {
      if (_playing) {
        _engine.pause();
        _playing = false;
      } else {
        _engine.play();
        _playing = true;
      }
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = '播放控制失败: $e';
      notifyListeners();
    }
  }

  /// Stops playback entirely and clears the current track.
  Future<void> stop() async {
    if (!_available) return;
    try {
      await _engine.stop();
      _track = null;
      _playing = false;
      _lastError = null;
      await _persist();
      notifyListeners();
    } catch (e) {
      _lastError = '停止播放失败: $e';
      notifyListeners();
    }
  }

  /// Sets the volume (clamped to 0..1).
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    _volume = clamped;
    if (_available) {
      try {
        _engine.setVolume(clamped);
        _lastError = null;
      } catch (e) {
        _lastError = '音量设置失败: $e';
      }
    }
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _engine.dispose();
    super.dispose();
  }
}
