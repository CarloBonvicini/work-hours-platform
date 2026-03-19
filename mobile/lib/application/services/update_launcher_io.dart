import 'dart:io';

import 'package:flutter/services.dart';

import 'update_launcher.dart';

const _updateChannel = MethodChannel('work_hours_mobile/update');

Future<bool> openExternalUrl(String url) async {
  if (Platform.isAndroid) {
    final didOpen = await _updateChannel.invokeMethod<bool>('openUrl', {
      'url': url,
    });
    return didOpen ?? false;
  }

  if (Platform.isWindows) {
    final result = await Process.run('cmd', ['/c', 'start', '', url]);
    return result.exitCode == 0;
  }

  if (Platform.isMacOS) {
    final result = await Process.run('open', [url]);
    return result.exitCode == 0;
  }

  if (Platform.isLinux) {
    final result = await Process.run('xdg-open', [url]);
    return result.exitCode == 0;
  }

  return false;
}

Future<UpdateInstallResult> installDownloadedApkFromPath(
  String filePath,
) async {
  if (!Platform.isAndroid) {
    return UpdateInstallResult.failed;
  }

  final result = await _updateChannel.invokeMethod<String>(
    'installDownloadedApk',
    {'filePath': filePath},
  );

  switch (result) {
    case 'started':
      return UpdateInstallResult.started;
    case 'permission_required':
      return UpdateInstallResult.permissionRequired;
    default:
      return UpdateInstallResult.failed;
  }
}
