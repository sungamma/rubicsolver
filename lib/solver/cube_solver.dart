import 'dart:async';
import 'dart:isolate';

import 'package:cuber/cuber.dart' as cuber;

import '../cube/cube_state.dart';
import '../cube/cube_validation.dart';
import 'solution_move.dart';

/// The default search depth used by the Kociemba solver.
const int defaultSolveMaxDepth = 25;

/// The default amount of time allowed for one solve request.
const Duration defaultSolveTimeout = Duration(seconds: 30);

/// Short aliases for callers that prefer module-level configuration names.
const int defaultMaxDepth = defaultSolveMaxDepth;
const Duration defaultTimeout = defaultSolveTimeout;

/// Thrown when a [CubeState] is not a physically reachable cube.
class InvalidCubeException implements Exception {
  InvalidCubeException(this.validation, {this.state});

  /// The state that failed validation, when available.
  final CubeState? state;

  /// The complete validation result, including actionable issues.
  final ValidationResult validation;

  /// Convenience access to the validation issues.
  List<ValidationIssue> get issues => validation.issues;

  /// Alias for [validation] used by error presenters.
  ValidationResult get result => validation;

  /// A localized summary suitable for displaying in an error surface.
  String get message => issues.isEmpty
      ? '魔方状态不合法。'
      : issues.map((issue) => issue.message).join('；');

  @override
  String toString() => 'InvalidCubeException: $message';
}

/// Thrown when Kociemba cannot produce a solution within the configured
/// search limits.
class SolveTimeoutException extends TimeoutException {
  SolveTimeoutException({required this.maxDepth, required this.timeout})
    : super('魔方求解超时：在 ${timeout.inSeconds} 秒或深度 $maxDepth 内未完成。', timeout);

  final int maxDepth;
  final Duration timeout;

  /// Alias for [timeout].
  @override
  Duration get duration => timeout;
}

/// Optional hook useful to UI clients and deterministic tests.
typedef CubeSolveOverride =
    FutureOr<List<SolutionMove>> Function(CubeState state);

/// Thin, isolate-backed adapter around cuber's Kociemba implementation.
///
/// The class deliberately remains non-final so a UI can provide a small fake
/// in widget tests by overriding [solve].
class CubeSolver {
  const CubeSolver({
    this.maxDepth = defaultSolveMaxDepth,
    this.timeout = defaultSolveTimeout,
    this.validator = const CubeValidator(),
    this.solveOverride,
  });

  /// Default maximum search depth.
  static const int defaultMaxDepth = defaultSolveMaxDepth;

  /// Default solve timeout.
  static const Duration defaultTimeout = defaultSolveTimeout;

  final int maxDepth;
  final Duration timeout;
  final CubeValidator validator;
  final CubeSolveOverride? solveOverride;

  /// Solves [state] and returns standard `R`, `R'`, `R2` moves.
  ///
  /// Validation runs on the caller isolate.  Only the validated facelet
  /// string and primitive search limits cross the isolate boundary.
  Future<List<SolutionMove>> solve(
    CubeState state, {
    int? maxDepth,
    Duration? timeout,
  }) async {
    final validation = validator.validate(state);
    if (!validation.isValid) {
      throw InvalidCubeException(validation, state: state);
    }

    final effectiveDepth = maxDepth ?? this.maxDepth;
    final effectiveTimeout = timeout ?? this.timeout;
    if (effectiveDepth < 0) {
      throw ArgumentError.value(effectiveDepth, 'maxDepth', '不能为负数');
    }
    if (effectiveTimeout.isNegative) {
      throw ArgumentError.value(effectiveTimeout, 'timeout', '不能为负数');
    }

    final override = solveOverride;
    if (override != null) {
      return List.unmodifiable(await override(state));
    }

    final algorithm = await Isolate.run<String?>(
      () => _solveFaceletsInIsolate(
        state.toFacelets(),
        effectiveDepth,
        effectiveTimeout.inMicroseconds,
      ),
    );

    if (algorithm == null) {
      throw SolveTimeoutException(
        maxDepth: effectiveDepth,
        timeout: effectiveTimeout,
      );
    }

    if (algorithm.trim().isEmpty) {
      return const <SolutionMove>[];
    }
    return parseAlgorithm(algorithm);
  }

  /// Parses a standard algorithm into immutable [SolutionMove] objects.
  static List<SolutionMove> parseAlgorithm(String algorithm) {
    final moves = <SolutionMove>[];
    var index = 0;

    while (index < algorithm.length) {
      final character = algorithm[index];
      if (_isAlgorithmSeparator(character)) {
        index++;
        continue;
      }

      if (!_faceLetters.contains(character)) {
        throw FormatException('算法包含无效动作“$character”（位置 $index）。');
      }

      var notation = character;
      index++;
      if (index < algorithm.length &&
          (algorithm[index] == "'" || algorithm[index] == '2')) {
        notation += algorithm[index++];
      }
      moves.add(SolutionMove.parse(notation));
    }

    return List.unmodifiable(moves);
  }

  /// Applies a standard algorithm to [state] without mutating it.
  static CubeState applyAlgorithm(CubeState state, String algorithm) {
    return applyMoves(state, parseAlgorithm(algorithm));
  }

  /// Applies [moves] to [state] without mutating it.
  static CubeState applyMoves(CubeState state, Iterable<SolutionMove> moves) {
    final cuberMoves = [
      for (final move in moves) cuber.Move.parse(move.notation),
    ];
    if (cuberMoves.isEmpty) {
      return state;
    }

    final cube = cuber.Algorithm(
      moves: cuberMoves,
    ).apply(cuber.Cube.from(state.toFacelets()));
    return CubeState.fromFacelets(cube.definition);
  }

  /// Convenience instance wrapper around [applyAlgorithm].
  CubeState apply(CubeState state, String algorithm) =>
      applyAlgorithm(state, algorithm);

  /// Convenience instance wrapper around [applyMoves].
  CubeState applyMoveList(CubeState state, Iterable<SolutionMove> moves) =>
      applyMoves(state, moves);
}

/// Backwards-compatible name for callers that refer to the package adapter as
/// a cuber solver.
typedef CuberSolver = CubeSolver;

const _faceLetters = 'URFDLB';

bool _isAlgorithmSeparator(String character) {
  return character.trim().isEmpty || '()[]'.contains(character);
}

/// Isolate entry point.  Return a string because plain strings are guaranteed
/// to be transferable between Dart isolates, whereas package objects need not
/// be.
String? _solveFaceletsInIsolate(
  String facelets,
  int maxDepth,
  int timeoutMicros,
) {
  final cube = cuber.Cube.from(facelets);
  final solution = cube.solve(
    maxDepth: maxDepth,
    timeout: Duration(microseconds: timeoutMicros),
  );
  return solution?.algorithm.toString();
}

/// Top-level aliases keep the pure helpers convenient in non-UI Dart code.
CubeState applyAlgorithm(CubeState state, String algorithm) =>
    CubeSolver.applyAlgorithm(state, algorithm);

CubeState applyMoves(CubeState state, Iterable<SolutionMove> moves) =>
    CubeSolver.applyMoves(state, moves);

List<SolutionMove> parseAlgorithm(String algorithm) =>
    CubeSolver.parseAlgorithm(algorithm);
