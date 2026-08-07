import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';
import 'package:rubicsolver/update/update_service.dart';
import 'package:rubicsolver/update/version_number.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('parses remote version and resolves the release APK', () async {
    final client = _QueueClient([
      http.Response('version: 1.1.0+2\n', 200),
      http.Response(
        jsonEncode({
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url':
                  'https://github.com/sungamma/flutter-learn/releases/download/rubicsolver1.1.0%2B2/app-release.apk',
            },
          ],
        }),
        200,
      ),
    ]);
    final preferences = await SharedPreferences.getInstance();
    final service = UpdateService(
      client: client,
      packageInfoProvider: () async => _packageInfo('1.0.0', '1'),
      preferencesProvider: () async => preferences,
      now: () => DateTime(2026, 8, 7, 10),
    );

    final result = await service.checkForUpdates(force: true);

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.update?.latestVersion, VersionNumber.parse('1.1.0+2'));
    expect(result.update?.releaseTag, 'rubicsolver1.1.0+2');
    expect(result.update?.assetName, 'app-release.apk');
    expect(
      result.update?.downloadUrl.toString(),
      contains('/releases/download/rubicsolver1.1.0%2B2/app-release.apk'),
    );
    expect(client.requestedUris, hasLength(2));
  });

  test('returns a failure result for malformed remote metadata', () async {
    final client = _QueueClient([http.Response('version: nope\n', 200)]);
    final preferences = await SharedPreferences.getInstance();
    final service = UpdateService(
      client: client,
      packageInfoProvider: () async => _packageInfo('1.0.0', '1'),
      preferencesProvider: () async => preferences,
      now: () => DateTime(2026, 8, 7),
    );

    final result = await service.checkForUpdates(force: true);

    expect(result.status, UpdateCheckStatus.failed);
    expect(result.update, isNull);
    expect(result.errorMessage, isNotEmpty);
  });

  test(
    'throttles automatic checks for seven days but allows a forced check',
    () async {
      final now = DateTime(2026, 8, 7, 10);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        UpdateService.lastCheckEpochKey,
        now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      final client = _QueueClient([http.Response('version: 1.0.0+1\n', 200)]);
      final service = UpdateService(
        client: client,
        packageInfoProvider: () async => _packageInfo('1.0.0', '1'),
        preferencesProvider: () async => preferences,
        now: () => now,
      );

      final automatic = await service.checkForUpdates();
      final forced = await service.checkForUpdates(force: true);

      expect(automatic.status, UpdateCheckStatus.throttled);
      expect(forced.status, UpdateCheckStatus.upToDate);
      expect(client.requestedUris, hasLength(1));
    },
  );

  test(
    'downloads the APK into app support storage and reports progress',
    () async {
      final directory = await Directory.systemTemp.createTemp('rubik-update-');
      addTearDown(() => directory.delete(recursive: true));
      final client = _QueueClient([
        http.Response.bytes(List<int>.generate(10, (index) => index), 200),
      ]);
      final service = UpdateService(
        client: client,
        supportDirectoryProvider: () async => directory,
      );
      final update = UpdateInfo(
        currentVersion: VersionNumber.parse('1.0.0+1'),
        latestVersion: VersionNumber.parse('1.1.0+2'),
        releaseTag: 'rubicsolver1.1.0+2',
        assetName: 'app-release.apk',
        downloadUrl: Uri.parse('https://example.test/app-release.apk'),
      );
      final progress = <double>[];

      final path = await service.downloadApk(update, onProgress: progress.add);

      expect(File(path).readAsBytesSync(), List<int>.generate(10, (i) => i));
      expect(progress, isNotEmpty);
      expect(progress.last, 1);
    },
  );

  test('requests Android install permission before opening the APK', () async {
    final directory = await Directory.systemTemp.createTemp('rubik-install-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/app-release.apk')
      ..writeAsBytesSync([1, 2, 3]);
    var permissionRequests = 0;
    var openedPath = '';
    final service = UpdateService(
      isAndroid: () => true,
      installPermissionRequester: () async {
        permissionRequests++;
        return PermissionStatus.granted;
      },
      apkOpener: (path) async {
        openedPath = path;
        return OpenResult(type: ResultType.done);
      },
    );

    await service.installApk(file.path);

    expect(permissionRequests, 1);
    expect(openedPath, file.path);
  });
}

PackageInfo _packageInfo(String version, String buildNumber) {
  return PackageInfo(
    appName: 'Rubik Solver',
    packageName: 'com.sungamma.rubicsolver',
    version: version,
    buildNumber: buildNumber,
  );
}

class _QueueClient extends http.BaseClient {
  _QueueClient(this._responses);

  final List<http.Response> _responses;
  final requestedUris = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUris.add(request.url);
    if (_responses.isEmpty) {
      throw StateError('No response queued for ${request.url}');
    }
    final response = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
