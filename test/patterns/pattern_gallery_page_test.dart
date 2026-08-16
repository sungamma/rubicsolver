import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_color_scheme.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/editor/cube_net.dart';
import 'package:rubicsolver/patterns/cube_pattern_catalog.dart';
import 'package:rubicsolver/patterns/pattern_gallery_page.dart';
import 'package:rubicsolver/playback/cube_3d_view.dart';
import 'package:rubicsolver/playback/solution_page.dart';

void main() {
  testWidgets('shows classics and opens the selected pattern', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PatternGalleryPage()));

    for (final pattern in CubePatternCatalog.classics.patterns) {
      final patternCard = find.byKey(ValueKey('pattern-card-${pattern.id}'));
      expect(patternCard, findsOneWidget);
      expect(
        find.descendant(of: patternCard, matching: find.text(pattern.name)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: patternCard,
          matching: find.text('${pattern.moveCount} 步'),
        ),
        findsOneWidget,
      );
    }

    final checkerboard = CubePatternCatalog.classics.patterns[1];
    final card = find.byKey(const ValueKey('pattern-card-checkerboard'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    final page = tester.widget<SolutionPage>(find.byType(SolutionPage));
    expect(page.initialState, CubeState.solved());
    expect(page.moves, checkerboard.moves);
    expect(page.title, '棋盘格演示');
    expect(page.completionText, '花式完成');
    expect(page.formulaTitle, '完整拼法');
  });

  testWidgets('keeps one color scheme in previews and playback', (
    tester,
  ) async {
    final scheme = CubeColorScheme.standard.swapColor(
      CubeFace.up,
      CubeFace.down,
    );
    await tester.pumpWidget(
      MaterialApp(home: PatternGalleryPage(colorScheme: scheme)),
    );

    final preview = tester.widget<CubeNet>(
      find.byKey(const ValueKey('pattern-preview-six-spots')),
    );
    expect(preview.colorScheme, scheme);

    await tester.tap(find.byKey(const ValueKey('pattern-card-six-spots')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Cube3DView>(find.byType(Cube3DView)).colorScheme,
      scheme,
    );
  });

  testWidgets('uses one column at 320dp without overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: PatternGalleryPage()));

    final first = find.byKey(const ValueKey('pattern-card-six-spots'));
    final second = find.byKey(const ValueKey('pattern-card-checkerboard'));
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses two columns at 700dp', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: PatternGalleryPage()));

    final first = tester.getTopLeft(
      find.byKey(const ValueKey('pattern-card-six-spots')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('pattern-card-checkerboard')),
    );
    expect(second.dy, closeTo(first.dy, 0.1));
    expect(second.dx, greaterThan(first.dx));
    expect(tester.takeException(), isNull);
  });
}
