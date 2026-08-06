import 'dart:math' as math;

final class RgbColor {
  RgbColor(this.r, this.g, this.b) {
    for (final channel in [r, g, b]) {
      if (channel < 0 || channel > 255) {
        throw ArgumentError.value(channel, 'channel', '必须位于 0 到 255');
      }
    }
  }

  final int r;
  final int g;
  final int b;

  double get relativeLuminance {
    final red = _linearChannel(r);
    final green = _linearChannel(g);
    final blue = _linearChannel(b);
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  }

  LabColor toLab() {
    final red = _linearChannel(r);
    final green = _linearChannel(g);
    final blue = _linearChannel(b);

    final x =
        (0.4124564 * red + 0.3575761 * green + 0.1804375 * blue) / 0.95047;
    final y = 0.2126729 * red + 0.7151522 * green + 0.0721750 * blue;
    final z =
        (0.0193339 * red + 0.1191920 * green + 0.9503041 * blue) / 1.08883;

    final fx = _labPivot(x);
    final fy = _labPivot(y);
    final fz = _labPivot(z);
    return LabColor(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
  }

  static double _linearChannel(int channel) {
    final value = channel / 255;
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _labPivot(double value) {
    const epsilon = 216 / 24389;
    const kappa = 24389 / 27;
    return value > epsilon
        ? math.pow(value, 1 / 3).toDouble()
        : (kappa * value + 16) / 116;
  }

  @override
  bool operator ==(Object other) =>
      other is RgbColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'RgbColor($r, $g, $b)';
}

final class LabColor {
  const LabColor(this.l, this.a, this.b);

  final double l;
  final double a;
  final double b;
}

double deltaE76(LabColor first, LabColor second) {
  final deltaL = first.l - second.l;
  final deltaA = first.a - second.a;
  final deltaB = first.b - second.b;
  return math.sqrt(deltaL * deltaL + deltaA * deltaA + deltaB * deltaB);
}
