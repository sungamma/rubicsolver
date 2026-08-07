import 'dart:math' as math;

import '../cube/cube_face.dart';
import '../cube/cube_state.dart';
import '../cube/cube_validation.dart';
import 'color_math.dart';
import 'sticker_sample.dart';

final class ClassificationIssue {
  ClassificationIssue({
    required this.code,
    required this.message,
    Iterable<int> stickerIndices = const [],
  }) : stickerIndices = List.unmodifiable(stickerIndices);

  final String code;
  final String message;
  final List<int> stickerIndices;
}

final class ColorClassificationResult {
  ColorClassificationResult({
    required this.state,
    required Map<CubeFace, RgbColor> centerColors,
    required Iterable<RecognitionHint> recognitionHints,
    required Iterable<int> uncertainStickerIndices,
    required Iterable<ClassificationIssue> issues,
  }) : centerColors = Map.unmodifiable(centerColors),
       recognitionHints = List.unmodifiable(recognitionHints),
       uncertainStickerIndices = List.unmodifiable(uncertainStickerIndices),
       issues = List.unmodifiable(issues);

  final CubeState state;
  final Map<CubeFace, RgbColor> centerColors;
  final List<RecognitionHint> recognitionHints;
  final List<int> uncertainStickerIndices;
  final List<ClassificationIssue> issues;
}

final class ColorClassifier {
  const ColorClassifier({
    this.uncertainThreshold = 0.2,
    this.minimumCenterDistance = 12,
  });

  final double uncertainThreshold;
  final double minimumCenterDistance;

  ColorClassificationResult classify({
    required Map<CubeFace, List<StickerSample>> samplesByFace,
    Map<CubeFace, Map<int, CubeFace>> lockedFacesByFace = const {},
  }) {
    for (final face in CubeFace.values) {
      if (samplesByFace[face]?.length != 9) {
        throw ArgumentError('每个面都必须包含 9 个贴纸样本');
      }
    }

    final centerColors = {
      for (final face in CubeFace.values) face: samplesByFace[face]![4].rgb,
    };
    final centerLabs = {
      for (final entry in centerColors.entries) entry.key: entry.value.toLab(),
    };
    final issues = <ClassificationIssue>[];
    final uncertainIndices = <int>{};
    final closeCenterIndices = <int>{};

    for (var first = 0; first < CubeFace.values.length; first++) {
      for (var second = first + 1; second < CubeFace.values.length; second++) {
        final firstFace = CubeFace.values[first];
        final secondFace = CubeFace.values[second];
        if (deltaE76(centerLabs[firstFace]!, centerLabs[secondFace]!) <
            minimumCenterDistance) {
          closeCenterIndices
            ..add(firstFace.centerIndex)
            ..add(secondFace.centerIndex);
        }
      }
    }
    if (closeCenterIndices.isNotEmpty) {
      uncertainIndices.addAll(closeCenterIndices);
      issues.add(
        ClassificationIssue(
          code: 'center-colors-too-close',
          message: '两个中心颜色过于接近，请改善光线后重拍对应面。',
          stickerIndices: closeCenterIndices,
        ),
      );
    }

    final stickers = <CubeFace>[];
    final hints = <RecognitionHint>[];
    final poorQualityIndices = <int>[];
    for (final capturedFace in CubeFace.values) {
      final samples = samplesByFace[capturedFace]!;
      final lockedFaces = lockedFacesByFace[capturedFace] ?? const {};
      for (var localIndex = 0; localIndex < samples.length; localIndex++) {
        final globalIndex = capturedFace.startIndex + localIndex;
        final sample = samples[localIndex];

        if (localIndex == 4) {
          stickers.add(capturedFace);
          continue;
        }

        final lockedFace = lockedFaces[localIndex];
        if (lockedFace != null) {
          stickers.add(lockedFace);
          continue;
        }

        if (sample.isLowQuality) {
          poorQualityIndices.add(globalIndex);
          uncertainIndices.add(globalIndex);
        }

        final sampleLab = sample.rgb.toLab();
        final distances = [
          for (final face in CubeFace.values)
            (face: face, distance: deltaE76(sampleLab, centerLabs[face]!)),
        ]..sort((first, second) => first.distance.compareTo(second.distance));
        final best = distances[0];
        final alternative = distances[1];
        final confidence =
            (alternative.distance - best.distance) /
            math.max(alternative.distance, 1);
        stickers.add(best.face);
        hints.add(
          RecognitionHint(
            stickerIndex: globalIndex,
            assignedFace: best.face,
            alternativeFace: alternative.face,
            confidence: confidence,
          ),
        );
        if (confidence < uncertainThreshold) {
          uncertainIndices.add(globalIndex);
        }
      }
    }

    if (poorQualityIndices.isNotEmpty) {
      issues.add(
        ClassificationIssue(
          code: 'poor-sample-quality',
          message: '部分贴纸过暗、过曝或光线不均，请检查高亮位置。',
          stickerIndices: poorQualityIndices,
        ),
      );
    }

    return ColorClassificationResult(
      state: CubeState(stickers),
      centerColors: centerColors,
      recognitionHints: hints,
      uncertainStickerIndices: uncertainIndices,
      issues: issues,
    );
  }
}
