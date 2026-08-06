import 'package:flutter/material.dart';

import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import '../scan/color_math.dart';

abstract final class CubeDisplayColors {
  static Color colorFor(
    CubeFace face, {
    Map<CubeFace, RgbColor> centerColors = const {},
  }) {
    final rgb = centerColors[face];
    return rgb == null
        ? CubePalette.colorFor(face)
        : Color.fromARGB(255, rgb.r, rgb.g, rgb.b);
  }

  static Color foregroundFor(
    CubeFace face, {
    Map<CubeFace, RgbColor> centerColors = const {},
  }) {
    final rgb = centerColors[face];
    if (rgb == null) {
      return CubePalette.foregroundFor(face);
    }
    return rgb.relativeLuminance > 0.45 ? Colors.black : Colors.white;
  }
}
