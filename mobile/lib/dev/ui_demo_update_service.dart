import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';

class UiDemoAppUpdateService implements AppUpdateService {
  const UiDemoAppUpdateService();

  @override
  Future<AppUpdate?> checkForUpdate() async {
    return null;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 0, totalBytes: 0));
    throw UnsupportedError('UI demo mode does not download updates.');
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.failed;
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return false;
  }
}
