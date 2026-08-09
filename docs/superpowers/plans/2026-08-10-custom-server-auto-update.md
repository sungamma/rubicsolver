# Rubik Solver 自定义服务器自动更新实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让 Rubik Solver 从 heat_ex_designer 使用的 HTTPS 服务器自动检查 `1.1.1+3` 更新，提示用户下载并打开系统安装器，同时提供可重复执行的 Android Release 部署脚本。

**架构：** `UpdateService` 作为唯一网络与安装边界，读取 Rubik Solver 专属版本、Markdown 和 APK 端点；共享的 `showUpdateDialog` 管理提示、下载进度和错误；`RubikSolverApp` 通过根导航器在首帧后显示自动检查结果。根目录 `deploy.bat` 委托工作区共享发布脚本，把正式签名 APK、版本文件和更新说明复制到同一服务器发布目录。

**技术栈：** Flutter/Dart、package:http、SharedPreferences、open_filex、permission_handler、flutter_test、Windows batch、Android SDK apksigner

---

## 文件结构

- 修改：`lib/update/update_service.dart` — 自定义服务器协议、Basic Auth、远程说明和 APK 下载。
- 创建：`lib/update/update_dialog.dart` — 可由启动流程和关于页复用的更新弹窗。
- 修改：`lib/app/rubik_solver_app.dart` — 首帧后自动检查并显示弹窗。
- 修改：`lib/settings/about_page.dart` — 手动检查复用共享弹窗。
- 修改：`test/update/update_service_test.dart` — 服务协议、回退和下载请求测试。
- 创建：`test/update/update_dialog_test.dart` — 弹窗说明、下载进度和安装行为测试。
- 修改：`test/app/home_page_test.dart` — 启动检查显示或静默的 Widget 测试。
- 创建：`test/deploy_script_test.dart` — 部署脚本契约测试。
- 创建：`deploy.bat` — 仅 Android Release 的项目发布入口。
- 修改：`pubspec.yaml` — 版本升级到 `1.1.1+3`。
- 修改：`assets/docs/update_notes.md` — 增加自动更新发布说明。

### 任务 1：把更新服务切换到自定义服务器

**文件：**
- 修改：`test/update/update_service_test.dart`
- 修改：`lib/update/update_service.dart`

- [ ] **步骤 1：编写自定义服务器检查的失败测试**

把现有 GitHub release 测试替换为服务器协议测试。MockClient 根据路径返回数据，并断言所有请求携带相同 Basic Auth：

```dart
test('reads version and notes from the custom update server', () async {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    if (request.url.path == '/rubicsolver_version.txt') {
      return http.Response('1.1.1+3\n', 200);
    }
    if (request.url.path == '/rubicsolver_update_notes.md') {
      return http.Response('# 1.1.1\n\n自动更新', 200);
    }
    fail('unexpected request: ${request.url}');
  });

  final service = UpdateService(
    client: client,
    packageInfoProvider: () async => _packageInfo('1.1.0', '2'),
    preferencesProvider: SharedPreferences.getInstance,
  );

  final result = await service.checkForUpdates(force: true);

  expect(result.status, UpdateCheckStatus.updateAvailable);
  expect(result.update?.latestVersion, VersionNumber.parse('1.1.1+3'));
  expect(result.update?.downloadUrl.path, '/rubicsolver.apk');
  expect(result.update?.releaseNotes, contains('自动更新'));
  expect(
    requests.every((request) =>
      request.headers['authorization'] == UpdateService.authorizationHeader),
    isTrue,
  );
});
```

- [ ] **步骤 2：运行测试并确认因仍访问 GitHub 而失败**

运行：`flutter test test/update/update_service_test.dart`

预期：FAIL，MockClient 收到 GitHub pubspec URL，或 `UpdateInfo.releaseNotes`/服务器常量尚不存在。

- [ ] **步骤 3：实现最小自定义服务器检查**

在 `UpdateInfo` 增加 `releaseNotes`，定义服务器常量并替换 GitHub 解析：

