import 'dart:math' as math;

import 'package:flutter/widgets.dart';

abstract final class ScanPreviewGeometry {
  static Size coverSize({
    required Size sourceSize,
    required Size viewportSize,
  }) {
    if (sourceSize.isEmpty || viewportSize.isEmpty) {
      throw ArgumentError('预览与视口尺寸必须大于零');
    }
    final scale = math.max(
      viewportSize.width / sourceSize.width,
      viewportSize.height / sourceSize.height,
    );
    return Size(sourceSize.width * scale, sourceSize.height * scale);
  }

  static Rect samplingRect({
    required Size viewportSize,
    required double cropFraction,
  }) {
    if (viewportSize.isEmpty) {
      throw ArgumentError.value(viewportSize, 'viewportSize', '必须大于零');
    }
    if (cropFraction <= 0 || cropFraction > 1) {
      throw ArgumentError.value(cropFraction, 'cropFraction', '必须位于 0 到 1');
    }
    final side =
        math.min(viewportSize.width, viewportSize.height) * cropFraction;
    return Rect.fromCenter(
      center: viewportSize.center(Offset.zero),
      width: side,
      height: side,
    );
  }
}
