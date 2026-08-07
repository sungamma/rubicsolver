import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/solver/cube_solver.dart';
import 'package:rubicsolver/solver/solution_move.dart';

void main() {
  group('SolutionMove', () {
    test('parses standard notation and describes the turn', () {
      final move = SolutionMove("R'");

      expect(move.notation, "R'");
      expect(move.face, CubeFace.right);
      expect(move.turns, 3);
      expect(move.signedQuarterTurns, -1);
      expect(move.instruction, '正对右面看，逆时针转动 90°');
    });

    test('supports double turns and rejects non-standard notation', () {
      final move = SolutionMove('F2');

      expect(move.turns, 2);
      expect(move.instruction, '正对前面看，转动 180°');
      expect(() => SolutionMove('R3'), throwsArgumentError);
      expect(() => SolutionMove.parse('r'), throwsArgumentError);
      expect(() => SolutionMove.parse('R3'), throwsArgumentError);
      expect(() => SolutionMove.parse("R2'"), throwsArgumentError);
    });
  });

  group('CubeSolver pure move helpers', () {
    test('applies and reverses a standard algorithm', () {
      final scrambled = CubeSolver.applyAlgorithm(
        CubeState.solved(),
        "R U R' U'",
      );

      expect(scrambled, isNot(CubeState.solved()));
      expect(
        CubeSolver.applyAlgorithm(scrambled, "U R U' R'"),
        CubeState.solved(),
      );
    });

    test('applies a list of solution moves without mutating the input', () {
      final initial = CubeState.solved();
      final moves = [SolutionMove('R'), SolutionMove('U2')];

      final updated = CubeSolver.applyMoves(initial, moves);

      expect(initial, CubeState.solved());
      expect(updated, CubeSolver.applyAlgorithm(initial, 'R U2'));
    });

    test('applies every standard face-turn and its inverse', () {
      for (final notation in const [
        'U',
        'R',
        'F',
        'D',
        'L',
        'B',
        "U'",
        "R'",
        "F'",
        "D'",
        "L'",
        "B'",
        'U2',
        'R2',
        'F2',
        'D2',
        'L2',
        'B2',
      ]) {
        final move = SolutionMove(notation);
        final inverse = move.inverse();
        final afterMove = CubeSolver.applyMoves(CubeState.solved(), [move]);
        expect(
          CubeSolver.applyMoves(afterMove, [inverse]),
          CubeState.solved(),
          reason: '$notation followed by ${inverse.notation}',
        );
      }
    });
  });

  group('CubeSolver', () {
    test('returns an empty move list for an already solved cube', () async {
      final moves = await const CubeSolver().solve(CubeState.solved());

      expect(moves, isEmpty);
    });

    test('solution solves a single face turn', () async {
      final scrambled = CubeSolver.applyAlgorithm(CubeState.solved(), 'R');

      final moves = await const CubeSolver().solve(scrambled);

      expect(CubeSolver.applyMoves(scrambled, moves), CubeState.solved());
      expect(moves, isNotEmpty);
    });

    test('solution solves a short scramble', () async {
      final scrambled = CubeSolver.applyAlgorithm(
        CubeState.solved(),
        "R U R' U'",
      );
      final moves = await const CubeSolver().solve(scrambled);
      final solved = CubeSolver.applyMoves(scrambled, moves);

      expect(solved, CubeState.solved());
      expect(moves, isNotEmpty);
      expect(
        moves.every(
          (move) => RegExp(r"^[URFDLB](2|')?$").hasMatch(move.notation),
        ),
        isTrue,
      );
    });

    test('rejects an invalid physical state before solving', () async {
      final invalid = CubeState.solved().replaceSticker(0, CubeFace.front);

      await expectLater(
        const CubeSolver().solve(invalid),
        throwsA(isA<InvalidCubeException>()),
      );
    });

    test('reports a null cuber result as a solve timeout', () async {
      final scrambled = CubeSolver.applyAlgorithm(CubeState.solved(), 'R U');

      await expectLater(
        const CubeSolver(
          maxDepth: 0,
          timeout: Duration(microseconds: 1),
        ).solve(scrambled),
        throwsA(isA<SolveTimeoutException>()),
      );
    });
  });
}
