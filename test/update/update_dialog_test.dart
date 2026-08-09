import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/update/update_dialog.dart';
import 'package:rubicsolver/update/update_service.dart';
import 'package:rubicsolver/update/version_number.dart';

void main() {
  testWidgets('shows release notes and downloads the selected update', (
    tester,
  ) async {
    final service = _FakeUpdateService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUpdateDialog(
              context: context,
              service: service,
              update: _updateInfo(notes: '# 新功能\n\n启动自动更新'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.textContaining('启动自动更新'), findsOneWidget);
    expect(find.text('当前版本 1.1.0+2'), findsOneWidget);
    expect(find.text('最新版本 1.1.1+3'), findsOneWidget);

    await tester.tap(find.text('下载并安装'));
    await tester.pump();

    expect(service.downloadCalls, 1);
    expect(find.text('50%'), findsOneWidget);

    service.finishDownload();
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsNothing);
  });

  testWidgets('keeps the dialog open and shows download errors', (
    tester,
  ) async {
    final service = _FakeUpdateService(error: StateError('服务器不可用'));
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUpdateDialog(
              context: context,
              service: service,
              update: _updateInfo(notes: '说明'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载并安装'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('服务器不可用'), findsOneWidget);
    expect(find.text('下载并安装'), findsOneWidget);
  });

  testWidgets('prevents back navigation while the APK is downloading', (
    tester,
  ) async {
    final service = _FakeUpdateService();
    addTearDown(service.finishDownload);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUpdateDialog(
              context: context,
              service: service,
              update: _updateInfo(notes: '说明'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载并安装'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);

    service.finishDownload();
    await tester.pumpAndSettle();
  });
}

UpdateInfo _updateInfo({required String notes}) {
  return UpdateInfo(
    currentVersion: VersionNumber.parse('1.1.0+2'),
    latestVersion: VersionNumber.parse('1.1.1+3'),
    assetName: 'rubicsolver.apk',
    downloadUrl: Uri.parse('https://zl.870413.xyz:5443/rubicsolver.apk'),
    releaseNotes: notes,
  );
}

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService({this.error});

  final Object? error;
  final _downloadCompleter = Completer<void>();
  int downloadCalls = 0;

  @override
  Future<String> downloadAndInstall(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    downloadCalls++;
    onProgress?.call(0.5);
    if (error != null) throw error!;
    await _downloadCompleter.future;
    onProgress?.call(1);
    return 'rubicsolver.apk';
  }

  void finishDownload() {
    if (!_downloadCompleter.isCompleted) _downloadCompleter.complete();
  }
}
