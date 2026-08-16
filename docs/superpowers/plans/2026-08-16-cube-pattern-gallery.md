# 花式魔方图鉴实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 提供六种经典 3×3 魔方花式的成品预览，并从复原态逐步播放每条标准公式。

**Architecture:** 用纯 Dart `CubePattern` 和 `CubePatternCatalog` 保存不可变元数据，所有目标状态统一由现有 `CubeSolver.applyMoves` 计算。新增只读 `PatternGalleryPage` 展示 `CubeNet` 预览，点击后复用可配置文案的 `SolutionPage`，以复原态、花式动作和当前配色播放过程。

**Tech Stack:** Dart 3、Flutter Material、flutter_test、现有 `CubeState`/`CubeSolver`/`CubeNet`/`SolutionPage`/`CubeColorScheme`、Android Release 部署脚本。

---

## 文件结构

- 创建 `lib/patterns/cube_pattern.dart`：定义花式难度和不可变花式模型。
- 创建 `lib/patterns/cube_pattern_catalog.dart`：维护六种经典花式及唯一标识校验。
- 创建 `test/patterns/cube_pattern_test.dart`：锁定公式、目标 facelet、合法性和不可变性。
- 修改 `lib/playback/solution_page.dart`、`test/playback/solution_page_test.dart`：为同一播放组件增加可选场景文案。
- 创建 `lib/patterns/pattern_gallery_page.dart`、`test/patterns/pattern_gallery_page_test.dart`：实现响应式图鉴、成品预览和演示导航。
- 修改 `lib/app/home_page.dart`、`test/app/home_page_test.dart`：增加主页入口并传递当前配色。
- 修改 `README.md`、`pubspec.yaml`、`assets/docs/update_notes.md`：记录功能并发布 `1.2.0+6`。

### 任务 1：建立经典花式领域模型与目录

**文件：**
- 创建：`lib/patterns/cube_pattern.dart`
- 创建：`lib/patterns/cube_pattern_catalog.dart`
- 创建：`test/patterns/cube_pattern_test.dart`

- [ ] **步骤 1：编写失败的模型与目录测试**

创建测试，固定目录顺序及每个公式对应的目标状态：

```dart
const expectedFacelets = {
  'six-spots': 'FFFFUFFFFRRRURURRRDDDRFRDDDBBBBDBBBBLLLDLDLLLUUULBLUUU',
  'checkerboard': 'UDUDUDUDURLRLRLRLRFBFBFBFBFDUDUDUDUDLRLRLRLRLBFBFBFBFB',
  'four-spots': 'UUUUUUUUULLLLRLLLLBBBBFBBBBDDDDDDDDDRRRRLRRRRFFFFBFFFF',
  'cube-in-cube': 'FFFFUUFUURRURRUUUURFFRFFRRRBBBDDBDDBDDDLLDLLDLLLLBBLBB',
  'snake': 'UUUDUBDUFRRBLRRRFBLBDBFDUBUFDFFDUBFDBFFRLLRLLLLRUBDLRD',
  'superflip': 'UBULURUFURURFRBRDRFUFLFRFDFDFDLDRDBDLULBLFLDLBUBRBLBDB',
};

test('classic catalog is ordered, legal and snapshot-stable', () {
  final patterns = CubePatternCatalog.classics.patterns;
  expect(patterns.map((pattern) => pattern.id), expectedFacelets.keys);
  expect(patterns.map((pattern) => pattern.id).toSet().length, patterns.length);

  for (final pattern in patterns) {
    expect(pattern.targetState.toFacelets(), expectedFacelets[pattern.id]);
    expect(const CubeValidator().validate(pattern.targetState).isValid, isTrue);
    expect(pattern.targetState, isNot(CubeState.solved()));
    expect(pattern.notation, pattern.moves.map((move) => move.notation).join(' '));
  }
});

test('model and catalog reject invalid data and remain immutable', () {
  final pattern = CubePattern.fromAlgorithm(
    id: 'sample',
    name: '示例',
    description: '测试花式',
    difficulty: CubePatternDifficulty.beginner,
    algorithm: 'R U',
  );
  expect(() => pattern.moves.clear(), throwsUnsupportedError);
  expect(() => CubePatternCatalog([pattern, pattern]), throwsArgumentError);
  expect(() => CubePattern.fromAlgorithm(
    id: '',
    name: '示例',
    description: '测试花式',
    difficulty: CubePatternDifficulty.beginner,
    algorithm: 'R',
  ), throwsArgumentError);
  expect(() => CubePattern.fromAlgorithm(
    id: 'empty',
    name: '示例',
    description: '测试花式',
    difficulty: CubePatternDifficulty.beginner,
    algorithm: '   ',
  ), throwsArgumentError);
});
```

