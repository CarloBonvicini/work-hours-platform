// Controllo, download e installazione degli aggiornamenti dell'app.

part of '../home_screen.dart';

mixin _AppUpdatesState on _HomeScreenStateBase {
  Future<void> _initializeUpdateExperience() async {
    await _initializeLocalNotifications();
    if (!mounted) {
      return;
    }

    await _checkForUpdate();
  }

  @override
  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingForUpdate = true;
    });

    try {
      final availableUpdate = await widget.appUpdateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _availableUpdate = availableUpdate;
        _isCheckingForUpdate = false;
      });
      if (availableUpdate != null) {
        unawaited(
          _localNotificationService.notifyUpdateAvailable(availableUpdate),
        );
        await _maybePromptForUpdate(availableUpdate);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _availableUpdate = null;
        _isCheckingForUpdate = false;
      });
    }
  }

  Future<void> _maybePromptForUpdate(AppUpdate update) async {
    if (_isShowingUpdateDialog) {
      return;
    }

    final shouldPrompt = await widget.updateReminderStore.shouldPromptFor(
      update,
    );
    if (!mounted || !shouldPrompt) {
      return;
    }

    _isShowingUpdateDialog = true;
    final action = await showDialog<UpdateDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(update: update),
    );
    _isShowingUpdateDialog = false;

    if (!mounted) {
      return;
    }

    switch (action) {
      case UpdateDialogAction.updateNow:
        await widget.updateReminderStore.deferAfterOpening(update);
        await _startInAppUpdateFlow(update);
        break;
      case UpdateDialogAction.remindLater:
      case null:
        await widget.updateReminderStore.remindLater(update);
        break;
    }
  }

  Future<void> _openUpdate() async {
    final availableUpdate = _availableUpdate;
    if (availableUpdate == null || _isOpeningUpdate) {
      return;
    }

    setState(() {
      _isOpeningUpdate = true;
    });

    final didOpen = await widget.appUpdateService.openUpdate(availableUpdate);
    if (!mounted) {
      return;
    }

    setState(() {
      _isOpeningUpdate = false;
    });

    if (didOpen) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Impossibile aprire l aggiornamento. Apri manualmente ${availableUpdate.releasePageUrl}',
        ),
      ),
    );
  }

  @override
  Future<void> _openUpdateFromSettings() async {
    if (_isOpeningUpdate || _isCheckingForUpdate) {
      return;
    }

    final downloadedUpdate = _backgroundDownloadedUpdate;
    if (downloadedUpdate != null) {
      await _promptInstallDownloadedUpdate(downloadedUpdate);
      return;
    }

    if (_isBackgroundUpdateDownloadInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download aggiornamento in background gia in corso.'),
        ),
      );
      return;
    }

    final cachedUpdate = _availableUpdate;
    if (cachedUpdate != null) {
      await _startInAppUpdateFlow(cachedUpdate);
      return;
    }

    setState(() {
      _isCheckingForUpdate = true;
    });

    try {
      final availableUpdate = await widget.appUpdateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _availableUpdate = availableUpdate;
        _isCheckingForUpdate = false;
      });

      if (availableUpdate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hai gia l ultima versione.')),
        );
        return;
      }

      await _startInAppUpdateFlow(availableUpdate);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingForUpdate = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Controllo aggiornamenti non riuscito.')),
      );
    }
  }

  Future<void> _startInAppUpdateFlow(AppUpdate update) async {
    final result = await showDialog<UpdateDownloadDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDownloadDialog(
        update: update,
        appUpdateService: widget.appUpdateService,
        onOpenReleasePage: _openUpdate,
        onBackgroundDownloadEnabled: () =>
            _handleBackgroundUpdateDownloadEnabled(update),
        onBackgroundProgress: _handleBackgroundUpdateDownloadProgress,
        onBackgroundDownloadCompleted: _handleBackgroundUpdateDownloadCompleted,
        onBackgroundDownloadFailed: _handleBackgroundUpdateDownloadFailed,
      ),
    );
    if (!mounted) {
      return;
    }

    if (result == UpdateDownloadDialogAction.downloadInBackground) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Download in background attivo. Puoi continuare a usare l app.',
          ),
        ),
      );
    }
  }

  void _handleBackgroundUpdateDownloadEnabled(AppUpdate update) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBackgroundUpdateDownloadInProgress = true;
      _backgroundUpdate = update;
      _backgroundDownloadedUpdate = null;
      _backgroundUpdateProgress = const UpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      );
    });
  }

  void _handleBackgroundUpdateDownloadProgress(
    UpdateDownloadProgress progress,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBackgroundUpdateDownloadInProgress = true;
      _backgroundUpdateProgress = progress;
    });
  }

  Future<void> _handleBackgroundUpdateDownloadCompleted(
    DownloadedAppUpdate downloadedUpdate,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBackgroundUpdateDownloadInProgress = false;
      _backgroundDownloadedUpdate = downloadedUpdate;
      _backgroundUpdate = downloadedUpdate.update;
      _backgroundUpdateProgress = UpdateDownloadProgress(
        receivedBytes: downloadedUpdate.bytesDownloaded,
        totalBytes: downloadedUpdate.bytesDownloaded,
      );
    });

    await _localNotificationService.notifyUpdateReadyToInstall(
      latestVersion: downloadedUpdate.update.latestVersion,
    );
    if (!mounted) {
      return;
    }

    await _promptInstallDownloadedUpdate(downloadedUpdate);
  }

  void _handleBackgroundUpdateDownloadFailed() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBackgroundUpdateDownloadInProgress = false;
      _backgroundDownloadedUpdate = null;
      _backgroundUpdate = null;
      _backgroundUpdateProgress = const UpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Download in background non riuscito. Riprova dagli aggiornamenti.',
        ),
      ),
    );
  }

  Future<void> _promptInstallDownloadedUpdate(
    DownloadedAppUpdate downloadedUpdate,
  ) async {
    if (!mounted || _isPromptingBackgroundUpdateInstall) {
      return;
    }

    _isPromptingBackgroundUpdateInstall = true;
    final shouldInstall = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Aggiornamento pronto'),
        content: Text(
          'Download completato per la versione ${downloadedUpdate.update.latestVersion}. Vuoi installarla ora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Piu tardi'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.install_mobile_outlined),
            label: const Text('Installa ora'),
          ),
        ],
      ),
    );
    _isPromptingBackgroundUpdateInstall = false;

    if (!mounted || shouldInstall != true) {
      return;
    }

    final result = await widget.appUpdateService.installUpdate(
      downloadedUpdate,
    );
    if (!mounted) {
      return;
    }

    switch (result) {
      case UpdateInstallResult.started:
        setState(() {
          _backgroundDownloadedUpdate = null;
          _backgroundUpdate = null;
          _backgroundUpdateProgress = const UpdateDownloadProgress(
            receivedBytes: 0,
            totalBytes: null,
          );
        });
        break;
      case UpdateInstallResult.permissionRequired:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Per installare l APK devi autorizzare questa app nelle impostazioni Android.',
            ),
          ),
        );
        break;
      case UpdateInstallResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile avviare l installazione.')),
        );
        break;
    }
  }
}
