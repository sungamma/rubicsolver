import 'color_math.dart';

enum StickerQuality { tooDark, overexposed, unevenLighting }

final class StickerSample {
  StickerSample({
    required this.rgb,
    required this.luminanceVariance,
    double? meanLuminance,
    this.darkPixelRatio = 0,
    this.clippedPixelRatio = 0,
  }) : meanLuminance = meanLuminance ?? rgb.relativeLuminance;

  final RgbColor rgb;
  final double luminanceVariance;
  final double meanLuminance;
  final double darkPixelRatio;
  final double clippedPixelRatio;

  List<StickerQuality> get qualityIssues {
    return List.unmodifiable([
      if (meanLuminance < 0.025 || darkPixelRatio > 0.5) StickerQuality.tooDark,
      if (clippedPixelRatio > 0.08) StickerQuality.overexposed,
      if (luminanceVariance > 1200) StickerQuality.unevenLighting,
    ]);
  }

  bool get isLowQuality => qualityIssues.isNotEmpty;
}
