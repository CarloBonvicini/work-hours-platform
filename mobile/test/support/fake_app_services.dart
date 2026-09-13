// Doppi di test dei servizi applicativi (aggiornamenti, preferenze, ticket).

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/support_ticket_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';

class FakeAppUpdateService implements AppUpdateService {
  @override
  Future<AppUpdate?> checkForUpdate() async {
    return const AppUpdate(
      currentVersion: '0.1.0',
      latestVersion: '0.1.1',
      downloadUrl: 'https://example.invalid/app-release.apk',
      releasePageUrl: 'https://example.invalid/releases/latest',
    );
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return true;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 10, totalBytes: 10));
    return DownloadedAppUpdate(
      update: update,
      filePath: '/tmp/app-release.apk',
      fileName: 'app-release.apk',
      bytesDownloaded: 10,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.started;
  }
}

class CountingAppUpdateService implements AppUpdateService {
  int checkCount = 0;

  @override
  Future<AppUpdate?> checkForUpdate() async {
    checkCount += 1;
    return null;
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return true;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 10, totalBytes: 10));
    return DownloadedAppUpdate(
      update: update,
      filePath: '/tmp/app-release.apk',
      fileName: 'app-release.apk',
      bytesDownloaded: 10,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.started;
  }
}

class ManualCheckAppUpdateService implements AppUpdateService {
  int checkCount = 0;

  @override
  Future<AppUpdate?> checkForUpdate() async {
    checkCount += 1;
    return const AppUpdate(
      currentVersion: '0.1.0',
      latestVersion: '0.1.1',
      downloadUrl: 'https://example.com/app-release.apk',
      releasePageUrl: 'https://example.com/release',
    );
  }

  @override
  Future<bool> openUpdate(AppUpdate update) async {
    return true;
  }

  @override
  Future<DownloadedAppUpdate> downloadUpdate(
    AppUpdate update, {
    required UpdateDownloadProgressCallback onProgress,
  }) async {
    onProgress(const UpdateDownloadProgress(receivedBytes: 10, totalBytes: 10));
    return DownloadedAppUpdate(
      update: update,
      filePath: '/tmp/app-release.apk',
      fileName: 'app-release.apk',
      bytesDownloaded: 10,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(DownloadedAppUpdate update) async {
    return UpdateInstallResult.started;
  }
}

class FakeUpdateReminderStore implements UpdateReminderStore {
  final List<String> remindedLaterVersions = [];
  final List<String> deferredAfterOpeningVersions = [];

  @override
  Future<void> deferAfterOpening(AppUpdate update) async {
    deferredAfterOpeningVersions.add(update.latestVersion);
  }

  @override
  Future<void> remindLater(AppUpdate update) async {
    remindedLaterVersions.add(update.latestVersion);
  }

  @override
  Future<bool> shouldPromptFor(AppUpdate update) async {
    return true;
  }
}

class FakeThemePreferenceStore implements ThemePreferenceStore {
  final List<ThemeMode> savedThemeModes = [];
  AppAppearanceSettings settings = AppAppearanceSettings.defaults;

  @override
  Future<ThemeMode> loadThemeMode() async {
    return settings.themeMode;
  }

  @override
  Future<AppAppearanceSettings> loadAppearanceSettings() async {
    return settings;
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    settings = settings.copyWith(themeMode: themeMode);
    savedThemeModes.add(themeMode);
  }

  @override
  Future<void> saveAppearanceSettings(AppAppearanceSettings settings) async {
    this.settings = settings;
    savedThemeModes.add(settings.themeMode);
  }
}

class FakeWorkdayStartStore implements WorkdayStartStore {
  FakeWorkdayStartStore({Map<String, WorkdaySession>? initialValues})
    : _values = {...?initialValues};

  final Map<String, WorkdaySession> _values;

  @override
  Future<void> clearSession(String isoDate) async {
    _values.remove(isoDate);
  }

  @override
  Future<WorkdaySession?> loadSession(String isoDate) async {
    return _values[isoDate];
  }

  @override
  Future<void> saveSession(String isoDate, WorkdaySession session) async {
    _values[isoDate] = session;
  }

  @override
  Future<Map<String, WorkdaySession>> exportAllSessions() async {
    return Map<String, WorkdaySession>.from(_values);
  }

  @override
  Future<void> importSessions(Map<String, WorkdaySession> sessions) async {
    _values.addAll(sessions);
  }
}

class FakeOnboardingPreferenceStore implements OnboardingPreferenceStore {
  FakeOnboardingPreferenceStore({required this.hasCompleted});

  final bool hasCompleted;
  int markCompletedCalls = 0;

  @override
  Future<bool> hasCompletedInitialSetup() async {
    return hasCompleted;
  }

  @override
  Future<void> markInitialSetupCompleted() async {
    markCompletedCalls += 1;
  }
}

class FakeSupportTicketStore implements SupportTicketStore {
  final List<TrackedSupportTicket> _tickets = [];

  @override
  Future<List<TrackedSupportTicket>> loadTrackedTickets() async {
    return List<TrackedSupportTicket>.from(_tickets);
  }

  @override
  Future<void> saveTrackedTickets(List<TrackedSupportTicket> tickets) async {
    _tickets
      ..clear()
      ..addAll(tickets);
  }

  @override
  Future<void> upsertTrackedTicket(TrackedSupportTicket ticket) async {
    _tickets.removeWhere((entry) => entry.id == ticket.id);
    _tickets.insert(0, ticket);
  }

  @override
  Future<void> markAdminRepliesSeen({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    final index = _tickets.indexWhere((entry) => entry.id == ticketId);
    if (index < 0) {
      return;
    }

    _tickets[index] = _tickets[index].copyWith(
      lastSeenAdminReplyCount: adminReplyCount,
    );
  }

  @override
  Future<void> markAdminRepliesNotified({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    final index = _tickets.indexWhere((entry) => entry.id == ticketId);
    if (index < 0) {
      return;
    }

    _tickets[index] = _tickets[index].copyWith(
      lastNotifiedAdminReplyCount: adminReplyCount,
    );
  }

  @override
  Future<void> markAdminRepliesNotifiedBatch({
    required Map<String, int> adminReplyCountByTicketId,
  }) async {
    if (adminReplyCountByTicketId.isEmpty) {
      return;
    }

    for (var index = 0; index < _tickets.length; index += 1) {
      final ticket = _tickets[index];
      final adminReplyCount = adminReplyCountByTicketId[ticket.id];
      if (adminReplyCount == null) {
        continue;
      }

      _tickets[index] = ticket.copyWith(
        lastNotifiedAdminReplyCount: adminReplyCount,
      );
    }
  }

  @override
  Future<void> markAdminRepliesSeenAndNotified({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    final index = _tickets.indexWhere((entry) => entry.id == ticketId);
    if (index < 0) {
      return;
    }

    _tickets[index] = _tickets[index].copyWith(
      lastSeenAdminReplyCount: adminReplyCount,
      lastNotifiedAdminReplyCount: adminReplyCount,
    );
  }
}
