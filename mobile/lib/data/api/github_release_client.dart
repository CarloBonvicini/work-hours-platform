import 'dart:convert';

import 'package:http/http.dart' as http;

class LatestRelease {
  const LatestRelease({
    required this.version,
    required this.releasePageUrl,
    required this.downloadUrl,
  });

  final String version;
  final String releasePageUrl;
  final String downloadUrl;
}

class GitHubReleaseClient {
  GitHubReleaseClient({
    required this.latestReleaseApiUrl,
    required this.fallbackReleasePageUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String latestReleaseApiUrl;
  final String fallbackReleasePageUrl;
  final http.Client _httpClient;

  Future<LatestRelease?> fetchLatestRelease() async {
    final response = await _httpClient.get(
      Uri.parse(latestReleaseApiUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'WorkHoursPlatform',
      },
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final tagName = payload['tag_name'] as String?;
    final releasePageUrl =
        (payload['html_url'] as String?) ?? fallbackReleasePageUrl;
    if (tagName == null || tagName.isEmpty) {
      return null;
    }

    final assets = payload['assets'];
    String downloadUrl = releasePageUrl;
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) {
          continue;
        }

        final browserDownloadUrl = asset['browser_download_url'] as String?;
        if (browserDownloadUrl != null && browserDownloadUrl.endsWith('.apk')) {
          downloadUrl = browserDownloadUrl;
          break;
        }
      }
    }

    return LatestRelease(
      version: _normalizeVersion(tagName),
      releasePageUrl: releasePageUrl,
      downloadUrl: downloadUrl,
    );
  }

  static String _normalizeVersion(String rawVersion) {
    return rawVersion
        .replaceFirst(RegExp(r'^mobile-v'), '')
        .replaceFirst(RegExp(r'^v'), '');
  }
}
