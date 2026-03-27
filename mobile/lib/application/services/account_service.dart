import 'package:work_hours_mobile/application/services/account_session_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';
import 'package:work_hours_mobile/data/repositories/local_dashboard_repository.dart';
import 'package:work_hours_mobile/domain/models/account_recovery_questions.dart';
import 'package:work_hours_mobile/domain/models/account_session.dart';
import 'package:work_hours_mobile/domain/models/cloud_backup_bundle.dart';

class RestoreFromCloudResult {
  const RestoreFromCloudResult({
    required this.hasBackup,
    this.bundle,
  });

  final bool hasBackup;
  final CloudBackupBundle? bundle;
}

class AccountService {
  AccountService({
    required String baseUrl,
    required AccountSessionStore sessionStore,
    required SharedPreferencesLocalDashboardRepository localRepository,
    required ThemePreferenceStore themePreferenceStore,
  }) : _baseUrl = baseUrl,
       _sessionStore = sessionStore,
       _localRepository = localRepository,
       _themePreferenceStore = themePreferenceStore;

  final String _baseUrl;
  final AccountSessionStore _sessionStore;
  final SharedPreferencesLocalDashboardRepository _localRepository;
  final ThemePreferenceStore _themePreferenceStore;

  Future<AccountSession?> loadSession() {
    return _sessionStore.loadSession();
  }

  Future<AccountSession> register({
    required String email,
    required String password,
  }) async {
    final client = WorkHoursApiClient(baseUrl: _baseUrl);
    final session = await client.register(email: email, password: password);
    await _sessionStore.saveSession(session);
    await backupToCloud(session: session);
    return session;
  }

  Future<RestoreFromCloudResult> login({
    required String email,
    required String password,
  }) async {
    final client = WorkHoursApiClient(baseUrl: _baseUrl);
    final session = await client.login(email: email, password: password);
    await _sessionStore.saveSession(session);
    return restoreFromCloud(session: session);
  }

  Future<void> logout() async {
    final session = await _sessionStore.loadSession();
    if (session != null) {
      final client = WorkHoursApiClient(
        baseUrl: _baseUrl,
        authToken: session.token,
      );
      try {
        await client.logout();
      } catch (_) {
        // Local logout must still work even if the server call fails.
      }
    }

    await _sessionStore.clearSession();
  }

  Future<AccountRecoveryQuestions> loadRecoveryQuestions({
    required String email,
  }) {
    final client = WorkHoursApiClient(baseUrl: _baseUrl);
    return client.fetchRecoveryQuestions(email: email);
  }

  Future<void> configureRecoveryQuestions({
    required String questionOne,
    required String answerOne,
    required String questionTwo,
    required String answerTwo,
    AccountSession? session,
  }) async {
    final effectiveSession = session ?? await _sessionStore.loadSession();
    if (effectiveSession == null) {
      throw ApiException('Sessione account non trovata.');
    }

    final client = WorkHoursApiClient(
      baseUrl: _baseUrl,
      authToken: effectiveSession.token,
    );
    await client.configureRecoveryQuestions(
      questionOne: questionOne,
      answerOne: answerOne,
      questionTwo: questionTwo,
      answerTwo: answerTwo,
    );
  }

  Future<void> recoverPassword({
    required String email,
    required String answerOne,
    required String answerTwo,
    required String newPassword,
  }) {
    final client = WorkHoursApiClient(baseUrl: _baseUrl);
    return client.recoverPassword(
      email: email,
      answerOne: answerOne,
      answerTwo: answerTwo,
      newPassword: newPassword,
    );
  }

  Future<void> backupToCloud({AccountSession? session}) async {
    final effectiveSession = session ?? await _sessionStore.loadSession();
    if (effectiveSession == null) {
      return;
    }

    final localBundle = await _localRepository.exportBundle();
    final appearanceSettings = await _themePreferenceStore.loadAppearanceSettings();
    final cloudBundle = CloudBackupBundle.fromLocal(
      localBundle: localBundle,
      appearanceSettings: appearanceSettings,
    );
    final client = WorkHoursApiClient(
      baseUrl: _baseUrl,
      authToken: effectiveSession.token,
    );
    await client.saveCloudBackup(cloudBundle);
  }

  Future<RestoreFromCloudResult> restoreFromCloud({
    AccountSession? session,
  }) async {
    final effectiveSession = session ?? await _sessionStore.loadSession();
    if (effectiveSession == null) {
      return const RestoreFromCloudResult(hasBackup: false);
    }

    final client = WorkHoursApiClient(
      baseUrl: _baseUrl,
      authToken: effectiveSession.token,
    );
    final backup = await client.fetchCloudBackup();
    if (backup == null) {
      return const RestoreFromCloudResult(hasBackup: false);
    }

    await _localRepository.importBundle(backup.toLocalBundle());
    await _themePreferenceStore.saveAppearanceSettings(backup.appearanceSettings);
    return RestoreFromCloudResult(hasBackup: true, bundle: backup);
  }
}
