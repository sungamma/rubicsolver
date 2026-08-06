import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/scan/scan_page.dart';

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
}

Future<List<CameraDescription>> _noCameras() async => const [];
