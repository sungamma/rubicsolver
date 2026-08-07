# Rubik Solver App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一款可通过手机相机采集 3×3 魔方、校验并编辑识别结果、离线求解和逐步播放解法的 Flutter 应用。

**Architecture:** 业务规则按 `cube/scan/solver/playback/update` 分区，保持纯 Dart 核心与 Flutter UI 分离。相机照片在本地转换为九格 RGB 样本，以六个中心色为动态 Lab 参考；合法状态交给 `cuber` 的 Kociemba 两阶段算法在 isolate 中计算，结果由二维展开图播放器演示。

**Tech Stack:** Flutter 3.32.1、Dart 3.8.1、Material 3、camera、image、cuber、http、yaml、package_info_plus、path_provider、permission_handler、open_filex、shared_preferences、flutter_test。

---

## 文件结构

```text
lib/
  main.dart                         入口
  app/rubik_solver_app.dart        MaterialApp、主题与首页
  app/app_info.dart                产品、作者和仓库常量
  cube/cube_face.dart              URFDLB 面定义
  cube/cube_palette.dart           实体颜色及显示颜色
  cube/cube_state.dart             54 贴纸不可变状态
  cube/cube_validation.dart        数量与物理合法性校验、错误建议
  scan/color_math.dart             sRGB、XYZ、Lab 与 Delta E
  scan/sticker_sample.dart         单格采样质量数据
  scan/face_sampler.dart           图像裁剪及 3×3 采样
  scan/color_classifier.dart       动态中心色分类与置信度
  scan/scan_session.dart           六面采集状态
  scan/scan_page.dart              相机采集向导
  editor/cube_net.dart             可复用魔方展开图
  editor/cube_editor_page.dart     校验、提示和点选纠错
  solver/cube_solver.dart          cuber 校验/求解适配及 isolate 入口
  solver/solution_move.dart        动作记号与中文说明
  playback/move_player.dart        可回放状态机
  playback/solution_page.dart      解法列表与播放控制
  update/version_number.dart       版本比较
  update/update_service.dart       GitHub 检查、下载及安装
  settings/about_page.dart         作者、隐私和算法说明
test/
  cube/cube_state_test.dart
  cube/cube_validation_test.dart
  scan/color_math_test.dart
  scan/face_sampler_test.dart
  scan/color_classifier_test.dart
  solver/cube_solver_test.dart
  playback/move_player_test.dart
  update/version_number_test.dart
  app/home_page_test.dart
  editor/cube_editor_page_test.dart
  playback/solution_page_test.dart
```

## Task 1: 创建工程并复用身份、签名和平台配置

**Files:**
- Create: Flutter 生成的 Android/iOS 工程文件
- Create: `lib/app/app_info.dart`
- Modify: `pubspec.yaml`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Local-only, ignored: `android/key.properties`
- Local-only, ignored: the JKS file referenced by `key.properties`

- [ ] **Step 1: 生成最小 Flutter 工程**

Run:

```powershell
flutter create --project-name rubicsolver --org com.sungamma --platforms=android,ios .
```

Expected: 创建工程，Android application id 默认为 `com.sungamma.rubicsolver`。

- [ ] **Step 2: 添加已核对 SDK 兼容性的依赖**

Run:

```powershell
flutter pub add camera image cuber http yaml package_info_plus path_provider permission_handler open_filex shared_preferences
flutter pub add --dev flutter_lints
```

Expected: `flutter pub get` 成功，`cuber` 解析为 `0.4.0`。

- [ ] **Step 3: 写入应用身份常量**

Create `lib/app/app_info.dart`:

```dart
abstract final class AppInfo {
  static const name = '魔方复原';
  static const packageName = 'rubicsolver';
  static const applicationId = 'com.sungamma.rubicsolver';
  static const author = 'Wei Xu';
  static const email = 'sungamma@gmail.com';
  static const repositoryOwner = 'sungamma';
  static const repositoryName = 'flutter-learn';
  static const repositoryPath = 'rubicsolver';
}
```

- [ ] **Step 4: 复用签名文件并配置 release signing**

Reuse `../heat_ex_designer/android/key.properties` and its referenced JKS file locally without printing their contents or adding either file to Git. In `android/app/build.gradle.kts`, load `../key.properties`, create the `release` signing config and assign it to the release build type. Keep the new application id instead of the heat-exchanger id.

