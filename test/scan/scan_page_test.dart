import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_color_scheme.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_palette.dart';
import 'package:rubicsolver/scan/camera_frame_sampler.dart';
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

  testWidgets(
    'uses standard color guidance and hides unverified flash control',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanPage(
            cameraDiscovery: () async => const [_backCamera],
            cameraFactory: _FakeScanCameraController.new,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('白色 U 面'), findsOneWidget);
      expect(find.textContaining('蓝色边朝上'), findsOneWidget);
      expect(find.textContaining('白色中心 = U'), findsOneWidget);
      expect(find.textContaining('绿色中心 = F'), findsOneWidget);
      expect(find.byIcon(Icons.flash_off), findsNothing);
      expect(find.byIcon(Icons.flash_on), findsNothing);
    },
  );

  testWidgets('uses configured colors in face and orientation guidance', (
    tester,
  ) async {
    final colorScheme = CubeColorScheme.standard.swapColor(
      CubeFace.up,
      CubeFace.down,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScanPage(
          colorScheme: colorScheme,
          cameraDiscovery: () async => const [_backCamera],
          cameraFactory: _FakeScanCameraController.new,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('黄色 U 面'), findsOneWidget);
    expect(find.textContaining('蓝色边朝上'), findsOneWidget);
    expect(find.textContaining('黄色中心 = U'), findsOneWidget);
    expect(find.textContaining('绿色中心 = F'), findsOneWidget);
  });

  testWidgets('shows the fixed color orientation for every scan face', (
    tester,
  ) async {
    const expected = {
      CubeFace.up: ('白色 U 面', '蓝色边朝上'),
      CubeFace.right: ('红色 R 面', '白色边朝上'),
      CubeFace.front: ('绿色 F 面', '白色边朝上'),
      CubeFace.down: ('黄色 D 面', '绿色边朝上'),
      CubeFace.left: ('橙色 L 面', '白色边朝上'),
      CubeFace.back: ('蓝色 B 面', '白色边朝上'),
    };

    for (final face in CubeFace.values) {
      final session = ScanSession();
      for (final completed in CubeFace.values.take(face.index)) {
        session.acceptCurrent(_samplesFor(completed));
      }
      await tester.pumpWidget(
        MaterialApp(
          home: ScanPage(
            key: ValueKey('scan-${face.name}'),
            cameraDiscovery: () async => const [_backCamera],
            cameraFactory: _FakeScanCameraController.new,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(expected[face]!.$1), findsOneWidget);
      expect(find.textContaining(expected[face]!.$2), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('shows recognized colors directly over the camera preview', (
    tester,
  ) async {
    final controllers = <_FakeScanCameraController>[];
    final session = ScanSession();
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
          sampleLiveFrame: (_) => _samplesFor(CubeFace.up),
          sampleInBackground: (_) async => _samplesFor(CubeFace.up),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller = controllers.single;
    expect(controller.isStreamingImages, isTrue);
    controller.emitFrame(_emptyFrame());
    await tester.pump();

    expect(find.byKey(const ValueKey('live-recognition-grid')), findsOneWidget);
    for (var index = 0; index < 9; index++) {
      expect(find.byKey(ValueKey('live-recognition-$index')), findsOneWidget);
    }
    expect(find.text('白'), findsNWidgets(9));
    final firstCell = tester.widget<Container>(
      find.byKey(const ValueKey('live-recognition-0')),
    );
    final decoration = firstCell.decoration! as BoxDecoration;
    expect(decoration.color!.a, lessThanOrEqualTo(0.12));
    final firstDot = tester.widget<Align>(
      find.byKey(const ValueKey('live-recognition-dot-0')),
    );
    expect(firstDot.alignment, Alignment.center);
    expect(find.byKey(const ValueKey('lock-current-colors')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('live-recognition-0')));
    await tester.pump();

    expect(find.byKey(const ValueKey('locked-recognition-0')), findsOneWidget);

    await tester.tap(find.text('拍摄此面'));
    await tester.pumpAndSettle();

    expect(controller.stopStreamCalls, 1);
    expect(find.text('接受此面'), findsOneWidget);
    expect(find.text('白色'), findsNWidgets(9));
    expect(find.byKey(const ValueKey('locked-preview-0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('preview-sticker-1')));
    await tester.pumpAndSettle();
    for (final face in CubeFace.values) {
      expect(
        find.byKey(ValueKey('preview-color-${face.name}')),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('preview-color-right')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('locked-preview-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('preview-sticker-4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preview-color-up')), findsNothing);

    await tester.ensureVisible(find.text('接受此面'));
    await tester.pump();
    await tester.tap(find.text('接受此面'));
    await tester.pumpAndSettle();

    expect(session.lockedFacesByFace[CubeFace.up]![0], CubeFace.up);
    expect(session.lockedFacesByFace[CubeFace.up]![1], CubeFace.right);
  });

  testWidgets('uses configured display colors and maps manual picks to logic', (
    tester,
  ) async {
    final colorScheme = CubeColorScheme.standard.swapColor(
      CubeFace.up,
      CubeFace.down,
    );
    final controllers = <_FakeScanCameraController>[];
    final session = ScanSession(colorScheme: colorScheme);
    await tester.pumpWidget(
      MaterialApp(
        home: ScanPage(
          colorScheme: colorScheme,
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
          sampleLiveFrame: (_) =>
              _samplesFor(CubeFace.up, colorScheme: colorScheme),
          sampleInBackground: (_) async =>
              _samplesFor(CubeFace.up, colorScheme: colorScheme),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();
    controllers.single.emitFrame(_emptyFrame());
    await tester.pump();

    expect(find.text('黄'), findsNWidgets(9));
    final dot = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('live-recognition-dot-0')),
        matching: find.byType(Container),
      ),
    );
    final dotDecoration = dot.decoration! as BoxDecoration;
    expect(dotDecoration.color, CubePalette.colorFor(CubeFace.down));

    await tester.tap(find.text('拍摄此面'));
    await tester.pumpAndSettle();
    expect(find.text('黄色'), findsNWidgets(9));
    await tester.tap(find.byKey(const ValueKey('preview-sticker-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preview-color-up')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('接受此面'));
    await tester.pump();
    await tester.tap(find.text('接受此面'));
    await tester.pumpAndSettle();

    expect(session.lockedFacesByFace[CubeFace.up]![1], CubeFace.down);
  });

  testWidgets('completed review stays camera-free and rescan opens camera', (
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

    expect(controllers, isEmpty);
    await tester.tap(find.text('查看校验结果'));
    await tester.pumpAndSettle();
    expect(find.text('校验与纠错'), findsOneWidget);

    await tester.ensureVisible(find.text('重新扫描某一面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新扫描某一面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上面（U）'));
    await tester.pumpAndSettle();

    expect(controllers, hasLength(1));
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

    expect(controllers, isEmpty);
    expect(find.text('六个面已采集完成'), findsOneWidget);
  });

  testWidgets('starting over from a completed scan reinitializes the camera', (
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

    await tester.tap(find.text('从头扫描'));
    await tester.pumpAndSettle();

    expect(controllers, hasLength(1));
    expect(controllers.last.isInitialized, isTrue);
    expect(find.text('扫描 U 面'), findsOneWidget);
  });

  testWidgets('does not reopen the camera while the editor route is active', (
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
    expect(find.text('校验与纠错'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(controllers, isEmpty);
  });

  testWidgets('serializes disposal before one resumed camera initialization', (
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(controllers.single.disposeStarted, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(controllers, hasLength(1));

    disposeGate.complete();
    await tester.pumpAndSettle();

    expect(controllers, hasLength(2));
    expect(controllers.last.isInitialized, isTrue);
  });

  testWidgets(
    'keeps one pending initialization across rapid lifecycle changes',
    (tester) async {
      final initializeGate = Completer<void>();
      final controllers = <_FakeScanCameraController>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ScanPage(
            cameraDiscovery: () async => const [_backCamera],
            cameraFactory: (description) {
              final controller = _FakeScanCameraController(
                description,
                initializeGate: controllers.isEmpty
                    ? initializeGate.future
                    : null,
              );
              controllers.add(controller);
              return controller;
            },
          ),
        ),
      );
      // The fake controller intentionally stays pending until the test opens
      // its gate, so settling the widget tree here would wait forever.
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(controllers, hasLength(1));
      expect(controllers.single.isInitialized, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      initializeGate.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(controllers, hasLength(1));
      expect(controllers.single.disposed, isFalse);
      expect(controllers.single.isInitialized, isTrue);
      expect(find.text('拍摄此面'), findsOneWidget);
    },
  );

  testWidgets(
    'serializes lifecycle changes while the first camera is initializing',
    (tester) async {
      final initializeGate = Completer<void>();
      final initializeStarted = Completer<void>();
      final controllers = <_FakeScanCameraController>[];
      var activeInitializations = 0;
      var maxConcurrentInitializations = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ScanPage(
            cameraDiscovery: () async => const [_backCamera],
            cameraFactory: (description) {
              final index = controllers.length;
              final controller = _FakeScanCameraController(
                description,
                initializeGate: index == 0 ? initializeGate.future : null,
                onInitializeStart: () {
                  activeInitializations++;
                  if (activeInitializations > maxConcurrentInitializations) {
                    maxConcurrentInitializations = activeInitializations;
                  }
                  if (index == 0 && !initializeStarted.isCompleted) {
                    initializeStarted.complete();
                  }
                },
                onInitializeEnd: () => activeInitializations--,
              );
              controllers.add(controller);
              return controller;
            },
          ),
        ),
      );
      await tester.pump();
      await initializeStarted.future;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(controllers, hasLength(1));
      expect(maxConcurrentInitializations, 1);

      initializeGate.complete();
      await tester.pumpAndSettle();

      expect(controllers, hasLength(1));
      expect(controllers.single.isInitialized, isTrue);
      expect(find.text('拍摄此面'), findsOneWidget);
    },
  );

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
  _FakeScanCameraController(
    this.description, {
    this.disposeGate,
    this.picture,
    this.initializeGate,
    this.onInitializeStart,
    this.onInitializeEnd,
  });

  @override
  final CameraDescription description;

  final Future<void>? disposeGate;
  final XFile? picture;
  final Future<void>? initializeGate;
  final VoidCallback? onInitializeStart;
  final VoidCallback? onInitializeEnd;
  var _initialized = false;
  var disposeStarted = false;
  var disposed = false;
  ValueChanged<ScanCameraFrame>? _frameListener;
  var stopStreamCalls = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isTakingPicture => false;

  @override
  bool get isStreamingImages => _frameListener != null;

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
    _frameListener = null;
  }

  @override
  Future<void> initialize() async {
    onInitializeStart?.call();
    final gate = initializeGate;
    try {
      if (gate != null) {
        await gate;
      }
      _initialized = true;
    } finally {
      onInitializeEnd?.call();
    }
  }

  @override
  Future<XFile> takePicture() => picture == null
      ? throw UnsupportedError('not used')
      : Future.value(picture);

  @override
  Future<void> startImageStream(ValueChanged<ScanCameraFrame> onFrame) async {
    _frameListener = onFrame;
  }

  @override
  Future<void> stopImageStream() async {
    if (_frameListener != null) {
      stopStreamCalls++;
      _frameListener = null;
    }
  }

  void emitFrame(ScanCameraFrame frame) => _frameListener?.call(frame);
}

ScanCameraFrame _emptyFrame() => ScanCameraFrame(
  width: 1,
  height: 1,
  format: ScanCameraPixelFormat.bgra8888,
  planes: [
    ScanCameraPlane(
      bytes: Uint8List.fromList([0, 0, 0, 255]),
      bytesPerRow: 4,
      bytesPerPixel: 4,
    ),
  ],
);

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

ScanSession _completedSession() {
  final session = ScanSession();
  for (final face in CubeFace.values) {
    session.acceptCurrent(_samplesFor(face));
  }
  return session;
}
