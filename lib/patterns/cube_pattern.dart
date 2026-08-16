import '../cube/cube_state.dart';
import '../solver/cube_solver.dart';
import '../solver/solution_move.dart';

enum CubePatternDifficulty {
  beginner('入门'),
  intermediate('进阶'),
  challenge('挑战');

  const CubePatternDifficulty(this.label);

  final String label;
}

final class CubePattern {
  factory CubePattern.fromAlgorithm({
    required String id,
    required String name,
    required String description,
    required CubePatternDifficulty difficulty,
    required String algorithm,
  }) {
    final normalizedId = id.trim();
    final normalizedName = name.trim();
    final normalizedDescription = description.trim();
    if (!_idPattern.hasMatch(normalizedId)) {
      throw ArgumentError.value(id, 'id', '花式标识必须使用小写英文、数字和连字符');
    }
    if (normalizedName.isEmpty || normalizedDescription.isEmpty) {
      throw ArgumentError('花式名称和说明不能为空');
    }

    final parsedMoves = CubeSolver.parseAlgorithm(algorithm);
    if (parsedMoves.isEmpty) {
      throw ArgumentError.value(algorithm, 'algorithm', '花式公式不能为空');
    }
    final moves = List<SolutionMove>.unmodifiable(parsedMoves);
    return CubePattern._(
      id: normalizedId,
      name: normalizedName,
      description: normalizedDescription,
      difficulty: difficulty,
      moves: moves,
      targetState: CubeSolver.applyMoves(CubeState.solved(), moves),
    );
  }

  const CubePattern._({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.moves,
    required this.targetState,
  });

  static final _idPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  final String id;
  final String name;
  final String description;
  final CubePatternDifficulty difficulty;
  final List<SolutionMove> moves;
  final CubeState targetState;

  int get moveCount => moves.length;

  String get notation => moves.map((move) => move.notation).join(' ');
}
