# Live Scan, 3D Playback, and Color Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现相机九格实时识别覆盖层、三维还原播放器和统一标准魔方色板。

**Architecture:** 相机插件帧先适配为独立数据模型，再由纯 Dart 取样器和预览分类器产生九格标准色；高分辨率拍照流程保持不变。播放器继续使用 `MovePlayer`，仅将二维展开图替换为由 `CubeState` 驱动的原生等距三维画布。

**Tech Stack:** Flutter、Dart、camera、CustomPainter、flutter_test

---

### Task 1: 锁定标准显示色

**Files:**
- Modify: `test/cube/cube_palette_test.dart`
- Modify: `test/editor/cube_editor_page_test.dart`
- Modify: `lib/cube/cube_palette.dart`
- Modify: `lib/editor/cube_display_colors.dart`

- [ ] **Step 1: 写标准十六进制色与显示归一化失败测试**

为六个面断言 `0xFFFFFFFF`、`0xFFB71234`、`0xFF009B48`、`0xFFFFD500`、`0xFFFF5800`、`0xFF0046AD`；编辑器传入偏暗中心 RGB 后仍断言贴纸和选项使用 `CubePalette.colorFor(face)`。

- [ ] **Step 2: 运行测试并确认因旧色板和原始中心色覆盖而失败**

Run: `flutter test test/cube/cube_palette_test.dart test/editor/cube_editor_page_test.dart`

Expected: FAIL，差异值来自旧色板或 `centerColors`。

- [ ] **Step 3: 实现最小显示色修改**

更新 `CubePalette.colorFor` 的六个常量；让 `CubeDisplayColors.colorFor` 与 `foregroundFor` 始终委托给 `CubePalette`，保留参数以兼容现有调用。

- [ ] **Step 4: 运行目标测试至通过**

Run: `flutter test test/cube/cube_palette_test.dart test/editor/cube_editor_page_test.dart`

Expected: PASS。

### Task 2: 实时相机帧取样与标准色分类

**Files:**
- Create: `lib/scan/camera_frame_sampler.dart`
- Create: `lib/scan/scan_preview_classifier.dart`
- Create: `test/scan/camera_frame_sampler_test.dart`
- Create: `test/scan/scan_preview_classifier_test.dart`
- Modify: `lib/scan/scan_camera.dart`

- [ ] **Step 1: 写 BGRA、YUV420 和朝向失败测试**

构造 90×90 的 BGRA 三色网格，断言九格按屏幕方向返回；构造常量 YUV420 帧，断言返回九个近似 RGB 样本；将同一网格设为一个顺时针 quarter turn，断言第一格来自旋转后的正确原始坐标。

- [ ] **Step 2: 运行取样测试并确认类型不存在**

Run: `flutter test test/scan/camera_frame_sampler_test.dart`

Expected: FAIL because `ScanCameraFrame` and `CameraFrameSampler` do not exist.

- [ ] **Step 3: 实现独立帧模型和稀疏九格取样**

`ScanCameraPlane` 保存字节、row stride 和 pixel stride；`ScanCameraFrame` 保存尺寸、格式、平面和顺时针 quarter turns；`CameraFrameSampler.sample` 对每格取 7×7 点，转换 BGRA/YUV 到 RGB 并计算均值与亮度方差。

- [ ] **Step 4: 运行取样测试至通过**

Run: `flutter test test/scan/camera_frame_sampler_test.dart`

Expected: PASS。

- [ ] **Step 5: 写预览分类失败测试**

用接近标准色的九个样本断言最近色分类；用错误颜色的中心样本断言中心仍固定为当前面；提供已扫描中心色后断言它优先于默认标准参考色。

- [ ] **Step 6: 实现 `ScanPreviewClassifier`**

将标准 `Color` 转为 `RgbColor`，用已采集中心和当前中心覆盖默认参考，按 Delta E 76 选择最近 `CubeFace`，并固定索引 4。

- [ ] **Step 7: 扩展相机适配器并运行测试**

`ScanCameraController` 增加 `startImageStream`/`stopImageStream`；插件层复制 `CameraImage` 平面并计算后置相机屏幕朝向。Run: `flutter test test/scan/camera_frame_sampler_test.dart test/scan/scan_preview_classifier_test.dart`，Expected: PASS。

### Task 3: 在扫描页显示实时识别九格

**Files:**
- Modify: `test/scan/scan_page_test.dart`
- Modify: `lib/scan/scan_page.dart`

- [ ] **Step 1: 写图像流 UI 失败测试**

测试假相机发出一帧后出现 key `live-recognition-grid`，九个格子带 `live-recognition-0..8` key，且显示识别色名；再断言点击拍摄前停止图像流。

- [ ] **Step 2: 运行测试并确认覆盖层不存在**

Run: `flutter test test/scan/scan_page_test.dart`

Expected: FAIL at `find.byKey(const ValueKey('live-recognition-grid'))`.

- [ ] **Step 3: 实现节流、生命周期和覆盖层**

相机初始化后启动流；每 250ms 最多处理一帧；用 `CameraFrameSampler` 和 `ScanPreviewClassifier` 更新状态；在 `_CaptureGuide` 的 3×3 引导格内绘制半透明标准色、中文简称及低质量警告。拍照前停止流，失败后安全重启。

- [ ] **Step 4: 验证扫描回归**

Run: `flutter test test/scan`

Expected: PASS，现有相机生命周期测试无回归。

### Task 4: 三维魔方还原视图

**Files:**
- Create: `lib/playback/cube_3d_view.dart`
- Create: `test/playback/cube_3d_view_test.dart`
- Modify: `test/playback/solution_page_test.dart`
- Modify: `lib/playback/solution_page.dart`

- [ ] **Step 1: 写三维视图失败测试**

断言 `Cube3DView` 构建 `CustomPaint`，画布语义包含“三维魔方”；状态变化后 `Cube3DPainter.state` 等于新状态。播放页断言存在 `Cube3DView` 且不存在 `CubeNet`。

- [ ] **Step 2: 运行测试并确认组件不存在**

Run: `flutter test test/playback/cube_3d_view_test.dart test/playback/solution_page_test.dart`

Expected: FAIL because `Cube3DView` is not defined.

- [ ] **Step 3: 实现等距三维画布与状态动画**

`Cube3DView` 保存上一状态并用 `AnimationController` 驱动 320ms 插值；`Cube3DPainter` 绘制阴影、黑色基体和 U/F/R 三个 3×3 四边形贴纸面，颜色来自 `CubePalette`，当前动作面使用主题强调色描边。

- [ ] **Step 4: 替换播放页二维展开图**

在 `SolutionPage` 中用 `Cube3DView(state: _player.currentState, move: _player.currentMove)` 替换 `CubeNet`，保留原进度、说明、控制和公式布局。

- [ ] **Step 5: 验证播放器回归**

Run: `flutter test test/playback`

Expected: PASS，自动播放、跳转、窄屏布局均无回归。

### Task 5: 完整验证

**Files:**
- Modify only files exposed by concrete formatter, analyzer, test, or build failures.

- [ ] **Step 1: 格式化并确认无差异**

Run: `dart format .` then `dart format --output=none --set-exit-if-changed .`

Expected: second command exits 0.

- [ ] **Step 2: 运行静态分析和完整测试**

Run: `flutter analyze` and `flutter test`

Expected: analyzer reports no issues; all tests pass.

- [ ] **Step 3: 构建 Android debug APK**

Run: `flutter build apk --debug`

Expected: exit 0 and `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 4: 检查最终差异**

Run: `git diff --check` and `git status --short`

Expected: no whitespace errors; only this feature's source, tests, and docs are changed.
