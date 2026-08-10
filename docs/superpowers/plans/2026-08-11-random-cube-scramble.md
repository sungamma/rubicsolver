# 随机魔方状态实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 从主页生成 18～25 步合法随机打乱，展示对应公式和魔方状态，并继续使用现有编辑与求解流程。

**架构：** 在求解模块新增纯 Dart `CubeScrambler`，通过现有 `CubeSolver.applyMoves` 从复原态得到天然合法的状态。主页把同一个不可变 `CubeScramble` 的状态和动作列表传给编辑器；编辑器只把动作作为来源说明显示，不改变求解输入。

**技术栈：** Dart 3 `dart:math`、Flutter Material、flutter_test、现有 `CubeState`/`SolutionMove`/`CubeSolver`、Android Release 部署脚本。

---

## 文件结构

- 创建 `lib/solver/cube_scrambler.dart`：定义随机公式生成器及公式/状态一致的不可变结果。
- 创建 `test/solver/cube_scrambler_test.dart`：覆盖长度、格式、相邻面、合法性、可重复测试和不可变性。
- 修改 `lib/app/home_page.dart`、`test/app/home_page_test.dart`：增加随机入口，传递状态、公式和当前配色。
- 修改 `lib/editor/cube_editor_page.dart`、`test/editor/cube_editor_page_test.dart`：显示紧凑随机打乱卡片并保持编辑/求解行为。
- 修改 `pubspec.yaml`、`assets/docs/update_notes.md`：发布 `1.1.3+5`。

### 任务 1：实现合法随机打乱生成器

**文件：**
- 创建：`lib/solver/cube_scrambler.dart`
- 创建：`test/solver/cube_scrambler_test.dart`

- [ ] **步骤 1：编写失败的生成器测试**

```dart
test('generates 18 to 25 moves without repeating a face', () {
  final scrambler = CubeScrambler(random: Random(7));
  for (var sample = 0; sample < 100; sample++) {
    final scramble = scrambler.generate();
    expect(scramble.moves.length, inInclusiveRange(18, 25));
    for (var index = 1; index < scramble.moves.length; index++) {
      expect(scramble.moves[index].face,
          isNot(scramble.moves[index - 1].face));
    }
  }
});

test('keeps formula and generated state consistent and legal', () {
  final scramble = CubeScrambler(random: Random(11)).generate();
  expect(
    scramble.state,
    CubeSolver.applyMoves(CubeState.solved(), scramble.moves),
  );
  expect(const CubeValidator().validate(scramble.state).isValid, isTrue);
  expect(() => scramble.moves.clear(), throwsUnsupportedError);
});
```

再验证动作只使用 `U/R/F/D/L/B` 和空后缀、`'`、`2`，并验证相同随机种子产生相同公式。

- [ ] **步骤 2：运行测试确认红灯**

运行：`flutter test test/solver/cube_scrambler_test.dart`

预期：FAIL，提示 `cube_scrambler.dart` 或类型不存在。

- [ ] **步骤 3：实现最小生成器**

```dart
class CubeScramble {
  factory CubeScramble.fromMoves(Iterable<SolutionMove> moves) {
    final immutableMoves = List<SolutionMove>.unmodifiable(moves);
    return CubeScramble._(
      immutableMoves,
      CubeSolver.applyMoves(CubeState.solved(), immutableMoves),
    );
  }

  const CubeScramble._(this.moves, this.state);
  final List<SolutionMove> moves;
  final CubeState state;
  String get notation => moves.map((move) => move.notation).join(' ');
}

class CubeScrambler {
  CubeScrambler({Random? random}) : _random = random ?? Random();
  final Random _random;

  CubeScramble generate() {
    final length = 18 + _random.nextInt(8);
    CubeFace? previousFace;
    final moves = <SolutionMove>[];
    while (moves.length < length) {
      final face = CubeFace.values[_random.nextInt(CubeFace.values.length)];
      if (face == previousFace) continue;
      const suffixes = ['', "'", '2'];
      moves.add(SolutionMove('${face.letter}${suffixes[_random.nextInt(3)]}'));
      previousFace = face;
    }
    return CubeScramble.fromMoves(moves);
  }
}
```

- [ ] **步骤 4：运行生成器测试确认绿灯**

运行：`flutter test test/solver/cube_scrambler_test.dart`

预期：全部通过。

- [ ] **步骤 5：提交生成器**

```bash
git add lib/solver/cube_scrambler.dart test/solver/cube_scrambler_test.dart
git commit -m "feat: generate legal random cube scrambles (task 1/3)"
```

### 任务 2：添加主页入口和编辑器公式展示

