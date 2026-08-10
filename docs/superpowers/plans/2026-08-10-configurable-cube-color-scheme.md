# 可配置魔方六面配色实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 允许用户在当前应用会话中重新分配 U/R/F/D/L/B 的六种标准色，并让该配色一致作用于扫描、识别、纠错和解法播放。

**架构：** 新增不依赖 Flutter 的不可变 `CubeColorScheme`，把逻辑 `CubeFace` 映射到标准调色板颜色标识，再提供反向映射和交换操作。求解状态始终保留逻辑面编码；UI 和识别边界显式接收同一个方案，并在显示颜色或解释照片颜色时做映射。

**技术栈：** Dart 3、Flutter Material、flutter_test、现有 CIE Lab/Delta E 识别与 Kociemba 求解链路、Android Gradle Release 构建和 `deploy.bat`。

---

## 文件结构

- 创建 `lib/cube/cube_color_scheme.dart`：定义配色方案、校验、双向查找、交换和值相等。
- 创建 `test/cube/cube_color_scheme_test.dart`：覆盖标准方案、非法映射、反查、交换和不可变性。
- 创建 `lib/app/cube_color_scheme_dialog.dart`：提供六面配色对话框和自动交换交互。
- 创建 `test/app/cube_color_scheme_dialog_test.dart`：验证颜色选项、交换、恢复默认、取消和应用。
- 修改 `lib/app/home_page.dart`、`test/app/home_page_test.dart`：保存会话方案，并向扫描和手动录入路由传递。
- 修改 `lib/scan/scan_color_matcher.dart`、`lib/scan/scan_preview_classifier.dart`、`lib/scan/color_classifier.dart`、`lib/scan/scan_session.dart`：用实际中心颜色校正样本，再把候选颜色反查为逻辑面。
- 修改 `test/scan/scan_color_matcher_test.dart`、`test/scan/scan_preview_classifier_test.dart`、`test/scan/color_classifier_test.dart`、`test/scan/scan_session_test.dart`：覆盖重排配色的实时和最终识别。
- 修改 `lib/scan/scan_page.dart`、`test/scan/scan_page_test.dart`：动态显示面色、方向提示、圆点和改色选项，并把方案传给纠错页。
- 修改 `lib/editor/cube_display_colors.dart`、`lib/editor/cube_editor_page.dart`、`lib/editor/cube_net.dart`、`test/editor/cube_editor_page_test.dart`：按方案显示贴纸和颜色选择项，并继续向解法页传递。
- 修改 `lib/playback/solution_page.dart`、`lib/playback/cube_3d_view.dart`、`test/playback/solution_page_test.dart`、`test/playback/cube_3d_view_test.dart`：按方案绘制三维贴纸并参与重绘判断。
- 修改 `pubspec.yaml`、`assets/docs/update_notes.md`：发布 `1.1.2+4` 说明。

### 任务 1：建立不可变配色领域模型

**文件：**
- 创建：`lib/cube/cube_color_scheme.dart`
- 创建：`test/cube/cube_color_scheme_test.dart`

- [ ] **步骤 1：编写失败的模型测试**

```dart
const swapped = {
  CubeFace.up: CubeFace.down,
  CubeFace.right: CubeFace.right,
  CubeFace.front: CubeFace.back,
  CubeFace.down: CubeFace.up,
  CubeFace.left: CubeFace.left,
  CubeFace.back: CubeFace.front,
};

test('standard maps every logical face to its conventional color', () {
  for (final face in CubeFace.values) {
    expect(CubeColorScheme.standard.colorIdentityFor(face), face);
    expect(CubeColorScheme.standard.logicalFaceFor(face), face);
  }
});

test('validates and reverses a complete permutation', () {
  final scheme = CubeColorScheme(swapped);
  expect(scheme.colorIdentityFor(CubeFace.up), CubeFace.down);
  expect(scheme.logicalFaceFor(CubeFace.down), CubeFace.up);
  expect(() => scheme.assignments[CubeFace.up] = CubeFace.up,
      throwsUnsupportedError);
});

test('swaps the owner when assigning an occupied color', () {
  final scheme = CubeColorScheme.standard.swapColor(
    CubeFace.up,
    CubeFace.down,
  );
  expect(scheme.colorIdentityFor(CubeFace.up), CubeFace.down);
  expect(scheme.colorIdentityFor(CubeFace.down), CubeFace.up);
  expect(scheme, CubeColorScheme(swapped));
});
```

