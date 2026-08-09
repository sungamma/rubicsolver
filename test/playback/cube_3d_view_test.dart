import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/playback/cube_3d_view.dart';
import 'package:rubicsolver/solver/cube_solver.dart';
import 'package:rubicsolver/solver/solution_move.dart';

void main() {
  test('culls hidden body faces and stickers before painting', () {
    final painter = Cube3DPainter(
      previousState: CubeState.solved(),
      state: CubeState.solved(),
      animationValue: 1,
      activeFace: null,
      accentColor: Colors.blue,
    );
    final canvas = TestRecordingCanvas();

    painter.paint(canvas, const Size(320, 280));

    final drawnPaths = canvas.invocations.where(
      (recorded) => recorded.invocation.memberName == #drawPath,
    );
    expect(drawnPaths, hasLength(60));
  });

  testWidgets('renders an accessible three-dimensional cube canvas', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 280,
            child: Cube3DView(
              state: CubeState.solved(),
              move: SolutionMove('R'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Cube3DView), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('三维魔方.*右面')), findsOneWidget);
    final canvas = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('cube-3d-canvas')),
    );
    final painter = canvas.painter! as Cube3DPainter;
    expect(painter.state, CubeState.solved());
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('animates to the latest cube state', (tester) async {
    final solved = CubeState.solved();
    final turned = CubeSolver.applyAlgorithm(solved, 'R');

    Widget app(CubeState state) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 280,
          child: Cube3DView(
            key: const ValueKey('animated-cube'),
            state: state,
            move: SolutionMove('R'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(solved));
    await tester.pumpWidget(app(turned));
    await tester.pump(const Duration(milliseconds: 320));

    final canvas = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('cube-3d-canvas')),
    );
    final painter = canvas.painter! as Cube3DPainter;
    expect(painter.state, turned);
    expect(painter.animationValue, 1);
  });

  testWidgets(
    'dragging changes the view and reset restores the standard angle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 280,
              child: Cube3DView(state: CubeState.solved()),
            ),
          ),
        ),
      );

      Cube3DPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('cube-3d-canvas')),
                  )
                  .painter!
              as Cube3DPainter;

      expect(painter().yaw, defaultCubeYaw);
      expect(painter().pitch, defaultCubePitch);

      await tester.drag(
        find.byKey(const ValueKey('cube-3d-canvas')),
        const Offset(80, -40),
      );
      await tester.pump();

      expect(painter().yaw, isNot(defaultCubeYaw));
      expect(painter().pitch, isNot(defaultCubePitch));

      await tester.tap(find.byKey(const ValueKey('reset-cube-view')));
      await tester.pump();

      expect(painter().yaw, defaultCubeYaw);
      expect(painter().pitch, defaultCubePitch);
    },
  );
}
