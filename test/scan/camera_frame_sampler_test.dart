import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/scan/camera_frame_sampler.dart';

void main() {
  test('samples a 3 by 3 BGRA camera frame in display order', () {
    const colors = [
      (255, 255, 255),
      (183, 18, 52),
      (0, 155, 72),
      (255, 213, 0),
      (255, 88, 0),
      (0, 70, 173),
      (40, 80, 120),
      (100, 140, 180),
      (210, 190, 170),
    ];
    final frame = _bgraGrid(colors);

    final samples = const CameraFrameSampler().sample(frame);

    expect(samples, hasLength(9));
    for (var index = 0; index < colors.length; index++) {
      expect(samples[index].rgb.r, closeTo(colors[index].$1, 1));
      expect(samples[index].rgb.g, closeTo(colors[index].$2, 1));
      expect(samples[index].rgb.b, closeTo(colors[index].$3, 1));
    }
  });

  test('maps a clockwise camera rotation into display grid order', () {
    const colors = [
      (10, 10, 10),
      (20, 20, 20),
      (30, 30, 30),
      (40, 40, 40),
      (50, 50, 50),
      (60, 60, 60),
      (70, 70, 70),
      (80, 80, 80),
      (90, 90, 90),
    ];
    final unrotated = _bgraGrid(colors);
    final frame = ScanCameraFrame(
      width: unrotated.width,
      height: unrotated.height,
      format: unrotated.format,
      planes: unrotated.planes,
      clockwiseQuarterTurns: 1,
    );

    final samples = const CameraFrameSampler().sample(frame);

    expect(samples[0].rgb.r, closeTo(70, 1));
    expect(samples[2].rgb.r, closeTo(10, 1));
    expect(samples[6].rgb.r, closeTo(90, 1));
  });

  test('converts a constant YUV420 frame to RGB samples', () {
    const width = 60;
    const height = 60;
    final frame = ScanCameraFrame(
      width: width,
      height: height,
      format: ScanCameraPixelFormat.yuv420,
      planes: [
        ScanCameraPlane(
          bytes: Uint8List(width * height)..fillRange(0, width * height, 82),
          bytesPerRow: width,
          bytesPerPixel: 1,
        ),
        ScanCameraPlane(
          bytes: Uint8List(width * height ~/ 4)
            ..fillRange(0, width * height ~/ 4, 90),
          bytesPerRow: width ~/ 2,
          bytesPerPixel: 1,
        ),
        ScanCameraPlane(
          bytes: Uint8List(width * height ~/ 4)
            ..fillRange(0, width * height ~/ 4, 240),
          bytesPerRow: width ~/ 2,
          bytesPerPixel: 1,
        ),
      ],
    );

    final samples = const CameraFrameSampler().sample(frame);

    expect(samples, hasLength(9));
    expect(samples.every((sample) => sample.rgb.r > 240), isTrue);
    expect(samples.every((sample) => sample.rgb.g < 20), isTrue);
    expect(samples.every((sample) => sample.rgb.b < 20), isTrue);
  });
}

ScanCameraFrame _bgraGrid(List<(int, int, int)> colors) {
  const width = 90;
  const height = 90;
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final color = colors[(y ~/ 30) * 3 + x ~/ 30];
      final offset = (y * width + x) * 4;
      bytes[offset] = color.$3;
      bytes[offset + 1] = color.$2;
      bytes[offset + 2] = color.$1;
      bytes[offset + 3] = 255;
    }
  }
  return ScanCameraFrame(
    width: width,
    height: height,
    format: ScanCameraPixelFormat.bgra8888,
    planes: [
      ScanCameraPlane(bytes: bytes, bytesPerRow: width * 4, bytesPerPixel: 4),
    ],
  );
}
