import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rubicsolver/scan/color_math.dart';
import 'package:rubicsolver/scan/face_sampler.dart';
import 'package:rubicsolver/scan/sticker_sample.dart';

void main() {
  const sampler = FaceSampler(cropFraction: 0.8, sampleFraction: 0.5);

  test('defaults to a bounded 60 percent analysis patch', () {
    const defaults = FaceSampler();

    expect(defaults.sampleFraction, 0.6);
    expect(defaults.maxAnalysisSize, 600);
  });

  test('samples nine cells from the central camera guide', () {
    final colors = <RgbColor>[
      RgbColor(245, 245, 245),
      RgbColor(220, 35, 45),
      RgbColor(30, 170, 70),
      RgbColor(250, 210, 25),
      RgbColor(245, 125, 20),
      RgbColor(25, 90, 210),
      RgbColor(150, 45, 170),
      RgbColor(45, 180, 190),
      RgbColor(125, 85, 45),
    ];
    final image = _gridImage(colors);

    final samples = sampler.sample(img.encodePng(image));

    expect(samples, hasLength(9));
    for (var index = 0; index < colors.length; index++) {
      expect(samples[index].rgb.r, closeTo(colors[index].r, 1));
      expect(samples[index].rgb.g, closeTo(colors[index].g, 1));
      expect(samples[index].rgb.b, closeTo(colors[index].b, 1));
      expect(samples[index].qualityIssues, isEmpty);
    }
  });

  test('center sampling ignores dark sticker borders', () {
    final image = img.Image(width: 360, height: 300);
    img.fill(image, color: img.ColorRgb8(0, 0, 0));
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final left = 60 + column * 80;
        final top = 30 + row * 80;
        img.fillRect(
          image,
          x1: left + 12,
          y1: top + 12,
          x2: left + 67,
          y2: top + 67,
          color: img.ColorRgb8(30, 170, 70),
        );
      }
    }

    final samples = sampler.sample(img.encodePng(image));

    expect(samples.first.rgb.g, greaterThan(165));
    expect(samples.first.rgb.r, closeTo(30, 2));
  });

  test('flags low light, overexposure and uneven patches', () {
    final dark = _gridImage(List.filled(9, RgbColor(3, 3, 3)));
    final bright = _gridImage(List.filled(9, RgbColor(255, 255, 255)));
    final uneven = _gridImage(List.filled(9, RgbColor(120, 120, 120)));
    for (var y = 50; y < 90; y++) {
      for (var x = 80; x < 120; x++) {
        final channel = (x + y).isEven ? 0 : 255;
        uneven.setPixelRgb(x, y, channel, channel, channel);
      }
    }

    expect(
      sampler.sample(img.encodePng(dark)).first.qualityIssues,
      contains(StickerQuality.tooDark),
    );
    expect(
      sampler.sample(img.encodePng(bright)).first.qualityIssues,
      contains(StickerQuality.overexposed),
    );
    expect(
      sampler.sample(img.encodePng(uneven)).first.qualityIssues,
      contains(StickerQuality.unevenLighting),
    );
  });

  test('detects localized white glare before trimming color outliers', () {
    final image = _gridImage(List.filled(9, RgbColor(200, 35, 35)));
    for (var y = 50; y < 66; y++) {
      for (var x = 80; x < 120; x++) {
        image.setPixelRgb(x, y, 255, 255, 255);
      }
    }

    final sample = sampler.sample(img.encodePng(image)).first;

    expect(sample.clippedPixelRatio, greaterThan(0.1));
    expect(sample.qualityIssues, contains(StickerQuality.overexposed));
  });

  test('trims sparse interior black and white outliers', () {
    final image = _gridImage(List.filled(9, RgbColor(30, 170, 70)));
    for (var index = 0; index < 100; index++) {
      final x = 80 + index % 10;
      final y = 50 + index ~/ 10;
      final channel = index.isEven ? 0 : 255;
      image.setPixelRgb(x, y, channel, channel, channel);
    }

    final sample = sampler.sample(img.encodePng(image)).first;

    expect(sample.rgb.r, closeTo(30, 3));
    expect(sample.rgb.g, closeTo(170, 3));
    expect(sample.rgb.b, closeTo(70, 3));
  });

  test('can decode and sample away from the caller isolate', () async {
    final image = _gridImage(List.filled(9, RgbColor(30, 170, 70)));

    final samples = await sampler.sampleInBackground(img.encodePng(image));

    expect(samples, hasLength(9));
    expect(samples.first.rgb.g, closeTo(170, 2));
  });

  test('applies EXIF orientation before assigning grid positions', () {
    final colors = <RgbColor>[
      RgbColor(240, 20, 20),
      RgbColor(20, 240, 20),
      RgbColor(20, 20, 240),
      RgbColor(240, 240, 20),
      RgbColor(240, 20, 240),
      RgbColor(20, 240, 240),
      RgbColor(150, 40, 20),
      RgbColor(40, 150, 20),
      RgbColor(20, 40, 150),
    ];
    final image = _gridImage(colors);
    image.exif.imageIfd.orientation = 6;

    final samples = sampler.sample(img.encodeJpg(image, quality: 100));

    expect(samples[0].rgb.r, closeTo(colors[6].r, 12));
    expect(samples[0].rgb.g, closeTo(colors[6].g, 12));
    expect(samples[2].rgb.r, closeTo(colors[0].r, 12));
    expect(samples[2].rgb.g, closeTo(colors[0].g, 12));
  });

  test('throws a Chinese sampling error for invalid image bytes', () {
    expect(
      () => sampler.sample(Uint8List.fromList([1, 2, 3])),
      throwsA(
        isA<FaceSamplingException>().having(
          (error) => error.message,
          'message',
          contains('照片'),
        ),
      ),
    );
  });
}

img.Image _gridImage(List<RgbColor> colors) {
  final image = img.Image(width: 360, height: 300);
  img.fill(image, color: img.ColorRgb8(10, 10, 10));
  for (var index = 0; index < colors.length; index++) {
    final row = index ~/ 3;
    final column = index % 3;
    final color = colors[index];
    img.fillRect(
      image,
      x1: 60 + column * 80,
      y1: 30 + row * 80,
      x2: 139 + column * 80,
      y2: 109 + row * 80,
      color: img.ColorRgb8(color.r, color.g, color.b),
    );
  }
  return image;
}