- [ ] **步骤 2：运行测试确认红灯**

运行：`flutter test test/patterns/cube_pattern_test.dart`

预期：FAIL，提示 `patterns/cube_pattern.dart` 和目录类型不存在。

- [ ] **步骤 3：实现不可变模型**

在 `cube_pattern.dart` 中实现：

```dart
enum CubePatternDifficulty {
  beginner('入门'),
  intermediate('进阶'),
  challenge('挑战');

  const CubePatternDifficulty(this.label);
  final String label;
}

final class CubePattern {
  factory CubePattern.fromAlgorithm({
    required String id,
    required String name,
    required String description,
    required CubePatternDifficulty difficulty,
    required String algorithm,
  }) {
    final normalizedId = id.trim();
    final normalizedName = name.trim();
    final normalizedDescription = description.trim();
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(normalizedId)) {
      throw ArgumentError.value(id, 'id', '花式标识必须使用小写英文、数字和连字符');
    }
    if (normalizedName.isEmpty || normalizedDescription.isEmpty) {
      throw ArgumentError('花式名称和说明不能为空');
    }
    final moves = CubeSolver.parseAlgorithm(algorithm);
    if (moves.isEmpty) {
      throw ArgumentError.value(algorithm, 'algorithm', '花式公式不能为空');
    }
    final immutableMoves = List<SolutionMove>.unmodifiable(moves);
    return CubePattern._(
      id: normalizedId,
      name: normalizedName,
      description: normalizedDescription,
      difficulty: difficulty,
      moves: immutableMoves,
      targetState: CubeSolver.applyMoves(CubeState.solved(), immutableMoves),
    );
  }

  const CubePattern._({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.moves,
    required this.targetState,
  });

  final String id;
  final String name;
  final String description;
  final CubePatternDifficulty difficulty;
  final List<SolutionMove> moves;
  final CubeState targetState;

  int get moveCount => moves.length;
  String get notation => moves.map((move) => move.notation).join(' ');
}
```

- [ ] **步骤 4：实现经典目录**

`CubePatternCatalog` 构造函数复制列表并拒绝空目录和重复标识；`classics` 按规格顺序创建六个条目，公式必须与设计文档一致：

```dart
final class CubePatternCatalog {
  factory CubePatternCatalog(Iterable<CubePattern> patterns) {
    final immutablePatterns = List<CubePattern>.unmodifiable(patterns);
    if (immutablePatterns.isEmpty) {
      throw ArgumentError.value(patterns, 'patterns', '花式目录不能为空');
    }
    final ids = immutablePatterns.map((pattern) => pattern.id).toSet();
    if (ids.length != immutablePatterns.length) {
      throw ArgumentError.value(patterns, 'patterns', '花式标识不能重复');
    }
    return CubePatternCatalog._(immutablePatterns);
  }

  const CubePatternCatalog._(this.patterns);
  final List<CubePattern> patterns;

  static final classics = CubePatternCatalog([
    CubePattern.fromAlgorithm(
      id: 'six-spots',
      name: '六面点',
      description: '每个面只保留中心色，周围八格来自相邻面。',
      difficulty: CubePatternDifficulty.beginner,
      algorithm: "U D' R L' F B'",
    ),
    CubePattern.fromAlgorithm(
      id: 'checkerboard',
      name: '棋盘格',
      description: '六个面都形成中心色与对面色交替的棋盘。',
      difficulty: CubePatternDifficulty.beginner,
      algorithm: 'U2 D2 R2 L2 F2 B2',
    ),
    CubePattern.fromAlgorithm(
      id: 'four-spots',
      name: '四面点',
      description: '上下两面保持完整，四个侧面各留下一个中心点。',
      difficulty: CubePatternDifficulty.intermediate,
      algorithm: "F2 B2 U D' R2 L2 U D'",
    ),
    CubePattern.fromAlgorithm(
      id: 'cube-in-cube',
      name: '立方体中立方体',
      description: '三个可见方向组合出嵌套的小立方体轮廓。',
      difficulty: CubePatternDifficulty.intermediate,
      algorithm: "F L F U' R U F2 L2 U' L' B D' B' L2 U",
    ),
    CubePattern.fromAlgorithm(
      id: 'snake',
      name: '蛇形',
      description: '连续色块沿六个面蜿蜒连接，形成环绕魔方的长蛇。',
      difficulty: CubePatternDifficulty.challenge,
      algorithm: "R2 F2 U2 R B2 U2 F2 L2 D' R2 F2 U2 R' D B2",
    ),
    CubePattern.fromAlgorithm(
      id: 'superflip',
      name: '超级翻转',
      description: '十二个棱块全部翻转，角块和中心保持原位。',
      difficulty: CubePatternDifficulty.challenge,
      algorithm: "U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2",
    ),
  ]);
}
```

