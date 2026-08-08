# 稳定扫描识别与播放修正实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 稳定六面扫描的实时与最终颜色识别，加入单面即时纠色、标准方位提示和居中识别圆点，并修复启动图标与三维播放缺陷。

**架构：** `ScanColorMatcher` 负责标准配色、逐帧 Lab 校正和 CIEDE2000 代价；实时提示只依赖当前帧，最终分类通过容量约束的全局最小代价分配保证每色九格。播放状态机显式发布本次状态过渡动作，三维画布依据变换后法线剔除背面。扫描 UI 和原生图标只消费这些稳定模型。

**技术栈：** Flutter、Dart、flutter_test、CustomPainter、Android Vector Drawable、Gradle/apksigner

---

## 文件结构

- 创建 `lib/scan/scan_color_matcher.dart`：固定标准色参考、逐帧 Lab 校正、颜色候选排序。
- 创建 `lib/scan/minimum_cost_assignment.dart`：方阵最小总代价分配，仅服务最终颜色容量约束。
- 创建 `test/scan/minimum_cost_assignment_test.dart`：验证分配器最优性和输入校验。
- 修改 `lib/scan/color_math.dart`、`test/scan/color_math_test.dart`：增加 CIEDE2000。
- 修改 `lib/scan/scan_preview_classifier.dart`、`test/scan/scan_preview_classifier_test.dart`：去除历史中心依赖。
- 修改 `lib/scan/color_classifier.dart`、`test/scan/color_classifier_test.dart`：逐面校正与全局容量分配。
- 修改 `lib/scan/scan_page.dart`、`test/scan/scan_page_test.dart`：即时改色、自动锁定、圆点居中、标准方向提示。
- 修改 `lib/playback/move_player.dart`、`test/playback/move_player_test.dart`：发布真实过渡动作。
- 修改 `lib/playback/solution_page.dart`、`test/playback/solution_page_test.dart`：使用过渡动作驱动三维动画。
- 修改 `lib/playback/cube_3d_view.dart`、`test/playback/cube_3d_view_test.dart`：背面剔除。
- 修改 `android/app/src/main/res/drawable/ic_launcher_foreground.xml`：完整打乱 3×3 立体魔方。
- 修改 `README.md`、`assets/docs/update_notes.md`：同步标准配色、识别、纠色与播放说明。

### 任务 1：标准颜色距离与逐帧匹配器

**文件：**
- 修改：`test/scan/color_math_test.dart`
- 创建：`test/scan/scan_color_matcher_test.dart`
- 修改：`lib/scan/color_math.dart`
- 创建：`lib/scan/scan_color_matcher.dart`

- [ ] **步骤 1：编写 CIEDE2000 与逐帧校正失败测试**

在 `color_math_test.dart` 使用 Sharma 标准样例：

```dart
test('CIEDE2000 matches the Sharma reference pair', () {
  const first = LabColor(50, 2.6772, -79.7751);
  const second = LabColor(50, 0, -82.7485);
  expect(deltaE2000(first, second), closeTo(2.0425, 0.0001));
});
```

在新测试中证明匹配器强制中心格、标准颜色顺序稳定，并能抵消同一帧的受限 Lab 偏移：

```dart
final matcher = ScanColorMatcher(
  capturedFace: CubeFace.front,
  observedCenter: RgbColor(20, 135, 55),
);
expect(matcher.rank(RgbColor(225, 225, 215)).first.face, CubeFace.up);
expect(matcher.rank(RgbColor(25, 140, 60)).first.face, CubeFace.front);
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/scan/color_math_test.dart test/scan/scan_color_matcher_test.dart`

预期：因 `deltaE2000` 和 `ScanColorMatcher` 不存在而编译失败。

- [ ] **步骤 3：实现最小颜色模型**

`color_math.dart` 实现完整 CIEDE2000 公式；`scan_color_matcher.dart` 定义：

