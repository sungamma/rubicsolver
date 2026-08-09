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

double deltaE2000(LabColor first, LabColor second) {
  final chroma1 = math.sqrt(first.a * first.a + first.b * first.b);
  final chroma2 = math.sqrt(second.a * second.a + second.b * second.b);
  final averageChroma = (chroma1 + chroma2) / 2;
  final averageChromaToSeventh = math.pow(averageChroma, 7).toDouble();
  final chromaAdjustment =
      0.5 *
      (1 -
          math.sqrt(
            averageChromaToSeventh / (averageChromaToSeventh + math.pow(25, 7)),
          ));

  final adjustedA1 = (1 + chromaAdjustment) * first.a;
  final adjustedA2 = (1 + chromaAdjustment) * second.a;
  final adjustedChroma1 = math.sqrt(
    adjustedA1 * adjustedA1 + first.b * first.b,
  );
  final adjustedChroma2 = math.sqrt(
    adjustedA2 * adjustedA2 + second.b * second.b,
  );
  final hue1 = _hueDegrees(first.b, adjustedA1);
  final hue2 = _hueDegrees(second.b, adjustedA2);

  final deltaLightness = second.l - first.l;
  final deltaChroma = adjustedChroma2 - adjustedChroma1;
  final hueDifference = _hueDifference(
    hue1,
    hue2,
    adjustedChroma1,
    adjustedChroma2,
  );
  final deltaHue =
      2 *
      math.sqrt(adjustedChroma1 * adjustedChroma2) *
      math.sin(_degreesToRadians(hueDifference / 2));

  final averageLightness = (first.l + second.l) / 2;
  final averageAdjustedChroma = (adjustedChroma1 + adjustedChroma2) / 2;
  final averageHue = _averageHue(hue1, hue2, adjustedChroma1, adjustedChroma2);
  final hueWeight =
      1 -
      0.17 * math.cos(_degreesToRadians(averageHue - 30)) +
      0.24 * math.cos(_degreesToRadians(2 * averageHue)) +
      0.32 * math.cos(_degreesToRadians(3 * averageHue + 6)) -
      0.20 * math.cos(_degreesToRadians(4 * averageHue - 63));
  final lightnessDifference = averageLightness - 50;
  final lightnessWeight =
      1 +
      0.015 *
          lightnessDifference *
          lightnessDifference /
          math.sqrt(20 + lightnessDifference * lightnessDifference);
  final chromaWeight = 1 + 0.045 * averageAdjustedChroma;
  final hueScale = 1 + 0.015 * averageAdjustedChroma * hueWeight;
  final hueRotation = 30 * math.exp(-math.pow((averageHue - 275) / 25, 2));
  final averageAdjustedChromaToSeventh = math
      .pow(averageAdjustedChroma, 7)
      .toDouble();
  final rotationMagnitude =
      2 *
      math.sqrt(
        averageAdjustedChromaToSeventh /
            (averageAdjustedChromaToSeventh + math.pow(25, 7)),
      );
  final rotationTerm =
      -math.sin(_degreesToRadians(2 * hueRotation)) * rotationMagnitude;

  final lightnessTerm = deltaLightness / lightnessWeight;
  final chromaTerm = deltaChroma / chromaWeight;
  final hueTerm = deltaHue / hueScale;
  return math.sqrt(
    lightnessTerm * lightnessTerm +
        chromaTerm * chromaTerm +
        hueTerm * hueTerm +
        rotationTerm * chromaTerm * hueTerm,
  );
}

double _hueDegrees(double b, double adjustedA) {
  final hue = math.atan2(b, adjustedA) * 180 / math.pi;
  return hue < 0 ? hue + 360 : hue;
}

double _hueDifference(
  double hue1,
  double hue2,
  double chroma1,
  double chroma2,
) {
  if (chroma1 * chroma2 == 0) {
    return 0;
  }
  final difference = hue2 - hue1;
  if (difference.abs() <= 180) {
    return difference;
  }
  return difference > 180 ? difference - 360 : difference + 360;
}

double _averageHue(double hue1, double hue2, double chroma1, double chroma2) {
  if (chroma1 * chroma2 == 0) {
    return hue1 + hue2;
  }
  if ((hue1 - hue2).abs() <= 180) {
    return (hue1 + hue2) / 2;
  }
  return hue1 + hue2 < 360 ? (hue1 + hue2 + 360) / 2 : (hue1 + hue2 - 360) / 2;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;
