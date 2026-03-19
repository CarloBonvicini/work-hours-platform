import 'update_launcher.dart';

Future<bool> openExternalUrl(String url) async {
  return false;
}

Future<UpdateInstallResult> installDownloadedApkFromPath(
  String filePath,
) async {
  return UpdateInstallResult.failed;
}