- [ ] **步骤 5：运行领域测试确认绿灯**

运行：`flutter test test/patterns/cube_pattern_test.dart`

预期：全部通过，六个 facelet 快照完全一致。

- [ ] **步骤 6：提交领域模型**

```powershell
git add lib/patterns/cube_pattern.dart lib/patterns/cube_pattern_catalog.dart test/patterns/cube_pattern_test.dart
git commit -m "feat: add classic cube pattern catalog (task 1/5)"
```

### 任务 2：让现有逐步播放支持花式文案

**文件：**
- 修改：`lib/playback/solution_page.dart`
- 修改：`test/playback/solution_page_test.dart`

- [ ] **步骤 1：编写失败的花式文案测试**

```dart
testWidgets('supports pattern-specific playback copy', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SolutionPage(
        initialState: CubeState.solved(),
        moves: [SolutionMove('R')],
        title: '棋盘格演示',
        completionText: '花式完成',
        formulaTitle: '完整拼法',
      ),
    ),
  );

  expect(find.text('棋盘格演示'), findsOneWidget);
  expect(find.text('完整拼法'), findsOneWidget);
  await tester.ensureVisible(find.text('下一步'));
  await tester.tap(find.text('下一步'));
  await tester.pump();
  expect(find.text('花式完成'), findsOneWidget);
});
```

保留并继续运行现有“解法演示”“完整解法”“复原完成”断言，证明默认流程没有改变。

- [ ] **步骤 2：运行测试确认红灯**

运行：`flutter test test/playback/solution_page_test.dart`

预期：FAIL，提示 `title`、`completionText` 和 `formulaTitle` 不是已命名参数。

- [ ] **步骤 3：加入带默认值的展示文案**

在 `SolutionPage` 构造函数和字段中加入：

```dart
this.title = '解法演示',
this.completionText = '复原完成',
this.formulaTitle = '完整解法',

final String title;
final String completionText;
final String formulaTitle;
```

将 AppBar 标题、完成提示和公式标题分别改为 `widget.title`、`widget.completionText`、`widget.formulaTitle`。空动作时仍显示“魔方已经复原”，因为花式目录不允许空公式。

- [ ] **步骤 4：运行播放测试确认绿灯**

运行：`flutter test test/playback/solution_page_test.dart`

预期：全部通过，默认求解文案和花式文案均正确。

- [ ] **步骤 5：提交播放复用**

```powershell
git add lib/playback/solution_page.dart test/playback/solution_page_test.dart
git commit -m "feat: support cube pattern playback copy (task 2/5)"
```

### 任务 3：实现响应式花式图鉴和演示导航

**文件：**
- 创建：`lib/patterns/pattern_gallery_page.dart`
- 创建：`test/patterns/pattern_gallery_page_test.dart`

- [ ] **步骤 1：编写失败的图鉴 Widget 测试**

覆盖以下行为：

```dart
testWidgets('shows classics and opens the selected pattern', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: PatternGalleryPage()));

  for (final pattern in CubePatternCatalog.classics.patterns) {
    expect(find.byKey(ValueKey('pattern-card-${pattern.id}')), findsOneWidget);
    expect(find.text(pattern.name), findsOneWidget);
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
```

配色与响应式行为使用以下测试：

