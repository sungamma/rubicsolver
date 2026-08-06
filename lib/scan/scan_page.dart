import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import '../cube/cube_state.dart';
import '../editor/cube_editor_page.dart';
import 'face_sampler.dart';
import 'scan_session.dart';
import 'sticker_sample.dart';

typedef CameraDiscovery = Future<List<CameraDescription>> Function();

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    this.cameraDiscovery,
    this.faceSampler = const FaceSampler(),
  });

  final CameraDiscovery? cameraDiscovery;
  final FaceSampler faceSampler;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final ScanSession _session = ScanSession();

  CameraController? _controller;
  List<StickerSample>? _previewSamples;
  String? _cameraError;
  String? _samplingError;
  var _loadingCamera = true;
  var _sampling = false;
  var _flashSupported = false;
  var _flashEnabled = false;
  var _cameraGeneration = 0;
  var _openingEditor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_releaseCamera());
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      unawaited(_initializeCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraGeneration++;
    unawaited(_controller?.dispose());
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final generation = ++_cameraGeneration;
    if (mounted) {
      setState(() {
        _loadingCamera = true;
        _cameraError = null;
      });
    }

    CameraController? nextController;
    try {
      final discover = widget.cameraDiscovery ?? availableCameras;
      final cameras = await discover();
      if (!mounted || generation != _cameraGeneration) {
        return;
      }
      if (cameras.isEmpty) {
        setState(() {
          _loadingCamera = false;
          _cameraError = '未找到可用相机，请改用手动录入。';
        });
        return;
      }

      final description = _backCameraFrom(cameras) ?? cameras.first;
      nextController = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await nextController.initialize();

      var supportsFlash = false;
      try {
        await nextController.setFlashMode(FlashMode.off);
        supportsFlash = true;
      } on CameraException {
        supportsFlash = false;
      }

      if (!mounted || generation != _cameraGeneration) {
        await nextController.dispose();
        return;
      }

      final previous = _controller;
      setState(() {
        _controller = nextController;
        _loadingCamera = false;
        _flashSupported = supportsFlash;
        _flashEnabled = false;
      });
      nextController = null;
      await previous?.dispose();
    } catch (error) {
      await nextController?.dispose();
      if (!mounted || generation != _cameraGeneration) {
        return;
      }
      setState(() {
        _loadingCamera = false;
        _cameraError = _cameraErrorMessage(error);
      });
    }
  }

  Future<void> _releaseCamera() async {
    _cameraGeneration++;
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (mounted) {
      setState(() {
        _controller = null;
        _loadingCamera = true;
        _flashEnabled = false;
      });
    }
    await controller.dispose();
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !_flashSupported) {
      return;
    }
    final enabled = !_flashEnabled;
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() => _flashEnabled = enabled);
      }
    } on CameraException {
      if (!mounted) {
        return;
      }
      setState(() {
        _flashSupported = false;
        _flashEnabled = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此设备不支持闪光灯切换。')));
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _sampling) {
      return;
    }

    setState(() {
      _sampling = true;
      _samplingError = null;
    });
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      final samples = await widget.faceSampler.sampleInBackground(bytes);
      if (!mounted) {
        return;
      }
      setState(() => _previewSamples = samples);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _samplingError = error is FaceSamplingException
            ? error.message
            : '拍照失败，请检查相机后重试。';
      });
    } finally {
      if (mounted) {
        setState(() => _sampling = false);
      }
    }
  }

  Future<void> _acceptPreview() async {
    final samples = _previewSamples;
    if (samples == null) {
      return;
    }

    _session.acceptCurrent(samples);
    setState(() {
      _previewSamples = null;
      _samplingError = null;
    });
    if (_session.isComplete) {
      await _openEditor();
    }
  }

  Future<void> _openEditor() async {
    if (_openingEditor || !_session.isComplete) {
      return;
    }
    _openingEditor = true;
    final result = _session.classify();
    if (!mounted) {
      _openingEditor = false;
      return;
    }

    final rescanFace = await Navigator.of(context).push<CubeFace>(
      MaterialPageRoute<CubeFace>(
        builder: (editorContext) => CubeEditorPage(
          initialState: result.state,
          recognitionHints: result.recognitionHints,
          uncertainStickerIndices: result.uncertainStickerIndices,
          classificationIssues: result.issues,
          onRescanFace: (face) => Navigator.of(editorContext).pop(face),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _openingEditor = false;
      if (rescanFace != null) {
        _session.restartFrom(rescanFace);
      }
    });
  }

  void _openManualEntry() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CubeEditorPage(initialState: CubeState.solved()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentFace = _session.currentFace;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentFace == null ? '扫描完成' : '扫描 ${currentFace.letter} 面',
        ),
        actions: [
          if (_flashSupported && _previewSamples == null)
            IconButton(
              tooltip: _flashEnabled ? '关闭闪光灯' : '打开闪光灯',
              onPressed: _toggleFlash,
              icon: Icon(_flashEnabled ? Icons.flash_on : Icons.flash_off),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _session.progress),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_cameraError != null) {
      return _CameraFallback(
        message: _cameraError!,
        onRetry: _initializeCamera,
        onManualEntry: _openManualEntry,
      );
    }
    if (_loadingCamera) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在启动相机…'),
          ],
        ),
      );
    }
    if (_session.isComplete) {
      return _CompletedScan(
        onReview: _openEditor,
        onRestart: () {
          setState(() {
            _session.restartFrom(CubeFace.up);
            _previewSamples = null;
          });
        },
      );
    }
    final samples = _previewSamples;
    if (samples != null) {
      return _SamplePreview(
        face: _session.currentFace!,
        samples: samples,
        onRetry: () => setState(() {
          _previewSamples = null;
          _samplingError = null;
        }),
        onAccept: _acceptPreview,
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _CameraFallback(
        message: '相机尚未就绪，请重试或改用手动录入。',
        onRetry: _initializeCamera,
        onManualEntry: _openManualEntry,
      );
    }
    return _CaptureGuide(
      controller: controller,
      face: _session.currentFace!,
      completedFaceCount: _session.completedFaceCount,
      sampling: _sampling,
      samplingError: _samplingError,
      onCapture: _capture,
    );
  }
}

