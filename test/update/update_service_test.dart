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

  test('reads version and notes from the custom update server', () async {
    final client = _QueueClient([
      http.Response('1.1.1+3\n', 200),
      http.Response(
        '# 1.1.1\n\n自动更新',
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
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
    expect(result.update?.latestVersion, VersionNumber.parse('1.1.1+3'));
    expect(result.update?.assetName, 'rubicsolver.apk');
    expect(result.update?.releaseNotes, contains('自动更新'));
    expect(
      result.update?.downloadUrl.toString(),
      'https://zl.870413.xyz:5443/rubicsolver.apk',
    );
    expect(client.requestedUris, hasLength(2));
    expect(
      client.requests.every(
        (request) =>
            request.headers['authorization'] ==
            UpdateService.authorizationHeader,
      ),
      isTrue,
    );
  });

  test('returns a failure result for malformed remote metadata', () async {
    final client = _QueueClient([http.Response('nope\n', 200)]);
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

  test('still reports an update when remote notes cannot be loaded', () async {
    final client = _QueueClient([
      http.Response('1.1.1+3', 200),
      http.Response('missing', 404),
    ]);
    final preferences = await SharedPreferences.getInstance();
    final service = UpdateService(
      client: client,
      packageInfoProvider: () async => _packageInfo('1.1.0', '2'),
      preferencesProvider: () async => preferences,
    );

    final result = await service.checkForUpdates(force: true);

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.update?.releaseNotes, contains('1.1.1+3'));
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
      final client = _QueueClient([http.Response('1.0.0+1\n', 200)]);
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
        latestVersion: VersionNumber.parse('1.1.1+3'),
        assetName: 'rubicsolver.apk',
        downloadUrl: Uri.parse('https://zl.870413.xyz:5443/rubicsolver.apk'),
        releaseNotes: '# 1.1.1',
      );
      final progress = <double>[];

      final path = await service.downloadApk(update, onProgress: progress.add);

      expect(File(path).readAsBytesSync(), List<int>.generate(10, (i) => i));
      expect(progress, isNotEmpty);
      expect(progress.last, 1);
      expect(
        client.requests.single.headers['authorization'],
        UpdateService.authorizationHeader,
      );
      expect(
        client.requests.single.headers['accept'],
        'application/octet-stream',
      );
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
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUris.add(request.url);
    requests.add(request);
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
