import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/scan/color_classifier.dart';
import 'package:rubicsolver/scan/color_math.dart';
import 'package:rubicsolver/scan/scan_color_matcher.dart';
import 'package:rubicsolver/scan/sticker_sample.dart';

void main() {
  const classifier = ColorClassifier();

  test('classifies a solved cube against its six scanned centers', () {
    final result = classifier.classify(samplesByFace: _solvedSamples());

    expect(result.state, CubeState.solved());
    expect(result.recognitionHints, hasLength(48));
    expect(result.uncertainStickerIndices, isEmpty);
    expect(result.issues, isEmpty);
    expect(result.centerColors.keys, containsAll(CubeFace.values));
  });

  test(
    'reports an ambiguous sticker with global index and alternative face',
    () {
      final samples = _solvedSamples();
      samples[CubeFace.right]![0] = StickerSample(
        rgb: _ambiguousColor(CubeFace.up, CubeFace.down),
        luminanceVariance: 0,
      );

      final result = classifier.classify(samplesByFace: samples);
      final hint = result.recognitionHints.singleWhere(
        (candidate) => candidate.stickerIndex == 9,
      );
      final matcher = ScanColorMatcher(
        capturedFace: CubeFace.right,
        observedCenter: samples[CubeFace.right]![4].rgb,
      );
      final candidates = matcher.rank(samples[CubeFace.right]![0].rgb);
      final assigned = candidates.singleWhere(
        (candidate) => candidate.face == hint.assignedFace,
      );
      final alternative = candidates.firstWhere(
        (candidate) => candidate.face != hint.assignedFace,
      );

      expect(result.uncertainStickerIndices, contains(9));
      expect(hint.alternativeFace, alternative.face);
      expect(hint.confidence, lessThan(0.02));
      expect(
        hint.confidence,
        closeTo(
          (alternative.cost - assigned.cost) / math.max(alternative.cost, 1),
          1e-9,
        ),
      );
    },
  );

  test(
    'forces centers to their captured faces and warns when centers overlap',
    () {
      final samples = _solvedSamples();
      samples[CubeFace.down]![4] = samples[CubeFace.up]![4];

      final result = classifier.classify(samplesByFace: samples);

      expect(result.state.stickers[CubeFace.down.centerIndex], CubeFace.down);
      expect(
        result.issues.map((issue) => issue.code),
        contains('center-colors-too-close'),
      );
    },
  );

  test('surfaces low quality samples as uncertain', () {
    final samples = _solvedSamples();
    samples[CubeFace.back]![8] = StickerSample(
      rgb: RgbColor(0, 0, 5),
      luminanceVariance: 0,
    );

    final result = classifier.classify(samplesByFace: samples);

    expect(result.uncertainStickerIndices, contains(53));
    expect(
      result.issues.map((issue) => issue.code),
      contains('poor-sample-quality'),
    );
  });

  test('locked colors override classification and count as confirmed', () {
    final samples = _solvedSamples();
    samples[CubeFace.up]![0] = StickerSample(
      rgb: RgbColor(0, 5, 0),
      luminanceVariance: 0,
    );

    final result = classifier.classify(
      samplesByFace: samples,
      lockedFacesByFace: const {
        CubeFace.up: {0: CubeFace.right},
      },
    );

    expect(result.state.stickers[0], CubeFace.right);
    expect(result.uncertainStickerIndices, isNot(contains(0)));
    expect(
      result.recognitionHints.any((hint) => hint.stickerIndex == 0),
      isFalse,
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.code == 'poor-sample-quality' &&
            issue.stickerIndices.contains(0),
      ),
      isFalse,
    );
  });

  test('globally assigns unlocked stickers to exactly nine of each color', () {
    final samples = _solvedSamples();
    samples[CubeFace.left]![0] = StickerSample(
      rgb: RgbColor(210, 40, 45),
      luminanceVariance: 0,
    );

    final result = classifier.classify(samplesByFace: samples);
    final counts = {
      for (final face in CubeFace.values)
        face: result.state.stickers.where((sticker) => sticker == face).length,
    };

    expect(counts.values, everyElement(9));
    expect(result.state.stickers[CubeFace.left.startIndex], CubeFace.left);
  });

  test('locked colors reduce the remaining global capacity', () {
    final result = classifier.classify(
      samplesByFace: _solvedSamples(),
      lockedFacesByFace: const {
        CubeFace.up: {0: CubeFace.right},
      },
    );

    expect(result.state.stickers[0], CubeFace.right);
    expect(
      result.state.stickers.where((face) => face == CubeFace.right),
      hasLength(9),
    );
    expect(
      result.recognitionHints.any((hint) => hint.stickerIndex == 0),
      isFalse,
    );
  });

  test('preserves over-capacity manual locks for validation to reject', () {
    final result = classifier.classify(
      samplesByFace: _solvedSamples(),
      lockedFacesByFace: const {
        CubeFace.up: {
          0: CubeFace.right,
          1: CubeFace.right,
          2: CubeFace.right,
          3: CubeFace.right,
          5: CubeFace.right,
          6: CubeFace.right,
          7: CubeFace.right,
          8: CubeFace.right,
        },
        CubeFace.front: {0: CubeFace.right},
      },
    );

    expect(
      result.state.stickers.where((face) => face == CubeFace.right).length,
      greaterThan(9),
    );
    for (final index in [0, 1, 2, 3, 5, 6, 7, 8]) {
      expect(result.state.stickers[index], CubeFace.right);
    }
    expect(result.state.stickers[CubeFace.front.startIndex], CubeFace.right);
  });

  test('rejects an incomplete six-face capture', () {
    final samples = _solvedSamples()..remove(CubeFace.back);

    expect(
      () => classifier.classify(samplesByFace: samples),
      throwsArgumentError,
    );
  });

  test('returns immutable result collections', () {
    final result = classifier.classify(samplesByFace: _solvedSamples());

    expect(
      () => result.recognitionHints.add(result.recognitionHints.first),
      throwsUnsupportedError,
    );
    expect(() => result.uncertainStickerIndices.add(0), throwsUnsupportedError);
    expect(() => result.issues.clear(), throwsUnsupportedError);
    expect(
      () => result.centerColors[CubeFace.up] = RgbColor(0, 0, 0),
      throwsUnsupportedError,
    );
  });
}

