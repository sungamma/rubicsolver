import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_palette.dart';
import 'package:rubicsolver/scan/color_math.dart';
import 'package:rubicsolver/scan/scan_color_matcher.dart';

void main() {
  test('ranks every fixed palette color against the standard references', () {
    final matcher = ScanColorMatcher(
      capturedFace: CubeFace.up,
      observedCenter: _standardRgb(CubeFace.up),
    );

    for (final expectedFace in CubeFace.values) {
      final rgb = _standardRgb(expectedFace);
      final candidates = matcher.rank(rgb);

      expect(candidates, hasLength(CubeFace.values.length));
      expect(candidates.first.face, expectedFace);
      expect(candidates.first.cost, closeTo(0, 1e-9));
      expect(
        candidates.map((candidate) => candidate.face),
        containsAll(CubeFace.values),
      );
      expect(
        candidates.map((candidate) => candidate.cost),
        orderedEquals(
          candidates.map((candidate) => candidate.cost).toList()..sort(),
        ),
      );
    }
  });

  test('cancels a shared center offset within the configured limits', () {
    final observedCenter = RgbColor(174, 23, 51);
    final matcher = ScanColorMatcher(
      capturedFace: CubeFace.right,
      observedCenter: observedCenter,
    );

    final candidates = matcher.rank(observedCenter);

    expect(candidates.first.face, CubeFace.right);
    expect(candidates.first.cost, closeTo(0, 1e-9));
  });

  test('limits the per-channel Lab correction and keeps references fixed', () {
    final matcher = ScanColorMatcher(
      capturedFace: CubeFace.up,
      observedCenter: RgbColor(0, 0, 0),
      maximumLightnessShift: 18,
      maximumChromaShift: 0,
    );

    final candidates = matcher.rank(RgbColor(0, 0, 0));
    final expectedSample = const LabColor(18, 0, 0);

    for (final candidate in candidates) {
      expect(
        candidate.cost,
        closeTo(
          deltaE2000(expectedSample, _standardRgb(candidate.face).toLab()),
          1e-9,
        ),
      );
    }
    expect(() => candidates.clear(), throwsUnsupportedError);
  });

  test('accepts zero correction limits', () {
    final matcher = ScanColorMatcher(
      capturedFace: CubeFace.up,
      observedCenter: RgbColor(0, 0, 0),
      maximumLightnessShift: 0,
      maximumChromaShift: 0,
    );

    final upCandidate = matcher
        .rank(RgbColor(0, 0, 0))
        .singleWhere((candidate) => candidate.face == CubeFace.up);

    expect(
      upCandidate.cost,
      closeTo(
        deltaE2000(
          RgbColor(0, 0, 0).toLab(),
          _standardRgb(CubeFace.up).toLab(),
        ),
        1e-9,
      ),
    );
  });

  test('rejects invalid correction limits before they can produce NaN', () {
    for (final invalid in [double.nan, double.infinity, -0.01]) {
      expect(
        () => ScanColorMatcher(
          capturedFace: CubeFace.up,
          observedCenter: _standardRgb(CubeFace.up),
          maximumLightnessShift: invalid,
        ),
        throwsArgumentError,
      );
      expect(
        () => ScanColorMatcher(
          capturedFace: CubeFace.up,
          observedCenter: _standardRgb(CubeFace.up),
          maximumChromaShift: invalid,
        ),
        throwsArgumentError,
      );
    }
  });
}

RgbColor _standardRgb(CubeFace face) {
  final argb = CubePalette.colorFor(face).toARGB32();
  return RgbColor((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);
}