- [ ] **Step 5: 配置相机、网络和安装权限**

Android manifest must contain:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
<uses-feature android:name="android.hardware.camera.any" android:required="false" />
```

iOS `Info.plist` must contain `NSCameraUsageDescription` with value `用于识别魔方六个面的贴纸颜色。`.

- [ ] **Step 6: 验证生成工程**

Run:

```powershell
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Expected: all commands exit 0.

- [ ] **Step 7: 提交工程基线**

```powershell
git add .
git commit -m "chore: scaffold Flutter Rubik solver app"
```

## Task 2: 以 TDD 实现魔方状态与校验

**Files:**
- Create: `lib/cube/cube_face.dart`
- Create: `lib/cube/cube_palette.dart`
- Create: `lib/cube/cube_state.dart`
- Create: `lib/cube/cube_validation.dart`
- Test: `test/cube/cube_state_test.dart`
- Test: `test/cube/cube_validation_test.dart`

- [ ] **Step 1: 写 CubeState 失败测试**

```dart
test('solved state serializes in URFDLB order', () {
  expect(
    CubeState.solved().toFacelets(),
    'UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB',
  );
});

test('center stickers cannot be edited', () {
  expect(
    () => CubeState.solved().replaceSticker(4, CubeFace.front),
    throwsArgumentError,
  );
});
```

- [ ] **Step 2: 运行测试并确认因类型不存在而失败**

Run: `flutter test test/cube/cube_state_test.dart`

Expected: FAIL because `CubeState` and `CubeFace` are not defined.

- [ ] **Step 3: 实现不可变状态 API**

`CubeFace.values` order must be `up, right, front, down, left, back`. `CubeState` must validate a 54-item list, expose an unmodifiable sticker list, serialize by each face letter, provide `solved()`, `fromFacelets(String)`, `replaceSticker(int, CubeFace)`, `countByFace()` and `isCenterIndex(int)`.

- [ ] **Step 4: 运行 CubeState 测试直至通过**

Run: `flutter test test/cube/cube_state_test.dart`

Expected: PASS.

- [ ] **Step 5: 写校验与错误建议失败测试**

```dart
test('solved cube is valid', () {
  expect(const CubeValidator().validate(CubeState.solved()).isValid, isTrue);
});

test('reports surplus and missing colors', () {
  final invalid = CubeState.solved().replaceSticker(0, CubeFace.front);
  final result = const CubeValidator().validate(invalid);
  expect(result.isValid, isFalse);
  expect(result.issues.map((issue) => issue.code),
      containsAll(['color-count-up', 'color-count-front']));
});

test('maps a single flipped edge to a Chinese physical error', () {
  final stickers = CubeState.solved().stickers.toList();
  final temp = stickers[7];
  stickers[7] = stickers[19];
  stickers[19] = temp;
  final result = const CubeValidator().validate(CubeState(stickers));
  expect(result.issues.single.message, contains('棱块'));
});
```

- [ ] **Step 6: 运行校验测试并确认失败**

Run: `flutter test test/cube/cube_validation_test.dart`

Expected: FAIL because validator classes are missing.

- [ ] **Step 7: 实现三层校验结果模型**

Create immutable `ValidationIssue`, `ValidationResult` and `CubeValidator`. Count checks run before `cuber.Cube.from(...).verify()`. Map statuses as follows:

```dart
const statusMessages = {
  cuber.CubeStatus.missingEdge: '棱块颜色组合不存在或出现重复，请检查高亮贴纸。',
  cuber.CubeStatus.twistedEdge: '检测到单个棱块翻转，这不是合法魔方状态。',
  cuber.CubeStatus.missingCorner: '角块颜色组合不存在或出现重复，请检查高亮贴纸。',
  cuber.CubeStatus.twistedCorner: '检测到角块扭转错误，请检查角落贴纸方向。',
  cuber.CubeStatus.parityError: '角块和棱块的排列奇偶性不一致，请复查识别结果。',
};
```

- [ ] **Step 8: 运行领域测试与静态分析**

Run:

```powershell
flutter test test/cube
flutter analyze
```

Expected: PASS and no analyzer issues.

- [ ] **Step 9: 提交领域核心**

```powershell
git add lib/cube test/cube
git commit -m "feat: validate editable Rubik cube states"
```