```dart
final class ScanColorCandidate {
  const ScanColorCandidate({required this.face, required this.cost});
  final CubeFace face;
  final double cost;
}

final class ScanColorMatcher {
  ScanColorMatcher({
    required this.capturedFace,
    required RgbColor observedCenter,
    this.maximumLightnessShift = 18,
    this.maximumChromaShift = 14,
  });

  final CubeFace capturedFace;
  final double maximumLightnessShift;
  final double maximumChromaShift;

  List<ScanColorCandidate> rank(RgbColor rgb);
}
```

构造时计算“当前面标准 Lab − 实测中心 Lab”的 L/a/b 偏移并分别限幅；`rank` 把偏移加到样本 Lab 后，对 `CubeFace.values` 的标准色计算 CIEDE2000 并升序返回。标准色从 `CubePalette.colorFor` 转成 RGB，不读取历史面。

- [ ] **步骤 4：运行目标测试并提交**

运行：`flutter test test/scan/color_math_test.dart test/scan/scan_color_matcher_test.dart`

提交：`feat: add stable standard color matcher`

### 任务 2：稳定实时提示

**文件：**
- 修改：`test/scan/scan_preview_classifier_test.dart`
- 修改：`lib/scan/scan_preview_classifier.dart`
- 修改：`lib/scan/scan_page.dart`

- [ ] **步骤 1：编写扫描进度不影响提示的失败测试**

删除“历史中心优先”断言，改为使用同一当前帧分别传入零个和五个历史面，断言结果完全相同；再断言中心格固定为 `currentFace`：

```dart
final withoutHistory = classifier.classify(
  samples: samples,
  currentFace: CubeFace.back,
);
final withHistory = classifier.classify(
  samples: samples,
  currentFace: CubeFace.back,
  capturedSamplesByFace: misleadingHistory,
);
expect(withHistory, withoutHistory);
expect(withHistory[4], CubeFace.back);
```

- [ ] **步骤 2：运行失败测试**

运行：`flutter test test/scan/scan_preview_classifier_test.dart`

预期：现有分类会被 `misleadingHistory` 改变而失败。

- [ ] **步骤 3：改用当前帧匹配器**

`ScanPreviewClassifier.classify` 保留兼容参数但不再读取 `capturedSamplesByFace`，用 `samples[4].rgb` 构造 `ScanColorMatcher`；中心格直接返回当前面，其余格取 `rank(...).first.face`。在参数文档中明确历史样本仅为兼容保留，不能改变结果。随后从 `ScanPage` 两个调用点删除历史样本传参。

- [ ] **步骤 4：运行扫描预览测试并提交**

运行：`flutter test test/scan/scan_preview_classifier_test.dart test/scan/scan_page_test.dart`

提交：`fix: keep live scan references stable`

### 任务 3：全局颜色容量分配

**文件：**
- 创建：`test/scan/minimum_cost_assignment_test.dart`
- 创建：`lib/scan/minimum_cost_assignment.dart`
- 修改：`test/scan/color_classifier_test.dart`
- 修改：`lib/scan/color_classifier.dart`

- [ ] **步骤 1：编写分配器和全局分类失败测试**

分配器测试使用可手算的 3×3 代价矩阵并断言列唯一、总代价为 5：

```dart
expect(
  minimumCostAssignment(const [
    [4, 1, 3],
    [2, 0, 5],
    [3, 2, 2],
  ]),
  [1, 0, 2],
);
```

