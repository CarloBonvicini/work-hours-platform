// Card aggiornamenti app nelle impostazioni.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/presentation/home/logic/download_size_label.dart';

class AppUpdateSettingsCard extends StatelessWidget {
  const AppUpdateSettingsCard({
    super.key,
    required this.availableUpdate,
    required this.isCheckingForUpdate,
    required this.isOpeningUpdate,
    required this.isBackgroundDownloadInProgress,
    required this.backgroundDownloadProgress,
    required this.backgroundUpdate,
    required this.onPressed,
  });

  final AppUpdate? availableUpdate;
  final bool isCheckingForUpdate;
  final bool isOpeningUpdate;
  final bool isBackgroundDownloadInProgress;
  final UpdateDownloadProgress backgroundDownloadProgress;
  final AppUpdate? backgroundUpdate;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUpdate = availableUpdate != null;
    final backgroundVersion =
        backgroundUpdate?.latestVersion ?? availableUpdate?.latestVersion;
    final title = isBackgroundDownloadInProgress
        ? 'Download in background'
        : hasUpdate
        ? 'Aggiornamento disponibile'
        : 'Aggiornamenti app';
    final subtitle = isBackgroundDownloadInProgress
        ? backgroundVersion == null
              ? 'Sto scaricando l aggiornamento in background. Puoi continuare a usare l app.'
              : 'Sto scaricando la versione $backgroundVersion in background. Puoi continuare a usare l app.'
        : hasUpdate
        ? 'Versione attuale ${availableUpdate!.currentVersion} -> nuova versione ${availableUpdate!.latestVersion}'
        : 'Controlla manualmente se c e una nuova versione, anche se hai scelto di ricordartelo piu tardi.';

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
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          if (isBackgroundDownloadInProgress) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: backgroundDownloadProgress.fractionCompleted,
            ),
            const SizedBox(height: 8),
            Text(
              backgroundDownloadProgress.totalBytes == null
                  ? '${formatDownloadSize(backgroundDownloadProgress.receivedBytes)} scaricati'
                  : '${formatDownloadSize(backgroundDownloadProgress.receivedBytes)} di ${formatDownloadSize(backgroundDownloadProgress.totalBytes!)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            key: const ValueKey('settings-update-button'),
            onPressed:
                (isCheckingForUpdate ||
                    isOpeningUpdate ||
                    isBackgroundDownloadInProgress)
                ? null
                : () => onPressed(),
            icon: Icon(
              isBackgroundDownloadInProgress
                  ? Icons.download_rounded
                  : hasUpdate
                  ? Icons.system_update_alt
                  : Icons.refresh_rounded,
            ),
            label: Text(
              isCheckingForUpdate
                  ? 'Controllo...'
                  : isOpeningUpdate
                  ? 'Apro...'
                  : isBackgroundDownloadInProgress
                  ? 'Download in background...'
                  : hasUpdate
                  ? 'Aggiorna ora'
                  : 'Controlla aggiornamenti',
            ),
          ),
        ],
      ),
    );
  }
}
