import 'package:flutter/foundation.dart';

class WorkHoursApiConfig {
  const WorkHoursApiConfig({required this.baseUrl});

  final String baseUrl;

  static WorkHoursApiConfig fromEnvironment() {
    return WorkHoursApiConfig(baseUrl: _resolveBaseUrl());
  }

  static String _resolveBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
  }
}
