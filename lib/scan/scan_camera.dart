import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ScanCameraFactory =
    ScanCameraController Function(CameraDescription description);

abstract interface class ScanCameraController {
  CameraDescription get description;

  bool get isInitialized;

  bool get isTakingPicture;

  Size? get previewSize;

  Widget buildPreview();

  Future<void> initialize();

  Future<void> dispose();

  Future<XFile> takePicture();
}

final class PluginScanCameraController implements ScanCameraController {
  PluginScanCameraController(CameraDescription description)
    : _controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

  final CameraController _controller;

  @override
  CameraDescription get description => _controller.description;

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  bool get isTakingPicture => _controller.value.isTakingPicture;

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
}
