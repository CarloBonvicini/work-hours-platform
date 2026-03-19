import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/data/api/github_release_client.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';

void main() {
  test('returns update metadata when GitHub release is newer', () async {
    final releaseClient = GitHubReleaseClient(
      latestReleaseApiUrl: 'https://example.invalid/releases/latest',
      fallbackReleasePageUrl: 'https://example.invalid/releases',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'mobile-v0.1.2',
            'html_url': 'https://example.invalid/releases/mobile-v0.1.2',
            'assets': [
              {
                'browser_download_url':
                    'https://example.invalid/downloads/app-release.apk',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final service = ReleaseAppUpdateService(
      releaseClient: releaseClient,
      updateLauncher: _FakeUpdateLauncher(),
      currentVersion: '0.1.0',
    );

    final update = await service.checkForUpdate();

    expect(update, isNotNull);
    expect(update!.latestVersion, '0.1.2');
    expect(
      update.downloadUrl,
      'https://example.invalid/downloads/app-release.apk',
    );
  });

  test(
    'ignores latest release when installed version is already current',
    () async {
      final releaseClient = GitHubReleaseClient(
        latestReleaseApiUrl: 'https://example.invalid/releases/latest',
        fallbackReleasePageUrl: 'https://example.invalid/releases',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tag_name': 'mobile-v0.1.0',
              'html_url': 'https://example.invalid/releases/mobile-v0.1.0',
              'assets': const [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final service = ReleaseAppUpdateService(
        releaseClient: releaseClient,
        updateLauncher: _FakeUpdateLauncher(),
        currentVersion: '0.1.0',
      );

      final update = await service.checkForUpdate();

      expect(update, isNull);
    },
  );

  test(
    'falls back to release page when direct download cannot be opened',
    () async {
      final launcher = _FakeUpdateLauncher(results: [false, true]);
      final service = ReleaseAppUpdateService(
        releaseClient: GitHubReleaseClient(
          latestReleaseApiUrl: 'https://example.invalid/releases/latest',
          fallbackReleasePageUrl: 'https://example.invalid/releases',
          httpClient: MockClient((request) async => http.Response('', 404)),
        ),
        updateLauncher: launcher,
        currentVersion: '0.1.0',
      );

      final didOpen = await service.openUpdate(
        const AppUpdate(
          currentVersion: '0.1.0',
          latestVersion: '0.1.1',
          downloadUrl: 'https://example.invalid/downloads/app-release.apk',
          releasePageUrl: 'https://example.invalid/releases/mobile-v0.1.1',
        ),
      );

      expect(didOpen, isTrue);
      expect(launcher.openedUrls, [
        'https://example.invalid/downloads/app-release.apk',
        'https://example.invalid/releases/mobile-v0.1.1',
      ]);
    },
  );

  test('downloads apk and reports progress', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'work-hours-update-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));

    final service = ReleaseAppUpdateService(
      releaseClient: GitHubReleaseClient(
        latestReleaseApiUrl: 'https://example.invalid/releases/latest',
        fallbackReleasePageUrl: 'https://example.invalid/releases',
        httpClient: MockClient((request) async => http.Response('', 404)),
      ),
      updateLauncher: _FakeUpdateLauncher(),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          [1, 2, 3, 4],
          200,
          headers: {'content-length': '4'},
        ),
      ),
      temporaryDirectoryProvider: () async => tempDirectory,
      currentVersion: '0.1.0',
    );

    final progressValues = <UpdateDownloadProgress>[];
    final downloadedUpdate = await service.downloadUpdate(
      const AppUpdate(
        currentVersion: '0.1.0',
        latestVersion: '0.1.1',
        downloadUrl: 'https://example.invalid/downloads/app-release.apk',
        releasePageUrl: 'https://example.invalid/releases/mobile-v0.1.1',
      ),
      onProgress: progressValues.add,
    );

    expect(progressValues, isNotEmpty);
    expect(progressValues.last.receivedBytes, 4);
    expect(progressValues.last.totalBytes, 4);
    expect(File(downloadedUpdate.filePath).existsSync(), isTrue);
  });

  test('delegates apk installation to platform launcher', () async {
    final launcher = _FakeUpdateLauncher(
      installResult: UpdateInstallResult.started,
    );
    final service = ReleaseAppUpdateService(
      releaseClient: GitHubReleaseClient(
        latestReleaseApiUrl: 'https://example.invalid/releases/latest',
        fallbackReleasePageUrl: 'https://example.invalid/releases',
        httpClient: MockClient((request) async => http.Response('', 404)),
      ),
      updateLauncher: launcher,
      currentVersion: '0.1.0',
    );

    final result = await service.installUpdate(
      const DownloadedAppUpdate(
        update: AppUpdate(
          currentVersion: '0.1.0',
          latestVersion: '0.1.1',
          downloadUrl: 'https://example.invalid/downloads/app-release.apk',
          releasePageUrl: 'https://example.invalid/releases/mobile-v0.1.1',
        ),
        filePath: '/tmp/app-release.apk',
        fileName: 'app-release.apk',
        bytesDownloaded: 1234,
      ),
    );

    expect(result, UpdateInstallResult.started);
    expect(launcher.installedFilePaths, ['/tmp/app-release.apk']);
  });
}

class _FakeUpdateLauncher implements UpdateLauncher {
  _FakeUpdateLauncher({
    List<bool>? results,
    this.installResult = UpdateInstallResult.failed,
  }) : _results = results ?? const [true];

  final List<bool> _results;
  final List<String> openedUrls = [];
  final List<String> installedFilePaths = [];
  final UpdateInstallResult installResult;

  @override
  Future<bool> open(String url) async {
    openedUrls.add(url);
    final index = openedUrls.length - 1;
    if (index < _results.length) {
      return _results[index];
    }

    return _results.isNotEmpty ? _results.last : false;
  }

  @override
  Future<UpdateInstallResult> installDownloadedApk(String filePath) async {
    installedFilePaths.add(filePath);
    return installResult;
  }
}
