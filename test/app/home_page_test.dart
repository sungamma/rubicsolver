import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/app/rubik_solver_app.dart';

void main() {
  testWidgets('home exposes scan, manual entry and local privacy promise', (
    tester,
  ) async {
    await tester.pumpWidget(const RubikSolverApp());

    expect(find.text('开始扫描'), findsOneWidget);
    expect(find.text('手动录入'), findsOneWidget);
    expect(find.textContaining('照片仅在本机处理'), findsOneWidget);
    expect(find.textContaining('Kociemba'), findsOneWidget);
  });

  testWidgets('manual entry opens the correction editor', (tester) async {
    await tester.pumpWidget(const RubikSolverApp());

    await tester.tap(find.text('手动录入'));
    await tester.pumpAndSettle();

    expect(find.text('校验与纠错'), findsOneWidget);
    expect(find.text('开始求解'), findsOneWidget);
  });
}
