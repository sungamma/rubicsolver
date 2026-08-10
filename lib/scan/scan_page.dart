import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../cube/cube_color_scheme.dart';
import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import '../cube/cube_state.dart';
import '../editor/cube_editor_page.dart';
import 'camera_frame_sampler.dart';
import 'face_sampler.dart';
import 'scan_camera.dart';
import 'scan_preview_geometry.dart';
import 'scan_preview_classifier.dart';
import 'scan_session.dart';
import 'sticker_sample.dart';

typedef CameraDiscovery = Future<List<CameraDescription>> Function();
typedef BackgroundFaceSampler =
    Future<List<StickerSample>> Function(Uint8List bytes);
typedef LiveFrameSampler = List<StickerSample> Function(ScanCameraFrame frame);

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    this.cameraDiscovery,
    this.cameraFactory,
    this.faceSampler = const FaceSampler(),
    this.sampleInBackground,
    this.sampleLiveFrame,
    this.session,
    this.colorScheme = CubeColorScheme.standard,
  });

  final CameraDiscovery? cameraDiscovery;
  final ScanCameraFactory? cameraFactory;
  final FaceSampler faceSampler;
  final BackgroundFaceSampler? sampleInBackground;
  final LiveFrameSampler? sampleLiveFrame;
  final ScanSession? session;
  final CubeColorScheme colorScheme;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  late final ScanSession _session;
  late final CubeColorScheme _colorScheme;

  ScanCameraController? _controller;
  List<StickerSample>? _previewSamples;
  List<StickerSample>? _liveSamples;
  final Map<int, CubeFace> _lockedPreviewFaces = {};
  String? _cameraError;
  String? _samplingError;
  var _loadingCamera = true;
  var _sampling = false;
  var _cameraGeneration = 0;
  var _openingEditor = false;
  var _editorRouteActive = false;
  var _lifecycleResumed = true;
  var _disposed = false;
  var _handlingLiveFrame = false;
  DateTime? _lastLiveFrameAt;
  var _cameraRequestRevision = 0;
  Future<void>? _cameraReconcileFuture;
  ScanCameraController? _pendingController;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? ScanSession(colorScheme: widget.colorScheme);
    _colorScheme = _session.colorScheme;
    WidgetsBinding.instance.addObserver(this);
    _lifecycleResumed = _isAppResumed;
    unawaited(_requestCameraReconcile());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleResumed = state == AppLifecycleState.resumed;
    unawaited(_requestCameraReconcile());
  }

  bool get _isAppResumed {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  bool get _shouldHaveCamera =>
      mounted &&
      !_disposed &&
      _lifecycleResumed &&
      !_editorRouteActive &&
      !_session.isComplete &&
      _previewSamples == null &&
      _cameraError == null;

  bool get _hasActiveCamera => _controller?.isInitialized == true;

  Future<void> _initializeCamera() => _requestCameraReconcile(clearError: true);

  Future<void> _requestCameraReconcile({bool clearError = false}) {
    if (clearError && mounted) {
      setState(() {
        _cameraError = null;
        _loadingCamera = true;
      });
    }
    _cameraRequestRevision++;
    final running = _cameraReconcileFuture;
    if (running != null) {
      return running;
    }

    final future = _runCameraReconcile();
    _cameraReconcileFuture = future;
    unawaited(
      future.then<void>(
        (_) => _finishCameraReconcile(future),
        onError: (Object error, StackTrace stack) {
          debugPrint('相机状态同步失败：$error');
          _finishCameraReconcile(future);
        },
      ),
    );
    return future;
  }

  void _finishCameraReconcile(Future<void> future) {
    if (!identical(_cameraReconcileFuture, future)) {
      return;
    }
    _cameraReconcileFuture = null;
    if (mounted &&
        (_shouldHaveCamera != _hasActiveCamera ||
            (_shouldHaveCamera && _cameraError == null && !_hasActiveCamera))) {
      unawaited(_requestCameraReconcile());
    }
  }

  Future<void> _runCameraReconcile() async {
    while (mounted && !_disposed) {
      final revision = _cameraRequestRevision;
      final shouldHaveCamera = _shouldHaveCamera;
      if (shouldHaveCamera) {
        if (_hasActiveCamera) {
          _setCameraLoading(false);
          await _ensureLiveRecognition(_controller!, _cameraGeneration);
        } else {
          await _createCamera();
        }
      } else {
        await _disposeActiveCamera();
      }

      if (revision == _cameraRequestRevision &&
          _shouldHaveCamera == _hasActiveCamera) {
        return;
      }
    }
  }

  void _setCameraLoading(bool loading) {
    if (!mounted || _loadingCamera == loading) {
      return;
    }
    setState(() => _loadingCamera = loading);
  }

  Future<void> _createCamera() async {
    final generation = ++_cameraGeneration;
    ScanCameraController? nextController;
    try {
      _setCameraLoading(true);
      final discover = widget.cameraDiscovery ?? availableCameras;
      final cameras = await discover();
      if (!mounted || generation != _cameraGeneration || !_shouldHaveCamera) {
        return;
      }
      if (cameras.isEmpty) {
        _setCameraFailure('未找到可用相机，请改用手动录入。');
        return;
      }

      final description = _backCameraFrom(cameras);
      if (description == null) {
        _setCameraFailure('未找到后置相机，请改用手动录入。');
        return;
      }

      final createCamera =
          widget.cameraFactory ?? PluginScanCameraController.new;
      nextController = createCamera(description);
      _pendingController = nextController;
      await nextController.initialize();
      _pendingController = null;

      if (!mounted || generation != _cameraGeneration || !_shouldHaveCamera) {
        await _safeDispose(nextController);
        return;
      }

      final previous = _controller;
      _controller = nextController;
      final activeController = nextController;
      nextController = null;
      _setCameraLoading(false);
      if (previous != null) {
        await _safeDispose(previous);
      }
      await _ensureLiveRecognition(activeController, generation);
    } catch (error) {
      _pendingController = null;
      if (nextController != null) {
        await _safeDispose(nextController);
      }
      if (!mounted || generation != _cameraGeneration) {
        return;
      }
      _setCameraFailure(_cameraErrorMessage(error));
    }
  }

  void _setCameraFailure(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingCamera = false;
      _cameraError = message;
    });
  }

  Future<void> _ensureLiveRecognition(
    ScanCameraController controller,
    int generation,
  ) async {
    if (!_isCurrentCapture(controller, generation) ||
        controller.isStreamingImages ||
        _previewSamples != null) {
      return;
    }
    try {
      await controller.startImageStream(
        (frame) => _handleLiveFrame(controller, generation, frame),
      );
    } catch (error) {
      debugPrint('启动实时颜色识别失败：$error');
      if (_isCurrentCapture(controller, generation) && mounted) {
        setState(() => _samplingError = '实时识别暂不可用，仍可拍摄此面。');
      }
    }
  }

  void _handleLiveFrame(
    ScanCameraController controller,
    int generation,
    ScanCameraFrame frame,
  ) {
    if (!_isCurrentCapture(controller, generation) ||
        _sampling ||
        _handlingLiveFrame ||
        _previewSamples != null) {
      return;
    }
    final now = DateTime.now();
    final lastFrameAt = _lastLiveFrameAt;
    if (lastFrameAt != null &&
        now.difference(lastFrameAt) < const Duration(milliseconds: 250)) {
      return;
    }

    _handlingLiveFrame = true;
    _lastLiveFrameAt = now;
    try {
      final sample =
          widget.sampleLiveFrame ??
          CameraFrameSampler(
            cropFraction: widget.faceSampler.cropFraction,
          ).sample;
      final samples = sample(frame);
      if (samples.length != 9 || !_isCurrentCapture(controller, generation)) {
        return;
      }
      setState(() => _liveSamples = List.unmodifiable(samples));
    } catch (error) {
      debugPrint('实时颜色取样失败：$error');
    } finally {
      _handlingLiveFrame = false;
    }
  }

  void _togglePreviewColorLock(int index, CubeFace face) {
    setState(() {
      if (_lockedPreviewFaces.containsKey(index)) {
        _lockedPreviewFaces.remove(index);
      } else {
        _lockedPreviewFaces[index] = face;
      }
    });
  }

  void _toggleAllPreviewColorLocks(List<CubeFace> faces) {
    setState(() {
      if (_lockedPreviewFaces.length == faces.length) {
        _lockedPreviewFaces.clear();
        return;
      }
      _lockedPreviewFaces
        ..clear()
        ..addEntries(
          faces.indexed.map((entry) => MapEntry(entry.$1, entry.$2)),
        );
    });
  }

  List<CubeFace> _applyPreviewColorLocks(List<CubeFace> faces) =>
      List<CubeFace>.unmodifiable([
        for (var index = 0; index < faces.length; index++)
          _lockedPreviewFaces[index] ?? faces[index],
      ]);

  Future<void> _editPreviewColor(int index) async {
    if (index == 4 || _previewSamples == null) {
      return;
    }
    final selectedFace = await showModalBottomSheet<CubeFace>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '选择第 ${index + 1} 格颜色',
                style: Theme.of(sheetContext).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final colorIdentity in CubeFace.values)
                    InkWell(
                      key: ValueKey('preview-color-${colorIdentity.name}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_colorScheme.logicalFaceFor(colorIdentity)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CubePalette.colorFor(colorIdentity),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(sheetContext).colorScheme.outline,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${CubePalette.nameFor(colorIdentity)} ${colorIdentity.letter}',
                            style: TextStyle(
                              color: CubePalette.foregroundFor(colorIdentity),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (selectedFace == null || !mounted || _previewSamples == null) {
      return;
    }
    setState(() => _lockedPreviewFaces[index] = selectedFace);
  }

  Future<bool> _safeDispose(ScanCameraController controller) async {
    try {
      await controller.dispose();
      return true;
    } catch (error) {
      debugPrint('释放相机失败：$error');
      if (mounted && !_disposed) {
        _setCameraFailure('无法释放相机，请重试或改用手动录入。');
      }
      return false;
    }
  }

  Future<void> _disposeActiveCamera() async {
    _cameraGeneration++;
    final controller = _controller;
    _controller = null;
    _sampling = false;
    _samplingError = null;
    _liveSamples = null;
    _lastLiveFrameAt = null;
    if (mounted) {
      setState(() => _loadingCamera = false);
    }
    if (controller != null) {
      await _safeDispose(controller);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cameraGeneration++;
    final controller = _controller;
    final pending = _pendingController;
    _controller = null;
    _pendingController = null;
    if (controller != null) {
      unawaited(_safeDispose(controller));
    }
    if (pending != null && !identical(pending, controller)) {
      unawaited(_safeDispose(pending));
    }
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.isInitialized ||
        controller.isTakingPicture ||
        _sampling) {
      return;
    }
    final generation = _cameraGeneration;

    setState(() {
      _sampling = true;
      _samplingError = null;
    });
    try {
      await controller.stopImageStream();
      if (!_isCurrentCapture(controller, generation)) {
        return;
      }
      final photo = await controller.takePicture();
      if (!_isCurrentCapture(controller, generation)) {
        return;
      }
      final bytes = await photo.readAsBytes();
      if (!_isCurrentCapture(controller, generation)) {
        return;
      }
      final sample =
          widget.sampleInBackground ?? widget.faceSampler.sampleInBackground;
      final samples = await sample(bytes);
      if (!_isCurrentCapture(controller, generation)) {
        return;
      }
      setState(() => _previewSamples = samples);
    } catch (error) {
      if (!_isCurrentCapture(controller, generation)) {
        return;
      }
      setState(() {
        _samplingError = error is FaceSamplingException
            ? error.message
            : '拍照失败，请检查相机后重试。';
      });
    } finally {
      if (_isCurrentCapture(controller, generation)) {
        setState(() => _sampling = false);
        if (_previewSamples == null) {
          unawaited(_ensureLiveRecognition(controller, generation));
        }
      }
    }
  }

  bool _isCurrentCapture(ScanCameraController controller, int generation) =>
      mounted &&
      generation == _cameraGeneration &&
      identical(controller, _controller);

  Future<void> _acceptPreview() async {
    final samples = _previewSamples;
    if (samples == null) {
      return;
    }

    if (samples.length != 9) {
      if (mounted) {
        setState(() {
          _samplingError = '照片未得到完整的 9 个贴纸样本，请重拍此面。';
        });
      }
      return;
    }

    try {
      _session.acceptCurrent(
        samples,
        lockedFaces: Map<int, CubeFace>.unmodifiable(_lockedPreviewFaces),
      );
      setState(() {
        _previewSamples = null;
        _liveSamples = null;
        _lockedPreviewFaces.clear();
        _lastLiveFrameAt = null;
        _samplingError = null;
      });
      await _requestCameraReconcile(clearError: true);
      if (_session.isComplete) {
        await _openEditor();
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _samplingError = error.message?.toString() ?? '样本数量不完整，请重拍此面。';
        });
      }
    }
  }

  Future<void> _retryPreview() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _previewSamples = null;
      _liveSamples = null;
      _lockedPreviewFaces.clear();
      _lastLiveFrameAt = null;
      _samplingError = null;
      _cameraError = null;
      _loadingCamera = true;
    });
    await _requestCameraReconcile(clearError: true);
  }

  Future<void> _openEditor() async {
    if (_openingEditor || !_session.isComplete) {
      return;
    }
    _openingEditor = true;
    _editorRouteActive = true;
    final result = _session.classify();
    try {
      await _requestCameraReconcile();
      if (!mounted || _cameraError != null) {
        return;
      }

      final rescanFace = await Navigator.of(context).push<CubeFace>(
        MaterialPageRoute<CubeFace>(
          builder: (editorContext) => CubeEditorPage(
            initialState: result.state,
            colorScheme: _colorScheme,
            recognitionHints: result.recognitionHints,
            uncertainStickerIndices: result.uncertainStickerIndices,
            classificationIssues: result.issues,
            centerColors: result.centerColors,
            onRescanFace: (face) => Navigator.of(editorContext).pop(face),
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      _editorRouteActive = false;
      if (rescanFace != null) {
        setState(() {
          _session.restartFrom(rescanFace);
          _lockedPreviewFaces.clear();
          _openingEditor = false;
          _cameraError = null;
          _loadingCamera = true;
        });
        await _requestCameraReconcile(clearError: true);
      } else {
        setState(() {
          _openingEditor = false;
          _loadingCamera = false;
        });
        _cameraRequestRevision++;
      }
    } catch (error) {
      if (mounted) {
        _editorRouteActive = false;
        _openingEditor = false;
        _setCameraFailure('无法打开校验页，请重试或改用手动录入。');
      }
    }
  }

  Future<void> _restartScan() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _session.restartFrom(CubeFace.up);
      _previewSamples = null;
      _liveSamples = null;
      _lockedPreviewFaces.clear();
      _lastLiveFrameAt = null;
      _cameraError = null;
      _editorRouteActive = false;
      _loadingCamera = true;
    });
    await _requestCameraReconcile(clearError: true);
  }

  Future<void> _openManualEntry() async {
    _editorRouteActive = true;
    await _requestCameraReconcile();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => CubeEditorPage(
          initialState: CubeState.solved(),
          colorScheme: _colorScheme,
        ),
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
        onRetry: () => unawaited(_initializeCamera()),
        onManualEntry: () => unawaited(_openManualEntry()),
      );
    }
    if (_session.isComplete) {
      return _CompletedScan(
        onReview: _openEditor,
        onRestart: () => unawaited(_restartScan()),
      );
    }
    final samples = _previewSamples;
    if (samples != null) {
      final face = _session.currentFace!;
      final recognizedFaces = _applyPreviewColorLocks(
        const ScanPreviewClassifier().classify(
          samples: samples,
          currentFace: face,
          colorScheme: _colorScheme,
        ),
      );
      return _SamplePreview(
        face: face,
        colorScheme: _colorScheme,
        samples: samples,
        recognizedFaces: recognizedFaces,
        lockedFaces: _lockedPreviewFaces,
        onEditColor: (index) => unawaited(_editPreviewColor(index)),
        onRetry: () => unawaited(_retryPreview()),
        onAccept: _acceptPreview,
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

    final controller = _controller;
    if (controller == null ||
        !controller.isInitialized ||
        controller.previewSize == null) {
      return _CameraFallback(
        message: '相机尚未就绪，请重试或改用手动录入。',
        onRetry: () => unawaited(_initializeCamera()),
        onManualEntry: () => unawaited(_openManualEntry()),
      );
    }
    final liveRecognizedFaces = _liveSamples == null
        ? null
        : _applyPreviewColorLocks(
            const ScanPreviewClassifier().classify(
              samples: _liveSamples!,
              currentFace: _session.currentFace!,
              colorScheme: _colorScheme,
            ),
          );
    return _CaptureGuide(
      controller: controller,
      face: _session.currentFace!,
      colorScheme: _colorScheme,
      completedFaceCount: _session.completedFaceCount,
      cropFraction: widget.faceSampler.cropFraction,
      liveSamples: _liveSamples,
      recognizedFaces: liveRecognizedFaces,
      lockedFaces: _lockedPreviewFaces,
      sampling: _sampling,
      samplingError: _samplingError,
      onToggleColorLock: (index) =>
          _togglePreviewColorLock(index, liveRecognizedFaces![index]),
      onToggleAllColorLocks: liveRecognizedFaces == null
          ? null
          : () => _toggleAllPreviewColorLocks(liveRecognizedFaces),
      onCapture: _capture,
    );
  }
}

