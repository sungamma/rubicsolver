import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_color_scheme.dart';
import 'package:rubicsolver/cube/cube_face.dart';

void main() {
  const rearranged = {
    CubeFace.up: CubeFace.down,
    CubeFace.right: CubeFace.right,
    CubeFace.front: CubeFace.back,
    CubeFace.down: CubeFace.up,
    CubeFace.left: CubeFace.left,
    CubeFace.back: CubeFace.front,
  };

  test('standard maps every logical face to its conventional color', () {
    for (final face in CubeFace.values) {
      expect(CubeColorScheme.standard.colorIdentityFor(face), face);
      expect(CubeColorScheme.standard.logicalFaceFor(face), face);
    }
  });

  test('validates and reverses a complete permutation', () {
    final source = Map<CubeFace, CubeFace>.of(rearranged);
    final scheme = CubeColorScheme(source);

    source[CubeFace.up] = CubeFace.up;

    expect(scheme.colorIdentityFor(CubeFace.up), CubeFace.down);
    expect(scheme.logicalFaceFor(CubeFace.down), CubeFace.up);
    expect(
      () => scheme.assignments[CubeFace.up] = CubeFace.up,
      throwsUnsupportedError,
    );
  });

  test('rejects incomplete and duplicate color assignments', () {
    expect(
      () => CubeColorScheme({
        for (final face in CubeFace.values.where(
          (face) => face != CubeFace.back,
        ))
          face: face,
      }),
      throwsArgumentError,
    );
    expect(
      () => CubeColorScheme({
        for (final face in CubeFace.values) face: CubeFace.up,
      }),
      throwsArgumentError,
    );
  });

  test('swaps the owner when assigning an occupied color', () {
    final scheme = CubeColorScheme.standard
        .swapColor(CubeFace.up, CubeFace.down)
        .swapColor(CubeFace.front, CubeFace.back);

    expect(scheme.colorIdentityFor(CubeFace.up), CubeFace.down);
    expect(scheme.colorIdentityFor(CubeFace.down), CubeFace.up);
    expect(scheme.colorIdentityFor(CubeFace.front), CubeFace.back);
    expect(scheme.colorIdentityFor(CubeFace.back), CubeFace.front);
    expect(scheme, CubeColorScheme(rearranged));
    expect(scheme.hashCode, CubeColorScheme(rearranged).hashCode);
    expect(
      CubeColorScheme.standard.swapColor(CubeFace.up, CubeFace.up),
      CubeColorScheme.standard,
    );
  });

  test('different assignments are not equal', () {
    final swapped = CubeColorScheme.standard.swapColor(
      CubeFace.up,
      CubeFace.down,
    );

    expect(swapped, isNot(CubeColorScheme.standard));
    expect(swapped, isNot('not a scheme'));
  });
}
