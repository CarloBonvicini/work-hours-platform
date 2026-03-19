// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'update_launcher.dart';

Future<bool> openExternalUrl(String url) async {
  html.window.open(url, '_blank');
  return true;
}

Future<UpdateInstallResult> installDownloadedApkFromPath(
  String filePath,
) async {
  return UpdateInstallResult.failed;
}
