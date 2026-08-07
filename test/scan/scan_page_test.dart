import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/scan/color_math.dart';
import 'package:rubicsolver/scan/scan_camera.dart';
import 'package:rubicsolver/scan/scan_page.dart';
import 'package:rubicsolver/scan/scan_session.dart';
import 'package:rubicsolver/scan/sticker_sample.dart';

void main() {
  testWidgets('offers manual entry when no camera is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ScanPage(cameraDiscovery: _noCameras)),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('未找到可用相机'), findsOneWidget);
    expect(find.text('手动录入'), findsOneWidget);

    await tester.tap(find.text('手动录入'));
    await tester.pumpAndSettle();

    expect(find.text('校验与纠错'), findsOneWidget);
  });

  testWidgets('does not fall back to a front-facing camera', (tester) async {
    var factoryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScanPage(
          cameraDiscovery: () async => const [_frontCamera],
          cameraFactory: (description) {
            factoryCalls++;
            return _FakeScanCameraController(description);
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('未找到后置相机'), findsOneWidget);
    expect(find.text('手动录入'), findsOneWidget);
    expect(factoryCalls, 0);
  });

  testWidgets('uses neutral face guidance and hides unverified flash control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanPage(
          cameraDiscovery: () async => const [_backCamera],
          cameraFactory: _FakeScanCameraController.new,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('将U 面中心'), findsOneWidget);
    expect(find.textContaining('白色'), findsNothing);
    expect(find.byIcon(Icons.flash_off), findsNothing);
    expect(find.byIcon(Icons.flash_on), findsNothing);
  });

  testWidgets('awaits disposal before editing and reopens camera for rescan', (
    tester,
  ) async {
    final disposeGate = Completer<void>();
    final controllers = <_FakeScanCameraController>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ScanPage(
          cameraDiscovery: () async => const [_backCamera],
          cameraFactory: (description) {
            final controller = _FakeScanCameraController(
              description,
              disposeGate: controllers.isEmpty ? disposeGate.future : null,
            );
            controllers.add(controller);
            return controller;
          },
          session: _completedSession(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看校验结果'));
    await tester.pump();

    expect(controllers.single.disposeStarted, isTrue);
    expect(find.text('校验与纠错'), findsNothing);

    disposeGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('校验与纠错'), findsOneWidget);

    await tester.ensureVisible(find.text('重新扫描某一面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新扫描某一面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上面（U）'));
    await tester.pumpAndSettle();

    expect(controllers, hasLength(2));
    expect(controllers.last.isInitialized, isTrue);
    expect(find.text('扫描 U 面'), findsOneWidget);
  });

  testWidgets('returning from a completed review keeps the camera closed', (
    tester,
  ) async {
    final controllers = <_FakeScanCameraController>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ScanPage(
          cameraDiscovery: () async => const [_backCamera],
          cameraFactory: (description) {
            final controller = _FakeScanCameraController(description);
            controllers.add(controller);
            return controller;
          },
          session: _completedSession(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看校验结果'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(controllers, hasLength(1));
    expect(controllers.single.disposed, isTrue);
    expect(find.text('六个面已采集完成'), findsOneWidget);
  });

  testWidgets('ignores a capture result from a released camera generation', (
    tester,
  ) async {
    final samplingStarted = Completer<void>();
    final oldSamples = Completer<List<StickerSample>>();
    final controllers = <_FakeScanCameraController>[];
    Future<List<StickerSample>> sampleInBackground(Uint8List bytes) {
      samplingStarted.complete();
      return oldSamples.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ScanPage(
          cameraDiscovery: () async => const [_backCamera],
          cameraFactory: (description) {
            final controller = _FakeScanCameraController(
              description,
              picture: XFile.fromData(
                Uint8List.fromList([1, 2, 3]),
                name: 'capture.jpg',
              ),
            );
            controllers.add(controller);
            return controller;
          },
          sampleInBackground: sampleInBackground,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('拍摄此面'));
    await samplingStarted.future;
    await tester.pump();
    expect(find.text('正在分析…'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(controllers, hasLength(2));

    oldSamples.complete(_samplesFor(CubeFace.up));
    await tester.pumpAndSettle();

    expect(find.text('接受此面'), findsNothing);
    expect(find.text('拍摄此面'), findsOneWidget);
  });
}

Future<List<CameraDescription>> _noCameras() async => const [];

const _frontCamera = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);

const _backCamera = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

class _FakeScanCameraController implements ScanCameraController {
  _FakeScanCameraController(this.description, {this.disposeGate, this.picture});

  @override
  final CameraDescription description;

  final Future<void>? disposeGate;
  final XFile? picture;
  var _initialized = false;
  var disposeStarted = false;
  var disposed = false;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isTakingPicture => false;

  @override
  Size? get previewSize => const Size(300, 400);

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);

  @override
  Future<void> dispose() async {
    disposeStarted = true;
    final gate = disposeGate;
    if (gate != null) {
      await gate;
    }
    disposed = true;
    _initialized = false;
  }

  @override
  Future<void> initialize() async => _initialized = true;

  @override
  Future<XFile> takePicture() => picture == null
      ? throw UnsupportedError('not used')
      : Future.value(picture);
}

List<StickerSample> _samplesFor(CubeFace face) {
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
    (_) => StickerSample(rgb: colors[face]!, luminanceVariance: 0),
  );
}

ScanSession _completedSession() {
  final session = ScanSession();
  for (final face in CubeFace.values) {
    session.acceptCurrent(_samplesFor(face));
  }
  return session;
}
