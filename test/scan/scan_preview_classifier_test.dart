import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_color_scheme.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/scan/color_math.dart';
import 'package:rubicsolver/scan/scan_preview_classifier.dart';
import 'package:rubicsolver/scan/sticker_sample.dart';

void main() {
  test('returns logical faces for a rearranged color scheme', () {
    final colorScheme = CubeColorScheme.standard.swapColor(
      CubeFace.up,
      CubeFace.down,
    );
    final samples = List.generate(9, (_) => _sample(252, 210, 2));
    samples[0] = _sample(250, 250, 250);

    final faces = const ScanPreviewClassifier().classify(
      samples: samples,
      currentFace: CubeFace.up,
      colorScheme: colorScheme,
    );

    expect(faces[4], CubeFace.up);
    expect(faces[0], CubeFace.down);
  });

  test('maps camera samples to calibrated cube colors', () {
    final samples = [
      _sample(250, 250, 250),
      _sample(185, 20, 54),
      _sample(2, 153, 70),
      _sample(252, 210, 2),
      _sample(248, 248, 248),
      _sample(254, 90, 2),
      _sample(2, 72, 170),
      _sample(180, 18, 50),
      _sample(4, 150, 75),
    ];

    final faces = const ScanPreviewClassifier().classify(
      samples: samples,
      currentFace: CubeFace.up,
    );

    expect(faces[0], CubeFace.up);
    expect(faces[1], CubeFace.right);
    expect(faces[2], CubeFace.front);
    expect(faces[3], CubeFace.down);
    expect(faces[4], CubeFace.up);
    expect(faces[5], CubeFace.left);
    expect(faces[6], CubeFace.back);
  });

  test('keeps live results stable as historical captures accumulate', () {
    final purple = _sample(90, 35, 155);
    final misleadingHistory = {
      for (final face in CubeFace.values.take(5))
        face: List.generate(9, (_) => purple),
    };
    final samples = List.generate(9, (_) => _sample(245, 245, 245));
    samples[0] = purple;

    final withoutHistory = const ScanPreviewClassifier().classify(
      samples: samples,
      currentFace: CubeFace.back,
    );
    final withHistory = const ScanPreviewClassifier().classify(
      samples: samples,
      currentFace: CubeFace.back,
      capturedSamplesByFace: misleadingHistory,
    );

    expect(withHistory, withoutHistory);
    expect(withHistory[4], CubeFace.back);
  });

  test('rejects an incomplete preview frame', () {
    expect(
      () => const ScanPreviewClassifier().classify(
        samples: [_sample(255, 255, 255)],
        currentFace: CubeFace.up,
      ),
      throwsArgumentError,
    );
  });
}

StickerSample _sample(int red, int green, int blue) =>
    StickerSample(rgb: RgbColor(red, green, blue), luminanceVariance: 0);
