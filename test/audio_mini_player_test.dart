import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pomodoro_app/src/audio/ambient_player.dart';
import 'package:pomodoro_app/src/theme/app_theme.dart';
import 'package:pomodoro_app/src/widgets/audio_control_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEngine implements AmbientEngine {
  @override
  Future<void> init() async {}

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
  Future<void> playChime() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  Future<void> pumpPlayer(WidgetTester tester,
      {bool available = true, AmbientTrack? track}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final player = AmbientPlayer(engine: _FakeEngine());
    if (available) await player.init();
    if (track != null) await player.playTrack(track);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: player),
          Provider<SharedPreferences>.value(value: prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            appBar: AppBar(actions: [const AudioMiniPlayer()]),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hidden when audio engine is unavailable', (tester) async {
    await pumpPlayer(tester, available: false);
    expect(find.byType(AudioMiniPlayer), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsNothing);
  });

  testWidgets('shows track label once a track is selected', (tester) async {
    await pumpPlayer(tester, track: AmbientTrack.rain);
    expect(find.text('雨声'), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
  });

  testWidgets('tapping opens the audio panel overlay with controls',
      (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.byType(AudioMiniPlayer));
    await tester.pumpAndSettle();

    expect(find.text('白噪音'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('选择背景音'), findsOneWidget);
  });
}
