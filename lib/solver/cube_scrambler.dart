import 'dart:math';

import '../cube/cube_face.dart';
import '../cube/cube_state.dart';
import 'cube_solver.dart';
import 'solution_move.dart';

final class CubeScramble {
  factory CubeScramble.fromMoves(Iterable<SolutionMove> moves) {
    final immutableMoves = List<SolutionMove>.unmodifiable(moves);
    return CubeScramble._(
      immutableMoves,
      CubeSolver.applyMoves(CubeState.solved(), immutableMoves),
    );
  }

  const CubeScramble._(this.moves, this.state);

  final List<SolutionMove> moves;
  final CubeState state;

  String get notation => moves.map((move) => move.notation).join(' ');
}

final class CubeScrambler {
  CubeScrambler({Random? random}) : _random = random ?? Random();

  static const minimumMoveCount = 18;
  static const maximumMoveCount = 25;
  static const _suffixes = ['', "'", '2'];

  final Random _random;

  CubeScramble generate() {
    final moveCount =
        minimumMoveCount +
        _random.nextInt(maximumMoveCount - minimumMoveCount + 1);
    final moves = <SolutionMove>[];
    CubeFace? previousFace;

    while (moves.length < moveCount) {
      final face = CubeFace.values[_random.nextInt(CubeFace.values.length)];
      if (face == previousFace) {
        continue;
      }
      final suffix = _suffixes[_random.nextInt(_suffixes.length)];
      moves.add(SolutionMove('${face.letter}$suffix'));
      previousFace = face;
    }

    return CubeScramble.fromMoves(moves);
  }
}