```dart
static const serverBaseUrl = 'https://zl.870413.xyz:5443';
static const versionAssetName = 'rubicsolver_version.txt';
static const notesAssetName = 'rubicsolver_update_notes.md';
static const apkAssetName = 'rubicsolver.apk';
static const serverUsername = 'zls';
static const serverPassword = 'zls12345';

static String get authorizationHeader =>
    'Basic ${base64Encode(utf8.encode('$serverUsername:$serverPassword'))}';

Uri get _versionUri => Uri.parse('$serverBaseUrl/$versionAssetName');
Uri get _notesUri => Uri.parse('$serverBaseUrl/$notesAssetName');
Uri get _apkUri => Uri.parse('$serverBaseUrl/$apkAssetName');
```

`checkForUpdates` 读取并 `trim()` 版本文本；若版本更新，再读取说明并返回固定 APK URL。删除 GitHub token、pubspec YAML、release tag 和 JSON asset 解析代码。

- [ ] **步骤 4：增加更新说明失败回退测试并验证红灯**

```dart
test('still reports an update when remote notes cannot be loaded', () async {
  final client = MockClient((request) async {
    if (request.url.path == '/rubicsolver_version.txt') {
      return http.Response('1.1.1+3', 200);
    }
    return http.Response('missing', 404);
  });
  final service = _service(client: client, current: '1.1.0+2');

  final result = await service.checkForUpdates(force: true);

  expect(result.status, UpdateCheckStatus.updateAvailable);
  expect(result.update?.releaseNotes, contains('1.1.1+3'));
});
```

运行：`flutter test test/update/update_service_test.dart`。

预期：FAIL，因为说明 404 仍使整个检查失败。

- [ ] **步骤 5：实现说明回退，并更新 APK 下载测试**

把说明读取放入独立的 best-effort 方法：

```dart
Future<String> _loadReleaseNotes(VersionNumber version) async {
  try {
    final response = await _get(_notesUri, headers: _textHeaders);
    if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
      return response.body.trim();
    }
  } catch (_) {}
  return '# 更新说明\n\n发现新版本 $version。';
}
```

修改下载测试，断言 `GET /rubicsolver.apk` 携带 `authorizationHeader` 和 `Accept: application/octet-stream`，并保留进度、临时文件清理、安装权限测试。

- [ ] **步骤 6：验证服务测试并提交**

运行：`flutter test test/update/update_service_test.dart test/update/version_number_test.dart`

预期：全部通过。

提交：

```bash
git add lib/update/update_service.dart test/update/update_service_test.dart
git commit -m "feat: use custom server for app updates"
```

### 任务 2：提取共享更新弹窗

**文件：**
- 创建：`test/update/update_dialog_test.dart`
- 创建：`lib/update/update_dialog.dart`
- 修改：`lib/settings/about_page.dart`

- [ ] **步骤 1：编写弹窗显示说明和触发安装的失败测试**

创建可记录 `downloadAndInstall` 调用的 `_FakeUpdateService`，测试顶层函数：

```dart
testWidgets('shows release notes and downloads the selected update', (tester) async {
  final service = _FakeUpdateService();
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      return TextButton(
        onPressed: () => showUpdateDialog(
          context: context,
          service: service,
          update: _updateInfo(notes: '# 新功能\n\n自动更新'),
        ),
        child: const Text('open'),
      );
    }),
  ));

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.textContaining('自动更新'), findsOneWidget);

  await tester.tap(find.text('下载并安装'));
  await tester.pumpAndSettle();
  expect(service.downloadCalls, 1);
});
```

- [ ] **步骤 2：运行并确认缺少共享弹窗而失败**

运行：`flutter test test/update/update_dialog_test.dart`

预期：FAIL，`lib/update/update_dialog.dart` 和 `showUpdateDialog` 尚不存在。

- [ ] **步骤 3：实现共享弹窗的最少代码**

实现：

```dart
Future<void> showUpdateDialog({
  required BuildContext context,
  required UpdateService service,
  required UpdateInfo update,
}) async {
  var downloading = false;
  var progress = 0.0;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('发现新版本'),
        content: SingleChildScrollView(child: /* versions, notes, progress, error */),
        actions: [/* 稍后；下载并安装 */],
      ),
    ),
  );
}
```

