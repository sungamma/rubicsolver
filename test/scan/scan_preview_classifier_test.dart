import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/scan/color_math.dart';
import 'package:rubicsolver/scan/scan_preview_classifier.dart';
import 'package:rubicsolver/scan/sticker_sample.dart';

void main() {
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

  test('uses previously captured centers before standard references', () {
    final purpleCenter = _sample(90, 35, 155);
    final captured = {CubeFace.right: List.generate(9, (_) => purpleCenter)};
    final samples = List.generate(9, (_) => _sample(245, 245, 245));
    samples[0] = _sample(92, 36, 153);

    final faces = const ScanPreviewClassifier().classify(
      samples: samples,
      currentFace: CubeFace.front,
      capturedSamplesByFace: captured,
    );

    expect(faces[0], CubeFace.right);
    expect(faces[4], CubeFace.front);
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
