import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pomodoro_app/src/audio/ambient_player.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';
import 'package:pomodoro_app/src/widgets/audio_control_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEngine implements AmbientEngine {
  AmbientTrack? loadedTrack;
  bool playCalled = false;
  bool pauseCalled = false;
  bool stopCalled = false;
  double? lastVolume;

  @override
  Future<void> init() async {}

  @override
  Future<void> loadTrack(AmbientTrack track) async {
    loadedTrack = track;
  }

  @override
  void pause() {
    pauseCalled = true;
  }

  @override
  void play() {
    playCalled = true;
  }

  @override
  void setVolume(double volume) {
    lastVolume = volume;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
    loadedTrack = null;
  }

  @override
  Future<void> playChime() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late _FakeEngine engine;
  late AmbientPlayer player;

  Future<void> pumpBar(WidgetTester tester, {bool available = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    engine = _FakeEngine();
    player = AmbientPlayer(engine: engine);
    if (available) await player.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: player),
          Provider<SharedPreferences>.value(value: prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AudioControlBar()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows unavailable state when engine failed to init',
      (tester) async {
    await pumpBar(tester, available: false);
    expect(find.text('音频不可用'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('renders track chips, play button and volume slider',
      (tester) async {
    await pumpBar(tester);
    expect(find.text('雨声'), findsOneWidget);
    expect(find.text('白噪音'), findsOneWidget);
    expect(find.text('氛围'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('selecting a track starts playback and shows pause icon',
      (tester) async {
    await pumpBar(tester);
    await tester.tap(find.text('雨声'));
    await tester.pumpAndSettle();

    expect(engine.loadedTrack, AmbientTrack.rain);
    expect(engine.playCalled, isTrue);
    expect(player.track, AmbientTrack.rain);
    expect(player.playing, isTrue);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('tapping play/pause toggles state', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.text('白噪音'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();
    expect(engine.pauseCalled, isTrue);
    expect(player.playing, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('stop button clears the track', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.text('氛围'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();
    expect(engine.stopCalled, isTrue);
    expect(player.track, isNull);
    expect(player.playing, isFalse);
  });

  testWidgets('volume slider forwards value to the player', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.text('雨声'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(player.volume, isNot(0.7));
    expect(engine.lastVolume, player.volume);
  });
}
