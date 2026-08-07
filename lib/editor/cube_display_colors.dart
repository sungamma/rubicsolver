import 'package:flutter/material.dart';

import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import '../scan/color_math.dart';

abstract final class CubeDisplayColors {
  static Color colorFor(
    CubeFace face, {
    Map<CubeFace, RgbColor> centerColors = const {},
  }) => CubePalette.colorFor(face);

  static Color foregroundFor(
    CubeFace face, {
    Map<CubeFace, RgbColor> centerColors = const {},
  }) => CubePalette.foregroundFor(face);
}
