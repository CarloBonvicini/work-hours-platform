// Dialogo di download e installazione dell'aggiornamento.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/theme/work_hours_colors.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/presentation/home/logic/download_size_label.dart';
import 'package:work_hours_mobile/presentation/home/logic/update_release_notes_parser.dart';

enum UpdateDownloadState { downloading, readyToInstall, failed, installing }

enum UpdateDownloadDialogAction { downloadInBackground }

class UpdateDownloadDialog extends StatefulWidget {
  const UpdateDownloadDialog({
    super.key,
    required this.update,
    required this.appUpdateService,
    required this.onOpenReleasePage,
    required this.onBackgroundDownloadEnabled,
    required this.onBackgroundProgress,
    required this.onBackgroundDownloadCompleted,
    required this.onBackgroundDownloadFailed,
  });

  final AppUpdate update;
  final AppUpdateService appUpdateService;
  final Future<void> Function() onOpenReleasePage;
  final VoidCallback onBackgroundDownloadEnabled;
  final ValueChanged<UpdateDownloadProgress> onBackgroundProgress;
  final Future<void> Function(DownloadedAppUpdate downloadedUpdate)
  onBackgroundDownloadCompleted;
  final VoidCallback onBackgroundDownloadFailed;

  @override
  State<UpdateDownloadDialog> createState() => UpdateDownloadDialogState();
}