**文件：**
- 修改：`lib/app/home_page.dart`
- 修改：`test/app/home_page_test.dart`
- 修改：`lib/editor/cube_editor_page.dart`
- 修改：`test/editor/cube_editor_page_test.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

```dart
testWidgets('random cube opens one matching state and formula', (tester) async {
  final scrambler = CubeScrambler(random: Random(17));
  await tester.pumpWidget(MaterialApp(home: HomePage(scrambler: scrambler)));
  await tester.tap(find.text('随机魔方'));
  await tester.pumpAndSettle();
  final editor = tester.widget<CubeEditorPage>(find.byType(CubeEditorPage));
  expect(editor.scrambleMoves.length, inInclusiveRange(18, 25));
  expect(
    editor.initialState,
    CubeSolver.applyMoves(CubeState.solved(), editor.scrambleMoves),
  );
});
```

编辑器测试传入固定动作 `R U' F2`，断言“随机打乱”和完整公式存在；点击非中心贴纸改色后公式仍存在；空动作列表不显示卡片；320dp 宽度无 overflow。

- [ ] **步骤 2：运行 Widget 测试确认红灯**

运行：`flutter test test/app/home_page_test.dart test/editor/cube_editor_page_test.dart`

预期：FAIL，主页入口和 `scrambleMoves` 尚不存在。

- [ ] **步骤 3：主页生成并传递一次打乱结果**

```dart
class HomePage extends StatefulWidget {
  HomePage({super.key, this.updateService, CubeScrambler? scrambler})
      : scrambler = scrambler ?? CubeScrambler();
  final CubeScrambler scrambler;
}

void _openRandomCube(BuildContext context) {
  final scramble = widget.scrambler.generate();
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => CubeEditorPage(
      initialState: scramble.state,
      scrambleMoves: scramble.moves,
      colorScheme: _colorScheme,
    ),
  ));
}
```

在现有按钮区增加带 `Icons.shuffle` 的“随机魔方”按钮；宽屏三按钮并排，窄屏按扫描、随机、手动顺序纵向排列。

- [ ] **步骤 4：编辑器显示紧凑来源卡片**

```dart
final List<SolutionMove> scrambleMoves;

if (widget.scrambleMoves.isNotEmpty) ...[
  Card(
    key: const ValueKey('random-scramble-card'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('随机打乱'),
          const SizedBox(height: 6),
          SelectableText(
            widget.scrambleMoves.map((move) => move.notation).join(' '),
            key: const ValueKey('random-scramble-formula'),
          ),
        ],
      ),
    ),
  ),
  const SizedBox(height: 8),
]
```

构造函数将传入动作复制为不可变列表；卡片放在 `CubeNet` 上方，编辑状态不修改它。

- [ ] **步骤 5：运行 Widget 测试确认绿灯**

运行：`flutter test test/app/home_page_test.dart test/editor/cube_editor_page_test.dart`

预期：全部通过且无 overflow。

- [ ] **步骤 6：提交用户流程**

```bash
git add lib/app/home_page.dart lib/editor/cube_editor_page.dart test/app/home_page_test.dart test/editor/cube_editor_page_test.dart
git commit -m "feat: open random cube states from home (task 2/3)"
```

### 任务 3：升级版本、验证并部署

**文件：**
- 修改：`pubspec.yaml`
- 修改：`assets/docs/update_notes.md`

- [ ] **步骤 1：升级版本并添加说明**

```yaml
version: 1.1.3+5
```

```markdown
## 1.1.3

- 主页新增随机魔方入口，可生成 18～25 步合法打乱并同时显示完整公式和对应状态，无需扫描即可进入求解。
```

- [ ] **步骤 2：执行完整质量检查**

运行：`dart format --output=none --set-exit-if-changed lib test`

运行：`flutter analyze`

运行：`flutter test`

预期：格式无改动、静态分析无问题、全部测试通过。

- [ ] **步骤 3：提交版本**

```bash
git add pubspec.yaml assets/docs/update_notes.md
git commit -m "chore: release version 1.1.3"
```

- [ ] **步骤 4：构建并部署 Android Release**

运行：`cmd /c deploy.bat android`

预期：构建 `1.1.3+5` 正式签名 APK，并发布版本、APK 和更新说明到现有服务器。

- [ ] **步骤 5：核对线上发布物**

使用应用相同的 Basic Authorization 请求服务器文件，验证版本为 `1.1.3+5`、说明包含随机入口、本地与远程 APK SHA-256 一致、签名证书 SHA-256 为 `CB0ED095CB12C804FB7D4BC6F57090CD79B3DD20E4EE43A3A56A196FEFA9DAE6`。

## 自检结果

- 规格覆盖：随机长度、动作约束、公式/状态一致性、合法性、主页入口、当前配色、编辑保留、窄屏、版本和部署均有对应任务。
- 类型一致性：统一使用 `CubeScramble.fromMoves`、`CubeScrambler.generate`、`scrambleMoves` 和 `notation`。
- 范围控制：不增加重新随机、步数配置、随机贴纸或独立预览页。
