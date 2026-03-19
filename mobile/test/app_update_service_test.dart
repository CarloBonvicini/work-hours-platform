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
}

class _FakeUpdateLauncher implements UpdateLauncher {
  _FakeUpdateLauncher({List<bool>? results})
    : _results = results ?? const [true];

  final List<bool> _results;
  final List<String> openedUrls = [];

  @override
  Future<bool> open(String url) async {
    openedUrls.add(url);
    final index = openedUrls.length - 1;
    if (index < _results.length) {
      return _results[index];
    }

    return _results.isNotEmpty ? _results.last : false;
  }
}