```dart
testWidgets('keeps one color scheme in previews and playback', (tester) async {
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
  expect(tester.widget<Cube3DView>(find.byType(Cube3DView)).colorScheme, scheme);
});

testWidgets('uses one column at 320dp without overflow', (tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 640);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const MaterialApp(home: PatternGalleryPage()));

  final first = find.byKey(const ValueKey('pattern-card-six-spots'));
  final second = find.byKey(const ValueKey('pattern-card-checkerboard'));
  expect(tester.getTopLeft(second).dy, greaterThan(tester.getTopLeft(first).dy));
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
});
```

- [ ] **步骤 2：运行测试确认红灯**

运行：`flutter test test/patterns/pattern_gallery_page_test.dart`

预期：FAIL，提示 `PatternGalleryPage` 不存在。

- [ ] **步骤 3：实现图鉴页面和花式卡片**

`PatternGalleryPage` 接收可选 `colorScheme`，默认使用标准配色。页面使用最大宽度 760dp 的滚动内容：

```dart
class PatternGalleryPage extends StatelessWidget {
  const PatternGalleryPage({
    super.key,
    this.colorScheme = CubeColorScheme.standard,
  });

  final CubeColorScheme colorScheme;

  void _openPattern(BuildContext context, CubePattern pattern) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SolutionPage(
          initialState: CubeState.solved(),
          moves: pattern.moves,
          colorScheme: colorScheme,
          title: '${pattern.name}演示',
          completionText: '花式完成',
          formulaTitle: '完整拼法',
        ),
      ),
    );
  }
}
```

顶部说明卡必须包含“请先将魔方完整复原”“U 面朝上、F 面朝前”“过程中不要整体转动魔方”。

窄屏使用 `Column` 和带间距的卡片列表；宽度至少 600dp 时使用 `GridView.builder(shrinkWrap: true)`，`crossAxisCount: 2`、`mainAxisExtent: 400`，并禁用内部滚动。每张卡片：

- 使用 `ValueKey('pattern-card-${pattern.id}')`。
- 通过 `CubeNet(key: ValueKey('pattern-preview-${pattern.id}'), state: pattern.targetState, showCenterLocks: false, colorScheme: colorScheme)` 渲染成品。
- 显示难度标签、`<moveCount> 步`、描述和“开始演示”。
- 整张卡片可点击，调用 `_openPattern`。

- [ ] **步骤 4：运行图鉴测试确认绿灯**

运行：`flutter test test/patterns/pattern_gallery_page_test.dart`

预期：全部通过且 `tester.takeException()` 为 null。

- [ ] **步骤 5：提交图鉴页面**

```powershell
git add lib/patterns/pattern_gallery_page.dart test/patterns/pattern_gallery_page_test.dart
git commit -m "feat: add responsive cube pattern gallery (task 3/5)"
```

### 任务 4：从主页进入花式图鉴并传递配色

**文件：**
- 修改：`lib/app/home_page.dart`
- 修改：`test/app/home_page_test.dart`

- [ ] **步骤 1：编写失败的主页入口测试**

在主页基础功能测试中断言“花式魔方”存在，并新增：

```dart
testWidgets('pattern gallery keeps the configured display scheme', (tester) async {
  await tester.pumpWidget(
    const RubikSolverApp(enableStartupUpdateCheck: false),
  );

  await tester.tap(find.text('配置六面配色'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('scheme-face-U')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('黄色').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('应用'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('花式魔方'));
  await tester.pumpAndSettle();

  final gallery = tester.widget<PatternGalleryPage>(
    find.byType(PatternGalleryPage),
  );
  expect(gallery.colorScheme.colorIdentityFor(CubeFace.up), CubeFace.down);
});
```

主页响应式测试直接固定两种视口：