class UpdateDownloadDialogState extends State<UpdateDownloadDialog> {
  UpdateDownloadProgress _progress = const UpdateDownloadProgress(
    receivedBytes: 0,
    totalBytes: null,
  );
  DownloadedAppUpdate? _downloadedUpdate;
  UpdateDownloadState _state = UpdateDownloadState.downloading;
  bool _isNewFeatureExpanded = false;
  bool _continueInBackground = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = UpdateDownloadState.downloading;
      _message = null;
      _downloadedUpdate = null;
      _progress = const UpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      );
    });

    try {
      final downloadedUpdate = await widget.appUpdateService.downloadUpdate(
        widget.update,
        onProgress: (progress) {
          if (_continueInBackground) {
            widget.onBackgroundProgress(progress);
          }
          if (!mounted) {
            return;
          }

          setState(() {
            _progress = progress;
          });
        },
      );

      if (_continueInBackground) {
        unawaited(widget.onBackgroundDownloadCompleted(downloadedUpdate));
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _downloadedUpdate = downloadedUpdate;
        _state = UpdateDownloadState.readyToInstall;
      });
    } catch (_) {
      if (!mounted) {
        if (_continueInBackground) {
          widget.onBackgroundDownloadFailed();
        }
        return;
      }

      setState(() {
        _state = UpdateDownloadState.failed;
        _message = 'Download non riuscito. Controlla la connessione e riprova.';
      });
      if (_continueInBackground) {
        widget.onBackgroundDownloadFailed();
      }
    }
  }

  void _continueDownloadInBackground() {
    if (_state != UpdateDownloadState.downloading || _continueInBackground) {
      return;
    }

    _continueInBackground = true;
    widget.onBackgroundDownloadEnabled();
    Navigator.of(context).pop(UpdateDownloadDialogAction.downloadInBackground);
  }

  Future<void> _installDownloadedUpdate() async {
    final downloadedUpdate = _downloadedUpdate;
    if (downloadedUpdate == null || _state == UpdateDownloadState.installing) {
      return;
    }

    setState(() {
      _state = UpdateDownloadState.installing;
      _message = null;
    });

    final result = await widget.appUpdateService.installUpdate(
      downloadedUpdate,
    );
    if (!mounted) {
      return;
    }

    switch (result) {
      case UpdateInstallResult.started:
        Navigator.of(context).pop();
        break;
      case UpdateInstallResult.permissionRequired:
        setState(() {
          _state = UpdateDownloadState.readyToInstall;
          _message =
              'Per installare l APK devi autorizzare questa app nelle impostazioni Android, poi tocca di nuovo Installa.';
        });
        break;
      case UpdateInstallResult.failed:
        setState(() {
          _state = UpdateDownloadState.readyToInstall;
          _message = 'Impossibile avviare l installazione dell aggiornamento.';
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final newFeatureItems = _resolveNewFeatureItems(widget.update.releaseNotes);
    final progressText = _progress.totalBytes == null
        ? '${formatDownloadSize(_progress.receivedBytes)} scaricati'
        : '${formatDownloadSize(_progress.receivedBytes)} di ${formatDownloadSize(_progress.totalBytes!)}';

    return AlertDialog(
      title: Text(_resolveTitle()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versione attuale ${widget.update.currentVersion} -> nuova versione ${widget.update.latestVersion}',
            ),
            const SizedBox(height: 12),
            _buildNewFeatureSection(context, featureItems: newFeatureItems),
            const SizedBox(height: 16),
            if (_state == UpdateDownloadState.downloading) ...[
              LinearProgressIndicator(value: _progress.fractionCompleted),
              const SizedBox(height: 12),
              Text(progressText),
            ] else if (_state == UpdateDownloadState.readyToInstall) ...[
              const Text(
                'Download completato. Quando sei pronto puoi avviare subito l installazione.',
              ),
              const SizedBox(height: 12),
              if (_downloadedUpdate != null)
                Text(
                  'File pronto: ${_downloadedUpdate!.fileName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ] else if (_state == UpdateDownloadState.installing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Avvio dell installazione in corso...'),
            ] else ...[
              const Text(
                'Non siamo riusciti a scaricare l aggiornamento dentro l app.',
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WorkHoursColors.of(context).debit,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _state == UpdateDownloadState.installing ||
                  _state == UpdateDownloadState.downloading
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Piu tardi'),
        ),
        if (_state == UpdateDownloadState.downloading)
          OutlinedButton.icon(
            onPressed: _continueDownloadInBackground,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Scarica in background'),
          ),
        if (_state == UpdateDownloadState.failed)
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton(
                onPressed: () async {
                  await widget.onOpenReleasePage();
                },
                child: const Text('Apri pagina release'),
              ),
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          )
        else if (_state == UpdateDownloadState.readyToInstall)
          FilledButton.icon(
            onPressed: _installDownloadedUpdate,
            icon: const Icon(Icons.install_mobile_outlined),
            label: const Text('Installa'),
          ),
      ],
    );
  }

  Widget _buildNewFeatureSection(
    BuildContext context, {
    required List<String> featureItems,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasFeatures = featureItems.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF142121) : const Color(0xFFF4FBFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2C4747) : const Color(0xFFD4E8E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _isNewFeatureExpanded = !_isNewFeatureExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Novita di questa versione',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isNewFeatureExpanded ? 'Nascondi' : 'Apri',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isNewFeatureExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_isNewFeatureExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: hasFeatures
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: featureItems
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '- $item',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    )
                  : Text(
                      'Aggiornamento con miglioramenti generali per l uso quotidiano.',
                      style: theme.textTheme.bodyMedium,
                    ),
            ),
        ],
      ),
    );
  }

  List<String> _resolveNewFeatureItems(String? releaseNotes) {
    if (releaseNotes == null) {
      return const [];
    }

    final lines = resolveUserFacingReleaseNotes(releaseNotes);
    final items = <String>[];
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      if (line.startsWith('#') || line.startsWith('```')) {
        continue;
      }

      final lowerLine = line.toLowerCase();
      if (lowerLine.startsWith('what\'s changed') ||
          lowerLine.startsWith("what’s changed") ||
          lowerLine.startsWith('new contributors')) {
        continue;
      }

      if (line.toLowerCase().startsWith('full changelog')) {
        continue;
      }

      final cleaned = line
          .replaceFirst(RegExp(r'^[-*+]\s+'), '')
          .replaceFirst(RegExp(r'^\d+\.\s+'), '')
          .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
          .replaceAll(RegExp(r'\s*\(#\d+\)$'), '')
          .replaceAll(RegExp(r'\s+by\s+@[\w-]+\s*$', caseSensitive: false), '')
          .trim();
      if (cleaned.isEmpty) {
        continue;
      }
      if (_isGenericBuildNote(cleaned)) {
        continue;
      }

      items.add(cleaned);
      if (items.length >= 5) {
        break;
      }
    }

    if (items.isNotEmpty) {
      return items;
    }

    final compact = resolveUserFacingReleaseNotes(
      releaseNotes,
    ).join(' ').trim();
    if (compact.isEmpty) {
      return const [];
    }
    if (_isGenericBuildNote(compact)) {
      return const [];
    }

    if (compact.length <= 120) {
      return [compact];
    }

    return ['${compact.substring(0, 117)}...'];
  }

  String _resolveTitle() {
    switch (_state) {
      case UpdateDownloadState.downloading:
        return 'Scarico aggiornamento';
      case UpdateDownloadState.readyToInstall:
        return 'Aggiornamento pronto';
      case UpdateDownloadState.failed:
        return 'Download non riuscito';
      case UpdateDownloadState.installing:
        return 'Avvio installazione';
    }
  }

  bool _isGenericBuildNote(String value) {
    final normalized = value.toLowerCase().trim();
    return RegExp(
      r'^android apk build[\s:]+v?\d+(\.\d+){1,4}\.?$',
    ).hasMatch(normalized);
  }
}
