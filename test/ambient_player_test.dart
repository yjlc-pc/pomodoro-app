import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/src/audio/ambient_player.dart';
import 'package:pomodoro_app/src/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records engine calls for asserting state-machine behaviour without a real
/// audio device.
class FakeAmbientEngine implements AmbientEngine {
  bool initialized = false;
  AmbientTrack? loadedTrack;
  bool playCalls = false;
  bool pauseCalls = false;
  bool stopCalls = false;
  double? lastVolume;
  bool throwOnLoad = false;

  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  Future<void> loadTrack(AmbientTrack track) async {
    if (throwOnLoad) throw Exception('load failed');
    loadedTrack = track;
  }

  @override
  void play() {
    playCalls = true;
  }

  @override
  void pause() {
    pauseCalls = true;
  }

  @override
  Future<void> stop() async {
    stopCalls = true;
    loadedTrack = null;
  }

  @override
  void setVolume(double volume) {
    lastVolume = volume;
  }

  @override
  Future<void> dispose() async {
    stopCalls = true;
  }
}

void main() {
  group('AmbientPlayer', () {
    late FakeAmbientEngine engine;
    late AmbientPlayer player;

    setUp(() {
      engine = FakeAmbientEngine();
      player = AmbientPlayer(engine: engine);
    });

    test('init marks player available', () async {
      expect(player.available, isFalse);
      await player.init();
      expect(player.available, isTrue);
      expect(engine.initialized, isTrue);
    });

    test('init failure disables player without throwing', () async {
      engine.throwOnLoad = true; // not used by init, but keep engine failing
      final failing = _FailingInitEngine();
      final p = AmbientPlayer(engine: failing);
      await p.init();
      expect(p.available, isFalse);
      expect(p.lastError, isNotNull);
    });

    test('playTrack loads, plays and reports state', () async {
      await player.init();
      await player.playTrack(AmbientTrack.rain);
      expect(engine.loadedTrack, AmbientTrack.rain);
      expect(engine.playCalls, isTrue);
      expect(player.track, AmbientTrack.rain);
      expect(player.playing, isTrue);
    });

    test('toggle pauses then resumes', () async {
      await player.init();
      await player.playTrack(AmbientTrack.focus);
      await player.toggle();
      expect(player.playing, isFalse);
      expect(engine.pauseCalls, isTrue);
      await player.toggle();
      expect(player.playing, isTrue);
      expect(engine.playCalls, isTrue);
    });

    test('toggle is a no-op without a track', () async {
      await player.init();
      await player.toggle();
      expect(player.playing, isFalse);
    });

    test('stop clears track and state', () async {
      await player.init();
      await player.playTrack(AmbientTrack.lofi);
      await player.stop();
      expect(engine.stopCalls, isTrue);
      expect(player.track, isNull);
      expect(player.playing, isFalse);
    });

    test('setVolume clamps and forwards to engine', () async {
      await player.init();
      await player.setVolume(0.3);
      expect(player.volume, 0.3);
      expect(engine.lastVolume, 0.3);
      await player.setVolume(1.7);
      expect(player.volume, 1.0);
      await player.setVolume(-0.2);
      expect(player.volume, 0.0);
    });

    test('failed load surfaces lastError and keeps player running', () async {
      await player.init();
      engine.throwOnLoad = true;
      await player.playTrack(AmbientTrack.rain);
      expect(player.lastError, isNotNull);
      expect(player.track, isNull);
      // Recovers on next successful call.
      engine.throwOnLoad = false;
      await player.playTrack(AmbientTrack.focus);
      expect(player.lastError, isNull);
      expect(player.track, AmbientTrack.focus);
    });
  });

  group('SettingsStore audio prefs', () {
    test('loadAudioPrefs defaults to disabled, 0.7 volume, no track',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final prefs2 = SettingsStore().loadAudioPrefs(prefs);
      expect(prefs2.enabled, isFalse);
      expect(prefs2.volume, 0.7);
      expect(prefs2.track, isNull);
    });

    test('save/load round-trip persists track, volume and enabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore();
      await store.saveAudioPrefs(
        prefs,
        const AudioPrefs(
          track: AmbientTrack.rain,
          volume: 0.45,
          enabled: true,
        ),
      );

      final loaded = store.loadAudioPrefs(prefs);
      expect(loaded.track, AmbientTrack.rain);
      expect(loaded.volume, 0.45);
      expect(loaded.enabled, isTrue);
    });

    test('loadAudioPrefs tolerates unknown track names', () async {
      SharedPreferences.setMockInitialValues(
          {'audio_track': 'does_not_exist', 'audio_volume': 0.9});
      final prefs = await SharedPreferences.getInstance();
      final loaded = SettingsStore().loadAudioPrefs(prefs);
      expect(loaded.track, isNull);
      expect(loaded.volume, 0.9);
    });
  });
}

class _FailingInitEngine implements AmbientEngine {
  @override
  Future<void> init() async => throw Exception('no audio device');

  @override
  Future<void> loadTrack(AmbientTrack track) async {}

  @override
  void pause() {}

  @override
  void play() {}

  @override
  void setVolume(double volume) {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
