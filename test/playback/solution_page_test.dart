import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/playback/solution_page.dart';
import 'package:rubicsolver/solver/solution_move.dart';

void main() {
  testWidgets('shows the complete formula and advances one move', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolutionPage(
          initialState: CubeState.solved(),
          moves: const [SolutionMove('R'), SolutionMove("U'")],
        ),
      ),
    );

    expect(find.text('R'), findsOneWidget);
    expect(find.text("U'"), findsOneWidget);
    expect(find.text('准备开始'), findsOneWidget);
    expect(find.text('步骤 0/2'), findsOneWidget);

    final nextButton = find.text('下一步');
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pump();

    expect(find.text('步骤 1/2'), findsOneWidget);
    expect(find.textContaining('正对右面看'), findsOneWidget);
  });

  testWidgets('formula chips seek and play button toggles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolutionPage(
          initialState: CubeState.solved(),
          moves: const [SolutionMove('R'), SolutionMove("U'")],
        ),
      ),
    );

    final secondMove = find.byKey(const ValueKey('solution-move-1'));
    await tester.ensureVisible(secondMove);
    await tester.tap(secondMove);
    await tester.pump();
    expect(find.text('步骤 2/2'), findsOneWidget);

    await tester.tap(find.text('播放'));
    await tester.pump();
    expect(find.text('暂停'), findsOneWidget);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('播放'), findsOneWidget);
  });
}
