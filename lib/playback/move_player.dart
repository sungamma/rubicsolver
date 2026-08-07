import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cube/cube_face.dart';
import '../cube/cube_state.dart';
import '../solver/cube_solver.dart';
import '../solver/solution_move.dart';

/// Default interval between two demonstrated moves.
const Duration defaultMoveSpeed = Duration(milliseconds: 900);

/// A small, deterministic state machine for stepping through a solution.
///
/// [currentIndex] is the number of moves already applied.  Thus zero is the
/// untouched input state and [moves.length] is the solved state.  Every seek
/// rebuilds from [_initialState], which prevents accumulated inverse/rounding
/// errors when the user jumps around the formula.
class MovePlayer extends ChangeNotifier {
  MovePlayer({
    required CubeState initial,
    required Iterable<SolutionMove> moves,
    Duration speed = defaultMoveSpeed,
  }) : _initialState = initial,
       _moves = List.unmodifiable(moves) {
    _validateSpeed(speed);
    _speed = speed;
    _currentState = initial;
  }

  /// Alias accepted by callers that prefer the more explicit name.
  MovePlayer.fromState({
    required CubeState initialState,
    required Iterable<SolutionMove> moves,
    Duration speed = defaultMoveSpeed,
  }) : this(initial: initialState, moves: moves, speed: speed);

  final CubeState _initialState;
  final List<SolutionMove> _moves;
  late CubeState _currentState;
  Timer? _timer;
  var _currentIndex = 0;
  late Duration _speed;
  var _disposed = false;

  /// The immutable state before any solution move is applied.
  CubeState get initialState => _initialState;

  /// The complete, immutable solution.
  List<SolutionMove> get moves => _moves;

  /// Number of moves already applied (from 0 through [moves.length]).
  int get currentIndex => _currentIndex;

  /// State represented by [currentIndex].
  CubeState get currentState => _currentState;

  /// The move most recently applied, or the first pending move at the start.
  SolutionMove? get currentMove {
    if (_moves.isEmpty) {
      return null;
    }
    return _currentIndex == 0 ? _moves.first : _moves[_currentIndex - 1];
  }

  /// The next move that will be applied, if any.
  SolutionMove? get nextMove =>
      _currentIndex < _moves.length ? _moves[_currentIndex] : null;

  /// Face highlighted by the current action.
  CubeFace? get currentFace => currentMove?.face;

  /// Whether every solution move has been applied.
  bool get isComplete => _currentIndex == _moves.length;

  /// Whether automatic playback is active.
  bool get isPlaying => _timer != null;

  /// Playback interval. Only the supported 500/900/1400 ms presets are
  /// accepted so the UI and the state machine cannot drift apart.
  Duration get speed => _speed;

  set speed(Duration value) {
    _validateSpeed(value);
    if (_speed == value) {
      return;
    }
    final wasPlaying = isPlaying;
    _timer?.cancel();
    _timer = null;
    _speed = value;
    if (wasPlaying) {
      _startTimer();
    }
    _notifySafely();
  }

  /// Fraction of the formula already completed.
  double get progress =>
      _moves.isEmpty ? 1 : _currentIndex / _moves.length.toDouble();

  /// Apply one move, if one remains.
  void next() {
    if (_currentIndex >= _moves.length) {
      return;
    }
    _setIndex(_currentIndex + 1);
  }

  /// Return to the previous state, if possible.
  void previous() {
    if (_currentIndex == 0) {
      return;
    }
    _setIndex(_currentIndex - 1);
  }

  /// Jump to a completed-move count. Values outside the formula are clamped.
  void seek(int index) {
    final target = index.clamp(0, _moves.length);
    if (target == _currentIndex) {
      return;
    }
    _setIndex(target);
  }

  /// Start automatic playback. At the end, playback starts over so the user
  /// can replay a finished solution without leaving the result page.
  void play() {
    if (_disposed || _moves.isEmpty) {
      return;
    }
    if (isComplete) {
      _setIndex(0);
    }
    if (isPlaying) {
      return;
    }
    _startTimer();
    _notifySafely();
  }

  /// Pause automatic playback without changing the current state.
  void pause() {
    if (!isPlaying) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _notifySafely();
  }

  /// Toggle automatic playback.
  void togglePlay() {
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(_speed, (_) {
      if (_disposed) {
        return;
      }
      if (isComplete) {
        pause();
      } else {
        next();
        if (isComplete) {
          pause();
        }
      }
    });
  }

  void _setIndex(int target) {
    final state = CubeSolver.applyMoves(_initialState, _moves.take(target));
    _currentIndex = target;
    _currentState = state;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  static void _validateSpeed(Duration value) {
    if (value != const Duration(milliseconds: 500) &&
        value != defaultMoveSpeed &&
        value != const Duration(milliseconds: 1400)) {
      throw ArgumentError.value(value, 'speed', '播放速度只能是 500、900 或 1400 毫秒');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
