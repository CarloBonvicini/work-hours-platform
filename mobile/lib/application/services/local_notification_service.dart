import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';

class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _updateChannelId = 'work_hours_updates';
  static const _updateChannelName = 'Aggiornamenti app';
  static const _updateChannelDescription =
      'Notifiche quando è disponibile una nuova versione.';

  static const _ticketChannelId = 'work_hours_ticket_replies';
  static const _ticketChannelName = 'Risposte ticket';
  static const _ticketChannelDescription =
      'Notifiche quando l admin risponde ai ticket.';

  static const _lastNotifiedUpdateVersionKey =
      'local_notifications.last_notified_update_version';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(initializationSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _updateChannelId,
          _updateChannelName,
          description: _updateChannelDescription,
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _ticketChannelId,
          _ticketChannelName,
          description: _ticketChannelDescription,
          importance: Importance.high,
        ),
      );
    }

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) {
      return;
    }
    await initialize();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    final macOsPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macOsPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> notifyUpdateAvailable(AppUpdate update) async {
    if (kIsWeb) {
      return;
    }
    await initialize();

    final preferences = await SharedPreferences.getInstance();
    final lastNotifiedVersion = preferences.getString(
      _lastNotifiedUpdateVersionKey,
    );
    if (lastNotifiedVersion == update.latestVersion) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _updateChannelId,
        _updateChannelName,
        channelDescription: _updateChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      1001,
      'Nuovo aggiornamento disponibile',
      'Versione ${update.latestVersion} pronta da installare.',
      details,
      payload: 'update:${update.latestVersion}',
    );
    await preferences.setString(
      _lastNotifiedUpdateVersionKey,
      update.latestVersion,
    );
  }

  Future<void> notifyUpdateReadyToInstall({
    required String latestVersion,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _updateChannelId,
        _updateChannelName,
        channelDescription: _updateChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      1002,
      'Download completato',
      'Versione $latestVersion pronta. Apri l app per installare.',
      details,
      payload: 'update_ready:$latestVersion',
    );
  }

  Future<void> notifyTicketReplies({
    required String message,
  }) async {
    if (kIsWeb || message.trim().isEmpty) {
      return;
    }
    await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _ticketChannelId,
        _ticketChannelName,
        channelDescription: _ticketChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 20),
      'Nuove risposte ai ticket',
      message,
      details,
      payload: 'ticket_replies',
    );
  }
}
