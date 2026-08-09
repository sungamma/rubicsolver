import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/app/rubik_solver_app.dart';
import 'package:rubicsolver/update/update_service.dart';

void main() {
  testWidgets('home exposes scan, manual entry and local privacy promise', (
    tester,
  ) async {
    await tester.pumpWidget(
      const RubikSolverApp(enableStartupUpdateCheck: false),
    );

    expect(find.text('开始扫描'), findsOneWidget);
    expect(find.text('手动录入'), findsOneWidget);
    expect(find.textContaining('照片仅在本机处理'), findsOneWidget);
    expect(find.textContaining('Kociemba'), findsOneWidget);
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
        '网络仅用于可选的版本检查和 APK 下载。',
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
