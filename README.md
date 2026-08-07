# 魔方复原（rubicsolver）

一个使用 Flutter 开发的 3×3 魔方识别与求解应用。应用通过手机相机分六面采集颜色，在本机完成识别、合法性校验和 Kociemba 两阶段求解，并以展开图、中文动作说明和自动播放展示解法。

作者：Wei Xu

邮箱：sungamma@gmail.com

## 功能

- 按固定方向引导扫描 `U → R → F → D → L → B` 六个面。
- 根据六个中心贴纸动态识别实体颜色，兼容不同配色方案。
- 检查采样质量、颜色数量和魔方物理可达性，并提示可能错误。
- 支持点击非中心贴纸手动纠错，也可重新扫描指定面。
- 使用 Kociemba 两阶段算法后台求解，支持取消等待和失败重试。
- 通过二维展开图逐步播放解法，同时显示完整动作序列。
- 支持启动静默检查更新和关于页手动检查更新。

## 扫描方法

始终让当前要拍摄的面正对镜头，将九枚贴纸对齐取景框。不要在拍摄过程中旋转当前面的二维方向；按页面提示保持指定面朝上。

| 顺序 | 当前面 | 拍摄时朝上的面 |
| --- | --- | --- |
| 1 | `U` 上面 | `B` 后面 |
| 2 | `R` 右面 | `U` 上面 |
| 3 | `F` 前面 | `U` 上面 |
| 4 | `D` 下面 | `F` 前面 |
| 5 | `L` 左面 | `U` 上面 |
| 6 | `B` 后面 | `U` 上面 |

建议使用均匀环境光，避免强反光、过暗和明显阴影。应用会拒绝质量不足的照片，并在六面完成后标出低置信度贴纸。

## 校验与纠错

识别完成后会显示魔方展开图和颜色数量。只有以下检查全部通过后才能开始求解：

- 每个颜色恰好有 9 枚贴纸；
- 低置信度贴纸已逐一确认或修改；
- 边块、角块、翻转、扭转和置换奇偶性满足真实 3×3 魔方约束。

点击任意非中心贴纸可修改颜色。六个中心贴纸用于定义 `U/R/F/D/L/B` 面，因此保持锁定。

## 动作记号

- `R`：正对右面看，顺时针转动 90°。
- `R'`：正对右面看，逆时针转动 90°。
- `R2`：正对右面看，转动 180°。
- `U/R/F/D/L/B` 分别表示上、右、前、下、左、后六个面。

解法使用 `cuber 0.4.0` 提供的 Kociemba 两阶段算法。该算法通常能很快生成较短解法，但不保证得到数学意义上的最少步数。

## 隐私

相机照片仅在本机解码、采样和识别，不会上传。网络只用于可选的版本检查和 APK 下载。应用不会把魔方照片发送到 GitHub 或其他服务器。

## 支持平台

- Android：主要交付平台，支持相机扫描、求解、播放和 APK 自动更新。
- iOS：保留相机与核心求解工程配置；APK 更新功能仅适用于 Android，当前交付验证以 Android 为准。

## 开发与构建

环境要求：Flutter 3.32 或更高版本、Dart 3.8 或更高版本，以及可用的 Android SDK。

```powershell
flutter pub get
flutter run
flutter test
flutter analyze
flutter build apk --debug
flutter build apk --release
```

构建产物位于：

- Debug：`build/app/outputs/flutter-apk/app-debug.apk`
- Release：`build/app/outputs/flutter-apk/app-release.apk`

## Release 签名

Android application id 为 `com.sungamma.rubicsolver`。Release 构建从 `android/key.properties` 读取 `storeFile`、`storePassword`、`keyAlias` 和 `keyPassword`，配置方式与上一级 `heat_ex_designer` 项目一致，可指向同一签名文件和身份。

不要提交 `key.properties`、keystore、密码或个人令牌。仓库只保存读取逻辑，不保存签名秘密。

## 更新发布约定

应用从以下地址读取远程版本：

```text
https://raw.githubusercontent.com/sungamma/flutter-learn/master/rubicsolver/pubspec.yaml
```

发布 GitHub Release 时使用以下固定命名：

- Tag：`rubicsolver<pubspec.yaml 中的 version>`，例如 `rubicsolver1.0.0+1`
- Android asset：`app-release.apk`

公开仓库不需要令牌。如需鉴权，只能在构建时通过 `GITHUB_TOKEN` 注入：

```powershell
flutter build apk --release --dart-define=GITHUB_TOKEN=<your-token>
```

应用启动后的自动检查最多每 7 天执行一次；关于页中的“手动检查更新”不受该限制。

## 第三方许可

项目使用 `tiagohm/cuber 0.4.0`（MIT License）。许可证全文见 [`LICENSES/cuber.txt`](LICENSES/cuber.txt)。
