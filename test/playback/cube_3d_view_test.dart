import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/playback/cube_3d_view.dart';
import 'package:rubicsolver/solver/cube_solver.dart';
import 'package:rubicsolver/solver/solution_move.dart';

void main() {
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
}