## Task 3: 以 TDD 实现照片采样和动态颜色识别

**Files:**
- Create: `lib/scan/color_math.dart`
- Create: `lib/scan/sticker_sample.dart`
- Create: `lib/scan/face_sampler.dart`
- Create: `lib/scan/color_classifier.dart`
- Test: `test/scan/color_math_test.dart`
- Test: `test/scan/face_sampler_test.dart`
- Test: `test/scan/color_classifier_test.dart`

- [ ] **Step 1: 写颜色数学失败测试**

```dart
test('identical colors have zero delta E', () {
  const rgb = RgbColor(255, 0, 0);
  expect(deltaE76(rgb.toLab(), rgb.toLab()), closeTo(0, 1e-9));
});

test('white is lighter than black in Lab', () {
  expect(const RgbColor(255, 255, 255).toLab().l,
      greaterThan(const RgbColor(0, 0, 0).toLab().l));
});
```

- [ ] **Step 2: 验证失败并实现 sRGB → XYZ → Lab**

Run: `flutter test test/scan/color_math_test.dart`

Expected before implementation: FAIL. Implement D65 conversion and Delta E 76, then rerun for PASS.

- [ ] **Step 3: 写合成图像九格采样失败测试**

Build a 300×300 `image.Image`, fill each 100×100 cell with a known color, encode it, call `FaceSampler.sample(bytes)`, and assert nine samples plus approximate center RGB values. Add tests for low-light, overexposure and high-variance flags.

- [ ] **Step 4: 实现 FaceSampler 最小功能**

Decode bytes, bake orientation, center-crop to a square, sample the central 60% of each cell, trim luminance outliers, and return nine `StickerSample` values. Invalid bytes throw `FaceSamplingException` with a user-readable Chinese message.

- [ ] **Step 5: 写六中心动态分类失败测试**

```dart
test('classifies stickers against scanned center colors', () {
  final result = ColorClassifier().classify(
    samplesByFace: syntheticSixFaceSamples(),
  );
  expect(result.state, CubeState.solved());
  expect(result.uncertainStickerIndices, isEmpty);
});
```

Also test an ambiguous sticker produces a low-confidence index and records a second-best face.

- [ ] **Step 6: 实现 ColorClassifier 与纠错建议元数据**

Center samples are forced to their captured face. Other samples choose the smallest Delta E; confidence is `(secondDistance - bestDistance) / max(secondDistance, 1)`. Preserve best and second face labels for validator suggestions.

- [ ] **Step 7: 运行扫描核心测试**

Run:

```powershell
flutter test test/scan
flutter analyze
```

Expected: PASS and no analyzer issues.

- [ ] **Step 8: 提交本地识别核心**

```powershell
git add lib/scan test/scan
git commit -m "feat: recognize cube colors from guided photos"
```

## Task 4: 实现相机向导、展开图和可编辑校验页

**Files:**
- Create: `lib/scan/scan_session.dart`
- Create: `lib/scan/scan_page.dart`
- Create: `lib/editor/cube_net.dart`
- Create: `lib/editor/cube_editor_page.dart`
- Modify: `lib/app/rubik_solver_app.dart`
- Test: `test/app/home_page_test.dart`
- Test: `test/editor/cube_editor_page_test.dart`

- [ ] **Step 1: 写首页入口 Widget 失败测试**

