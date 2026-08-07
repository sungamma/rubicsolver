# 扫描锁色与三维引导实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现轻量扫描提示、逐格/整面锁色、确认后解除低置信度阻断、可拖动复位的三维层旋转播放、慢动作和魔方主题 Android 图标。

**架构：** 锁色作为 `ScanSession` 的独立标签覆盖层传入 `ColorClassifier`，原始 RGB 数据保持不变；校验页把识别质量与物理合法性拆成软/硬门槛。三维视图使用纯 Dart 向量投影 54 枚贴纸并对当前层做轴旋转，播放状态仍由 `MovePlayer` 唯一驱动。

**技术栈：** Flutter、Dart、camera、CustomPainter、Android Vector Drawable、flutter_test

---

### 任务 1：扫描锁色数据模型

**文件：**
- 修改：`test/scan/scan_session_test.dart`
- 修改：`test/scan/color_classifier_test.dart`
- 修改：`lib/scan/scan_session.dart`
- 修改：`lib/scan/color_classifier.dart`

- [ ] **步骤 1：编写失败测试**

在 `scan_session_test.dart` 中接受当前面时传入 `{0: CubeFace.right}`，断言 `lockedFacesByFace[CubeFace.up]![0]` 为 `right`，并断言 `restartFrom(CubeFace.up)` 后映射被删除。在 `color_classifier_test.dart` 中构造一个自动会判为绿色的样本，但用锁定映射指定为红色，断言结果贴纸为红色且该索引不在 `uncertainStickerIndices` 和 `recognitionHints`。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/scan/scan_session_test.dart test/scan/color_classifier_test.dart`

预期：因 `acceptCurrent`/`classify` 尚无 `lockedFaces` 参数而编译失败。

- [ ] **步骤 3：实现最小数据模型**

为 `ScanSession` 增加不可变 getter `lockedFacesByFace`；`acceptCurrent(samples, {Map<int, CubeFace> lockedFaces = const {}})` 校验索引 0–8，并强制中心索引 4 为当前面。`ColorClassifier.classify` 接收 `lockedFacesByFace`，非中心锁定格直接使用指定面且跳过自动 hint/uncertain。

- [ ] **步骤 4：运行目标测试至通过并提交**

运行：`flutter test test/scan/scan_session_test.dart test/scan/color_classifier_test.dart`

提交：`feat: persist locked scan colors`

### 任务 2：轻量提示层和拍摄锁色交互

**文件：**
- 修改：`test/scan/scan_page_test.dart`
- 修改：`lib/scan/scan_page.dart`

- [ ] **步骤 1：编写失败 Widget 测试**

相机发出实时帧后，读取 `live-recognition-0` 的 `BoxDecoration`，断言背景透明度不高于 0.12；断言存在 `lock-current-colors`；点击 `live-recognition-0` 后出现 `locked-recognition-0`，点击拍摄和接受后断言会话的锁定映射包含索引 0。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/scan/scan_page_test.dart`

预期：锁定控件和 key 不存在，原背景透明度为 0.72。

- [ ] **步骤 3：实现交互**

`ScanPage` 为当前面维护 `_lockedPreviewFaces`；实时网格用透明背景、标准色边框和右上角 24dp 色点。单格点击锁定/解锁当前识别色；整面按钮锁定九格或清空。接受预览时把映射传入 `ScanSession.acceptCurrent`，重拍、进入下一面和从某面重扫时清空临时映射。

- [ ] **步骤 4：验证扫描测试并提交**

运行：`flutter test test/scan`

提交：`feat: add scan color locking controls`

### 任务 3：用户确认后放行合法状态

**文件：**
- 修改：`test/editor/cube_editor_page_test.dart`
- 修改：`lib/editor/cube_editor_page.dart`

- [ ] **步骤 1：编写失败 Widget 测试**

