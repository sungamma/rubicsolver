import 'dart:isolate';
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
  const FaceSampler({
    this.cropFraction = 0.8,
    this.sampleFraction = 0.6,
    this.maxAnalysisSize = 600,
  }) : assert(cropFraction > 0 && cropFraction <= 1),
       assert(sampleFraction > 0 && sampleFraction <= 1),
       assert(maxAnalysisSize >= 90);

  final double cropFraction;
  final double sampleFraction;
  final int maxAnalysisSize;

  Future<List<StickerSample>> sampleInBackground(Uint8List bytes) {
    return Isolate.run(() => sample(bytes));
  }

  List<StickerSample> sample(Uint8List bytes) {
    image.Image decoded;
    try {
      final source = image.decodeImage(bytes);
      if (source == null) {
        throw const FaceSamplingException('无法读取照片，请重新拍摄。');
      }
      decoded =
          source.exif.imageIfd.hasOrientation &&
              source.exif.imageIfd.orientation != 1
          ? image.bakeOrientation(source)
          : source;
    } on FaceSamplingException {
      rethrow;
    } catch (_) {
      throw const FaceSamplingException('无法读取照片，请重新拍摄。');
    }

    var shortestSide = math.min(decoded.width, decoded.height);
    var cropSize = (shortestSide * cropFraction).round();
    if (cropSize < 30) {
      throw const FaceSamplingException('照片尺寸太小，无法识别魔方贴纸。');
    }

    if (cropSize > maxAnalysisSize) {
      final scale = maxAnalysisSize / cropSize;
      decoded = image.copyResize(
        decoded,
        width: math.max(1, (decoded.width * scale).round()),
        height: math.max(1, (decoded.height * scale).round()),
        interpolation: image.Interpolation.linear,
      );
      shortestSide = math.min(decoded.width, decoded.height);
      cropSize = math.min(
        maxAnalysisSize,
        (shortestSide * cropFraction).round(),
      );
    }

    final cropped = image.copyCrop(
      decoded,
      x: (decoded.width - cropSize) ~/ 2,
      y: (decoded.height - cropSize) ~/ 2,
      width: cropSize,
      height: cropSize,
    );
    final cellSize = cropSize / 3;
    return [
      for (var row = 0; row < 3; row++)
        for (var column = 0; column < 3; column++)
          _sampleCell(
            cropped,
            left: column * cellSize,
            top: row * cellSize,
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
    final counts = List<int>.filled(256, 0);
    final redSums = List<int>.filled(256, 0);
    final greenSums = List<int>.filled(256, 0);
    final blueSums = List<int>.filled(256, 0);
    var totalLuminance = 0.0;
    var darkPixels = 0;
    var clippedPixels = 0;
    var totalPixels = 0;

    for (var y = patchTop; y < patchTop + patchSize; y++) {
      for (var x = patchLeft; x < patchLeft + patchSize; x++) {
        final pixel = source.getPixelClamped(x, y);
        final red = pixel.r.round().clamp(0, 255);
        final green = pixel.g.round().clamp(0, 255);
        final blue = pixel.b.round().clamp(0, 255);
        final luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
        final bin = luminance.round().clamp(0, 255);
        counts[bin]++;
        redSums[bin] += red;
        greenSums[bin] += green;
        blueSums[bin] += blue;
        totalLuminance += luminance;
        if (luminance <= 12) {
          darkPixels++;
        }
        if (red >= 250 && green >= 250 && blue >= 250) {
          clippedPixels++;
        }
        totalPixels++;
      }
    }

    final retainedCounts = List<int>.from(counts);
    final trimCount = totalPixels >= 20 ? (totalPixels * 0.1).floor() : 0;
    _trimHistogram(retainedCounts, trimCount, fromDarkEnd: true);
    _trimHistogram(retainedCounts, trimCount, fromDarkEnd: false);

    var retainedPixels = 0;
    var retainedRed = 0.0;
    var retainedGreen = 0.0;
    var retainedBlue = 0.0;
    var retainedLuminance = 0.0;
    var retainedLuminanceSquared = 0.0;
    for (var bin = 0; bin < retainedCounts.length; bin++) {
      final kept = retainedCounts[bin];
      final original = counts[bin];
      if (kept == 0 || original == 0) {
        continue;
      }
      final retainedFraction = kept / original;
      retainedPixels += kept;
      retainedRed += redSums[bin] * retainedFraction;
      retainedGreen += greenSums[bin] * retainedFraction;
      retainedBlue += blueSums[bin] * retainedFraction;
      retainedLuminance += bin * kept;
      retainedLuminanceSquared += bin * bin * kept;
    }

    final meanRetainedLuminance = retainedLuminance / retainedPixels;
    final variance =
        retainedLuminanceSquared / retainedPixels -
        meanRetainedLuminance * meanRetainedLuminance;

    return StickerSample(
      rgb: RgbColor(
        (retainedRed / retainedPixels).round(),
        (retainedGreen / retainedPixels).round(),
        (retainedBlue / retainedPixels).round(),
      ),
      luminanceVariance: math.max(0, variance),
      meanLuminance: totalLuminance / totalPixels / 255,
      darkPixelRatio: darkPixels / totalPixels,
      clippedPixelRatio: clippedPixels / totalPixels,
    );
  }

  void _trimHistogram(
    List<int> counts,
    int trimCount, {
    required bool fromDarkEnd,
  }) {
    var remaining = trimCount;
    for (
      var bin = fromDarkEnd ? 0 : counts.length - 1;
      fromDarkEnd ? bin < counts.length : bin >= 0;
      bin += fromDarkEnd ? 1 : -1
    ) {
      if (remaining == 0) {
        return;
      }
      final removed = math.min(counts[bin], remaining);
      counts[bin] -= removed;
      remaining -= removed;
    }
  }
}
