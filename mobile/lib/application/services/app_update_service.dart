import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/data/api/github_release_client.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';

typedef UpdateDownloadProgressCallback =
    void Function(UpdateDownloadProgress progress);

class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get fractionCompleted {
    if (totalBytes == null || totalBytes == 0) {
      return null;
    }

    return receivedBytes / totalBytes!;
  }
}

class DownloadedAppUpdate {
  const DownloadedAppUpdate({
    required this.update,
    required this.filePath,
    required this.fileName,
    required this.bytesDownloaded,
  });

  final AppUpdate update;
  final String filePath;
  final String fileName;
  final int bytesDownloaded;
}

abstract class AppUpdateService {
  Future<AppUpdate?> checkForUpdate();

  Future<bool> openUpdate(AppUpdate update);

  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  });

  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update);
}

class ReleaseAppUpdateService implements AppUpdateService {
  ReleaseAppUpdateService({
    required GitHubReleaseClient releaseClient,
    required UpdateLauncher updateLauncher,
    http.Client? httpClient,
    Future<Directory> Function()? temporaryDirectoryProvider,
    String currentVersion = const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '0.1.0',
    ),
  }) : _releaseClient = releaseClient,
       _updateLauncher = updateLauncher,
       _httpClient = httpClient ?? http.Client(),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _currentVersion = currentVersion;

  final GitHubReleaseClient _releaseClient;
  final UpdateLauncher _updateLauncher;
  final http.Client _httpClient;
  final Future<Directory> Function() _temporaryDirectoryProvider;
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

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    final downloadUri = Uri.tryParse(update.downloadUrl);
    if (downloadUri == null) {
      throw HttpException('URL di download non valida.');
    }

    final request = http.Request('GET', downloadUri);
    final response = await _httpClient.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Download update non riuscito (${response.statusCode}).',
      );
    }

    final downloadsDirectory = await _resolveDownloadDirectory();
    final fileName = _resolveFileName(update, downloadUri);
    final filePath =
        '${downloadsDirectory.path}${Platform.pathSeparator}$fileName';
    final outputFile = File(filePath);

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final sink = outputFile.openWrite();
    final totalBytes = response.contentLength;
    var receivedBytes = 0;

    onProgress(
      UpdateDownloadProgress(receivedBytes: 0, totalBytes: totalBytes),
    );

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(
          UpdateDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      await sink.flush();
      return DownloadedAppUpdate(
        update: update,
        filePath: outputFile.path,
        fileName: fileName,
        bytesDownloaded: receivedBytes,
      );
    } catch (_) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      rethrow;
    } finally {
      await sink.close();
    }
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) {
    return _updateLauncher.installDownloadedApk(update.filePath);
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

  Future<Directory> _resolveDownloadDirectory() async {
    final temporaryDirectory = await _temporaryDirectoryProvider();
    final updateDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}app_update',
    );
    if (!await updateDirectory.exists()) {
      await updateDirectory.create(recursive: true);
    }

    return updateDirectory;
  }

  String _resolveFileName(AppUpdate update, Uri downloadUri) {
    final lastSegment = downloadUri.pathSegments.isEmpty
        ? ''
        : downloadUri.pathSegments.last.trim();

    if (lastSegment.isNotEmpty && lastSegment.endsWith('.apk')) {
      return lastSegment;
    }

    return 'work-hours-mobile-${update.latestVersion}.apk';
  }
}