同时断言缺键、未知键和重复值均抛出 `ArgumentError`，相同映射具有相等的 `==` 与 `hashCode`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/cube/cube_color_scheme_test.dart`

预期：FAIL，提示 `cube_color_scheme.dart` 或 `CubeColorScheme` 不存在。

- [ ] **步骤 3：实现最小领域模型**

```dart
final class CubeColorScheme {
  factory CubeColorScheme(Map<CubeFace, CubeFace> assignments) {
    if (assignments.length != CubeFace.values.length ||
        !assignments.keys.toSet().containsAll(CubeFace.values) ||
        assignments.values.toSet().length != CubeFace.values.length) {
      throw ArgumentError.value(assignments, 'assignments', '必须是六面的唯一配色');
    }
    return CubeColorScheme._(Map.unmodifiable(assignments));
  }

  const CubeColorScheme._(this.assignments);

  static const standard = CubeColorScheme._({
    CubeFace.up: CubeFace.up,
    CubeFace.right: CubeFace.right,
    CubeFace.front: CubeFace.front,
    CubeFace.down: CubeFace.down,
    CubeFace.left: CubeFace.left,
    CubeFace.back: CubeFace.back,
  });

  final Map<CubeFace, CubeFace> assignments;

  CubeFace colorIdentityFor(CubeFace logicalFace) => assignments[logicalFace]!;

  CubeFace logicalFaceFor(CubeFace colorIdentity) => assignments.entries
      .singleWhere((entry) => entry.value == colorIdentity)
      .key;

  CubeColorScheme swapColor(CubeFace logicalFace, CubeFace colorIdentity) {
    final otherFace = logicalFaceFor(colorIdentity);
    final currentColor = colorIdentityFor(logicalFace);
    return CubeColorScheme({...assignments,
      logicalFace: colorIdentity,
      otherFace: currentColor,
    });
  }
}
```

补充基于六个固定枚举值的 `operator ==` 与 `hashCode`，不引入第三方集合依赖。

- [ ] **步骤 4：运行模型测试验证通过**

运行：`flutter test test/cube/cube_color_scheme_test.dart`

预期：PASS。

- [ ] **步骤 5：提交领域模型**

```bash
git add lib/cube/cube_color_scheme.dart test/cube/cube_color_scheme_test.dart
git commit -m "feat: add configurable cube color scheme model"
```

### 任务 2：让识别链路理解重排配色

**文件：**
- 修改：`lib/scan/scan_color_matcher.dart`
- 修改：`lib/scan/scan_preview_classifier.dart`
- 修改：`lib/scan/color_classifier.dart`
- 修改：`lib/scan/scan_session.dart`
- 修改：`test/scan/scan_color_matcher_test.dart`
- 修改：`test/scan/scan_preview_classifier_test.dart`
- 修改：`test/scan/color_classifier_test.dart`
- 修改：`test/scan/scan_session_test.dart`

- [ ] **步骤 1：编写失败的重排识别测试**

```dart
final scheme = CubeColorScheme.standard
    .swapColor(CubeFace.up, CubeFace.down)
    .swapColor(CubeFace.front, CubeFace.back);

