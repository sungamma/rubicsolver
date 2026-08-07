import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_frame_sampler.dart';

typedef ScanCameraFactory =
    ScanCameraController Function(CameraDescription description);

abstract interface class ScanCameraController {
  CameraDescription get description;

  bool get isInitialized;

  bool get isTakingPicture;

  bool get isStreamingImages;

  Size? get previewSize;

  Widget buildPreview();

  Future<void> initialize();

  Future<void> dispose();

  Future<XFile> takePicture();

  Future<void> startImageStream(ValueChanged<ScanCameraFrame> onFrame);

  Future<void> stopImageStream();
}

final class PluginScanCameraController implements ScanCameraController {
  PluginScanCameraController(CameraDescription description)
    : _controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

  final CameraController _controller;

  @override
  CameraDescription get description => _controller.description;

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  bool get isTakingPicture => _controller.value.isTakingPicture;

  @override
  bool get isStreamingImages => _controller.value.isStreamingImages;

  @override
  Size? get previewSize {
    final size = _controller.value.previewSize;
    if (size == null) {
      return null;
    }
    final orientation = _controller.value.deviceOrientation;
    final landscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    return landscape ? size : Size(size.height, size.width);
  }

  @override
  Widget buildPreview() => CameraPreview(_controller);

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Future<XFile> takePicture() => _controller.takePicture();

  @override
  Future<void> startImageStream(ValueChanged<ScanCameraFrame> onFrame) {
    return _controller.startImageStream((image) {
      final pixelFormat = switch (image.format.group) {
        ImageFormatGroup.bgra8888 => ScanCameraPixelFormat.bgra8888,
        ImageFormatGroup.yuv420 => ScanCameraPixelFormat.yuv420,
        _ => null,
      };
      if (pixelFormat == null) {
        return;
      }
      onFrame(
        ScanCameraFrame(
          width: image.width,
          height: image.height,
          format: pixelFormat,
          planes: [
            for (var index = 0; index < image.planes.length; index++)
              ScanCameraPlane(
                bytes: image.planes[index].bytes,
                bytesPerRow: image.planes[index].bytesPerRow,
                bytesPerPixel:
                    image.planes[index].bytesPerPixel ??
                    (pixelFormat == ScanCameraPixelFormat.bgra8888 ? 4 : 1),
              ),
          ],
          clockwiseQuarterTurns: _clockwiseQuarterTurns,
        ),
      );
    });
  }

  @override
  Future<void> stopImageStream() async {
    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
  }

  int get _clockwiseQuarterTurns {
    final deviceDegrees = switch (_controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final sensorDegrees = _controller.description.sensorOrientation;
    final rotationDegrees =
        _controller.description.lensDirection == CameraLensDirection.front
        ? (sensorDegrees + deviceDegrees) % 360
        : (sensorDegrees - deviceDegrees + 360) % 360;
    return (rotationDegrees ~/ 90) % 4;
  }
}
