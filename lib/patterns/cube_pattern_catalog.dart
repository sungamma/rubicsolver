import 'cube_pattern.dart';

final class CubePatternCatalog {
  factory CubePatternCatalog(Iterable<CubePattern> patterns) {
    final values = List<CubePattern>.unmodifiable(patterns);
    if (values.isEmpty) {
      throw ArgumentError.value(patterns, 'patterns', '花式目录不能为空');
    }
    final ids = values.map((pattern) => pattern.id).toSet();
    if (ids.length != values.length) {
      throw ArgumentError.value(patterns, 'patterns', '花式标识不能重复');
    }
    return CubePatternCatalog._(values);
  }

  const CubePatternCatalog._(this.patterns);

  final List<CubePattern> patterns;

  static final classics = CubePatternCatalog([
    CubePattern.fromAlgorithm(
      id: 'six-spots',
      name: '六面点',
      description: '每个面只保留中心色，周围八格来自相邻面。',
      difficulty: CubePatternDifficulty.beginner,
      algorithm: "U D' R L' F B'",
    ),
    CubePattern.fromAlgorithm(
      id: 'checkerboard',
      name: '棋盘格',
      description: '六个面都形成中心色与对面色交替的棋盘。',
      difficulty: CubePatternDifficulty.beginner,
      algorithm: 'U2 D2 R2 L2 F2 B2',
    ),
    CubePattern.fromAlgorithm(
      id: 'four-spots',
      name: '四面点',
      description: '上下两面保持完整，四个侧面各留下一个中心点。',
      difficulty: CubePatternDifficulty.intermediate,
      algorithm: "F2 B2 U D' R2 L2 U D'",
    ),
    CubePattern.fromAlgorithm(
      id: 'cube-in-cube',
      name: '立方体中立方体',
      description: '三个可见方向组合出嵌套的小立方体轮廓。',
      difficulty: CubePatternDifficulty.intermediate,
      algorithm: "F L F U' R U F2 L2 U' L' B D' B' L2 U",
    ),
    CubePattern.fromAlgorithm(
      id: 'snake',
      name: '蛇形',
      description: '连续色块沿六个面蜿蜒连接，形成环绕魔方的长蛇。',
      difficulty: CubePatternDifficulty.challenge,
      algorithm: "R2 F2 U2 R B2 U2 F2 L2 D' R2 F2 U2 R' D B2",
    ),
    CubePattern.fromAlgorithm(
      id: 'superflip',
      name: '超级翻转',
      description: '十二个棱块全部翻转，角块和中心保持原位。',
      difficulty: CubePatternDifficulty.challenge,
      algorithm: "U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2",
    ),
  ]);
}
