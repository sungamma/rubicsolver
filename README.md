# 魔方复原（rubicsolver）

一个使用 Flutter 开发的 3×3 魔方识别与求解应用。应用通过手机相机分六面采集颜色，在本机完成识别、合法性校验和 Kociemba 两阶段求解，并以三维魔方、中文动作说明和自动播放展示解法。

作者：Wei Xu

邮箱：sungamma@gmail.com

## 功能

- 按固定方向引导扫描 `U → R → F → D → L → B` 六个面。
- 使用标准配色识别：白 `U`、红 `R`、绿 `F`、黄 `D`、橙 `L`、蓝 `B`。
- 在相机预览中直接显示识别色；可点击单格锁定，也可一键锁定当前九格，避免光线变化覆盖已确认颜色。
- 检查采样质量、颜色数量和魔方物理可达性，并提示可能错误。
- 支持点击非中心贴纸手动纠错，也可重新扫描指定面。
- 低置信度和画质提示属于软警告；确认当前颜色后，只要物理状态合法就允许求解。
- 使用 Kociemba 两阶段算法后台求解，支持取消等待和失败重试。
- 通过可拖动、可复位的三维魔方逐步播放解法，同时显示完整动作序列、转动方向箭头和慢动作（2.4 秒/步）。
- 支持启动静默检查更新和关于页手动检查更新。

## 扫描方法

扫描开始前先固定方向：白色中心面为 `U` 上面，绿色中心面为 `F` 前面。始终让当前要拍摄的面正对镜头，将九枚贴纸对齐取景框；不要在拍摄过程中旋转当前面的二维方向。

| 顺序 | 当前面 | 拍摄时朝上的面 |
| --- | --- | --- |
| 1 | 白色 `U` 上面 | 蓝色边朝上 |
| 2 | 红色 `R` 右面 | 白色边朝上 |
| 3 | 绿色 `F` 前面 | 白色边朝上 |
| 4 | 黄色 `D` 下面 | 绿色边朝上 |
| 5 | 橙色 `L` 左面 | 白色边朝上 |
| 6 | 蓝色 `B` 后面 | 白色边朝上 |

建议使用均匀环境光，避免强反光、过暗和明显阴影。实时色框采用透明底，识别色圆点位于格子中心；点击格子即可锁定当前识别色，点击“锁定九格”可整面锁定。拍照后可点击任意非中心格立即改色，手动选择会自动锁定；重拍会清除当前面的临时修改。

## 校验与纠错

识别完成后会显示魔方展开图和颜色数量。画质、低置信度和识别疑问会作为提醒展示；点击“我已核对，使用当前颜色”后，求解只以以下物理检查作为硬门槛：

- 每个颜色恰好有 9 枚贴纸；
- 边块、角块、翻转、扭转和置换奇偶性满足真实 3×3 魔方约束。

点击任意非中心贴纸可修改颜色。六个中心贴纸用于定义 `U/R/F/D/L/B` 面，因此保持锁定。

## 动作记号

- `R`：正对右面看，顺时针转动 90°。
- `R'`：正对右面看，逆时针转动 90°。
- `R2`：正对右面看，转动 180°。
- `U/R/F/D/L/B` 分别表示上、右、前、下、左、后六个面。

播放页的三维魔方可以拖动查看任意角度，点击左上角按钮恢复标准视角；当前动作旁会显示顺时针、逆时针或 180° 转动箭头。速度菜单提供 0.5 秒、0.9 秒、1.4 秒和 2.4 秒慢动作。

Android 启动图标采用深蓝背景、三个可见面各九格的打乱六色等距魔方，兼容旧版与自适应图标样式。

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

签名材料只保留在本机。需要复用现有签名时，可在本地从 `../heat_ex_designer/android` 复制 `key.properties` 与实际使用的 JKS 文件，或改为配置自己的 keystore；这些文件以及 `keystore.base64` 均已加入忽略规则，不应进入 Git。

不要提交 `key.properties`、keystore、密码或个人令牌。仓库只保存读取逻辑，不保存签名秘密。

## 更新发布约定

应用从以下地址读取远程版本：

```text
https://raw.githubusercontent.com/sungamma/flutter-learn/master/rubicsolver/pubspec.yaml
```

发布 GitHub Release 时使用以下固定命名：

- Tag：`rubicsolver<pubspec.yaml 中的 version>`，例如 `rubicsolver1.1.0+2`
- Android asset：`app-release.apk`

公开仓库不需要令牌。如需鉴权，只能在构建时通过 `GITHUB_TOKEN` 注入：

```powershell
flutter build apk --release --dart-define=GITHUB_TOKEN=<your-token>
```

应用启动后的自动检查最多每 7 天执行一次；关于页中的“手动检查更新”不受该限制。

## 第三方许可

项目使用 `tiagohm/cuber 0.4.0`（MIT License）。许可证全文见 [`LICENSES/cuber.txt`](LICENSES/cuber.txt)。
