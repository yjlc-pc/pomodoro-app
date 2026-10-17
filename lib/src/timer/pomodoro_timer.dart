import 'dart:async';
import 'package:flutter/foundation.dart';
import 'pomodoro_settings.dart';

/// The current phase of the Pomodoro cycle.
enum PomodoroPhase { focus, shortBreak, longBreak }

extension PomodoroPhaseX on PomodoroPhase {
  String get label => switch (this) {
        PomodoroPhase.focus => '专注',
        PomodoroPhase.shortBreak => '短休息',
        PomodoroPhase.longBreak => '长休息',
      };

  String get title => switch (this) {
        PomodoroPhase.focus => '保持专注',
        PomodoroPhase.shortBreak => '休息一下',
        PomodoroPhase.longBreak => '该休息了',
      };
}

/// The core Pomodoro timer engine.
///
/// Drive by [start], [pause], [reset], [skip]. Emits notifications on every
/// tick so an attached UI can rebuild. Recomputes remaining time from
/// [DateTime] timestamps rather than naive counters to avoid drift.
class PomodoroTimer extends ChangeNotifier {
  PomodoroTimer(PomodoroSettings settings, {DateTime Function()? clock})
      : _settings = settings,
        _clock = clock ?? DateTime.now {
    _focusDuration = Duration(minutes: settings.focusMinutes);
    _shortBreakDuration = Duration(minutes: settings.shortBreakMinutes);
    _longBreakDuration = Duration(minutes: settings.longBreakMinutes);
    _remaining = _focusDuration.inMilliseconds;
  }

  PomodoroSettings _settings;
  final DateTime Function() _clock;

  late Duration _focusDuration;
  late Duration _shortBreakDuration;
  late Duration _longBreakDuration;

  PomodoroPhase _phase = PomodoroPhase.focus;
  bool _running = false;
  int _completedFocusSessions = 0;
  bool _isLongBreakDue = false;

  int _remaining = 0; // milliseconds
  DateTime? _lastTick;
  DateTime? _focusStartTime;
  Timer? _ticker;

  /// Called exactly once when a focus phase completes naturally (the countdown
  /// ran to zero). Not invoked when the focus is skipped or reset. Receives the
  /// full [Duration] of the completed focus so callers can persist it.
  void Function(Duration completedFocus)? onFocusCompleted;

  /// Called every time the engine moves from one phase to another, receiving
  /// the phase now in effect.
  ///
  /// Fires from natural completion *and* from [skip] (so the user gets the same
  /// acknowledgement whether the phase ended or was cut short), but never from
  /// [reset] or [pause], which do not change phase. Auto-start continuations
  /// also fire, since they arrive via the same [_switchPhase] call.
  ///
  /// [onFocusCompleted] remains the seam for statistics: it fires only on
  /// natural completion, which is the distinction callers that record or log
  /// actually care about.
  void Function(PomodoroPhase phase)? onPhaseChanged;

  /// The todo linked to the current focus session, if any. Display-only: it is
  /// never aggregated and is cleared when the focus ends.
  String? _linkedTodoId;

  /// Active settings.
  PomodoroSettings get settings => _settings;

  /// Current phase of the cycle.
  PomodoroPhase get phase => _phase;

  /// Whether the timer is currently counting down.
  bool get running => _running;

  /// Count of completed focus sessions in the current cycle.
  int get completedFocusSessions => _completedFocusSessions;

  /// Total duration of the current phase (for rendering full progress).
  Duration get phaseDuration => switch (_phase) {
        PomodoroPhase.focus => _focusDuration,
        PomodoroPhase.shortBreak => _shortBreakDuration,
        PomodoroPhase.longBreak => _longBreakDuration,
      };

  int get remainingMilliseconds => _remaining;
  Duration get remaining => Duration(milliseconds: _remaining);

  /// Fraction of the phase completed: 0.0 (start) → 1.0 (done).
  ///
  /// Kept for callers that want to report *elapsed* work. For rendering a
  /// countdown prefer [remainingFraction], which is its complement and matches
  /// what the timer displays.
  double get progress {
    final total = phaseDuration.inMilliseconds;
    if (total <= 0) return 1.0;
    return ((total - _remaining) / total).clamp(0.0, 1.0).toDouble();
  }

  /// Fraction of the phase still to go: 1.0 (just started) → 0.0 (done).
  ///
  /// This is what a countdown ring should draw. Using [progress] instead makes
  /// the ring fill up as the number inside it counts down, so the two disagree
  /// about direction; using this getter keeps them aligned.
  double get remainingFraction {
    final total = phaseDuration.inMilliseconds;
    if (total <= 0) return 0.0;
    return (_remaining / total).clamp(0.0, 1.0).toDouble();
  }

