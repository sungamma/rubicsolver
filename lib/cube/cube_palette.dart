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
      CubeFace.up => const Color(0xFFF7F7F2),
      CubeFace.right => const Color(0xFFE53935),
      CubeFace.front => const Color(0xFF22A447),
      CubeFace.down => const Color(0xFFFFD600),
      CubeFace.left => const Color(0xFFFB8C00),
      CubeFace.back => const Color(0xFF1976D2),
    };
  }

  static Color foregroundFor(CubeFace face) {
    return switch (face) {
      CubeFace.up || CubeFace.down || CubeFace.left => Colors.black,
      CubeFace.right || CubeFace.front || CubeFace.back => Colors.white,
    };
  }
}
