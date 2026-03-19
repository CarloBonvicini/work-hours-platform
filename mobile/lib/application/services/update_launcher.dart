import 'update_launcher_platform.dart';

abstract class UpdateLauncher {
  Future<bool> open(String url);
}

class PlatformUpdateLauncher implements UpdateLauncher {
  const PlatformUpdateLauncher();

  @override
  Future<bool> open(String url) {
    return openExternalUrl(url);
  }
}
