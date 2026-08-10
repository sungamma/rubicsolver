import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/app/cube_color_scheme_dialog.dart';
import 'package:rubicsolver/cube/cube_color_scheme.dart';
import 'package:rubicsolver/cube/cube_face.dart';
import 'package:rubicsolver/cube/cube_palette.dart';

void main() {
  testWidgets('shows all six logical faces with their current colors', (
    tester,
  ) async {
    await tester.pumpWidget(_dialogLauncher());

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    for (final face in CubeFace.values) {
      expect(
        find.byKey(ValueKey('scheme-face-${face.letter}')),
        findsOneWidget,
      );
      final swatch = tester.widget<CircleAvatar>(
        find.byKey(ValueKey('scheme-swatch-${face.letter}')),
      );
      expect(swatch.backgroundColor, CubePalette.colorFor(face));
    }
    expect(find.text('白色'), findsOneWidget);
    expect(find.text('黄色'), findsOneWidget);
  });

  testWidgets('choosing an occupied color swaps the two faces', (tester) async {
    CubeColorScheme? result;
    await tester.pumpWidget(
      _dialogLauncher(onComplete: (value) => result = value),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scheme-face-U')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('黄色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result!.colorIdentityFor(CubeFace.up), CubeFace.down);
    expect(result!.colorIdentityFor(CubeFace.down), CubeFace.up);
  });

  testWidgets('cancel returns no scheme', (tester) async {
    CubeColorScheme? result = CubeColorScheme.standard;
    await tester.pumpWidget(
      _dialogLauncher(onComplete: (value) => result = value),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('restore default replaces the dialog draft', (tester) async {
    CubeColorScheme? result;
    final initial = CubeColorScheme.standard.swapColor(
      CubeFace.up,
      CubeFace.down,
    );
    await tester.pumpWidget(
      _dialogLauncher(
        initialScheme: initial,
        onComplete: (value) => result = value,
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认'));
    await tester.pump();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(result, CubeColorScheme.standard);
  });
}

Widget _dialogLauncher({
  CubeColorScheme initialScheme = CubeColorScheme.standard,
  ValueChanged<CubeColorScheme?>? onComplete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await showCubeColorSchemeDialog(
              context,
              initialScheme: initialScheme,
            );
            onComplete?.call(result);
          },
          child: const Text('打开'),
        ),
      ),
    ),
  );
}
