import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/app/rubik_solver_app.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/editor/cube_editor_page.dart';
import 'package:rubicsolver/scan/scan_page.dart';
import 'package:rubicsolver/update/update_service.dart';
import 'package:rubicsolver/update/version_number.dart';

void main() {
  testWidgets('home exposes scan, manual entry and local privacy promise', (
    tester,
  ) async {
    await tester.pumpWidget(
      const RubikSolverApp(enableStartupUpdateCheck: false),
    );

    expect(find.text('开始扫描'), findsOneWidget);
    expect(find.text('手动录入'), findsOneWidget);
    expect(find.text('配置六面配色'), findsOneWidget);
    expect(find.textContaining('照片仅在本机处理'), findsOneWidget);
    expect(find.textContaining('Kociemba'), findsOneWidget);
  });

  testWidgets('applies one configured scheme to scan and manual entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const RubikSolverApp(enableStartupUpdateCheck: false),
    );

    await tester.tap(find.text('配置六面配色'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scheme-face-U')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('黄色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    final scanButton = find
        .ancestor(
          of: find.text('开始扫描'),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString().contains('FilledButton'),
          ),
        )
        .last;
    final scanButtonWidget = tester.widget(scanButton) as dynamic;
    (scanButtonWidget.onPressed as VoidCallback)();
    await tester.pump(const Duration(seconds: 1));
    final scanFinder = find.byType(ScanPage, skipOffstage: false);
    final scanPage = tester.widget<ScanPage>(scanFinder);
    expect(scanPage.colorScheme.colorIdentityFor(CubeFace.up), CubeFace.down);

    Navigator.of(tester.element(scanFinder)).pop();
    await tester.pump(const Duration(milliseconds: 400));
    final manualButton = find
        .ancestor(
          of: find.text('手动录入'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.runtimeType.toString().contains('OutlinedButton'),
          ),
        )
        .last;
    final manualButtonWidget = tester.widget(manualButton) as dynamic;
    (manualButtonWidget.onPressed as VoidCallback)();
    await tester.pumpAndSettle();
    final editor = tester.widget<CubeEditorPage>(
      find.byType(CubeEditorPage, skipOffstage: false),
    );
    expect(editor.colorScheme, scanPage.colorScheme);
  });

  testWidgets('manual entry opens the correction editor', (tester) async {
    await tester.pumpWidget(
      const RubikSolverApp(enableStartupUpdateCheck: false),
    );

    await tester.tap(find.text('手动录入'));
    await tester.pumpAndSettle();

    expect(find.text('校验与纠错'), findsOneWidget);
    expect(find.text('开始求解'), findsOneWidget);
  });

  testWidgets('settings opens the author and update page', (tester) async {
    await tester.pumpWidget(
      const RubikSolverApp(enableStartupUpdateCheck: false),
    );

    await tester.tap(find.byTooltip('设置与关于'));
    await tester.pumpAndSettle();

    expect(find.text('关于与更新'), findsOneWidget);
    expect(find.text('Wei Xu'), findsOneWidget);
    expect(find.text('sungamma@gmail.com'), findsOneWidget);
    final pageScroll = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(pageScroll, findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(
        '核心库：cuber 0.4.0（tiagohm/cuber，MIT License）。'
        '许可证全文见 LICENSES/cuber.txt。',
      ),
      200,
      scrollable: pageScroll,
    );
    expect(find.textContaining('cuber 0.4.0'), findsWidgets);
    expect(find.textContaining('LICENSES/cuber.txt'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text(
        '照片仅在本机处理，用于完成采样、颜色识别和校验，不会上传到服务器。'
        '网络仅用于版本检查和用户确认后的 APK 下载。',
      ),
      200,
      scrollable: pageScroll,
    );
    expect(find.textContaining('照片仅在本机处理'), findsWidgets);

    await tester.drag(pageScroll, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('手动检查更新'), findsOneWidget);
  });

  testWidgets('startup update check does not block the home screen', (
    tester,
  ) async {
    final service = _PendingUpdateService();

    await tester.pumpWidget(RubikSolverApp(updateService: service));
    await tester.pump();

    expect(find.text('开始扫描'), findsOneWidget);
    expect(service.checkCount, 1);

    service.complete();
    await tester.pump();
  });

  testWidgets('startup update check shows the update prompt', (tester) async {
    final service = _ImmediateUpdateService(
      UpdateCheckResult.updateAvailable(_updateInfo()),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(RubikSolverApp(updateService: service));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.textContaining('启动自动更新说明'), findsOneWidget);
    expect(find.text('开始扫描'), findsOneWidget);

    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
  });

  testWidgets('startup update failure stays silent', (tester) async {
    final service = _ImmediateUpdateService(
      const UpdateCheckResult.failed('offline'),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(RubikSolverApp(updateService: service));
    await tester.pumpAndSettle();

    expect(find.text('开始扫描'), findsOneWidget);
    expect(find.text('发现新版本'), findsNothing);
  });
}

UpdateInfo _updateInfo() {
  return UpdateInfo(
    currentVersion: VersionNumber.parse('1.1.0+2'),
    latestVersion: VersionNumber.parse('1.1.1+3'),
    assetName: 'rubicsolver.apk',
    downloadUrl: Uri.parse('https://zl.870413.xyz:5443/rubicsolver.apk'),
    releaseNotes: '启动自动更新说明',
  );
}

class _ImmediateUpdateService extends UpdateService {
  _ImmediateUpdateService(this.result);

  final UpdateCheckResult result;

  @override
  Future<UpdateCheckResult> checkForUpdates({bool force = false}) async {
    return result;
  }
}

class _PendingUpdateService extends UpdateService {
  final _result = Completer<UpdateCheckResult>();
  int checkCount = 0;

  @override
  Future<UpdateCheckResult> checkForUpdates({bool force = false}) {
    checkCount++;
    return _result.future;
  }

  void complete() {
    _result.complete(const UpdateCheckResult.upToDate());
  }
}
