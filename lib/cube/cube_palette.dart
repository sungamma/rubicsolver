import 'package:flutter/material.dart';

import 'cube_face.dart';

abstract final class CubePalette {
  static String nameFor(CubeFace face) {
    return switch (face) {
      CubeFace.up => '白色',
      CubeFace.right => '红色',
      CubeFace.front => '绿色',
      CubeFace.down => '黄色',
      CubeFace.left => '橙色',
      CubeFace.back => '蓝色',
    };
  }

  static Color colorFor(CubeFace face) {
    return switch (face) {
      CubeFace.up => const Color(0xFFFFFFFF),
      CubeFace.right => const Color(0xFFB71234),
      CubeFace.front => const Color(0xFF009B48),
      CubeFace.down => const Color(0xFFFFD500),
      CubeFace.left => const Color(0xFFFF5800),
      CubeFace.back => const Color(0xFF0046AD),
    };
  }

  static Color foregroundFor(CubeFace face) {
    return switch (face) {
      CubeFace.up || CubeFace.down || CubeFace.left => Colors.black,
      CubeFace.right || CubeFace.front || CubeFace.back => Colors.white,
    };
  }
}