class _CaptureGuide extends StatelessWidget {
  const _CaptureGuide({
    required this.controller,
    required this.face,
    required this.colorScheme,
    required this.completedFaceCount,
    required this.cropFraction,
    required this.liveSamples,
    required this.recognizedFaces,
    required this.lockedFaces,
    required this.sampling,
    required this.samplingError,
    required this.onToggleColorLock,
    required this.onToggleAllColorLocks,
    required this.onCapture,
  });

  final ScanCameraController controller;
  final CubeFace face;
  final CubeColorScheme colorScheme;
  final int completedFaceCount;
  final double cropFraction;
  final List<StickerSample>? liveSamples;
  final List<CubeFace>? recognizedFaces;
  final Map<int, CubeFace> lockedFaces;
  final bool sampling;
  final String? samplingError;
  final ValueChanged<int> onToggleColorLock;
  final VoidCallback? onToggleAllColorLocks;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _FaceInstruction(
            face: face,
            colorScheme: colorScheme,
            subtitle:
                '第 ${completedFaceCount + 1}/6 面 · '
                '${_orientationHint(face, colorScheme)}',
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dimension = math
                  .max(
                    0,
                    math.min(constraints.maxWidth - 32, constraints.maxHeight),
                  )
                  .toDouble();
              return Center(
                child: SizedBox.square(
                  dimension: dimension,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: Colors.black,
                          child: _CoverCameraPreview(controller: controller),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _GridGuidePainter(cropFraction),
                          ),
                        ),
                        if (liveSamples != null && recognizedFaces != null)
                          _LiveRecognitionGrid(
                            samples: liveSamples!,
                            faces: recognizedFaces!,
                            colorScheme: colorScheme,
                            lockedFaces: lockedFaces,
                            cropFraction: cropFraction,
                            onToggleColorLock: onToggleColorLock,
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
              );
            },
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  recognizedFaces == null
                      ? '等待识别颜色；识别后可点击单格锁定。'
                      : '点击九格可锁定颜色，拍照后仍会保留。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const ValueKey('lock-current-colors'),
                onPressed: sampling ? null : onToggleAllColorLocks,
                icon: Icon(
                  lockedFaces.length == 9
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                ),
                label: Text(lockedFaces.length == 9 ? '全部解锁' : '锁定九格'),
              ),
            ],
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

