import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/cube/cube_validation.dart';
import 'package:rubicsolver/solver/cube_scrambler.dart';
import 'package:rubicsolver/solver/cube_solver.dart';
import 'package:rubicsolver/solver/solution_move.dart';

void main() {
  test('generates 18 to 25 moves without repeating a face', () {
    final scrambler = CubeScrambler(random: Random(7));

    for (var sample = 0; sample < 100; sample++) {
      final scramble = scrambler.generate();

      expect(scramble.moves.length, inInclusiveRange(18, 25));
      for (var index = 1; index < scramble.moves.length; index++) {
        expect(
          scramble.moves[index].face,
          isNot(scramble.moves[index - 1].face),
        );
      }
    }
  });

  test('uses only supported face turns and suffixes', () {
    final scrambler = CubeScrambler(random: Random(9));

    for (var sample = 0; sample < 50; sample++) {
      for (final move in scrambler.generate().moves) {
        expect('URFDLB', contains(move.notation[0]));
        expect(const ['', "'", '2'], contains(move.notation.substring(1)));
      }
    }
  });

  test('keeps formula and generated state consistent and legal', () {
    final scrambler = CubeScrambler(random: Random(11));

    for (var sample = 0; sample < 30; sample++) {
      final scramble = scrambler.generate();

      expect(
        scramble.state,
        CubeSolver.applyMoves(CubeState.solved(), scramble.moves),
      );
      expect(const CubeValidator().validate(scramble.state).isValid, isTrue);
    }
  });

  test('same random seed produces the same formulas', () {
    final first = CubeScrambler(random: Random(17));
    final second = CubeScrambler(random: Random(17));

    for (var sample = 0; sample < 10; sample++) {
      expect(first.generate().notation, second.generate().notation);
    }
  });

  test('creates immutable results directly from a move list', () {
    final source = [SolutionMove('R'), SolutionMove("U'"), SolutionMove('F2')];
    final scramble = CubeScramble.fromMoves(source);

    source.clear();

    expect(scramble.notation, "R U' F2");
    expect(
      scramble.state,
      CubeSolver.applyAlgorithm(CubeState.solved(), "R U' F2"),
    );
    expect(() => scramble.moves.clear(), throwsUnsupportedError);
    expect(CubeScramble.fromMoves(const []).state, CubeState.solved());
  });
}
