class ReleaseFeedConfig {
  const ReleaseFeedConfig({
    required this.latestReleaseApiUrl,
    required this.releasePageUrl,
  });

  final String latestReleaseApiUrl;
  final String releasePageUrl;

  static ReleaseFeedConfig fromEnvironment() {
    const latestReleaseApiUrl = String.fromEnvironment(
      'UPDATE_FEED_URL',
      defaultValue:
          'https://api.github.com/repos/CarloBonvicini/work-hours-platform/releases/latest',
    );
    const releasePageUrl = String.fromEnvironment(
      'UPDATE_PAGE_URL',
      defaultValue:
          'https://github.com/CarloBonvicini/work-hours-platform/releases/latest',
    );

    return const ReleaseFeedConfig(
      latestReleaseApiUrl: latestReleaseApiUrl,
      releasePageUrl: releasePageUrl,
    );
  }
}
