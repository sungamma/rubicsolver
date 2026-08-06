import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/editor/cube_editor_page.dart';
import 'package:rubicsolver/scan/color_classifier.dart';
import 'package:rubicsolver/scan/color_math.dart';

void main() {
  testWidgets('renders all 54 stickers in a cube net', (tester) async {
    await tester.pumpWidget(_testApp(CubeState.solved()));

    for (var index = 0; index < 54; index++) {
      expect(find.byKey(ValueKey('sticker-$index')), findsOneWidget);
    }
  });

  testWidgets('lays out U above L F R B and D below', (tester) async {
    await tester.pumpWidget(_testApp(CubeState.solved()));

    final up = tester.getCenter(find.byKey(const ValueKey('sticker-4')));
    final right = tester.getCenter(find.byKey(const ValueKey('sticker-13')));
    final front = tester.getCenter(find.byKey(const ValueKey('sticker-22')));
    final down = tester.getCenter(find.byKey(const ValueKey('sticker-31')));
    final left = tester.getCenter(find.byKey(const ValueKey('sticker-40')));
    final back = tester.getCenter(find.byKey(const ValueKey('sticker-49')));

    expect(up.dy, lessThan(front.dy));
    expect(down.dy, greaterThan(front.dy));
    expect(left.dx, lessThan(front.dx));
    expect(front.dx, lessThan(right.dx));
    expect(right.dx, lessThan(back.dx));
    expect(left.dy, closeTo(front.dy, 0.1));
    expect(front.dy, closeTo(right.dy, 0.1));
    expect(right.dy, closeTo(back.dy, 0.1));
  });

  testWidgets('invalid state disables solving and a sticker can be corrected', (
    tester,
  ) async {
    final invalid = CubeState.solved().replaceSticker(0, CubeFace.front);
    await tester.pumpWidget(_testApp(invalid));

    expect(_solveButton(tester).onPressed, isNull);
    expect(find.textContaining('合法状态应为 9 枚'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('sticker-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上面颜色').last);
    await tester.pumpAndSettle();

    expect(_solveButton(tester).onPressed, isNotNull);
    expect(find.text('状态合法，可以开始求解。'), findsOneWidget);
  });

  testWidgets('center stickers stay locked', (tester) async {
    await tester.pumpWidget(_testApp(CubeState.solved()));

    await tester.tap(find.byKey(const ValueKey('sticker-4')));
    await tester.pump();

    expect(find.textContaining('中心贴纸不可编辑'), findsOneWidget);
    expect(find.text('上面颜色'), findsNothing);
  });

  testWidgets('valid state is delivered to the solve callback', (tester) async {
    CubeState? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CubeEditorPage(
          initialState: CubeState.solved(),
          onSolve: (state) => submitted = state,
        ),
      ),
    );

    await tester.tap(find.text('开始求解'));
    await tester.pump();

    expect(submitted, CubeState.solved());
  });

  testWidgets(
    'classification issues block solving until the face is rescanned',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CubeEditorPage(
            initialState: CubeState.solved(),
            classificationIssues: [
              ClassificationIssue(
                code: 'poor-sample-quality',
                message: '部分贴纸采样质量较差。',
              ),
            ],
          ),
        ),
      );

      expect(_solveButton(tester).onPressed, isNull);
      expect(find.textContaining('请重新扫描'), findsOneWidget);
    },
  );

  testWidgets('uses recognized center colors for stickers and color choices', (
    tester,
  ) async {
    final centerColors = {
      for (final face in CubeFace.values) face: RgbColor(20, 30, 40),
      CubeFace.up: RgbColor(12, 34, 56),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: CubeEditorPage(
          initialState: CubeState.solved(),
          centerColors: centerColors,
        ),
      ),
    );

    final sticker = tester.widget<Material>(
      find.byKey(const ValueKey('sticker-0')),
    );
    expect(sticker.color, const Color.fromARGB(255, 12, 34, 56));

    await tester.tap(find.byKey(const ValueKey('sticker-0')));
    await tester.pumpAndSettle();

    final upOption = find.widgetWithText(ListTile, '上面颜色');
    final avatar = tester.widget<CircleAvatar>(
      find.descendant(of: upOption, matching: find.byType(CircleAvatar)),
    );
    expect(avatar.backgroundColor, const Color.fromARGB(255, 12, 34, 56));
  });
}

Widget _testApp(CubeState state) {
  return MaterialApp(home: CubeEditorPage(initialState: state));
}

FilledButton _solveButton(WidgetTester tester) {
  return tester.widget<FilledButton>(find.widgetWithText(FilledButton, '开始求解'));
}
