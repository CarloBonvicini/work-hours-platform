// Card account cloud e stato backup.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/domain/models/account_session.dart';
import 'package:work_hours_mobile/presentation/home/logic/ticket_labels.dart';

enum AccountAuthMode { login, register }

class CloudBackupAccountCard extends StatelessWidget {
  const CloudBackupAccountCard({
    super.key,
    required this.accountSession,
    required this.selectedAuthMode,
    required this.emailController,
    required this.passwordController,
    required this.isAuthenticating,
    required this.isRecoveringPassword,
    required this.isConfiguringRecoveryQuestions,
    required this.isRestoring,
    required this.isSyncing,
    required this.hasCloudBackupAvailable,
    required this.isLoadingStatus,
    required this.lastCloudBackupAt,
    required this.lastCloudBackupAttemptAt,
    required this.lastCloudBackupSucceeded,
    required this.lastCloudBackupFeedback,
    required this.onRegister,
    required this.onLogin,
    required this.onAuthModeChanged,
    required this.onOpenPasswordRecovery,
    required this.onOpenRecoveryQuestionsSetup,
    required this.onBackupNow,
    required this.onRestoreFromCloud,
    required this.onLogout,
  });

  final AccountSession? accountSession;
  final AccountAuthMode selectedAuthMode;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isAuthenticating;
  final bool isRecoveringPassword;
  final bool isConfiguringRecoveryQuestions;
  final bool isRestoring;
  final bool isSyncing;
  final bool hasCloudBackupAvailable;
  final bool isLoadingStatus;
  final DateTime? lastCloudBackupAt;
  final DateTime? lastCloudBackupAttemptAt;
  final bool? lastCloudBackupSucceeded;
  final String? lastCloudBackupFeedback;
  final Future<void> Function() onRegister;
  final Future<void> Function() onLogin;
  final ValueChanged<AccountAuthMode> onAuthModeChanged;
  final Future<void> Function() onOpenPasswordRecovery;
  final Future<void> Function() onOpenRecoveryQuestionsSetup;
  final Future<void> Function() onBackupNow;
  final Future<void> Function() onRestoreFromCloud;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoggedIn = accountSession != null;
    final isBusy = isAuthenticating || isRecoveringPassword;
    final canRestoreFromCloud = hasCloudBackupAvailable && !isLoadingStatus;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account e backup cloud opzionale',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLoggedIn
                ? 'Sei registrato come ${accountSession!.user.email}. I dati restano su questo dispositivo e vengono anche salvati nel cloud, cosi puoi recuperarli dopo una disinstallazione o su un altro telefono.'
                : 'Puoi usare l app anche senza registrarti. In quel caso i dati restano solo su questo dispositivo e si perdono se disinstalli l app o cambi telefono. Se ti registri, profilo e impostazioni vengono salvati anche nel cloud.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (!isLoggedIn) ...[
            SegmentedButton<AccountAuthMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AccountAuthMode.login,
                  icon: Icon(Icons.login_rounded),
                  label: Text('Login'),
                ),
                ButtonSegment(
                  value: AccountAuthMode.register,
                  icon: Icon(Icons.person_add_alt_1_rounded),
                  label: Text('Registrati'),
                ),
              ],
              selected: {selectedAuthMode},
              onSelectionChanged: isBusy
                  ? null
                  : (selection) => onAuthModeChanged(selection.first),
            ),
            const SizedBox(height: 12),
            Text(
              selectedAuthMode == AccountAuthMode.register
                  ? 'Dopo la registrazione puoi impostare 2 domande di sicurezza per recuperare la password.'
                  : 'Accedi con email e password. Se non ricordi la password usa "Password dimenticata?".',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'Scegli la password che preferisci',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (selectedAuthMode == AccountAuthMode.register)
                  FilledButton.tonalIcon(
                    onPressed: isBusy ? null : () => onRegister(),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      isAuthenticating ? 'Attendi...' : 'Registrati e salva',
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: isBusy ? null : () => onLogin(),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(isAuthenticating ? 'Attendi...' : 'Accedi'),
                  ),
                if (selectedAuthMode == AccountAuthMode.login)
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => onAuthModeChanged(AccountAuthMode.register),
                    child: const Text('Non hai un account? Registrati'),
                  )
                else
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => onAuthModeChanged(AccountAuthMode.login),
                    child: const Text('Hai gia un account? Accedi'),
                  ),
                if (selectedAuthMode == AccountAuthMode.login)
                  TextButton(
                    onPressed: isBusy ? null : () => onOpenPasswordRecovery(),
                    child: Text(
                      isRecoveringPassword
                          ? 'Recupero in corso...'
                          : 'Password dimenticata?',
                    ),
                  ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: (isSyncing || isAuthenticating)
                      ? null
                      : () => onBackupNow(),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(isSyncing ? 'Sincronizzo...' : 'Backup ora'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      (isRestoring || isAuthenticating || !canRestoreFromCloud)
                      ? null
                      : () => onRestoreFromCloud(),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(
                    isRestoring ? 'Ripristino...' : 'Ripristina dal cloud',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isConfiguringRecoveryQuestions
                      ? null
                      : () => onOpenRecoveryQuestionsSetup(),
                  icon: const Icon(Icons.security_outlined),
                  label: Text(
                    isConfiguringRecoveryQuestions
                        ? 'Salvo domande...'
                        : 'Metodi di recupero',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isAuthenticating ? null : () => onLogout(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Esci'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasCloudBackupAvailable
                  ? 'Backup cloud disponibile: puoi ripristinarlo quando vuoi.'
                  : isLoadingStatus
                  ? 'Controllo disponibilita backup cloud...'
                  : 'Nessun backup cloud disponibile: fai prima "Backup ora".',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            CloudBackupStatusInfo(
              isLoadingStatus: isLoadingStatus,
              isSyncing: isSyncing,
              lastCloudBackupAt: lastCloudBackupAt,
              lastCloudBackupAttemptAt: lastCloudBackupAttemptAt,
              lastCloudBackupSucceeded: lastCloudBackupSucceeded,
              lastCloudBackupFeedback: lastCloudBackupFeedback,
            ),
          ],
        ],
      ),
    );
  }
}

