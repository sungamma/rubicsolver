import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/playback/cube_3d_view.dart';
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
          moves: [SolutionMove('R'), SolutionMove("U'")],
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
          moves: [SolutionMove('R'), SolutionMove("U'")],
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

  testWidgets('current formula chip uses the primary color treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolutionPage(
          initialState: CubeState.solved(),
          moves: [SolutionMove('R'), SolutionMove("U'")],
        ),
      ),
    );

    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pump();

    final chip = tester.widget<ActionChip>(
      find.descendant(
        of: find.byKey(const ValueKey('solution-move-0')),
        matching: find.byType(ActionChip),
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(SolutionPage)),
    ).colorScheme;
    expect(chip.backgroundColor, scheme.primaryContainer);
  });

  testWidgets('playback uses a three-dimensional cube canvas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolutionPage(
          initialState: CubeState.solved(),
          moves: [SolutionMove('R'), SolutionMove('U')],
        ),
      ),
    );

    expect(find.byType(Cube3DView), findsOneWidget);
    expect(find.byKey(const ValueKey('sticker-0')), findsNothing);
    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pump();

    final canvas = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('cube-3d-canvas')),
    );
    final painter = canvas.painter! as Cube3DPainter;
    expect(painter.state, isNot(CubeState.solved()));
    expect(painter.activeFace, CubeFace.right);
  });

  testWidgets('completed playback clears action highlighting and shows check', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolutionPage(
          initialState: CubeState.solved(),
          moves: [SolutionMove('R')],
        ),
      ),
    );

    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pump();

    expect(find.text('复原完成'), findsOneWidget);
    expect(find.byIcon(Icons.rotate_right), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
    final canvas = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('cube-3d-canvas')),
    );
    final painter = canvas.painter! as Cube3DPainter;
    expect(painter.activeFace, isNull);
  });

  testWidgets('shows a counter-clockwise turn arrow for inverse moves', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolutionPage(
          initialState: CubeState.solved(),
          moves: [SolutionMove("R'")],
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('turn-arrow-counter-clockwise')),
      findsOneWidget,
    );
  });

  testWidgets('offers a 2.4 second slow-motion playback option', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SolutionPage(
          initialState: CubeState.solved(),
          moves: [SolutionMove('R')],
        ),
      ),
    );

    final speedMenu = find.byType(DropdownButton<Duration>);
    await tester.ensureVisible(speedMenu);
    await tester.pump();
    await tester.tap(speedMenu);
    await tester.pump();
    expect(find.text('慢动作 · 2.4 秒'), findsOneWidget);
  });

  testWidgets('320dp playback controls keep Chinese labels on one line', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: SolutionPage(
          initialState: CubeState.solved(),
          moves: [SolutionMove('R'), SolutionMove('U')],
        ),
      ),
    );
    await tester.ensureVisible(find.text('上一步'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('上一步')).height, lessThan(25));
    expect(tester.getSize(find.text('下一步')).height, lessThan(25));
  });
}