test('maps palette identities back to configured logical faces', () {
  final matcher = ScanColorMatcher(
    capturedFace: CubeFace.up,
    observedCenter: _standardRgb(CubeFace.down),
    colorScheme: scheme,
  );
  expect(matcher.rank(_standardRgb(CubeFace.down)).first.face, CubeFace.up);
  expect(matcher.rank(_standardRgb(CubeFace.up)).first.face, CubeFace.down);
});
```

为预览添加黄色中心强制为 U、白色样本输出 D 的断言；为最终分类构造按 `scheme.colorIdentityFor(face)` 生成的 54 个样本，并断言仍得到 `CubeState.solved()`；为 `ScanSession` 断言 `colorScheme` getter 与分类结果一致。

- [ ] **步骤 2：运行扫描单元测试验证失败**

运行：`flutter test test/scan/scan_color_matcher_test.dart test/scan/scan_preview_classifier_test.dart test/scan/color_classifier_test.dart test/scan/scan_session_test.dart`

预期：FAIL，构造函数和 `classify` 尚无 `colorScheme` 参数。

- [ ] **步骤 3：在匹配器中校正实际中心并返回逻辑面**

```dart
ScanColorMatcher({
  required this.capturedFace,
  required RgbColor observedCenter,
  this.colorScheme = CubeColorScheme.standard,
  this.maximumLightnessShift = 18,
  this.maximumChromaShift = 14,
}) {
  final centerIdentity = colorScheme.colorIdentityFor(capturedFace);
  final standardCenter = _standardLabs[centerIdentity]!;
  // 保留现有受限 Lab 偏移计算。
}

final CubeColorScheme colorScheme;

