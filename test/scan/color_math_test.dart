import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/scan/color_math.dart';

void main() {
  test('identical colors have zero Delta E', () {
    final rgb = RgbColor(255, 0, 0);

    expect(deltaE76(rgb.toLab(), rgb.toLab()), closeTo(0, 1e-9));
  });

  test('converts reference red to CIE Lab using D65', () {
    final lab = RgbColor(255, 0, 0).toLab();

    expect(lab.l, closeTo(53.24, 0.08));
    expect(lab.a, closeTo(80.09, 0.12));
    expect(lab.b, closeTo(67.20, 0.12));
  });

  test('white is lighter than black and RGB values are immutable', () {
    final white = RgbColor(255, 255, 255);
    final black = RgbColor(0, 0, 0);

    expect(white.toLab().l, closeTo(100, 0.02));
    expect(black.toLab().l, closeTo(0, 0.02));
    expect(white.relativeLuminance, greaterThan(black.relativeLuminance));
    expect(white, RgbColor(255, 255, 255));
  });

  test('rejects channels outside the byte range', () {
    expect(() => RgbColor(-1, 0, 0), throwsArgumentError);
    expect(() => RgbColor(0, 0, 256), throwsArgumentError);
  });

  test('Delta E is symmetric', () {
    final first = RgbColor(220, 30, 40).toLab();
    final second = RgbColor(20, 90, 230).toLab();

    expect(deltaE76(first, second), closeTo(deltaE76(second, first), 1e-9));
  });
}