class _CaptureGuide extends StatelessWidget {
  const _CaptureGuide({
    required this.controller,
    required this.face,
    required this.completedFaceCount,
    required this.sampling,
    required this.samplingError,
    required this.onCapture,
  });

  final CameraController controller;
  final CubeFace face;
  final int completedFaceCount;
  final bool sampling;
  final String? samplingError;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _FaceInstruction(
            face: face,
            subtitle:
                '第 ${completedFaceCount + 1}/6 面 · ${_orientationHint(face)}',
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: Center(child: CameraPreview(controller)),
                      ),
                      const IgnorePointer(
                        child: CustomPaint(painter: _GridGuidePainter()),
                      ),
                      if (sampling)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (samplingError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              samplingError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: sampling ? null : onCapture,
            icon: const Icon(Icons.camera),
            label: Text(sampling ? '正在分析…' : '拍摄此面'),
          ),
        ),
      ],
    );
  }
}

class _SamplePreview extends StatelessWidget {
  const _SamplePreview({
    required this.face,
    required this.samples,
    required this.onRetry,
    required this.onAccept,
  });

  final CubeFace face;
  final List<StickerSample> samples;
  final VoidCallback onRetry;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final poorSamples = samples.where((sample) => sample.isLowQuality).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FaceInstruction(face: face, subtitle: '检查九格取色结果'),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: samples.length,
                  itemBuilder: (context, index) {
                    final sample = samples[index];
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(
                          255,
                          sample.rgb.r,
                          sample.rgb.g,
                          sample.rgb.b,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sample.isLowQuality
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.outline,
                          width: sample.isLowQuality ? 3 : 1,
                        ),
                      ),
                      child: sample.isLowQuality
                          ? const Icon(Icons.warning_amber_rounded)
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (poorSamples == 0)
                const Text('光线质量正常，可以接受此面。', textAlign: TextAlign.center)
              else
                Text(
                  '有 $poorSamples 枚贴纸可能过暗、过曝或光线不均，建议调整光线后重拍。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('重拍'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: const Text('接受此面'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceInstruction extends StatelessWidget {
  const _FaceInstruction({required this.face, required this.subtitle});

  final CubeFace face;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: CubePalette.colorFor(face),
          foregroundColor: CubePalette.foregroundFor(face),
          child: Text(face.letter),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将${_faceName(face)}中心对准九格',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({
    required this.message,
    required this.onRetry,
    required this.onManualEntry,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('重试相机')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onManualEntry,
                child: const Text('手动录入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedScan extends StatelessWidget {
  const _CompletedScan({required this.onReview, required this.onRestart});

  final VoidCallback onReview;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text('六个面已采集完成'),
            const SizedBox(height: 20),
            FilledButton(onPressed: onReview, child: const Text('查看校验结果')),
            TextButton(onPressed: onRestart, child: const Text('从头扫描')),
          ],
        ),
      ),
    );
  }
}

class _GridGuidePainter extends CustomPainter {
  const _GridGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Offset.zero & size, paint);
    for (var division = 1; division < 3; division++) {
      final x = size.width * division / 3;
      final y = size.height * division / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridGuidePainter oldDelegate) => false;
}

CameraDescription? _backCameraFrom(List<CameraDescription> cameras) {
  for (final camera in cameras) {
    if (camera.lensDirection == CameraLensDirection.back) {
      return camera;
    }
  }
  return null;
}

String _cameraErrorMessage(Object error) {
  if (error is CameraException) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted') {
      return '没有相机权限。请在系统设置中允许相机访问，或改用手动录入。';
    }
  }
  return '无法启动相机，请重试或改用手动录入。';
}

String _faceName(CubeFace face) {
  return switch (face) {
    CubeFace.up => '白色（U）面',
    CubeFace.right => '红色（R）面',
    CubeFace.front => '绿色（F）面',
    CubeFace.down => '黄色（D）面',
    CubeFace.left => '橙色（L）面',
    CubeFace.back => '蓝色（B）面',
  };
}

String _orientationHint(CubeFace face) {
  return switch (face) {
    CubeFace.up => '蓝色面朝上',
    CubeFace.right => '白色面朝上',
    CubeFace.front => '白色面朝上',
    CubeFace.down => '绿色面朝上',
    CubeFace.left => '白色面朝上',
    CubeFace.back => '白色面朝上',
  };
}
