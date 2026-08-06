import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/scan/scan_preview_geometry.dart';

void main() {
  test('cover size center-crops a landscape 4:3 preview into a square', () {
    expect(
      ScanPreviewGeometry.coverSize(
        sourceSize: const Size(400, 300),
        viewportSize: const Size.square(300),
      ),
      const Size(400, 300),
    );
  });

  test('cover size center-crops a portrait 4:3 preview into a square', () {
    expect(
      ScanPreviewGeometry.coverSize(
        sourceSize: const Size(300, 400),
        viewportSize: const Size.square(300),
      ),
      const Size(300, 400),
    );
  });

  test('sampling guide uses cropFraction and stays centered', () {
    expect(
      ScanPreviewGeometry.samplingRect(
        viewportSize: const Size.square(300),
        cropFraction: 0.8,
      ),
      const Rect.fromLTWH(30, 30, 240, 240),
    );
    expect(
      ScanPreviewGeometry.samplingRect(
        viewportSize: const Size(400, 300),
        cropFraction: 0.6,
      ),
      const Rect.fromLTWH(110, 60, 180, 180),
    );
  });
}