分类测试构造两个都局部偏向红色、但配额要求其中一个为橙色的样本，断言最终每色恰好 9 格；另测试一个红色锁定格会把红色剩余容量减一；九个以上同色锁定时保留锁定结果并产生颜色数量硬错误。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/scan/minimum_cost_assignment_test.dart test/scan/color_classifier_test.dart`

预期：分配器不存在，现有逐格最近中心分类不能满足全局配额。

- [ ] **步骤 3：实现方阵最小代价分配**

在 `minimum_cost_assignment.dart` 实现 O(n³) Hungarian 算法：校验矩阵非空、方阵、所有代价有限；返回每一行选择的列索引。禁止添加第三方依赖。

- [ ] **步骤 4：将最终分类改为容量约束**

`ColorClassifier` 对每个面用自己的中心构造 `ScanColorMatcher`。中心与锁定格先写入结果并统计每色数量；未锁定格记录六色代价。把每个颜色剩余容量展开成槽位，使槽位总数等于未锁定格数；用 Hungarian 结果写入颜色。若任一锁色已超过九格，则跳过容量分配，按每格首选颜色完成结果，让现有 `CubeValidation` 报告数量错误。

`RecognitionHint.assignedFace` 使用最终分配颜色，`alternativeFace` 使用除已分配颜色外代价最低的颜色；置信度仍由两者代价差归一化。锁定格不产生 hint、uncertain 或画质 issue。

- [ ] **步骤 5：运行分类测试并提交**

运行：`flutter test test/scan/minimum_cost_assignment_test.dart test/scan/color_classifier_test.dart test/scan/scan_session_test.dart`

提交：`feat: constrain final scan color assignment`

### 任务 4：单面即时纠色、居中圆点与标准方位

**文件：**
- 修改：`test/scan/scan_page_test.dart`
- 修改：`lib/scan/scan_page.dart`
- 修改：`README.md`

- [ ] **步骤 1：编写 Widget 失败测试**

新增测试断言：实时 `live-recognition-dot-0` 的 `Align.alignment` 为 `Alignment.center`；拍照后点击 `preview-sticker-0` 会出现六个 `preview-color-*` 选择项；点击 `preview-color-right` 后 `locked-preview-0` 出现且接受此面后 `session.lockedFacesByFace[CubeFace.up]![0] == CubeFace.right`；中心 `preview-sticker-4` 不打开色板；重拍清空临时修改。

再逐面构建页面并断言文本包含：`白色 U 面 / 蓝色边朝上`、`红色 R 面 / 白色边朝上`、`绿色 F 面 / 白色边朝上`、`黄色 D 面 / 绿色边朝上`、`橙色 L 面 / 白色边朝上`、`蓝色 B 面 / 白色边朝上`。

- [ ] **步骤 2：运行失败测试**

运行：`flutter test test/scan/scan_page_test.dart`

预期：圆点 key、颜色选择器和完整颜色方位文案不存在。

- [ ] **步骤 3：实现预览改色和自动锁定**

新增 `_editPreviewColor(int index)`：中心索引 4 直接返回；用 `showModalBottomSheet<CubeFace>` 展示六个 `CubePalette` 色项；选择后执行：

```dart
setState(() => _lockedPreviewFaces[index] = selectedFace);
```

`_SamplePreview` 的九格使用 `preview-sticker-$index`，非中心点击调用编辑；颜色来自 `_applyPreviewColorLocks(recognizedFaces)`，锁图标保持现有 key。重拍路径继续清空 `_lockedPreviewFaces`。

- [ ] **步骤 4：居中圆点并统一提示词**

`_LiveRecognitionGrid` 的圆点改为 `Align(alignment: Alignment.center)` 并添加 `live-recognition-dot-$index`。扫描页顶部增加“标准方向：白色中心 = U，绿色中心 = F”；`_faceLabel` 返回颜色加字母，`_orientationHint` 返回具体颜色边朝上。README 删除任意配色兼容表述并使用相同六步文案。

- [ ] **步骤 5：运行扫描全量测试并提交**

运行：`flutter test test/scan`

提交：`feat: add immediate scan color correction`

### 任务 5：真实播放过渡动作

**文件：**
- 修改：`test/playback/move_player_test.dart`
- 修改：`test/playback/solution_page_test.dart`
- 修改：`lib/playback/move_player.dart`
- 修改：`lib/playback/solution_page.dart`

- [ ] **步骤 1：编写过渡动作失败测试**

断言：`next()` 后 `transitionMove` 是刚应用的动作，包括最后一步；`previous()` 后是被撤销动作的 `inverseMove`；跨两步 `seek()` 后为 null；相邻 seek 使用正确正向或逆向动作。播放页读取 `Cube3DView.move` 验证最后一步和上一步。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/playback/move_player_test.dart test/playback/solution_page_test.dart`

预期：`transitionMove` 不存在，最后一步的 `Cube3DView.move` 为 null。

