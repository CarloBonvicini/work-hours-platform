// Card profilo con account, aspetto, aggiornamenti e vista giorno.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/domain/models/account_session.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/app_update_settings_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/appearance_settings_panel.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/cloud_backup_account_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/day_calendar_settings_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/section_cards.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.formKey,
    required this.fullNameController,
    required this.isBusy,
    required this.isReloading,
    required this.isDarkTheme,
    required this.appearanceSettings,
    required this.availableUpdate,
    required this.isCheckingForUpdate,
    required this.isOpeningUpdate,
    required this.isBackgroundUpdateDownloadInProgress,
    required this.backgroundUpdateProgress,
    required this.backgroundUpdate,
    required this.isUpdatingThemeMode,
    required this.accountSession,
    required this.selectedAuthMode,
    required this.accountEmailController,
    required this.accountPasswordController,
    required this.isAuthenticatingAccount,
    required this.isRecoveringPassword,
    required this.isConfiguringRecoveryQuestions,
    required this.isRestoringCloudBackup,
    required this.isSyncingCloudBackup,
    required this.hasCloudBackupAvailable,
    required this.isLoadingCloudBackupStatus,
    required this.lastCloudBackupAt,
    required this.lastCloudBackupAttemptAt,
    required this.lastCloudBackupSucceeded,
    required this.lastCloudBackupFeedback,
    required this.onDarkThemeChanged,
    required this.onOpenUpdateFromSettings,
    required this.onAppearanceSettingsChanged,
    required this.onRegisterAccount,
    required this.onLoginAccount,
    required this.onAuthModeChanged,
    required this.onOpenPasswordRecovery,
    required this.onOpenRecoveryQuestionsSetup,
    required this.onBackupNow,
    required this.onRestoreCloudBackup,
    required this.onLogoutAccount,
    required this.onReload,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final bool isBusy;
  final bool isReloading;
  final bool isDarkTheme;
  final AppAppearanceSettings appearanceSettings;
  final AppUpdate? availableUpdate;
  final bool isCheckingForUpdate;
  final bool isOpeningUpdate;
  final bool isBackgroundUpdateDownloadInProgress;
  final UpdateDownloadProgress backgroundUpdateProgress;
  final AppUpdate? backgroundUpdate;
  final bool isUpdatingThemeMode;
  final AccountSession? accountSession;
  final AccountAuthMode selectedAuthMode;
  final TextEditingController accountEmailController;
  final TextEditingController accountPasswordController;
  final bool isAuthenticatingAccount;
  final bool isRecoveringPassword;
  final bool isConfiguringRecoveryQuestions;
  final bool isRestoringCloudBackup;
  final bool isSyncingCloudBackup;
  final bool hasCloudBackupAvailable;
  final bool isLoadingCloudBackupStatus;
  final DateTime? lastCloudBackupAt;
  final DateTime? lastCloudBackupAttemptAt;
  final bool? lastCloudBackupSucceeded;
  final String? lastCloudBackupFeedback;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function() onOpenUpdateFromSettings;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;
  final Future<void> Function() onRegisterAccount;
  final Future<void> Function() onLoginAccount;
  final ValueChanged<AccountAuthMode> onAuthModeChanged;
  final Future<void> Function() onOpenPasswordRecovery;
  final Future<void> Function() onOpenRecoveryQuestionsSetup;
  final Future<void> Function() onBackupNow;
  final Future<void> Function() onRestoreCloudBackup;
  final Future<void> Function() onLogoutAccount;
  final Future<void> Function() onReload;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Impostazioni app',
      subtitle: 'Gestisci profilo, backup e aspetto dell app.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci il nome completo.';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy || isReloading ? null : () => onReload(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(isReloading ? 'Carico...' : 'Carica profilo'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy || isReloading ? null : () => onSubmit(),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isBusy ? 'Salvo...' : 'Salva nome'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            CloudBackupAccountCard(
              accountSession: accountSession,
              selectedAuthMode: selectedAuthMode,
              emailController: accountEmailController,
              passwordController: accountPasswordController,
              isAuthenticating: isAuthenticatingAccount,
              isRecoveringPassword: isRecoveringPassword,
              isConfiguringRecoveryQuestions: isConfiguringRecoveryQuestions,
              isRestoring: isRestoringCloudBackup,
              isSyncing: isSyncingCloudBackup,
              hasCloudBackupAvailable: hasCloudBackupAvailable,
              isLoadingStatus: isLoadingCloudBackupStatus,
              lastCloudBackupAt: lastCloudBackupAt,
              lastCloudBackupAttemptAt: lastCloudBackupAttemptAt,
              lastCloudBackupSucceeded: lastCloudBackupSucceeded,
              lastCloudBackupFeedback: lastCloudBackupFeedback,
              onRegister: onRegisterAccount,
              onLogin: onLoginAccount,
              onAuthModeChanged: onAuthModeChanged,
              onOpenPasswordRecovery: onOpenPasswordRecovery,
              onOpenRecoveryQuestionsSetup: onOpenRecoveryQuestionsSetup,
              onBackupNow: onBackupNow,
              onRestoreFromCloud: onRestoreCloudBackup,
              onLogout: onLogoutAccount,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            AppUpdateSettingsCard(
              availableUpdate: availableUpdate,
              isCheckingForUpdate: isCheckingForUpdate,
              isOpeningUpdate: isOpeningUpdate,
              isBackgroundDownloadInProgress:
                  isBackgroundUpdateDownloadInProgress,
              backgroundDownloadProgress: backgroundUpdateProgress,
              backgroundUpdate: backgroundUpdate,
              onPressed: onOpenUpdateFromSettings,
            ),
            const SizedBox(height: 20),
            AppearanceSettingsPanel(
              isDarkTheme: isDarkTheme,
              appearanceSettings: appearanceSettings,
              isUpdatingThemeMode: isUpdatingThemeMode,
              onDarkThemeChanged: onDarkThemeChanged,
              onAppearanceSettingsChanged: onAppearanceSettingsChanged,
            ),
            const SizedBox(height: 20),
            DayCalendarSettingsCard(
              appearanceSettings: appearanceSettings,
              isUpdatingThemeMode: isUpdatingThemeMode,
              onAppearanceSettingsChanged: onAppearanceSettingsChanged,
            ),
          ],
        ),
      ),
    );
  }
}
