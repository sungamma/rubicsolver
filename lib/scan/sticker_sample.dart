import 'color_math.dart';

enum StickerQuality { tooDark, overexposed, unevenLighting }

final class StickerSample {
  StickerSample({required this.rgb, required this.luminanceVariance});

  final RgbColor rgb;
  final double luminanceVariance;

  List<StickerQuality> get qualityIssues {
    return List.unmodifiable([
      if (rgb.relativeLuminance < 0.015) StickerQuality.tooDark,
      if (rgb.r >= 250 && rgb.g >= 250 && rgb.b >= 250)
        StickerQuality.overexposed,
      if (luminanceVariance > 1200) StickerQuality.unevenLighting,
    ]);
  }

  bool get isLowQuality => qualityIssues.isNotEmpty;
}
