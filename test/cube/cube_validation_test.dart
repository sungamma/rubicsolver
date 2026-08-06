import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/cube/cube_validation.dart';

void main() {
  const validator = CubeValidator();

  test('solved cube is valid', () {
    final result = validator.validate(CubeState.solved());

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test('reports surplus and missing colors', () {
    final invalid = CubeState.solved().replaceSticker(0, CubeFace.front);
    final result = validator.validate(invalid);

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      containsAll(['color-count-up', 'color-count-front']),
    );
    expect(result.issues.map((issue) => issue.message).join(), contains('9'));
  });

  test('uses recognition alternatives to suggest a likely correction', () {
    final invalid = CubeState.solved().replaceSticker(0, CubeFace.front);
    final result = validator.validate(
      invalid,
      recognitionHints: const [
        RecognitionHint(
          stickerIndex: 0,
          assignedFace: CubeFace.front,
          alternativeFace: CubeFace.up,
          confidence: 0.03,
        ),
      ],
    );

    expect(result.suspectStickerIndices, contains(0));
    expect(
      result.issues
          .where((issue) => issue.code == 'color-count-front')
          .single
          .stickerIndices,
      contains(0),
    );
  });

  test('maps a single flipped edge to a Chinese physical error', () {
    final stickers = CubeState.solved().stickers.toList();
    final temp = stickers[7];
    stickers[7] = stickers[19];
    stickers[19] = temp;

    final result = validator.validate(CubeState(stickers));

    expect(result.isValid, isFalse);
    expect(result.issues.single.code, 'twisted-edge');
    expect(result.issues.single.message, contains('棱块'));
  });

  test('maps a twisted corner to a Chinese physical error', () {
    final stickers = CubeState.solved().stickers.toList();
    final first = stickers[8];
    stickers[8] = stickers[9];
    stickers[9] = stickers[20];
    stickers[20] = first;

    final result = validator.validate(CubeState(stickers));

    expect(result.isValid, isFalse);
    expect(result.issues.single.code, 'twisted-corner');
    expect(result.issues.single.message, contains('角块'));
  });

  test('low confidence stickers are surfaced for physical errors', () {
    final stickers = CubeState.solved().stickers.toList();
    final temp = stickers[7];
    stickers[7] = stickers[19];
    stickers[19] = temp;

    final result = validator.validate(
      CubeState(stickers),
      recognitionHints: const [
        RecognitionHint(
          stickerIndex: 19,
          assignedFace: CubeFace.up,
          alternativeFace: CubeFace.front,
          confidence: 0.02,
        ),
        RecognitionHint(
          stickerIndex: 7,
          assignedFace: CubeFace.front,
          alternativeFace: CubeFace.up,
          confidence: 0.01,
        ),
      ],
    );

    expect(result.suspectStickerIndices, [7, 19]);
  });
}
