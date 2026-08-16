import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/cube/cube_validation.dart';
import 'package:rubicsolver/patterns/cube_pattern.dart';
import 'package:rubicsolver/patterns/cube_pattern_catalog.dart';

void main() {
  const expectedFacelets = {
    'six-spots': 'FFFFUFFFFRRRURURRRDDDRFRDDDBBBBDBBBBLLLDLDLLLUUULBLUUU',
    'checkerboard': 'UDUDUDUDURLRLRLRLRFBFBFBFBFDUDUDUDUDLRLRLRLRLBFBFBFBFB',
    'four-spots': 'UUUUUUUUULLLLRLLLLBBBBFBBBBDDDDDDDDDRRRRLRRRRFFFFBFFFF',
    'cube-in-cube': 'FFFFUUFUURRURRUUUURFFRFFRRRBBBDDBDDBDDDLLDLLDLLLLBBLBB',
    'snake': 'UUUDUBDUFRRBLRRRFBLBDBFDUBUFDFFDUBFDBFFRLLRLLLLRUBDLRD',
    'superflip': 'UBULURUFURURFRBRDRFUFLFRFDFDFDLDRDBDLULBLFLDLBUBRBLBDB',
  };

  test('classic catalog is ordered, legal and snapshot-stable', () {
    final patterns = CubePatternCatalog.classics.patterns;

    expect(
      patterns.map((pattern) => pattern.id),
      orderedEquals(expectedFacelets.keys),
    );
    expect(
      patterns.map((pattern) => pattern.id).toSet().length,
      patterns.length,
    );
    expect(
      patterns.map((pattern) => pattern.targetState).toSet().length,
      patterns.length,
    );

    for (final pattern in patterns) {
      expect(pattern.targetState.toFacelets(), expectedFacelets[pattern.id]);
      expect(
        const CubeValidator().validate(pattern.targetState).isValid,
        isTrue,
      );
      expect(pattern.targetState, isNot(CubeState.solved()));
      expect(
        pattern.notation,
        pattern.moves.map((move) => move.notation).join(' '),
      );
      expect(pattern.moveCount, pattern.moves.length);
    }
  });

  test('model and catalog reject invalid data and remain immutable', () {
    final pattern = CubePattern.fromAlgorithm(
      id: 'sample',
      name: '示例',
      description: '测试花式',
      difficulty: CubePatternDifficulty.beginner,
      algorithm: 'R U',
    );

    expect(() => pattern.moves.clear(), throwsUnsupportedError);
    expect(
      () => CubePatternCatalog.classics.patterns.clear(),
      throwsUnsupportedError,
    );
    expect(() => CubePatternCatalog([pattern, pattern]), throwsArgumentError);
    expect(
      () => CubePattern.fromAlgorithm(
        id: '',
        name: '示例',
        description: '测试花式',
        difficulty: CubePatternDifficulty.beginner,
        algorithm: 'R',
      ),
      throwsArgumentError,
    );
    expect(
      () => CubePattern.fromAlgorithm(
        id: 'empty',
        name: '示例',
        description: '测试花式',
        difficulty: CubePatternDifficulty.beginner,
        algorithm: '   ',
      ),
      throwsArgumentError,
    );
  });
}
