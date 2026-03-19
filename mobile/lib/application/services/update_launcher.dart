import 'update_launcher_platform.dart';

enum UpdateInstallResult { started, permissionRequired, failed }

abstract class UpdateLauncher {
  Future<bool> open(String url);

  Future<UpdateInstallResult> installDownloadedApk(String filePath);
}

class PlatformUpdateLauncher implements UpdateLauncher {
  const PlatformUpdateLauncher();

  @override
  Future<bool> open(String url) {
    return openExternalUrl(url);
  }

  @override
  Future<UpdateInstallResult> installDownloadedApk(String filePath) {
    return installDownloadedApkFromPath(filePath);
  }
}
