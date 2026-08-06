import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_state.dart';

void main() {
  group('CubeFace', () {
    test('uses the Kociemba URFDLB order', () {
      expect(CubeFace.values.map((face) => face.letter).join(), 'URFDLB');
    });

    test('parses face letters case-insensitively', () {
      expect(CubeFace.fromLetter('f'), CubeFace.front);
      expect(() => CubeFace.fromLetter('X'), throwsFormatException);
    });
  });

  group('CubeState', () {
    const solved = 'UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB';

    test('solved state serializes in URFDLB order', () {
      expect(CubeState.solved().toFacelets(), solved);
    });

    test('round-trips a facelet string', () {
      expect(CubeState.fromFacelets(solved), CubeState.solved());
    });

    test('rejects wrong length and unsupported letters', () {
      expect(() => CubeState.fromFacelets('U'), throwsFormatException);
      expect(
        () => CubeState.fromFacelets('${solved.substring(0, 53)}X'),
        throwsFormatException,
      );
    });

    test('rejects a state whose center no longer identifies its face', () {
      final stickers = CubeState.solved().stickers.toList();
      stickers[CubeFace.up.centerIndex] = CubeFace.front;

      expect(() => CubeState(stickers), throwsArgumentError);
    });

    test('center stickers cannot be edited', () {
      expect(
        () => CubeState.solved().replaceSticker(4, CubeFace.front),
        throwsArgumentError,
      );
    });

    test('non-center sticker edit returns a new state', () {
      final solvedState = CubeState.solved();
      final edited = solvedState.replaceSticker(0, CubeFace.front);

      expect(solvedState.stickers[0], CubeFace.up);
      expect(edited.stickers[0], CubeFace.front);
      expect(edited, isNot(solvedState));
    });

    test('exposes immutable stickers and per-face counts', () {
      final state = CubeState.solved();

      expect(() => state.stickers[0] = CubeFace.front, throwsUnsupportedError);
      expect(state.countByFace(), {
        for (final face in CubeFace.values) face: 9,
      });
      expect(state.stickersFor(CubeFace.left), hasLength(9));
      expect(state.isCenterIndex(CubeFace.left.centerIndex), isTrue);
      expect(state.isCenterIndex(CubeFace.left.centerIndex + 1), isFalse);
    });

    test('rejects out-of-range sticker edits', () {
      final state = CubeState.solved();
      expect(() => state.replaceSticker(-1, CubeFace.front), throwsRangeError);
      expect(() => state.replaceSticker(54, CubeFace.front), throwsRangeError);
    });
  });
}
