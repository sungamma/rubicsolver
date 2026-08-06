import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'color_math.dart';
import 'sticker_sample.dart';

final class FaceSamplingException implements Exception {
  const FaceSamplingException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class FaceSampler {
  const FaceSampler({this.cropFraction = 0.8, this.sampleFraction = 0.5})
    : assert(cropFraction > 0 && cropFraction <= 1),
      assert(sampleFraction > 0 && sampleFraction <= 1);

  final double cropFraction;
  final double sampleFraction;

  List<StickerSample> sample(Uint8List bytes) {
    image.Image decoded;
    try {
      final source = image.decodeImage(bytes);
      if (source == null) {
        throw const FaceSamplingException('无法读取照片，请重新拍摄。');
      }
      decoded = image.bakeOrientation(source);
    } on FaceSamplingException {
      rethrow;
    } catch (_) {
      throw const FaceSamplingException('无法读取照片，请重新拍摄。');
    }

    final shortestSide = math.min(decoded.width, decoded.height);
    final cropSize = (shortestSide * cropFraction).round();
    if (cropSize < 30) {
      throw const FaceSamplingException('照片尺寸太小，无法识别魔方贴纸。');
    }

    final cropLeft = (decoded.width - cropSize) ~/ 2;
    final cropTop = (decoded.height - cropSize) ~/ 2;
    final cellSize = cropSize / 3;
    return [
      for (var row = 0; row < 3; row++)
        for (var column = 0; column < 3; column++)
          _sampleCell(
            decoded,
            left: cropLeft + column * cellSize,
            top: cropTop + row * cellSize,
            cellSize: cellSize,
          ),
    ];
  }

  StickerSample _sampleCell(
    image.Image source, {
    required double left,
    required double top,
    required double cellSize,
  }) {
    final patchSize = math.max(1, (cellSize * sampleFraction).floor());
    final patchLeft = (left + (cellSize - patchSize) / 2).round();
    final patchTop = (top + (cellSize - patchSize) / 2).round();
    final pixels = <_SampledPixel>[];

    for (var y = patchTop; y < patchTop + patchSize; y++) {
      for (var x = patchLeft; x < patchLeft + patchSize; x++) {
        final pixel = source.getPixelClamped(x, y);
        final red = pixel.r.round().clamp(0, 255);
        final green = pixel.g.round().clamp(0, 255);
        final blue = pixel.b.round().clamp(0, 255);
        pixels.add(
          _SampledPixel(
            red,
            green,
            blue,
            0.2126 * red + 0.7152 * green + 0.0722 * blue,
          ),
        );
      }
    }

    pixels.sort((first, second) => first.luminance.compareTo(second.luminance));
    final trimCount = pixels.length >= 20 ? (pixels.length * 0.1).floor() : 0;
    final retained = pixels.sublist(trimCount, pixels.length - trimCount);
    final red =
        retained.map((pixel) => pixel.red).reduce((a, b) => a + b) /
        retained.length;
    final green =
        retained.map((pixel) => pixel.green).reduce((a, b) => a + b) /
        retained.length;
    final blue =
        retained.map((pixel) => pixel.blue).reduce((a, b) => a + b) /
        retained.length;
    final meanLuminance =
        retained.map((pixel) => pixel.luminance).reduce((a, b) => a + b) /
        retained.length;
    final variance =
        retained
            .map((pixel) {
              final delta = pixel.luminance - meanLuminance;
              return delta * delta;
            })
            .reduce((a, b) => a + b) /
        retained.length;

    return StickerSample(
      rgb: RgbColor(red.round(), green.round(), blue.round()),
      luminanceVariance: variance,
    );
  }
}

final class _SampledPixel {
  const _SampledPixel(this.red, this.green, this.blue, this.luminance);

  final int red;
  final int green;
  final int blue;
  final double luminance;
}
