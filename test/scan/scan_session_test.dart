import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_color_scheme.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/scan/color_math.dart';
import 'package:rubicsolver/scan/scan_session.dart';
import 'package:rubicsolver/scan/sticker_sample.dart';

void main() {
  test('keeps one color scheme for capture and final classification', () {
    final colorScheme = CubeColorScheme.standard
        .swapColor(CubeFace.up, CubeFace.down)
        .swapColor(CubeFace.front, CubeFace.back);
    final session = ScanSession(colorScheme: colorScheme);

    for (final face in CubeFace.values) {
      session.acceptCurrent(_samplesFor(face, colorScheme: colorScheme));
    }

    expect(session.colorScheme, colorScheme);
    expect(session.classify().state, CubeState.solved());
  });

  test('captures faces in URFDLB order and reports progress', () {
    final session = ScanSession();

    expect(session.currentFace, CubeFace.up);
    expect(session.completedFaceCount, 0);
    expect(session.progress, 0);

    session.acceptCurrent(_samplesFor(CubeFace.up));

    expect(session.currentFace, CubeFace.right);
    expect(session.completedFaceCount, 1);
    expect(session.progress, closeTo(1 / 6, 1e-9));
  });

  test('rejects a face with anything other than nine samples', () {
    final session = ScanSession();

    expect(
      () => session.acceptCurrent(_samplesFor(CubeFace.up).take(8).toList()),
      throwsArgumentError,
    );
  });

  test('persists locked colors for the accepted face', () {
    final session = ScanSession();

    session.acceptCurrent(
      _samplesFor(CubeFace.up),
      lockedFaces: const {0: CubeFace.right},
    );

    expect(session.lockedFacesByFace[CubeFace.up]![0], CubeFace.right);
    expect(
      () => session.lockedFacesByFace[CubeFace.up]![0] = CubeFace.front,
      throwsUnsupportedError,
    );
  });

  test('classifies a completed session as a solved cube', () {
    final session = ScanSession();
    for (final face in CubeFace.values) {
      expect(session.currentFace, face);
      session.acceptCurrent(_samplesFor(face));
    }

    expect(session.isComplete, isTrue);
    expect(session.currentFace, isNull);
    expect(session.progress, 1);
    expect(session.classify().state, CubeState.solved());
  });

  test('cannot classify before all faces are captured', () {
    expect(() => ScanSession().classify(), throwsStateError);
  });

  test('restartFrom removes the selected face and all later captures', () {
    final session = ScanSession();
    for (final face in CubeFace.values.take(4)) {
      session.acceptCurrent(_samplesFor(face), lockedFaces: {0: face});
    }

    session.restartFrom(CubeFace.front);

    expect(session.currentFace, CubeFace.front);
    expect(session.completedFaceCount, 2);
    expect(session.samplesByFace.keys, [CubeFace.up, CubeFace.right]);
    expect(session.lockedFacesByFace.keys, [CubeFace.up, CubeFace.right]);
    expect(
      () => session.samplesByFace[CubeFace.front] = _samplesFor(CubeFace.front),
      throwsUnsupportedError,
    );
  });
}

List<StickerSample> _samplesFor(
  CubeFace face, {
  CubeColorScheme colorScheme = CubeColorScheme.standard,
}) {
  final colors = {
    CubeFace.up: RgbColor(245, 245, 245),
    CubeFace.right: RgbColor(220, 35, 45),
    CubeFace.front: RgbColor(30, 170, 70),
    CubeFace.down: RgbColor(250, 210, 25),
    CubeFace.left: RgbColor(245, 125, 20),
    CubeFace.back: RgbColor(25, 90, 210),
  };
  return List.generate(
    9,
    (_) => StickerSample(
      rgb: colors[colorScheme.colorIdentityFor(face)]!,
      luminanceVariance: 0,
    ),
  );
}
