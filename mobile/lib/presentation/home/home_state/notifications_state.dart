// Notifiche locali e gestione delle push in foreground.

part of '../home_screen.dart';

mixin _NotificationsState on _HomeScreenStateBase {
  Future<void> _initializeRemotePushForegroundHandling() async {
    try {
      await _foregroundPushSubscription?.cancel();
      _foregroundPushSubscription = FirebaseMessaging.onMessage.listen((
        message,
      ) {
        unawaited(_handleForegroundRemotePush(message));
      });
    } catch (_) {
      // Foreground push handling is best-effort.
    }
  }

  Future<void> _handleForegroundRemotePush(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final type = _normalizePushDataValue(data['type']);

    if (type == 'ticket_reply') {
      final fallbackTicketMessage = data['message'];
      final ticketMessage = notification?.body?.trim().isNotEmpty == true
          ? notification!.body!.trim()
          : _normalizePushDataValue(fallbackTicketMessage) ??
                'Nuova risposta dal supporto.';
      await _localNotificationService.notifyTicketReplies(
        message: ticketMessage,
      );
      return;
    }

    if (type == 'app_update') {
      final fallbackUpdateMessage = data['message'];
      final updateMessage = notification?.body?.trim().isNotEmpty == true
          ? notification!.body!.trim()
          : _normalizePushDataValue(fallbackUpdateMessage) ??
                'Nuova versione disponibile. Apri l app per vedere le novita.';
      final updateTitle = notification?.title?.trim().isNotEmpty == true
          ? notification!.title!.trim()
          : 'Nuovo aggiornamento disponibile';
      await _localNotificationService.notifyUpdateMessage(
        title: updateTitle,
        message: updateMessage,
        version: _normalizePushDataValue(data['version']),
      );
      return;
    }
  }

  String? _normalizePushDataValue(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  @override
  Future<void> _initializeLocalNotifications() async {
    try {
      await _localNotificationService.initialize();
      await _localNotificationService.requestPermissions();
    } catch (_) {
      // Local notifications are best-effort and should not block app startup.
    }
  }

  @override
  void _handleOvertimeLimitExceededNotification(int exceededMinutes) {
    if (exceededMinutes <= 0 || !isSameDay(_selectedDate, _todayDate)) {
      _lastOvertimeExceededNotificationKey = null;
      return;
    }

    final notificationKey = DashboardService.defaultEntryDateOf(_selectedDate);
    if (_lastOvertimeExceededNotificationKey == notificationKey) {
      return;
    }
    _lastOvertimeExceededNotificationKey = notificationKey;

    unawaited(
      _localNotificationService.notifyOvertimeLimitExceeded(
        message:
            'Sei oltre il limite di straordinario di ${formatHoursInput(exceededMinutes)}.',
      ),
    );
  }
}