```dart
for (final size in const [Size(320, 640), Size(700, 900)]) {
  testWidgets('home fits four actions at ${size.width}dp', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const RubikSolverApp(enableStartupUpdateCheck: false),
    );

    for (final label in const [
      '开始扫描',
      '随机魔方',
      '花式魔方',
      '手动录入',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **步骤 2：运行主页测试确认红灯**

运行：`flutter test test/app/home_page_test.dart`

预期：FAIL，找不到“花式魔方”或 `PatternGalleryPage`。

- [ ] **步骤 3：增加入口并调整按钮布局**

导入 `pattern_gallery_page.dart`，在随机入口后加入：

```dart
FilledButton.tonalIcon(
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PatternGalleryPage(colorScheme: _colorScheme),
    ),
  ),
  icon: const Icon(Icons.auto_awesome),
  label: const Text('花式魔方'),
),
```

窄屏按“开始扫描、随机魔方、花式魔方、手动录入”纵向排列。宽屏用不可滚动、`shrinkWrap` 的两列 Grid，固定 48dp 主轴高度和 12dp 横纵间距，避免四个按钮被压缩。

- [ ] **步骤 4：运行主页与图鉴测试确认绿灯**

运行：`flutter test test/app/home_page_test.dart test/patterns/pattern_gallery_page_test.dart`

预期：全部通过，当前配色贯穿主页、图鉴和播放。

- [ ] **步骤 5：提交主页流程**

```powershell
git add lib/app/home_page.dart test/app/home_page_test.dart
git commit -m "feat: open cube pattern gallery from home (task 4/5)"
```

### 任务 5：更新版本、文档、完整验证与发布

**文件：**
- 修改：`README.md`
- 修改：`pubspec.yaml`
- 修改：`assets/docs/update_notes.md`

- [ ] **步骤 1：更新用户文档和版本**

将版本改为：

```yaml
version: 1.2.0+6
```

在 README 功能列表增加：

```markdown
- 内置六面点、棋盘格、四面点、立方体中立方体、蛇形和超级翻转六种经典花式，可预览成品并从复原态逐步演示。
```

在更新说明顶部增加：

```markdown
## 1.2.0

- 新增花式魔方图鉴，内置六种经典花式及真实六面成品预览。
- 每种花式都可从完整复原状态开始，使用三维魔方按公式逐步、自动或慢动作演示。
- 花式预览与演示沿用主页配置的六面配色。
```

- [ ] **步骤 2：执行针对性格式与测试**

运行：`dart format lib/patterns test/patterns lib/playback/solution_page.dart test/playback/solution_page_test.dart lib/app/home_page.dart test/app/home_page_test.dart`

运行：`flutter test test/patterns test/playback/solution_page_test.dart test/app/home_page_test.dart`

预期：格式化成功，新增及直接相关测试全部通过。

- [ ] **步骤 3：执行完整质量检查**

运行：`dart format --output=none --set-exit-if-changed lib test`

运行：`flutter analyze`

运行：`flutter test`

预期：格式无改动、静态分析无问题、全部测试通过。

- [ ] **步骤 4：提交发布版本**

```powershell
git add README.md pubspec.yaml assets/docs/update_notes.md
git commit -m "chore: release version 1.2.0"
```

- [ ] **步骤 5：构建并部署 Android Release**

运行：`cmd /c deploy.bat android`

预期：构建正式签名的 arm64 APK，并把 `rubicsolver.apk`、`rubicsolver_version.txt` 和 `rubicsolver_update_notes.md` 发布到配置的 `X:\certificate` 或 `DEPLOY_PUBLISH_DIR`。

- [ ] **步骤 6：核对发布物**

验证：

- `rubicsolver_version.txt` 内容为 `1.2.0+6`。
- 更新说明包含“花式魔方图鉴”。
- `build/app/outputs/flutter-apk/app-release.apk` 与发布目录 `rubicsolver.apk` 的 SHA-256 一致。
- `apksigner verify --print-certs` 显示证书 SHA-256 为 `CB0ED095CB12C804FB7D4BC6F57090CD79B3DD20E4EE43A3A56A196FEFA9DAE6`。
- `git status --short --branch` 显示 `master` 工作区干净。

## 自检结果

- 规格覆盖：六个经典公式、目标预览、固定朝向、当前配色、逐步播放、响应式布局、版本和发布均有对应任务。
- 快照一致：计划锁定了使用现有变换引擎预先验证得到的六个目标 facelet 字符串。
- 类型一致：统一使用 `CubePatternDifficulty`、`CubePattern.fromAlgorithm`、`CubePatternCatalog.classics`、`PatternGalleryPage` 以及 `SolutionPage` 的 `title/completionText/formulaTitle`。
- 范围控制：不增加自定义公式、联网目录、收藏、搜索、中层转动或实体魔方状态检测。