  /// Format remaining time as "MM:SS".
  String get formattedTime {
    final totalSeconds = (_remaining / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// The id of the todo linked to the current focus session, or null when none
  /// is linked. Used for display only; cleared when the focus ends.
  String? get linkedTodoId => _linkedTodoId;

  /// Start or resume counting down.
  ///
  /// When starting a fresh focus phase, [linkedTodoId] may carry the id of the
  /// todo the user chose to focus on. Starting any non-focus phase always clears
  /// the link so a stale todo never bleeds into the next round.
  void start({String? linkedTodoId}) {
    if (_running) return;
    _linkedTodoId = _phase == PomodoroPhase.focus ? linkedTodoId : null;
    if (_phase == PomodoroPhase.focus) _focusStartTime = _clock();
    _running = true;
    _lastTick = _clock();
    _startTicker();
    notifyListeners();
  }

  /// Pause the countdown.
  void pause() {
    if (!_running) return;
    _running = false;
    _ticker?.cancel();
    _ticker = null;
    _lastTick = null;
    notifyListeners();
  }

  /// Toggle running state.
  void toggle() => _running ? pause() : start();

  /// Reset the current phase to full duration and stop.
  void reset() {
    _running = false;
    _ticker?.cancel();
    _ticker = null;
    _linkedTodoId = null;
    _focusStartTime = null;
    _remaining = phaseDuration.inMilliseconds;
    notifyListeners();
  }

  /// Reconfigure durations from settings. When the timer is running the
  /// durations are applied immediately (the current countdown is NOT reset)
  /// so the user can adjust settings without interrupting a session. The new
  /// durations take effect on the next phase transition or manual reset.
  void applySettings(PomodoroSettings settings) {
    _settings = settings;
    _focusDuration = Duration(minutes: settings.focusMinutes);
    _shortBreakDuration = Duration(minutes: settings.shortBreakMinutes);
    _longBreakDuration = Duration(minutes: settings.longBreakMinutes);
    if (!_running) {
      _remaining = phaseDuration.inMilliseconds;
    }
    notifyListeners();
  }

  /// Skip to the next phase.
  void skip() {
    _advance();
    notifyListeners();
  }

  /// Process one tick immediately. Exposed for tests; production ticks on a
  /// periodic timer.
  @visibleForTesting
  void tick() {
    _tick();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final now = _clock();
    if (_lastTick != null) {
      _remaining -= now.difference(_lastTick!).inMilliseconds;
    }
    _lastTick = now;
    if (_remaining <= 0) {
      _remaining = 0;
      _onPhaseComplete();
      return;
    }
    notifyListeners();
  }

  void _onPhaseComplete() {
    _running = false;
    _ticker?.cancel();
    _ticker = null;

    if (_phase == PomodoroPhase.focus) {
      _completedFocusSessions += 1;
      // Report actual elapsed wall-clock time so stats reflect real focus, not
      // just the configured duration (which could differ after drift correction).
      final elapsed = _focusStartTime != null
          ? _clock().difference(_focusStartTime!)
          : _focusDuration;
      _focusStartTime = null;
      onFocusCompleted?.call(elapsed);
      _linkedTodoId = null;
      _isLongBreakDue =
          _completedFocusSessions % _settings.sessionsBeforeLongBreak == 0;
      _switchPhase(
          _isLongBreakDue ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak);
      if (_settings.autoStartBreaks) start();
    } else {
      _switchPhase(PomodoroPhase.focus);
      if (_settings.autoStartFocus) start();
    }
    // Always announce the phase change: without this, the UI stays frozen
    // on the completed phase when no auto-start is configured, because the
    // completion tick returns before the notifyListeners() below.
    notifyListeners();
  }

  void _advance() {
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    _linkedTodoId = null;
    _focusStartTime = null;
    if (_phase == PomodoroPhase.focus) {
      _switchPhase(_isLongBreakDue
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak);
      // Skipping ends the focus early, so the same auto-start rule applies.
      if (_settings.autoStartBreaks) start();
    } else {
      _switchPhase(PomodoroPhase.focus);
      if (_settings.autoStartFocus) start();
    }
  }

  void _switchPhase(PomodoroPhase next) {
    _phase = next;
    _remaining = switch (next) {
      PomodoroPhase.focus => _focusDuration.inMilliseconds,
      PomodoroPhase.shortBreak => _shortBreakDuration.inMilliseconds,
      PomodoroPhase.longBreak => _longBreakDuration.inMilliseconds,
    };
    _lastTick = null;
    // Entering a focus phase always starts a fresh round: clear the
    // long-break marker so a manual skip can never re-enter a long break
    // after the previous long break already happened.
    if (next == PomodoroPhase.focus) {
      _isLongBreakDue = false;
    }
    onPhaseChanged?.call(next);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