ScanColorCandidate(
  face: colorScheme.logicalFaceFor(colorIdentity),
  cost: deltaE2000(correctedLab, _standardLabs[colorIdentity]!),
)
```

遍历候选时仍按六个标准颜色标识计算代价；排序后的 `face` 始终为逻辑面。

- [ ] **步骤 4：把方案传过预览、最终分类和会话**

```dart
List<CubeFace> classify({
  required List<StickerSample> samples,
  required CubeFace currentFace,
  CubeColorScheme colorScheme = CubeColorScheme.standard,
  Map<CubeFace, List<StickerSample>> capturedSamplesByFace = const {},
})
```

`ColorClassifier.classify` 增加相同默认参数并传给每个 `ScanColorMatcher`。`ScanSession` 构造函数保存 `final CubeColorScheme colorScheme`，`classify()` 将其传给 `_classifier.classify`。中心格、锁色、容量和 Hungarian 分配继续使用逻辑面。

- [ ] **步骤 5：运行扫描单元测试验证通过**

运行：`flutter test test/scan/scan_color_matcher_test.dart test/scan/scan_preview_classifier_test.dart test/scan/color_classifier_test.dart test/scan/scan_session_test.dart`

预期：PASS。

- [ ] **步骤 6：提交识别链路**

```bash
git add lib/scan test/scan/scan_color_matcher_test.dart test/scan/scan_preview_classifier_test.dart test/scan/color_classifier_test.dart test/scan/scan_session_test.dart
git commit -m "feat: classify scans with configurable face colors"
```

### 任务 3：添加主页配色配置和会话传递

**文件：**
- 创建：`lib/app/cube_color_scheme_dialog.dart`
- 创建：`test/app/cube_color_scheme_dialog_test.dart`
- 修改：`lib/app/home_page.dart`
- 修改：`test/app/home_page_test.dart`

- [ ] **步骤 1：编写失败的对话框和主页测试**

```dart
testWidgets('choosing an occupied color swaps the two faces', (tester) async {
  CubeColorScheme? applied;
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
    return TextButton(
      onPressed: () async => applied = await showCubeColorSchemeDialog(
        context,
        initialScheme: CubeColorScheme.standard,
      ),
      child: const Text('open'),
    );
  })));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('scheme-face-U')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('黄色').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('应用'));
  await tester.pumpAndSettle();
  expect(applied!.colorIdentityFor(CubeFace.up), CubeFace.down);
  expect(applied!.colorIdentityFor(CubeFace.down), CubeFace.up);
});
```

补充恢复默认、取消返回 `null`、六行都有色块和中文色名的测试。主页测试点击“配置六面配色”并应用后，分别点击“开始扫描”和“手动录入”，断言目标 Widget 的 `colorScheme` 是同一重排方案。

- [ ] **步骤 2：运行 UI 测试验证失败**

运行：`flutter test test/app/cube_color_scheme_dialog_test.dart test/app/home_page_test.dart`

预期：FAIL，对话框入口和页面参数不存在。

- [ ] **步骤 3：实现局部草稿和自动交换的配置对话框**

```dart
Future<CubeColorScheme?> showCubeColorSchemeDialog(
  BuildContext context, {
  required CubeColorScheme initialScheme,
}) => showDialog<CubeColorScheme>(
  context: context,
  builder: (_) => _CubeColorSchemeDialog(initialScheme: initialScheme),
);
```

对话框内部用 `StatefulWidget` 保存 `_draft`。每行显示逻辑面字母、`CubePalette.colorFor(identity)` 圆形色块、`CubePalette.nameFor(identity)` 和 `DropdownButton<CubeFace>`；`onChanged` 调用 `_draft.swapColor(face, identity)`。按钮分别设置 `standard`、`Navigator.pop(null)` 和 `Navigator.pop(_draft)`。

- [ ] **步骤 4：让主页持有并传递会话方案**

```dart
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.updateService});
  final UpdateService? updateService;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CubeColorScheme _colorScheme = CubeColorScheme.standard;
}
```

在两个主操作上方增加带 `Icons.palette_outlined` 的“配置六面配色”命令；应用结果后 `setState`。构造 `ScanPage(colorScheme: _colorScheme)` 和 `CubeEditorPage(initialState: CubeState.solved(), colorScheme: _colorScheme)`。

- [ ] **步骤 5：运行 UI 测试验证通过**

运行：`flutter test test/app/cube_color_scheme_dialog_test.dart test/app/home_page_test.dart`

预期：PASS，320dp 宽度无 overflow。

- [ ] **步骤 6：提交配置入口**

```bash
git add lib/app test/app
git commit -m "feat: configure cube face colors from home"
```

### 任务 4：让扫描提示、预览和改色面板使用配置方案

**文件：**
- 修改：`lib/scan/scan_page.dart`
- 修改：`test/scan/scan_page_test.dart`

- [ ] **步骤 1：编写失败的扫描页面测试**

```dart
final scheme = CubeColorScheme.standard
    .swapColor(CubeFace.up, CubeFace.down)
    .swapColor(CubeFace.front, CubeFace.back);

testWidgets('shows configured face and orientation colors', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: ScanPage(colorScheme: scheme, cameraDiscovery: _noCameras),
  ));
  await tester.pumpAndSettle();
  expect(find.textContaining('黄色 U 面'), findsOneWidget);
  expect(find.textContaining('黄色中心 = U，蓝色中心 = F'), findsOneWidget);
});
```

推进已注入的 `ScanSession(colorScheme: scheme)` 到 F、D 等面，分别断言 U 面显示蓝色朝上、侧面显示黄色朝上、D 面显示蓝色朝上。用已有照片/预览夹具断言圆点和九格改色选项的背景色来自方案。

- [ ] **步骤 2：运行扫描页面测试验证失败**

运行：`flutter test test/scan/scan_page_test.dart`

预期：FAIL，页面仍硬编码标准配色和提示。

- [ ] **步骤 3：把方案作为页面与会话的单一来源**

```dart
const ScanPage({
  super.key,
  this.colorScheme = CubeColorScheme.standard,
  this.session,
  // 保留现有注入参数。
});

final CubeColorScheme colorScheme;

