import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import 'color_math.dart';
import 'sticker_sample.dart';

final class ScanPreviewClassifier {
  const ScanPreviewClassifier();

  List<CubeFace> classify({
    required List<StickerSample> samples,
    required CubeFace currentFace,
    Map<CubeFace, List<StickerSample>> capturedSamplesByFace = const {},
  }) {
    if (samples.length != 9) {
      throw ArgumentError.value(samples.length, 'samples.length', '必须为 9');
    }

    final references = {
      for (final face in CubeFace.values) face: _standardRgb(face),
      for (final entry in capturedSamplesByFace.entries)
        if (entry.value.length == 9) entry.key: entry.value[4].rgb,
      currentFace: samples[4].rgb,
    };
    final referenceLabs = {
      for (final entry in references.entries) entry.key: entry.value.toLab(),
    };

    return List.unmodifiable([
      for (var index = 0; index < samples.length; index++)
        if (index == 4)
          currentFace
        else
          _nearestFace(samples[index].rgb, referenceLabs),
    ]);
  }

  CubeFace _nearestFace(RgbColor rgb, Map<CubeFace, LabColor> referenceLabs) {
    final sampleLab = rgb.toLab();
    return CubeFace.values.reduce((best, face) {
      final bestDistance = deltaE76(sampleLab, referenceLabs[best]!);
      final distance = deltaE76(sampleLab, referenceLabs[face]!);
      return distance < bestDistance ? face : best;
    });
  }

  RgbColor _standardRgb(CubeFace face) {
    final argb = CubePalette.colorFor(face).toARGB32();
    return RgbColor((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);
  }
}
