import '../cube/cube_color_scheme.dart';
import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import 'color_math.dart';

final class ScanColorCandidate {
  const ScanColorCandidate({required this.face, required this.cost});

  final CubeFace face;
  final double cost;
}

final class ScanColorMatcher {
  ScanColorMatcher({
    required this.capturedFace,
    required RgbColor observedCenter,
    this.colorScheme = CubeColorScheme.standard,
    this.maximumLightnessShift = 18,
    this.maximumChromaShift = 14,
  }) {
    _validateLimit(maximumLightnessShift, 'maximumLightnessShift');
    _validateLimit(maximumChromaShift, 'maximumChromaShift');

    final standardCenter =
        _standardLabs[colorScheme.colorIdentityFor(capturedFace)]!;
    final observedCenterLab = observedCenter.toLab();
    _lightnessShift = _limit(
      standardCenter.l - observedCenterLab.l,
      maximumLightnessShift,
    );
    _aShift = _limit(
      standardCenter.a - observedCenterLab.a,
      maximumChromaShift,
    );
    _bShift = _limit(
      standardCenter.b - observedCenterLab.b,
      maximumChromaShift,
    );
  }

  final CubeFace capturedFace;
  final CubeColorScheme colorScheme;
  final double maximumLightnessShift;
  final double maximumChromaShift;

  late final double _lightnessShift;
  late final double _aShift;
  late final double _bShift;

  static final Map<CubeFace, LabColor> _standardLabs = Map.unmodifiable({
    for (final face in CubeFace.values) face: _standardRgb(face).toLab(),
  });

  List<ScanColorCandidate> rank(RgbColor rgb) {
    final observedLab = rgb.toLab();
    final correctedLab = LabColor(
      observedLab.l + _lightnessShift,
      observedLab.a + _aShift,
      observedLab.b + _bShift,
    );
    final candidates =
        [
          for (final colorIdentity in CubeFace.values)
            ScanColorCandidate(
              face: colorScheme.logicalFaceFor(colorIdentity),
              cost: deltaE2000(correctedLab, _standardLabs[colorIdentity]!),
            ),
        ]..sort((first, second) {
          final costOrder = first.cost.compareTo(second.cost);
          return costOrder != 0
              ? costOrder
              : first.face.index.compareTo(second.face.index);
        });
    return List.unmodifiable(candidates);
  }

  static void _validateLimit(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name, '必须为有限的非负数');
    }
  }

  static double _limit(double value, double maximum) =>
      value.clamp(-maximum, maximum).toDouble();

  static RgbColor _standardRgb(CubeFace face) {
    final argb = CubePalette.colorFor(face).toARGB32();
    return RgbColor((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);
  }
}
