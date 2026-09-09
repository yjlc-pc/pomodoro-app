import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

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

/// Plays a single looping ambient track with volume control.
///
/// A [ChangeNotifier] so the UI can react to track / playing / volume changes.
/// All engine calls are routed through an injectable [AmbientEngine] (the real
/// one is [SoLoudAmbientEngine]); failures are caught and surfaced via
/// [lastError] instead of crashing, and [available] flips to false so the UI
/// can render a disabled state.
class AmbientPlayer extends ChangeNotifier {
  AmbientPlayer({AmbientEngine? engine})
      : _engine = engine ?? SoLoudAmbientEngine();

  final AmbientEngine _engine;

  AmbientTrack? _track;
  bool _playing = false;
  double _volume = 0.7;
  bool _available = false;
  String? _lastError;

  AmbientTrack? get track => _track;
  bool get playing => _playing;
  double get volume => _volume;

  /// False when the audio engine failed to initialize (e.g. no audio device).
  bool get available => _available;

  /// Last non-fatal error message, cleared on next successful operation.
  String? get lastError => _lastError;

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
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _engine.dispose();
    super.dispose();
  }
}
