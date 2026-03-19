import 'dart:io';

import 'package:flutter/services.dart';

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
