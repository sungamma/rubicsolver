import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

import 'version_number.dart';

typedef PackageInfoProvider = Future<PackageInfo> Function();
typedef PreferencesProvider = Future<SharedPreferences> Function();
typedef SupportDirectoryProvider = Future<Directory> Function();
typedef InstallPermissionRequester = Future<PermissionStatus> Function();
typedef ApkOpener = Future<OpenResult> Function(String path);
typedef PlatformDetector = bool Function();

enum UpdateCheckStatus { updateAvailable, upToDate, throttled, failed }

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseTag,
    required this.assetName,
    required this.downloadUrl,
  });

  final VersionNumber currentVersion;
  final VersionNumber latestVersion;
  final String releaseTag;
  final String assetName;
  final Uri downloadUrl;
}

class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.status,
    this.update,
    this.errorMessage,
  });

  const UpdateCheckResult.updateAvailable(UpdateInfo update)
    : this._(status: UpdateCheckStatus.updateAvailable, update: update);

  const UpdateCheckResult.upToDate()
    : this._(status: UpdateCheckStatus.upToDate);

  const UpdateCheckResult.throttled()
    : this._(status: UpdateCheckStatus.throttled);

  const UpdateCheckResult.failed(String message)
    : this._(status: UpdateCheckStatus.failed, errorMessage: message);

  final UpdateCheckStatus status;
  final UpdateInfo? update;
  final String? errorMessage;

  bool get hasUpdate => status == UpdateCheckStatus.updateAvailable;
}

