import 'package:cuber/cuber.dart' as cuber;

import 'cube_face.dart';
import 'cube_state.dart';

class RecognitionHint {
  const RecognitionHint({
    required this.stickerIndex,
    required this.assignedFace,
    required this.alternativeFace,
    required this.confidence,
  });

  final int stickerIndex;
  final CubeFace assignedFace;
  final CubeFace alternativeFace;
  final double confidence;
}

class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.message,
    this.stickerIndices = const [],
  });

  final String code;
  final String message;
  final List<int> stickerIndices;
}

class ValidationResult {
  ValidationResult(List<ValidationIssue> issues)
    : issues = List.unmodifiable(issues),
      suspectStickerIndices = List.unmodifiable({
        for (final issue in issues) ...issue.stickerIndices,
      });

  final List<ValidationIssue> issues;
  final List<int> suspectStickerIndices;

  bool get isValid => issues.isEmpty;
}

class CubeValidator {
  const CubeValidator();

  ValidationResult validate(
    CubeState state, {
    List<RecognitionHint> recognitionHints = const [],
  }) {
    final counts = state.countByFace();
    final missingFaces = {
      for (final face in CubeFace.values)
        if (counts[face]! < 9) face,
    };
    final countIssues = <ValidationIssue>[];

    for (final face in CubeFace.values) {
      final count = counts[face]!;
      if (count == 9) {
        continue;
      }
      countIssues.add(
        ValidationIssue(
          code: 'color-count-${face.name}',
          message: '${face.letter} 面颜色识别到 $count 枚，合法状态应为 9 枚。',
          stickerIndices: _countSuspects(
            state: state,
            face: face,
            count: count,
            missingFaces: missingFaces,
            hints: recognitionHints,
          ),
        ),
      );
    }

    if (countIssues.isNotEmpty) {
      return ValidationResult(countIssues);
    }

    final status = cuber.Cube.from(state.toFacelets()).verify();
    if (status == cuber.CubeStatus.ok) {
      return ValidationResult(const []);
    }

    final suspects =
        recognitionHints
            .where(
              (hint) =>
                  hint.stickerIndex >= 0 &&
                  hint.stickerIndex < 54 &&
                  !state.isCenterIndex(hint.stickerIndex),
            )
            .toList()
          ..sort((left, right) => left.confidence.compareTo(right.confidence));

    return ValidationResult([
      ValidationIssue(
        code: _physicalCode(status),
        message: _physicalMessage(status),
        stickerIndices: [
          for (final hint in suspects.take(6)) hint.stickerIndex,
        ],
      ),
    ]);
  }

  List<int> _countSuspects({
    required CubeState state,
    required CubeFace face,
    required int count,
    required Set<CubeFace> missingFaces,
    required List<RecognitionHint> hints,
  }) {
    final matchingHints =
        hints
            .where(
              (hint) =>
                  hint.stickerIndex >= 0 &&
                  hint.stickerIndex < 54 &&
                  !state.isCenterIndex(hint.stickerIndex) &&
                  ((count > 9 &&
                          hint.assignedFace == face &&
                          missingFaces.contains(hint.alternativeFace)) ||
                      (count < 9 && hint.alternativeFace == face)),
            )
            .toList()
          ..sort((left, right) => left.confidence.compareTo(right.confidence));

    if (matchingHints.isNotEmpty) {
      return [for (final hint in matchingHints.take(6)) hint.stickerIndex];
    }
    if (count < 9) {
      return const [];
    }

    return [
      for (var index = 0; index < state.stickers.length; index++)
        if (!state.isCenterIndex(index) && state.stickers[index] == face) index,
    ].take(6).toList();
  }

  String _physicalCode(cuber.CubeStatus status) {
    return switch (status) {
      cuber.CubeStatus.missingEdge => 'missing-edge',
      cuber.CubeStatus.twistedEdge => 'twisted-edge',
      cuber.CubeStatus.missingCorner => 'missing-corner',
      cuber.CubeStatus.twistedCorner => 'twisted-corner',
      cuber.CubeStatus.parityError => 'parity-error',
      cuber.CubeStatus.ok => 'ok',
    };
  }

  String _physicalMessage(cuber.CubeStatus status) {
    return switch (status) {
      cuber.CubeStatus.missingEdge => '棱块颜色组合不存在或出现重复，请检查高亮贴纸。',
      cuber.CubeStatus.twistedEdge => '检测到单个棱块翻转，这不是合法魔方状态。',
      cuber.CubeStatus.missingCorner => '角块颜色组合不存在或出现重复，请检查高亮贴纸。',
      cuber.CubeStatus.twistedCorner => '检测到角块扭转错误，请检查角落贴纸方向。',
      cuber.CubeStatus.parityError => '角块和棱块的排列奇偶性不一致，请复查识别结果。',
      cuber.CubeStatus.ok => '',
    };
  }
}
