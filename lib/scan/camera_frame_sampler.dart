import 'dart:math' as math;
import 'dart:typed_data';

import 'color_math.dart';
import 'sticker_sample.dart';

enum ScanCameraPixelFormat { bgra8888, yuv420 }

final class ScanCameraPlane {
  const ScanCameraPlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

final class ScanCameraFrame {
  ScanCameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required List<ScanCameraPlane> planes,
    this.clockwiseQuarterTurns = 0,
  }) : planes = List.unmodifiable(planes) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('相机帧尺寸必须大于零');
    }
    if (clockwiseQuarterTurns < 0 || clockwiseQuarterTurns > 3) {
      throw ArgumentError.value(
        clockwiseQuarterTurns,
        'clockwiseQuarterTurns',
        '必须为 0 到 3',
      );
    }
    final expectedPlanes = format == ScanCameraPixelFormat.bgra8888 ? 1 : 3;
    if (planes.length != expectedPlanes) {
      throw ArgumentError.value(planes.length, 'planes.length', '平面数量不正确');
    }
  }

  final int width;
  final int height;
  final ScanCameraPixelFormat format;
  final List<ScanCameraPlane> planes;
  final int clockwiseQuarterTurns;
}

final class CameraFrameSampler {
  const CameraFrameSampler({
    this.cropFraction = 0.8,
    this.sampleFraction = 0.6,
    this.samplesPerAxis = 7,
  }) : assert(cropFraction > 0 && cropFraction <= 1),
       assert(sampleFraction > 0 && sampleFraction <= 1),
       assert(samplesPerAxis > 0);

  final double cropFraction;
  final double sampleFraction;
  final int samplesPerAxis;

  List<StickerSample> sample(ScanCameraFrame frame) {
    final rotated = frame.clockwiseQuarterTurns.isOdd;
    final displayWidth = rotated ? frame.height : frame.width;
    final displayHeight = rotated ? frame.width : frame.height;
    final cropSize = math.min(displayWidth, displayHeight) * cropFraction;
    final cropLeft = (displayWidth - cropSize) / 2;
    final cropTop = (displayHeight - cropSize) / 2;
    final cellSize = cropSize / 3;

    return [
      for (var row = 0; row < 3; row++)
        for (var column = 0; column < 3; column++)
          _sampleCell(
            frame,
            left: cropLeft + column * cellSize,
            top: cropTop + row * cellSize,
            cellSize: cellSize,
            displayWidth: displayWidth,
            displayHeight: displayHeight,
          ),
    ];
  }

  StickerSample _sampleCell(
    ScanCameraFrame frame, {
    required double left,
    required double top,
    required double cellSize,
    required int displayWidth,
    required int displayHeight,
  }) {
    final inset = cellSize * (1 - sampleFraction) / 2;
    final sampleSize = cellSize * sampleFraction;
    var redTotal = 0;
    var greenTotal = 0;
    var blueTotal = 0;
    var luminanceTotal = 0.0;
    var luminanceSquaredTotal = 0.0;
    var darkPixels = 0;
    var clippedPixels = 0;
    final count = samplesPerAxis * samplesPerAxis;

    for (var sampleY = 0; sampleY < samplesPerAxis; sampleY++) {
      for (var sampleX = 0; sampleX < samplesPerAxis; sampleX++) {
        final displayX =
            (left + inset + (sampleX + 0.5) * sampleSize / samplesPerAxis)
                .floor()
                .clamp(0, displayWidth - 1);
        final displayY =
            (top + inset + (sampleY + 0.5) * sampleSize / samplesPerAxis)
                .floor()
                .clamp(0, displayHeight - 1);
        final (sourceX, sourceY) = _sourcePoint(frame, displayX, displayY);
        final (red, green, blue) = _rgbAt(frame, sourceX, sourceY);
        final luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
        redTotal += red;
        greenTotal += green;
        blueTotal += blue;
        luminanceTotal += luminance;
        luminanceSquaredTotal += luminance * luminance;
        if (luminance <= 12) {
          darkPixels++;
        }
        if (red >= 250 && green >= 250 && blue >= 250) {
          clippedPixels++;
        }
      }
    }

    final meanLuminance = luminanceTotal / count;
    final variance =
        luminanceSquaredTotal / count - meanLuminance * meanLuminance;
    return StickerSample(
      rgb: RgbColor(
        (redTotal / count).round(),
        (greenTotal / count).round(),
        (blueTotal / count).round(),
      ),
      luminanceVariance: math.max(0, variance),
      meanLuminance: meanLuminance / 255,
      darkPixelRatio: darkPixels / count,
      clippedPixelRatio: clippedPixels / count,
    );
  }

  (int, int) _sourcePoint(ScanCameraFrame frame, int displayX, int displayY) {
    return switch (frame.clockwiseQuarterTurns) {
      0 => (displayX, displayY),
      1 => (displayY, frame.height - 1 - displayX),
      2 => (frame.width - 1 - displayX, frame.height - 1 - displayY),
      3 => (frame.width - 1 - displayY, displayX),
      _ => throw StateError('无法识别相机画面朝向'),
    };
  }

  (int, int, int) _rgbAt(ScanCameraFrame frame, int x, int y) {
    if (frame.format == ScanCameraPixelFormat.bgra8888) {
      final plane = frame.planes.single;
      final offset = y * plane.bytesPerRow + x * plane.bytesPerPixel;
      return (
        plane.bytes[offset + 2],
        plane.bytes[offset + 1],
        plane.bytes[offset],
      );
    }

    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];
    final yValue =
        yPlane.bytes[y * yPlane.bytesPerRow + x * yPlane.bytesPerPixel];
    final uvX = x ~/ 2;
    final uvY = y ~/ 2;
    final uValue =
        uPlane.bytes[uvY * uPlane.bytesPerRow + uvX * uPlane.bytesPerPixel];
    final vValue =
        vPlane.bytes[uvY * vPlane.bytesPerRow + uvX * vPlane.bytesPerPixel];
    final chromaBlue = uValue - 128;
    final chromaRed = vValue - 128;
    final luma = math.max(0, yValue - 16);
    final red = ((298 * luma + 409 * chromaRed + 128) >> 8).clamp(0, 255);
    final green = ((298 * luma - 100 * chromaBlue - 208 * chromaRed + 128) >> 8)
        .clamp(0, 255);
    final blue = ((298 * luma + 516 * chromaBlue + 128) >> 8).clamp(0, 255);
    return (red, green, blue);
  }
}