class UpdateService {
  UpdateService({
    http.Client? client,
    PackageInfoProvider? packageInfoProvider,
    PreferencesProvider? preferencesProvider,
    SupportDirectoryProvider? supportDirectoryProvider,
    InstallPermissionRequester? installPermissionRequester,
    ApkOpener? apkOpener,
    PlatformDetector? isAndroid,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _packageInfoProvider = packageInfoProvider ?? PackageInfo.fromPlatform,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory,
       _installPermissionRequester =
           installPermissionRequester ??
           (() => Permission.requestInstallPackages.request()),
       _apkOpener = apkOpener ?? OpenFilex.open,
       _isAndroid = isAndroid ?? (() => Platform.isAndroid),
       _now = now ?? DateTime.now;

  static const rawPubspecUrl =
      'https://raw.githubusercontent.com/sungamma/flutter-learn/master/'
      'rubicsolver/pubspec.yaml';
  static const repositoryApiBaseUrl =
      'https://api.github.com/repos/sungamma/flutter-learn';
  static const apkAssetName = 'app-release.apk';
  static const lastCheckEpochKey = 'rubicsolver.last_update_check_epoch_ms';
  static const checkInterval = Duration(days: 7);

  // A token is intentionally only accepted from a compile-time environment
  // variable. Never place a personal token in source control.
  static const githubToken = String.fromEnvironment('GITHUB_TOKEN');

  final http.Client _client;
  final PackageInfoProvider _packageInfoProvider;
  final PreferencesProvider _preferencesProvider;
  final SupportDirectoryProvider _supportDirectoryProvider;
  final InstallPermissionRequester _installPermissionRequester;
  final ApkOpener _apkOpener;
  final PlatformDetector _isAndroid;
  final DateTime Function() _now;

  static String releaseTagFor(VersionNumber version) => 'rubicsolver$version';

  static bool shouldThrottle({
    required DateTime? lastChecked,
    required DateTime now,
  }) {
    if (lastChecked == null) return false;
    return now.isBefore(lastChecked.add(checkInterval));
  }

  Future<UpdateCheckResult> checkForUpdates({bool force = false}) async {
    final now = _now();
    try {
      final preferences = await _preferencesProvider();
      final lastChecked = _lastChecked(preferences);
      if (!force && shouldThrottle(lastChecked: lastChecked, now: now)) {
        return const UpdateCheckResult.throttled();
      }

      // Record an attempted check before network I/O. This prevents repeated
      // background retries when a device is offline, while force=true remains
      // available from the About page.
      await preferences.setInt(lastCheckEpochKey, now.millisecondsSinceEpoch);

      final packageInfo = await _packageInfoProvider();
      final currentVersion = _parsePackageVersion(packageInfo);
      final pubspecResponse = await _get(
        Uri.parse(rawPubspecUrl),
        headers: _rawFileHeaders,
      );
      if (pubspecResponse.statusCode != 200) {
        throw HttpException('远程版本文件返回 HTTP ${pubspecResponse.statusCode}');
      }

      final latestVersion = _parseRemoteVersion(pubspecResponse.body);
      if (latestVersion <= currentVersion) {
        return const UpdateCheckResult.upToDate();
      }

      final releaseTag = releaseTagFor(latestVersion);
      final releaseResponse = await _get(
        Uri.parse(
          '$repositoryApiBaseUrl/releases/tags/${Uri.encodeComponent(releaseTag)}',
        ),
        headers: _githubHeaders,
      );
      if (releaseResponse.statusCode != 200) {
        throw HttpException(
          'GitHub release 返回 HTTP ${releaseResponse.statusCode}',
        );
      }

      final downloadUrl = _findApkDownloadUrl(releaseResponse.body);
      final update = UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseTag: releaseTag,
        assetName: apkAssetName,
        downloadUrl: downloadUrl,
      );
      return UpdateCheckResult.updateAvailable(update);
    } catch (error) {
      return UpdateCheckResult.failed(_friendlyError(error));
    }
  }

  Future<String> downloadApk(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    Directory? updateDirectory;
    File? targetFile;
    try {
      final supportDirectory = await _supportDirectoryProvider();
      updateDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}updates',
      );
      await updateDirectory.create(recursive: true);
      targetFile = File(
        '${updateDirectory.path}${Platform.pathSeparator}${update.assetName}',
      );

      final request = http.Request('GET', update.downloadUrl)
        ..headers.addAll({
          ..._githubHeaders,
          'Accept': 'application/octet-stream',
        });
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw HttpException('APK 下载返回 HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      var received = 0;
      final sink = targetFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength != null && contentLength > 0) {
            onProgress?.call((received / contentLength).clamp(0, 1).toDouble());
          }
        }
        await sink.flush();
      } catch (_) {
        await sink.close();
        rethrow;
      }
      await sink.close();
      onProgress?.call(1);
      return targetFile.path;
    } catch (_) {
      if (targetFile != null && await targetFile.exists()) {
        await targetFile.delete();
      }
      rethrow;
    }
  }

  Future<OpenResult> installApk(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('安装文件不存在');
    }
    if (_isAndroid()) {
      final permission = await _installPermissionRequester();
      if (!permission.isGranted) {
        throw StateError('未授予安装应用权限');
      }
    }

    final result = await _apkOpener(path);
    if (result.type != ResultType.done) {
      throw StateError('打开安装包失败：${result.message}');
    }
    return result;
  }

  Future<String> downloadAndInstall(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    final path = await downloadApk(update, onProgress: onProgress);
    await installApk(path);
    return path;
  }

  void dispose() => _client.close();

  DateTime? _lastChecked(SharedPreferences preferences) {
    final value = preferences.getInt(lastCheckEpochKey);
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  VersionNumber _parsePackageVersion(PackageInfo info) {
    final raw = info.version.contains('+')
        ? info.version
        : '${info.version}+${info.buildNumber}';
    final version = VersionNumber.tryParse(raw);
    if (version == null) {
      throw FormatException('本地版本号无效：$raw');
    }
    return version;
  }

  VersionNumber _parseRemoteVersion(String content) {
    final yaml = loadYaml(content);
    if (yaml is! YamlMap) {
      throw const FormatException('远程 pubspec 不是 YAML 映射');
    }
    final rawVersion = yaml['version'];
    if (rawVersion is! String) {
      throw const FormatException('远程 pubspec 缺少 version');
    }
    final version = VersionNumber.tryParse(rawVersion);
    if (version == null) {
      throw FormatException('远程版本号无效：$rawVersion');
    }
    return version;
  }

  Uri _findApkDownloadUrl(String content) {
    final payload = jsonDecode(content);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('GitHub release 响应格式无效');
    }
    final assets = payload['assets'];
    if (assets is! List) {
      throw const FormatException('GitHub release 缺少 assets');
    }
    for (final item in assets) {
      if (item is! Map) continue;
      if (item['name'] != apkAssetName) continue;
      final rawUrl = item['browser_download_url'] ?? item['url'];
      if (rawUrl is! String || rawUrl.isEmpty) break;
      return Uri.parse(rawUrl);
    }
    throw const FormatException('GitHub release 中未找到 app-release.apk');
  }

  Future<http.Response> _get(Uri uri, {required Map<String, String> headers}) {
    return _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
  }

  Map<String, String> get _rawFileHeaders => {
    'User-Agent': 'RubikSolver-App',
    'Accept': 'text/plain',
    if (githubToken.isNotEmpty) 'Authorization': 'Bearer $githubToken',
  };

  Map<String, String> get _githubHeaders => {
    'User-Agent': 'RubikSolver-App',
    'Accept': 'application/vnd.github+json',
    if (githubToken.isNotEmpty) 'Authorization': 'Bearer $githubToken',
  };

  String _friendlyError(Object error) {
    if (error is TimeoutException) return '检查更新超时';
    if (error is FormatException) return error.message.toString();
    if (error is HttpException) return error.message;
    return '检查更新失败';
  }
}
