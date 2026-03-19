import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    return message;
  }
}

class WorkHoursApiClient {
  WorkHoursApiClient({required String baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = _normalizeBaseUri(baseUrl),
      baseUrl = _normalizeBaseUri(baseUrl).toString();

  final http.Client _httpClient;
  final Uri _baseUri;
  final String baseUrl;

  Future<UserProfile> fetchProfile() async {
    final response = await _httpClient.get(_buildUri('profile'));
    return UserProfile.fromJson(_decodeObject(response));
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    required int dailyTargetMinutes,
  }) async {
    final response = await _httpClient.put(
      _buildUri('profile'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'fullName': fullName,
        'dailyTargetMinutes': dailyTargetMinutes,
      }),
    );

    return UserProfile.fromJson(_decodeObject(response));
  }

  Future<List<WorkEntry>> fetchWorkEntries({required String month}) async {
    final response = await _httpClient.get(
      _buildUri('work-entries', queryParameters: {'month': month}),
    );

    final body = _decodeObject(response);
    final items = body['items'];
    if (items is! List) {
      throw ApiException('Risposta work entries non valida.');
    }

    return items
        .map((item) => WorkEntry.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<WorkEntry> createWorkEntry({
    required String date,
    required int minutes,
    String? note,
  }) async {
    final response = await _httpClient.post(
      _buildUri('work-entries'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'date': date,
        'minutes': minutes,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );

    return WorkEntry.fromJson(_decodeObject(response));
  }

  Future<MonthlySummary> fetchMonthlySummary({required String month}) async {
    final response = await _httpClient.get(_buildUri('monthly-summary/$month'));
    return MonthlySummary.fromJson(_decodeObject(response));
  }

  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    return _baseUri.resolve(path).replace(queryParameters: queryParameters);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = _decodeResponse(response);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Risposta API non valida.');
    }

    return decoded;
  }

  dynamic _decodeResponse(http.Response response) {
    final hasBody = response.bodyBytes.isNotEmpty;
    final decodedBody = hasBody
        ? jsonDecode(utf8.decode(response.bodyBytes))
        : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    if (decodedBody is Map<String, dynamic> && decodedBody['error'] is String) {
      throw ApiException(
        decodedBody['error'] as String,
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Richiesta fallita (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  static Uri _normalizeBaseUri(String baseUrl) {
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBaseUrl);
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
