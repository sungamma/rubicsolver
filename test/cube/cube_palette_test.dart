import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_palette.dart';

void main() {
  test('uses the conventional white red green yellow orange blue scheme', () {
    expect(CubePalette.nameFor(CubeFace.up), '白色');
    expect(CubePalette.nameFor(CubeFace.right), '红色');
    expect(CubePalette.nameFor(CubeFace.front), '绿色');
    expect(CubePalette.nameFor(CubeFace.down), '黄色');
    expect(CubePalette.nameFor(CubeFace.left), '橙色');
    expect(CubePalette.nameFor(CubeFace.back), '蓝色');
  });

  test('provides six distinct opaque display colors', () {
    final colors = CubeFace.values.map(CubePalette.colorFor).toSet();

    expect(colors, hasLength(6));
    expect(colors.every((color) => color.a == 1), isTrue);
    expect(CubePalette.foregroundFor(CubeFace.down), Colors.black);
  });

  test('uses calibrated competition cube display colors', () {
    expect(CubePalette.colorFor(CubeFace.up), const Color(0xFFFFFFFF));
    expect(CubePalette.colorFor(CubeFace.right), const Color(0xFFB71234));
    expect(CubePalette.colorFor(CubeFace.front), const Color(0xFF009B48));
    expect(CubePalette.colorFor(CubeFace.down), const Color(0xFFFFD500));
    expect(CubePalette.colorFor(CubeFace.left), const Color(0xFFFF5800));
    expect(CubePalette.colorFor(CubeFace.back), const Color(0xFF0046AD));
  });
}