void initState() {
  super.initState();
  _session = widget.session ?? ScanSession(colorScheme: widget.colorScheme);
  _colorScheme = _session.colorScheme;
}
```

实时两处 `ScanPreviewClassifier.classify` 都传 `_colorScheme`；进入识别纠错和手动录入时传给 `CubeEditorPage`。

- [ ] **步骤 4：动态生成扫描显示文本与颜色**

```dart
String _configuredFaceName(CubeFace face) {
  final identity = _colorScheme.colorIdentityFor(face);
  return '${CubePalette.nameFor(identity)} ${face.letter} 面';
}

CubeFace _topEdgeFor(CubeFace face) => switch (face) {
  CubeFace.up => CubeFace.back,
  CubeFace.down => CubeFace.front,
  _ => CubeFace.up,
};
```

朝向文案先取逻辑上的朝上边，再通过方案转换成实际中文色名。标准方向显示方案中 U/F 的色名。所有 `CubePalette.colorFor/foregroundFor/nameFor` 调用先将逻辑面转换为颜色标识；选择实际色时用 `logicalFaceFor` 写入锁定值。保持实时识别小圆点位于格子中心的现有布局。

- [ ] **步骤 5：运行扫描页面测试验证通过**

运行：`flutter test test/scan/scan_page_test.dart`

预期：PASS。

- [ ] **步骤 6：提交扫描界面贯穿**

```bash
git add lib/scan/scan_page.dart test/scan/scan_page_test.dart
git commit -m "feat: apply configured colors throughout scanning"
```

### 任务 5：让纠错编辑器和解法播放使用配置方案

**文件：**
- 修改：`lib/editor/cube_display_colors.dart`
- 修改：`lib/editor/cube_editor_page.dart`
- 修改：`lib/editor/cube_net.dart`
- 修改：`lib/playback/solution_page.dart`
- 修改：`lib/playback/cube_3d_view.dart`
- 修改：`test/editor/cube_editor_page_test.dart`
- 修改：`test/playback/solution_page_test.dart`
- 修改：`test/playback/cube_3d_view_test.dart`

- [ ] **步骤 1：编写失败的编辑与绘制测试**

```dart
testWidgets('editor renders logical stickers with configured colors', (tester) async {
  final scheme = CubeColorScheme.standard.swapColor(
    CubeFace.up,
    CubeFace.down,
  );
  await tester.pumpWidget(MaterialApp(home: CubeEditorPage(
    initialState: CubeState.solved(),
    colorScheme: scheme,
  )));
  final sticker = tester.widget<Material>(
    find.byKey(const ValueKey('sticker-0')),
  );
  expect(sticker.color, CubePalette.colorFor(CubeFace.down));
});
```

断言编辑颜色列表中“上面颜色”显示 U 当前实际色；求解后 `SolutionPage.colorScheme` 与编辑器一致；`Cube3DView` 生成的 `Cube3DPainter.colorScheme` 一致；相同状态但不同方案时 `shouldRepaint` 返回 true。

- [ ] **步骤 2：运行编辑与播放测试验证失败**

运行：`flutter test test/editor/cube_editor_page_test.dart test/playback/solution_page_test.dart test/playback/cube_3d_view_test.dart`

预期：FAIL，各 Widget 和 Painter 尚无 `colorScheme`。

- [ ] **步骤 3：在编辑器边界映射显示色**

```dart
Color colorFor(
  CubeFace face, {
  CubeColorScheme colorScheme = CubeColorScheme.standard,
}) => CubePalette.colorFor(colorScheme.colorIdentityFor(face));
```

`CubeDisplayColors.foregroundFor` 同样映射。`CubeEditorPage` 与 `CubeNet` 增加标准方案默认参数；贴纸、选择列表和前景色都传方案。编辑动作仍把用户选中的列表项对应逻辑面写入 `CubeState`。进入 `SolutionPage` 时继续传方案。

- [ ] **步骤 4：在 3D 播放边界映射显示色**

```dart
final previousColor = CubePalette.colorFor(
  colorScheme.colorIdentityFor(previousState.stickers[index]),
);
final currentColor = CubePalette.colorFor(
  colorScheme.colorIdentityFor(state.stickers[targetIndex]),
);
```

`SolutionPage`、`Cube3DView`、`Cube3DPainter` 均增加 `CubeColorScheme.standard` 默认参数并逐层传递；`Cube3DPainter.shouldRepaint` 比较 `colorScheme`。

- [ ] **步骤 5：运行编辑与播放测试验证通过**

运行：`flutter test test/editor/cube_editor_page_test.dart test/playback/solution_page_test.dart test/playback/cube_3d_view_test.dart`

预期：PASS。

- [ ] **步骤 6：提交编辑和播放贯穿**

```bash
git add lib/editor lib/playback test/editor/cube_editor_page_test.dart test/playback
git commit -m "feat: render configured colors in editing and playback"
```

### 任务 6：升级版本并完成发布验证

**文件：**
- 修改：`pubspec.yaml`
- 修改：`assets/docs/update_notes.md`

- [ ] **步骤 1：添加发布版本和更新说明**

```yaml
version: 1.1.2+4
```

在更新说明顶部新增：

```markdown
## 1.1.2