下载回调调用 `service.downloadAndInstall`，进度写入状态；成功后关闭弹窗，失败后恢复按钮并显示去掉 `Bad state:` 前缀的错误。

- [ ] **步骤 4：让关于页使用共享弹窗**

导入 `update_dialog.dart`，把 `_checkForUpdates` 的 updateAvailable 分支替换为：

```dart
await showUpdateDialog(
  context: context,
  service: _updateService,
  update: result.update!,
);
```

删除关于页私有 `_showUpdateDialog`，保留手动检查反馈。

- [ ] **步骤 5：验证弹窗与关于页测试并提交**

运行：`flutter test test/update/update_dialog_test.dart test/app/home_page_test.dart`

预期：全部通过。

提交：

```bash
git add lib/update/update_dialog.dart lib/settings/about_page.dart test/update/update_dialog_test.dart
git commit -m "refactor: share the app update dialog"
```

### 任务 3：启动时发现更新就提示

**文件：**
- 修改：`test/app/home_page_test.dart`
- 修改：`lib/app/rubik_solver_app.dart`

- [ ] **步骤 1：编写启动发现更新的失败测试**

```dart
testWidgets('startup update check shows the update prompt', (tester) async {
  final service = _ImmediateUpdateService(UpdateCheckResult.updateAvailable(
    _updateInfo(notes: '启动自动更新说明'),
  ));

  await tester.pumpWidget(RubikSolverApp(updateService: service));
  await tester.pump();
  await tester.pumpAndSettle();

  expect(find.text('发现新版本'), findsOneWidget);
  expect(find.textContaining('启动自动更新说明'), findsOneWidget);
});
```

再加一个 `UpdateCheckResult.failed('offline')` 测试，断言首页可见且没有更新弹窗。

- [ ] **步骤 2：运行并确认结果被静默丢弃而失败**

运行：`flutter test test/app/home_page_test.dart --plain-name "startup update check shows the update prompt"`

预期：FAIL，找不到“发现新版本”。

- [ ] **步骤 3：实现根导航器与自动弹窗**

在 `_RubikSolverAppState` 增加：

```dart
final _navigatorKey = GlobalKey<NavigatorState>();
```

传给 `MaterialApp(navigatorKey: _navigatorKey)`，并把启动检查改为：

```dart
final result = await _updateService.checkForUpdates();
if (!mounted || result.status != UpdateCheckStatus.updateAvailable) return;
final context = _navigatorKey.currentContext;
if (context == null || !context.mounted) return;
await showUpdateDialog(
  context: context,
  service: _updateService,
  update: result.update!,
);
```

异常继续静默处理，不阻塞首页。

- [ ] **步骤 4：验证启动行为并提交**

运行：`flutter test test/app/home_page_test.dart test/update/update_dialog_test.dart`

预期：全部通过。

提交：

```bash
git add lib/app/rubik_solver_app.dart test/app/home_page_test.dart
git commit -m "feat: prompt for updates after startup"
```

### 任务 4：增加部署脚本、升版和更新说明

**文件：**
- 创建：`test/deploy_script_test.dart`
- 创建：`deploy.bat`
- 修改：`pubspec.yaml`
- 修改：`assets/docs/update_notes.md`

- [ ] **步骤 1：编写部署契约失败测试**

```dart
test('deploy script publishes a project-specific Android release', () {
  final script = File('deploy.bat').readAsStringSync();
  expect(script, contains('set "projectName=rubicsolver"'));
  expect(script, contains('set "updateNotesDest=rubicsolver_update_notes.md"'));
  expect(script, contains('findstr /r /c:"^version:" pubspec.yaml'));
  expect(script, contains('deploy_flutter_app.bat'));
  expect(script, isNot(contains('flutter build')));
});
```

- [ ] **步骤 2：运行并确认缺少脚本而失败**

运行：`flutter test test/deploy_script_test.dart`