- [ ] **步骤 3：实现显式过渡动作**

`MovePlayer` 增加 `SolutionMove? _transitionMove` 与只读 getter。`next` 在变更索引前取 `_moves[_currentIndex]`；`previous` 取 `_moves[_currentIndex - 1].inverseMove`；`seek` 只在目标与当前相差一时设置对应正/逆动作，跨步设置 null。`_setIndex` 接收 `transitionMove` 并在通知前保存。更新速度注释为四档。

`SolutionPage` 仅把 `_player.transitionMove` 传给 `Cube3DView.move`；说明文字和公式高亮继续使用 `currentMove`。

- [ ] **步骤 4：运行播放状态测试并提交**

运行：`flutter test test/playback/move_player_test.dart test/playback/solution_page_test.dart`

提交：`fix: animate actual solution transitions`

### 任务 6：三维背面剔除

**文件：**
- 修改：`test/playback/cube_3d_view_test.dart`
- 修改：`lib/playback/cube_3d_view.dart`

- [ ] **步骤 1：编写可见贴纸失败测试**

为 painter 提供只读测试 getter `visibleStickerCount`，默认视角的复原状态断言为 27；拖到相反 yaw 后仍为 27；R 层动画中断言所有被返回的可见贴纸法线均朝向相机。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/playback/cube_3d_view_test.dart`

预期：可见性 API 不存在，当前 painter 会加入全部 54 格。

- [ ] **步骤 3：实现法线剔除**

把贴纸 geometry 的法线经过 `_viewTransform`，只保留 `z > 1e-6` 的贴纸；实体面使用相同规则。剔除发生在旋转 geometry 计算后、投影和深度排序前。`visibleStickerCount` 复用同一内部 geometry 枚举，避免测试与绘制算法分叉。

- [ ] **步骤 4：运行三维与播放测试并提交**

运行：`flutter test test/playback`

提交：`fix: cull hidden 3d cube stickers`

### 任务 7：规整打乱 3×3 Android 图标与文档

**文件：**
- 修改：`android/app/src/main/res/drawable/ic_launcher_foreground.xml`
- 修改：`README.md`
- 修改：`assets/docs/update_notes.md`

- [ ] **步骤 1：重绘完整三面九格矢量**

保持 108×108 viewport 与深蓝背景。顶部、前面、右面各绘制 9 个带深色 1.2–1.5 宽描边的四边形；中心分别固定白、绿、红，其余按视觉稿 B 使用六色打乱。所有顶点限制在 adaptive icon 安全区约 18–90 内，避免圆形蒙版裁切。

- [ ] **步骤 2：验证资源结构与文档**

PowerShell 解析 `colors.xml`、foreground、v21、v26 四个 XML；脚本统计 foreground 中贴纸 path 为 27。README 和更新说明记录标准配色、稳定实时识别、全局九色容量、单面即时纠色、居中圆点、图标和播放修复。

- [ ] **步骤 3：构建并提交**

运行：`flutter build apk --release`

提交：`feat: improve scan recognition and launcher icon`

### 任务 8：完整验证与 Release-only 交付

**文件：**
- 仅修改验证暴露的具体问题文件。

- [ ] **步骤 1：格式和静态检查**

运行：`dart format .`、`dart format --output=none --set-exit-if-changed .`、`git diff --check`、`flutter analyze`。

- [ ] **步骤 2：全量测试**

运行：`flutter test`。

预期：所有测试通过，数量不少于当前 125 项。

- [ ] **步骤 3：Release 构建与签名**

运行：`flutter build apk --release`。使用 Android SDK 36.0.0 的 `apksigner verify --verbose --print-certs` 验证 `build/app/outputs/flutter-apk/app-release.apk`；安全读取同级 `heat_ex_designer/android/key.properties`，用 `keytool -list -v` 比较 JKS 和 APK 公开证书 SHA-256。不得输出密码。

- [ ] **步骤 4：最终状态**

运行：`git status --short --branch`、`git log --oneline --decorate -15`。预期 master 工作树洁净；最终只交付 Release APK。
