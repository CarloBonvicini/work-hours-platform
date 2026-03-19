class AppUpdate {
  const AppUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releasePageUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releasePageUrl;
}