```dart
testWidgets('home exposes scan and manual entry', (tester) async {
  await tester.pumpWidget(const RubikSolverApp());
  expect(find.text('开始扫描'), findsOneWidget);
  expect(find.text('手动录入'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试确认失败，再实现 Material 3 首页**

Run: `flutter test test/app/home_page_test.dart`

Expected before implementation: FAIL. Implement a responsive home page with the two required actions, privacy copy, algorithm badge and settings action, then rerun for PASS.

- [ ] **Step 3: 写编辑器行为失败测试**

```dart
testWidgets('invalid state disables solving and a sticker can be corrected',
    (tester) async {
  final invalid = CubeState.solved().replaceSticker(0, CubeFace.front);
  await tester.pumpWidget(testApp(CubeEditorPage(initialState: invalid)));
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '开始求解')).onPressed,
      isNull);
  await tester.tap(find.byKey(const ValueKey('sticker-0')));
  await tester.tap(find.text('上面颜色').last);
  await tester.pumpAndSettle();
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '开始求解')).onPressed,
      isNotNull);
});
```

- [ ] **Step 4: 实现 CubeNet 和 CubeEditorPage**

Render positions `U` above, `L F R B` in the middle and `D` below. Each sticker has a stable key. Centers are visually locked. The editor shows color counts, validation issues, uncertain sticker outlines, reset-to-solved and rescan-face actions.

- [ ] **Step 5: 实现 ScanSession 与相机向导**

`ScanSession` owns accepted samples in URFDLB order. `ScanPage` initializes the back camera, provides flash toggle when supported, overlays a square 3×3 guide, captures an `XFile`, invokes `FaceSampler`, shows a preview, and allows accept/retry. Camera denial or absence shows a manual-entry button instead of a dead end.

- [ ] **Step 6: 验证 UI 阶段**

Run:

```powershell
flutter test test/app test/editor
flutter analyze
```

Expected: PASS and no analyzer issues.

- [ ] **Step 7: 提交采集与纠错流程**

```powershell
git add lib/app lib/scan lib/editor test/app test/editor
git commit -m "feat: add guided camera scan and correction flow"
```

## Task 5: 以 TDD 接入 Kociemba 求解并实现播放器

**Files:**
- Create: `lib/solver/cube_solver.dart`
- Create: `lib/solver/solution_move.dart`
- Create: `lib/playback/move_player.dart`
- Create: `lib/playback/solution_page.dart`
- Modify: `lib/editor/cube_editor_page.dart`
- Test: `test/solver/cube_solver_test.dart`
- Test: `test/playback/move_player_test.dart`
- Test: `test/playback/solution_page_test.dart`

- [ ] **Step 1: 写真实求解失败测试**

```dart
test('solution solves a short scramble', () async {
  final scrambled = CubeSolver.applyAlgorithm(CubeState.solved(), "R U R' U'");
  final moves = await const CubeSolver().solve(scrambled);
  final solved = CubeSolver.applyMoves(scrambled, moves);
  expect(solved, CubeState.solved());
});
```

Add solved-state and invalid-state tests. The invalid state must throw `InvalidCubeException` before invoking the solver.

- [ ] **Step 2: 运行测试确认失败，再实现 solver 适配**

Run: `flutter test test/solver/cube_solver_test.dart`

Expected before implementation: FAIL. Use `cuber.Cube.from`, `cuber.Algorithm.parse`, `Cube.solve(maxDepth: 25, timeout: 30 seconds)` and `Isolate.run`. Convert `null` to `SolveTimeoutException` and `Solution.empty` to an empty move list.

- [ ] **Step 3: 写 MovePlayer 状态机失败测试**

```dart
test('seek and previous rebuild exact cube state', () {
  final initial = CubeSolver.applyAlgorithm(CubeState.solved(), 'R U');
  final player = MovePlayer(initial: initial, moves: const [
    SolutionMove("U'"),
    SolutionMove("R'"),
  ]);
  player.seek(2);
  expect(player.currentState, CubeState.solved());
  player.previous();
  expect(player.currentIndex, 1);
});
```

- [ ] **Step 4: 实现动作模型与播放器**

`SolutionMove` validates `[URFDLB](2|')?`, exposes `face`, `turns`, `notation`, and Chinese instruction. `MovePlayer` extends `ChangeNotifier`, provides `next`, `previous`, `seek`, `play`, `pause`, `speed`, `currentState`, `currentMove` and `isComplete`. Seeking always replays from the immutable initial state.

- [ ] **Step 5: 写播放页 Widget 失败测试**

Assert the page shows the complete formula, updates step text after tapping “下一步”, toggles play/pause, and permits tapping a move chip to seek.

- [ ] **Step 6: 实现 SolutionPage 并串联编辑器**

After validation, editor starts an async solve with a blocking progress surface. On success, push `SolutionPage`. The page keeps `CubeNet`, current instruction, formula chips, previous/play/next, speed selector and progress visible on phone portrait layouts.

- [ ] **Step 7: 验证求解和播放阶段**

Run:

```powershell
flutter test test/solver test/playback
flutter analyze
```

Expected: the real scramble is solved, all widget tests pass, analyzer is clean.

- [ ] **Step 8: 提交求解与播放**

```powershell
git add lib/solver lib/playback lib/editor test/solver test/playback
git commit -m "feat: solve and play Rubik cube algorithms"
```

## Task 6: 复用更新能力并补齐关于信息

**Files:**
- Create: `lib/update/version_number.dart`
- Create: `lib/update/update_service.dart`
- Create: `lib/settings/about_page.dart`
- Create: `assets/docs/update_notes.md`
- Modify: `lib/app/rubik_solver_app.dart`
- Test: `test/update/version_number_test.dart`
- Modify: `test/app/home_page_test.dart`

- [ ] **Step 1: 写版本比较失败测试**

```dart
test('compares semantic version and Flutter build number', () {
  expect(VersionNumber.parse('1.2.0+4') > VersionNumber.parse('1.1.9+99'), isTrue);
  expect(VersionNumber.parse('1.2.0+4') > VersionNumber.parse('1.2.0+3'), isTrue);
  expect(VersionNumber.parse('1.2.0') == VersionNumber.parse('1.2.0+0'), isTrue);
});
```

- [ ] **Step 2: 验证失败并实现 VersionNumber**

Run: `flutter test test/update/version_number_test.dart`

Expected before implementation: FAIL; after implementation: PASS. Reject malformed remote versions without crashing startup.

- [ ] **Step 3: 实现 GitHub 更新服务**

Fetch `https://raw.githubusercontent.com/sungamma/flutter-learn/master/rubicsolver/pubspec.yaml`, parse its `version`, compare with `PackageInfo`. If newer, resolve release tag `rubicsolver<version>` and asset `app-release.apk`, stream it to an application support/download directory, expose progress, request install-package permission on Android, then open it with `OpenFilex`. The optional GitHub token comes only from `String.fromEnvironment('GITHUB_TOKEN')`.

- [ ] **Step 4: 实现关于页与自动检查策略**

Show application version, `Wei Xu`, `sungamma@gmail.com`, Kociemba/cuber MIT attribution, local-photo privacy statement, manual update button and copied update notes. Startup checks at most once every seven days through `SharedPreferences`; a failed check is silent and never blocks the home page.

- [ ] **Step 5: 验证更新与关于信息**

Run:

```powershell
flutter test test/update test/app
flutter analyze
```

Expected: PASS and no analyzer issues.

- [ ] **Step 6: 提交更新和作者信息**

```powershell
git add lib/update lib/settings lib/app assets test/update test/app pubspec.yaml
git commit -m "feat: add signed updates and author information"
```

## Task 7: 完成说明、视觉细节和交付验证

**Files:**
- Modify: `README.md`
- Create: `LICENSES/cuber.txt`
- Modify: `assets/docs/update_notes.md`
- Modify: UI files only where verification exposes concrete layout/accessibility issues

- [ ] **Step 1: 写交付说明**

README must document scan orientation, manual correction, move notation, privacy, supported platforms, debug/release build commands, signing reuse, release tag/asset naming and known limitation that Kociemba solutions are fast but not guaranteed mathematically shortest.

- [ ] **Step 2: 保存第三方许可证**

Copy the MIT license text for `tiagohm/cuber` to `LICENSES/cuber.txt` and mention it on the about page.

- [ ] **Step 3: 运行格式化检查**

Run:

```powershell
dart format .
dart format --output=none --set-exit-if-changed .
```

Expected: second command exits 0.

- [ ] **Step 4: 运行完整分析和测试**

Run:

```powershell
flutter analyze
flutter test
```

Expected: analyzer reports no issues and all tests pass.

- [ ] **Step 5: 构建 Android 调试包**

Run: `flutter build apk --debug`

Expected: exit 0 and `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 6: 验证 release 签名配置**

Run: `flutter build apk --release`

Expected: exit 0 and signed `build/app/outputs/flutter-apk/app-release.apk` exists. Do not print signing secrets.

- [ ] **Step 7: 检查仓库差异和阶段提交**

Run:

```powershell
git diff --check
git status --short
```

Expected: only intended delivery files are pending and no whitespace errors exist.

- [ ] **Step 8: 提交交付版本**

```powershell
git add .
git commit -m "docs: finish Rubik solver app delivery"
```

- [ ] **Step 9: 最终证据检查**

Run:

```powershell
git status --short --branch
git log --oneline --decorate -10
flutter analyze
flutter test
flutter build apk --release
```

Expected: `master` worktree clean; analysis, tests and release build all exit 0.
