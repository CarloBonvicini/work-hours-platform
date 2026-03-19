import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/data/api/github_release_client.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';

abstract class AppUpdateService {
  Future<AppUpdate?> checkForUpdate();

  Future<bool> openUpdate(AppUpdate update);
}

class ReleaseAppUpdateService implements AppUpdateService {
  ReleaseAppUpdateService({
    required GitHubReleaseClient releaseClient,
    required UpdateLauncher updateLauncher,
    String currentVersion = const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '0.1.0',
    ),
  }) : _releaseClient = releaseClient,
       _updateLauncher = updateLauncher,
       _currentVersion = currentVersion;

  final GitHubReleaseClient _releaseClient;
  final UpdateLauncher _updateLauncher;
  final String _currentVersion;

  @override
  Future<AppUpdate?> checkForUpdate() async {
    final latestRelease = await _releaseClient.fetchLatestRelease();
    if (latestRelease == null) {
      return null;
    }

    if (_compareVersions(latestRelease.version, _currentVersion) <= 0) {
      return null;
    }

    return AppUpdate(
      currentVersion: _currentVersion,
      latestVersion: latestRelease.version,
      downloadUrl: latestRelease.downloadUrl,
      releasePageUrl: latestRelease.releasePageUrl,
    );
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    final didOpenDownload = await _updateLauncher.open(update.downloadUrl);
    if (didOpenDownload) {
      return true;
    }

    return _updateLauncher.open(update.releasePageUrl);
  }

  static int _compareVersions(String left, String right) {
    final leftParts = _parseVersion(left);
    final rightParts = _parseVersion(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < maxLength; index += 1) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    return 0;
  }

  static List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map((segment) => int.tryParse(segment) ?? 0)
        .toList(growable: false);
  }
}