- 支持在主页重新配置 U、R、F、D、L、B 六个面的标准颜色，选择已使用颜色时自动交换。
- 自定义配色会一致应用于扫描方向提示、颜色识别、拍照后改色、校验编辑和三维解法播放。
```

- [ ] **步骤 2：格式化并运行静态检查**

运行：`dart format --output=none --set-exit-if-changed lib test`

预期：退出码 0；若失败，运行 `dart format lib test` 后再次检查。

运行：`flutter analyze`

预期：`No issues found!`

- [ ] **步骤 3：运行完整测试套件**

运行：`flutter test`

预期：全部测试通过，退出码 0。

- [ ] **步骤 4：提交发布版本**

```bash
git add pubspec.yaml assets/docs/update_notes.md
git commit -m "chore: release version 1.1.2"
```

- [ ] **步骤 5：使用现有脚本构建并上传 Android Release**

运行：`cmd /c deploy.bat android`

预期：脚本使用同级 `heat_ex_designer` 的签名配置构建 Release APK，并成功上传 `rubicsolver_version.txt`、`rubicsolver_update_notes.md` 与 `rubicsolver.apk`。

- [ ] **步骤 6：核对线上发布物**

运行：

```powershell
Invoke-WebRequest $versionUrl -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest $notesUrl -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest $apkUrl -OutFile "$env:TEMP\rubicsolver-1.1.2.apk"
Get-FileHash "$env:TEMP\rubicsolver-1.1.2.apk" -Algorithm SHA256
& "$env:ANDROID_HOME\build-tools\35.0.0\apksigner.bat" verify --print-certs "$env:TEMP\rubicsolver-1.1.2.apk"
```

预期：版本为 `1.1.2`，更新说明含可配置六面配色，远程 APK 哈希与本地 Release APK 一致，签名证书 SHA-256 为 `CB0ED095CB12C804FB7D4BC6F57090CD79B3DD20E4EE43A3A56A196FEFA9DAE6`。

## 自检结果

- 规格覆盖：模型、唯一性与交换、会话生命周期、Home 入口、识别双向映射、动态扫描提示、拍照后修改、编辑器、三维播放、版本和部署均有对应任务。
- 占位符扫描：每个生产变更均给出类型签名、映射规则、测试命令和预期结果。
- 类型一致性：统一使用 `CubeColorScheme.colorIdentityFor`、`logicalFaceFor`、`swapColor`、`assignments` 与 `colorScheme` 命名，所有旧调用通过 `CubeColorScheme.standard` 默认值保持兼容。