class _LiveRecognitionGrid extends StatelessWidget {
  const _LiveRecognitionGrid({
    required this.samples,
    required this.faces,
    required this.colorScheme,
    required this.lockedFaces,
    required this.cropFraction,
    required this.onToggleColorLock,
  });

  final List<StickerSample> samples;
  final List<CubeFace> faces;
  final CubeColorScheme colorScheme;
  final Map<int, CubeFace> lockedFaces;
  final double cropFraction;
  final ValueChanged<int> onToggleColorLock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: cropFraction,
        heightFactor: cropFraction,
        child: GridView.builder(
          key: const ValueKey('live-recognition-grid'),
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final face = faces[index];
            final lowQuality = samples[index].isLowQuality;
            final locked = lockedFaces.containsKey(index);
            final colorIdentity = colorScheme.colorIdentityFor(face);
            final color = CubePalette.colorFor(colorIdentity);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggleColorLock(index),
              child: Container(
                key: ValueKey('live-recognition-$index'),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color, width: locked ? 3 : 2),
                ),
                child: Stack(
                  children: [
                    Align(
                      key: ValueKey('live-recognition-dot-$index'),
                      alignment: Alignment.center,
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x44000000), blurRadius: 2),
                          ],
                        ),
                        child: Text(
                          CubePalette.nameFor(colorIdentity).substring(0, 1),
                          style: TextStyle(
                            color: CubePalette.foregroundFor(colorIdentity),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (locked)
                      Positioned(
                        key: ValueKey('locked-recognition-$index'),
                        left: 5,
                        bottom: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.lock_rounded, size: 13),
                          ),
                        ),
                      ),
                    if (lowQuality && !locked)
                      const Positioned(
                        left: 5,
                        bottom: 5,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 17,
                          color: Colors.amber,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SamplePreview extends StatelessWidget {
  const _SamplePreview({
    required this.face,
    required this.colorScheme,
    required this.samples,
    required this.recognizedFaces,
    required this.lockedFaces,
    required this.onEditColor,
    required this.onRetry,
    required this.onAccept,
  });

  final CubeFace face;
  final CubeColorScheme colorScheme;
  final List<StickerSample> samples;
  final List<CubeFace> recognizedFaces;
  final Map<int, CubeFace> lockedFaces;
  final ValueChanged<int> onEditColor;
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
              _FaceInstruction(
                face: face,
                colorScheme: colorScheme,
                subtitle: '检查九格取色结果',
              ),
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
                    final recognizedFace = recognizedFaces[index];
                    final colorIdentity = colorScheme.colorIdentityFor(
                      recognizedFace,
                    );
                    return InkWell(
                      key: ValueKey('preview-sticker-$index'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: index == 4 ? null : () => onEditColor(index),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CubePalette.colorFor(colorIdentity),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sample.isLowQuality
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.outline,
                            width: sample.isLowQuality ? 3 : 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              CubePalette.nameFor(colorIdentity),
                              style: TextStyle(
                                color: CubePalette.foregroundFor(colorIdentity),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (sample.isLowQuality)
                              const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.warning_amber_rounded),
                                ),
                              ),
                            if (lockedFaces.containsKey(index))
                              Align(
                                key: ValueKey('locked-preview-$index'),
                                alignment: Alignment.bottomRight,
                                child: const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Icon(Icons.lock_rounded, size: 18),
                                ),
                              ),
                          ],
                        ),
                      ),
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
  const _FaceInstruction({
    required this.face,
    required this.colorScheme,
    required this.subtitle,
  });

  final CubeFace face;
  final CubeColorScheme colorScheme;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorIdentity = colorScheme.colorIdentityFor(face);
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: CubePalette.colorFor(colorIdentity),
          foregroundColor: CubePalette.foregroundFor(colorIdentity),
          child: Text(face.letter),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将${_faceName(face, colorScheme)}中心对准九格',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(subtitle),
              Text(
                '标准方向：'
                '${CubePalette.nameFor(colorScheme.colorIdentityFor(CubeFace.up))}中心 = U，'
                '${CubePalette.nameFor(colorScheme.colorIdentityFor(CubeFace.front))}中心 = F',
                style: const TextStyle(fontSize: 12),
              ),
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
  const _GridGuidePainter(this.cropFraction);

  final double cropFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = ScanPreviewGeometry.samplingRect(
      viewportSize: size,
      cropFraction: cropFraction,
    );
    final shade = Paint()..color = const Color(0x44000000);
    final shadedArea = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(guide);
    canvas.drawPath(shadedArea, shade);

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(guide, paint);
    for (var division = 1; division < 3; division++) {
      final x = guide.left + guide.width * division / 3;
      final y = guide.top + guide.height * division / 3;
      canvas.drawLine(Offset(x, guide.top), Offset(x, guide.bottom), paint);
      canvas.drawLine(Offset(guide.left, y), Offset(guide.right, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridGuidePainter oldDelegate) =>
      oldDelegate.cropFraction != cropFraction;
}

class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final ScanCameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sourceSize = controller.previewSize!;
        final fittedSize = ScanPreviewGeometry.coverSize(
          sourceSize: sourceSize,
          viewportSize: constraints.biggest,
        );
        return ClipRect(
          child: OverflowBox(
            minWidth: fittedSize.width,
            maxWidth: fittedSize.width,
            minHeight: fittedSize.height,
            maxHeight: fittedSize.height,
            child: SizedBox.fromSize(
              size: fittedSize,
              child: controller.buildPreview(),
            ),
          ),
        );
      },
    );
  }
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

String _faceName(CubeFace face, CubeColorScheme colorScheme) {
  final colorIdentity = colorScheme.colorIdentityFor(face);
  return '${CubePalette.nameFor(colorIdentity)} ${face.letter} 面';
}

String _orientationHint(CubeFace face, CubeColorScheme colorScheme) {
  final topEdgeFace = switch (face) {
    CubeFace.up => CubeFace.back,
    CubeFace.down => CubeFace.front,
    _ => CubeFace.up,
  };
  final colorIdentity = colorScheme.colorIdentityFor(topEdgeFace);
  return '${CubePalette.nameFor(colorIdentity)}边朝上';
}