class CloudBackupStatusInfo extends StatelessWidget {
  const CloudBackupStatusInfo({
    super.key,
    required this.isLoadingStatus,
    required this.isSyncing,
    required this.lastCloudBackupAt,
    required this.lastCloudBackupAttemptAt,
    required this.lastCloudBackupSucceeded,
    required this.lastCloudBackupFeedback,
  });

  final bool isLoadingStatus;
  final bool isSyncing;
  final DateTime? lastCloudBackupAt;
  final DateTime? lastCloudBackupAttemptAt;
  final bool? lastCloudBackupSucceeded;
  final String? lastCloudBackupFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (lastCloudBackupSucceeded) {
      true => theme.colorScheme.primary,
      false => theme.colorScheme.error,
      null => theme.colorScheme.onSurfaceVariant,
    };

    final statusLabel = switch (lastCloudBackupSucceeded) {
      true when lastCloudBackupAttemptAt != null =>
        'Ultimo tentativo: riuscito alle ${formatTicketDateTime(lastCloudBackupAttemptAt!)}',
      true => 'Ultimo tentativo: riuscito',
      false when lastCloudBackupAttemptAt != null =>
        'Ultimo tentativo: non riuscito alle ${formatTicketDateTime(lastCloudBackupAttemptAt!)}',
      false => 'Ultimo tentativo: non riuscito',
      null when isSyncing => 'Backup in corso...',
      null => 'Nessun tentativo recente.',
    };

    final lastCloudBackupLabel = isLoadingStatus
        ? 'Controllo ultimo backup cloud...'
        : lastCloudBackupAt == null
        ? 'Ultimo backup cloud: nessun backup salvato.'
        : 'Ultimo backup cloud: ${formatTicketDateTime(lastCloudBackupAt!)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lastCloudBackupLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            statusLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (lastCloudBackupFeedback != null &&
              lastCloudBackupFeedback!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(lastCloudBackupFeedback!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