Map<CubeFace, List<StickerSample>> _solvedSamples() {
  return {
    for (final face in CubeFace.values)
      face: List.generate(
        9,
        (_) => StickerSample(rgb: _colors[face]!, luminanceVariance: 0),
      ),
  };
}

final _colors = {
  CubeFace.up: RgbColor(245, 245, 245),
  CubeFace.right: RgbColor(220, 35, 45),
  CubeFace.front: RgbColor(30, 170, 70),
  CubeFace.down: RgbColor(250, 210, 25),
  CubeFace.left: RgbColor(245, 125, 20),
  CubeFace.back: RgbColor(25, 90, 210),
};

RgbColor _ambiguousColor(CubeFace firstFace, CubeFace secondFace) {
  final first = _colors[firstFace]!;
  final second = _colors[secondFace]!;
  RgbColor? bestColor;
  var bestGap = double.infinity;

  for (var step = 0; step <= 1000; step++) {
    final ratio = step / 1000;
    final candidate = RgbColor(
      (first.r + (second.r - first.r) * ratio).round(),
      (first.g + (second.g - first.g) * ratio).round(),
      (first.b + (second.b - first.b) * ratio).round(),
    );
    final distances = [
      for (final entry in _colors.entries)
        (
          face: entry.key,
          distance: deltaE76(candidate.toLab(), entry.value.toLab()),
        ),
    ]..sort((left, right) => left.distance.compareTo(right.distance));
    if ({
      distances[0].face,
      distances[1].face,
    }.containsAll({firstFace, secondFace})) {
      final gap = (distances[1].distance - distances[0].distance).abs();
      if (gap < bestGap) {
        bestGap = gap;
        bestColor = candidate;
      }
    }
  }

  return bestColor!;
}
