import '../cube/cube_color_scheme.dart';
import '../cube/cube_face.dart';
import 'scan_color_matcher.dart';
import 'sticker_sample.dart';

final class ScanPreviewClassifier {
  const ScanPreviewClassifier();

  List<CubeFace> classify({
    required List<StickerSample> samples,
    required CubeFace currentFace,
    CubeColorScheme colorScheme = CubeColorScheme.standard,
    Map<CubeFace, List<StickerSample>> capturedSamplesByFace = const {},
  }) {
    if (samples.length != 9) {
      throw ArgumentError.value(samples.length, 'samples.length', '必须为 9');
    }

    final matcher = ScanColorMatcher(
      capturedFace: currentFace,
      observedCenter: samples[4].rgb,
      colorScheme: colorScheme,
    );

    return List.unmodifiable([
      for (var index = 0; index < samples.length; index++)
        if (index == 4)
          currentFace
        else
          matcher.rank(samples[index].rgb).first.face,
    ]);
  }
}
