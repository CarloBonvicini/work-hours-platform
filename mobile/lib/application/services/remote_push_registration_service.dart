import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';

@pragma('vm:entry-point')
Future<void> remotePushBackgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase init is best-effort in background.
  }
}

class RemotePushRegistrationService {
  RemotePushRegistrationService({
    required this.baseUrl,
    this.appVersion = const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '0.1.0',
    ),
  });

  final String baseUrl;
  final String appVersion;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  bool _available = true;

  Future<void> initialize() async {
    if (_initialized || !_available || kIsWeb) {
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(remotePushBackgroundMessageHandler);
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _registerTokenSafely(token.trim());
      }

      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((nextToken) {
            final trimmed = nextToken.trim();
            if (trimmed.isEmpty) {
              return;
            }
            unawaited(_registerTokenSafely(trimmed));
          });

      _initialized = true;
    } on FirebaseException catch (error) {
      debugPrint('Remote push Firebase init failed: $error');
      _available = false;
    } catch (error) {
      // Keep service available for future app restarts when transient failures occur.
      debugPrint('Remote push initialization failed: $error');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  Future<void> _registerToken(String token) async {
    final client = WorkHoursApiClient(baseUrl: baseUrl);
    await client.registerMobilePushToken(
      token: token,
      platform: _platformName,
      appVersion: appVersion,
    );
  }

  Future<void> _registerTokenSafely(String token) async {
    try {
      await _registerToken(token);
    } catch (error) {
      debugPrint('Unable to register mobile push token: $error');
    }
  }

  String get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