用合法复原状态、一个低置信度索引和一个画质 issue 构建编辑器；初始求解按钮禁用，点击“我已核对，使用当前颜色”后按钮启用且低置信度提示消失。另用颜色数量非法状态执行同样确认，断言按钮仍禁用。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/editor/cube_editor_page_test.dart`

预期：确认按钮不存在。

- [ ] **步骤 3：实现软警告确认**

增加 `_recognitionWarningsAcknowledged`。只在未确认时把 uncertain 加入高亮；`canSolve = _validation.isValid && (!hasRecognitionWarnings || acknowledged)`。警告卡改为说明性颜色，并提供确认按钮；确认后显示“已使用当前颜色，物理校验通过”。

- [ ] **步骤 4：验证编辑器测试并提交**

运行：`flutter test test/editor`

提交：`fix: allow confirmed cube states to solve`

### 任务 4：可查看三维魔方、箭头与慢动作

**文件：**
- 修改：`test/playback/cube_3d_view_test.dart`
- 修改：`test/playback/move_player_test.dart`
- 修改：`test/playback/solution_page_test.dart`
- 修改：`lib/playback/cube_3d_view.dart`
- 修改：`lib/playback/move_player.dart`
- 修改：`lib/playback/solution_page.dart`

- [ ] **步骤 1：编写失败测试**

三维视图测试拖动后读取 `Cube3DPainter.yaw/pitch` 发生变化；点击 `reset-cube-view` 后恢复 `defaultCubeYaw/defaultCubePitch`；动作 `R'` 显示 `turn-arrow-counter-clockwise`。播放器测试接受 2400 ms；播放页速度菜单包含“慢动作 · 2.4 秒”。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/playback`

预期：painter 无视角字段、复位/箭头 key 不存在、2400 ms 被拒绝。

- [ ] **步骤 3：实现六面投影和层旋转**

在 `cube_3d_view.dart` 内定义私有三维向量、贴纸四边形和旋转/投影函数。生成 URFDLB 六面的 54 个贴纸；动画期间把属于当前层的旧状态贴纸绕面法向旋转 `-signedQuarterTurns * pi/2 * progress`，变换到 yaw/pitch 后按深度排序绘制。手势更新视角并限制 pitch。

- [ ] **步骤 4：实现视角与方向控件**

视图左上角加入 key `reset-cube-view` 的复位按钮；右侧加入顺/逆/180° 箭头 key；底部显示拖动和复位引导。`SolutionPage` 按 `_player.speed` 传入 380/720/1200/2100 ms 动画时长。

- [ ] **步骤 5：增加慢动作并验证提交**

`MovePlayer._validateSpeed` 接受 2400 ms，速度菜单增加对应选项。运行：`flutter test test/playback`。

提交：`feat: add interactive 3d turn guidance`

### 任务 5：魔方主题 Android 图标和说明

**文件：**
- 创建：`android/app/src/main/res/values/colors.xml`
- 创建：`android/app/src/main/res/drawable/ic_launcher_foreground.xml`
- 创建：`android/app/src/main/res/mipmap-anydpi-v21/ic_launcher.xml`
- 创建：`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- 修改：`README.md`
- 修改：`assets/docs/update_notes.md`

- [ ] **步骤 1：创建原生矢量资源**

用深蓝圆角背景和等距魔方六色贴纸构成前景；v21 legacy 图标引用完整矢量，v26 adaptive icon 引用背景色和前景。

- [ ] **步骤 2：验证资源和说明**

运行 PowerShell XML 解析检查四个资源；README 记录扫描锁定、确认放行、3D 拖动/复位和慢动作；更新说明增加本轮改进。

- [ ] **步骤 3：构建并提交**

运行：`flutter build apk --debug`

提交：`feat: add Rubik cube launcher icon`

### 任务 6：完整验证

**文件：**
- 仅修改由格式化、分析、测试或构建暴露出的具体问题文件。

- [ ] **步骤 1：格式与差异检查**

运行：`dart format .`、`dart format --output=none --set-exit-if-changed .`、`git diff --check`。

- [ ] **步骤 2：静态分析与全量测试**

运行：`flutter analyze`、`flutter test`。

- [ ] **步骤 3：Android 构建与签名**

运行：`flutter build apk --debug`、`flutter build apk --release`，再用 `apksigner` 验证 Release APK，并比较本机 JKS 与 APK 的公开证书 SHA-256 指纹。

- [ ] **步骤 4：最终状态**

运行：`git status --short --branch` 和 `git log --oneline --decorate -12`。预期 master 工作树洁净，所有阶段均已提交。
