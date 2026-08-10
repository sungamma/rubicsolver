import 'cube_face.dart';

final class CubeColorScheme {
  factory CubeColorScheme(Map<CubeFace, CubeFace> assignments) {
    if (assignments.length != CubeFace.values.length ||
        !assignments.keys.toSet().containsAll(CubeFace.values) ||
        assignments.values.toSet().length != CubeFace.values.length) {
      throw ArgumentError.value(
        assignments,
        'assignments',
        '必须为六个逻辑面各分配一种唯一颜色',
      );
    }
    return CubeColorScheme._(Map.unmodifiable(assignments));
  }

  const CubeColorScheme._(this.assignments);

  static const standard = CubeColorScheme._({
    CubeFace.up: CubeFace.up,
    CubeFace.right: CubeFace.right,
    CubeFace.front: CubeFace.front,
    CubeFace.down: CubeFace.down,
    CubeFace.left: CubeFace.left,
    CubeFace.back: CubeFace.back,
  });

  final Map<CubeFace, CubeFace> assignments;

  CubeFace colorIdentityFor(CubeFace logicalFace) => assignments[logicalFace]!;

  CubeFace logicalFaceFor(CubeFace colorIdentity) => assignments.entries
      .singleWhere((entry) => entry.value == colorIdentity)
      .key;

  CubeColorScheme swapColor(CubeFace logicalFace, CubeFace colorIdentity) {
    final currentColor = colorIdentityFor(logicalFace);
    if (currentColor == colorIdentity) {
      return this;
    }
    final otherFace = logicalFaceFor(colorIdentity);
    return CubeColorScheme({
      ...assignments,
      logicalFace: colorIdentity,
      otherFace: currentColor,
    });
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CubeColorScheme &&
        CubeFace.values.every(
          (face) => assignments[face] == other.assignments[face],
        );
  }

  @override
  int get hashCode =>
      Object.hashAll(CubeFace.values.map((face) => assignments[face]));
}
