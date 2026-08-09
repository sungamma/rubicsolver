# Rubik Solver 自定义服务器自动更新设计

## 目标

Rubik Solver 在 Android 启动后非阻塞地检查新版本。发现新版本时弹出更新提示，由用户决定是否下载；下载完成后打开 Android 系统安装器。手动检查更新入口继续保留，并与自动检查共用同一套服务和弹窗。

更新源、认证方式和发布目录复用同级 `heat_ex_designer` 项目，但 Rubik Solver 使用独立文件名，避免覆盖其他应用的版本、APK 和更新说明。

## 方案选择

采用“自定义服务器作为唯一更新源”。与“GitHub 主源、自定义服务器备用”相比，这种方案不会因两个源版本不同步而给出矛盾结果；与抽象为多更新源框架相比，它更符合当前单一 Android 发布目标，代码和测试也更集中。

服务器使用现有 HTTPS 地址和 Basic Auth。客户端保留正常 TLS 证书校验，不复制 `heat_ex_designer` 中忽略证书错误的兼容代码。

## 服务器协议

客户端读取以下资源：

- `GET /rubicsolver_version.txt`：UTF-8 纯文本版本号，格式与 `pubspec.yaml` 一致，例如 `1.1.0+2`。
- `GET /rubicsolver_update_notes.md`：UTF-8 Markdown 更新说明。
- `GET /rubicsolver.apk`：已使用正式 JKS 签名的 Android Release APK。

三个请求均携带与 `heat_ex_designer` 相同的 Basic Authorization 头。版本和更新说明请求使用文本 Accept 头，APK 下载使用二进制 Accept 头。

## 客户端结构

### UpdateService

`lib/update/update_service.dart` 继续负责版本比较、检查节流、网络访问、APK 下载和调用系统安装器，但把 GitHub pubspec/release API 逻辑替换为自定义服务器协议。

`UpdateInfo` 增加 `releaseNotes`，检查到新版本后尝试读取远程 Markdown。更新说明获取失败不应掩盖已经发现的新版本，服务返回包含简短回退说明的 `UpdateInfo`。版本文件、认证或响应格式错误则返回 `failed`。

自动检查保持现有七天节流；关于页的手动检查传入 `force: true`，始终访问服务器。检查失败不会阻塞应用启动。

### UpdateDialog

新增 `lib/update/update_dialog.dart`，集中实现更新交互：

- 显示当前版本、最新版本和服务器更新说明。
- 用户可选择“稍后”或“下载并安装”。
- 下载期间显示百分比进度并禁用关闭和重复下载。
- 下载或安装失败时在对话框内显示可重试错误。
- 成功打开系统安装器后关闭弹窗。

关于页和启动自动检查都调用该组件，避免维护两套下载状态机。

### 启动检查

`RubikSolverApp` 为 `MaterialApp` 提供 `navigatorKey`。首帧完成后执行自动检查；仅当结果为 `updateAvailable` 且导航上下文仍有效时显示更新弹窗。`upToDate`、`throttled` 和 `failed` 在启动阶段均保持静默。

## 部署脚本

项目根目录新增 `deploy.bat`，委托工作区共享的 `..\deploy_flutter_app.bat` 完成 Release Android 构建和复制：

- `projectName=rubicsolver`，生成 `rubicsolver.apk` 和 `rubicsolver_version.txt`。
- `updateNotesDest=rubicsolver_update_notes.md`。
- 从 `pubspec.yaml` 的 `+build` 部分读取 Android build number，防止脚本与应用版本漂移。
- 默认发布目录沿用 `X:\certificate`，同时继续支持共享脚本的命令行发布目录覆盖。

本次只执行 `deploy.bat android`，不会生成 Debug 或 Windows 版本。发布后通过 HTTPS 端点重新读取版本、更新说明和 APK 元数据，确认服务器已更新。

## 更新说明

`assets/docs/update_notes.md` 的 `1.1.0` 章节增加自动更新说明。部署脚本把同一文件发布为服务器端 `rubicsolver_update_notes.md`，确保应用弹窗展示的内容与 Release 包内关于页一致。

## 错误处理与安全

- 网络请求设置有限超时；自动检查的错误静默处理，手动检查显示友好错误。
- 非 200 响应、空版本和无效版本均视为检查失败。
- APK 下载失败时删除不完整文件。
- Android 安装前验证文件存在并请求安装未知应用权限。
- 客户端中的 Basic Auth 只用于读取发布文件，不能被视为秘密；服务器账户必须保持只读权限。
- 不关闭 HTTPS 证书验证。

## 测试与验收

- 服务测试覆盖自定义服务器 URL、Basic Auth、版本解析、版本比较、远程更新说明、说明失败回退、检查节流、APK 下载认证与进度、系统安装调用。
- Widget 测试覆盖启动检查发现新版本时弹窗、无更新和失败时不弹窗，以及关于页继续使用同一更新弹窗。
- 部署脚本测试覆盖共享脚本委托、项目文件名、独立更新说明文件名，以及从 `pubspec.yaml` 读取 build number。
- 完整运行格式检查、`flutter analyze`、`flutter test` 和 Android Release 构建。
- 使用 `apksigner` 核对发布 APK 的 v1/v2 签名及证书 SHA-256，并与 `heat_ex_designer` 的 JKS 比较。
- 通过服务器 HTTPS 端点确认版本内容、更新说明内容和 APK 可下载。

## 非目标

- 不在后台无提示下载 APK。
- 不绕过 Android 系统安装确认。
- 不增加 GitHub 回退源、断点续传、强制更新或 Windows 更新。
- 不修改 `heat_ex_designer` 的现有更新实现或服务器文件。
