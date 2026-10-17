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
  Future<AmbientPlayer> pumpPlayer(WidgetTester tester,
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
    return player;
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

  testWidgets('opens a dialog on wide windows and a sheet on narrow ones',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPlayer(tester);
    await tester.tap(find.byType(AudioMiniPlayer));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tapAt(const Offset(640, 20)); // dismiss
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AudioMiniPlayer));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the volume slider stays draggable inside the panel',
      (tester) async {
    // The panel used to live in a disabled PopupMenuItem, which swallowed the
    // slider's drag gesture; it must now respond to a real drag.
    final player = await pumpPlayer(tester);
    await tester.tap(find.byType(AudioMiniPlayer));
    await tester.pumpAndSettle();

    final before = player.volume;
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();

    // Only responsiveness is asserted, not direction: the regression this locks
    // is the drag gesture being swallowed at all, which happens regardless of
    // which way the value moves.
    expect(player.volume, isNot(closeTo(before, 1e-6)));
  });
}