预期：FAIL，`deploy.bat` 不存在。

- [ ] **步骤 3：创建项目部署入口**

`deploy.bat` 应只设置项目参数并委托共享脚本：

```bat
@echo off
chcp 65001 >nul
setlocal
pushd "%~dp0"
set "projectName=rubicsolver"
set "publishDir=X:\certificate"
set "updateNotesDest=rubicsolver_update_notes.md"
for /f "tokens=2 delims=+" %%a in ('findstr /r /c:"^version:" pubspec.yaml') do set "buildNumber=%%a"
if not defined buildNumber exit /b 1
call "%~dp0..\deploy_flutter_app.bat" %*
set "exitCode=%errorlevel%"
popd
exit /b %exitCode%
```

- [ ] **步骤 4：升级版本并补充说明**

把 `pubspec.yaml` 改为：

```yaml
version: 1.1.1+3
```

在更新说明顶部加入：

```markdown
## 1.1.1

- 启动后每七天自动检查一次新版本，发现更新时展示更新说明，由用户确认下载并调用系统安装器。
- 手动检查和自动检查统一改用 heat ex 项目的 HTTPS 更新服务器，并使用 Rubik Solver 独立的版本、APK 与更新说明文件。
- 增加 Android Release 一键部署脚本，自动发布正式签名 APK、版本文件和更新说明。
```

- [ ] **步骤 5：验证部署测试、版本和说明并提交**

运行：`flutter test test/deploy_script_test.dart`

运行：`rg -n "^version:|^## 1.1.1|rubicsolver_update_notes" pubspec.yaml assets/docs/update_notes.md deploy.bat`

预期：测试通过，版本为 `1.1.1+3`，三个服务器文件名一致。

提交：

```bash
git add deploy.bat pubspec.yaml assets/docs/update_notes.md test/deploy_script_test.dart
git commit -m "feat: add Android update deployment"
```

### 任务 5：完整验证、发布和服务器验收

**文件：**
- 验证：`build/app/outputs/flutter-apk/app-release.apk`
- 发布：`X:\certificate\rubicsolver.apk`
- 发布：`X:\certificate\rubicsolver_version.txt`
- 发布：`X:\certificate\rubicsolver_update_notes.md`

- [ ] **步骤 1：运行完整代码质量检查**

运行：

```powershell
dart format --output=none --set-exit-if-changed .
git diff --check
flutter analyze
flutter test
```

预期：格式无变化、diff 无空白错误、静态分析 0 issue、全部测试通过。

- [ ] **步骤 2：执行 Android Release 部署**

运行：`cmd /c deploy.bat android`

预期：只构建 Android arm64 Release；复制 `rubicsolver.apk`、`rubicsolver_version.txt` 和 `rubicsolver_update_notes.md` 到 `X:\certificate`。

- [ ] **步骤 3：验证本地和发布 APK 签名**

使用 Android SDK 36.0.0 `apksigner.bat verify --verbose --print-certs` 检查两个 APK，要求 v1/v2 为 true；通过 `keytool -list -v` 读取 `heat_ex_designer/android/key.properties` 指向的 JKS，并确认三者证书 SHA-256 都为：

```text
CB0ED095CB12C804FB7D4BC6F57090CD79B3DD20E4EE43A3A56A196FEFA9DAE6
```

- [ ] **步骤 4：通过 HTTPS 验收服务器**

使用与客户端相同的 Basic Auth 请求三个端点，要求：

- `/rubicsolver_version.txt` 返回 200 且正文是 `1.1.1+3`。
- `/rubicsolver_update_notes.md` 返回 200 且包含 `## 1.1.1`。
- `/rubicsolver.apk` 返回 200，长度与 `X:\certificate\rubicsolver.apk` 一致，下载文件 SHA-256 与发布文件一致。

- [ ] **步骤 5：记录最终状态**

运行：

```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
git status --short --branch
git log --oneline --decorate -15
```

预期：工作树干净，`master` 包含全部实现提交，并给出 Release APK 的路径、大小和 SHA-256。
