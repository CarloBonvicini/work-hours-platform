import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:work_hours_mobile/domain/models/account_session.dart';
import 'package:work_hours_mobile/domain/models/account_recovery_questions.dart';
import 'package:work_hours_mobile/domain/models/cloud_backup_bundle.dart';
import 'package:work_hours_mobile/domain/models/cloud_backup_status.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/monthly_summary.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
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
  WorkHoursApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.authToken,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = _normalizeBaseUri(baseUrl),
       baseUrl = _normalizeBaseUri(baseUrl).toString();

  final http.Client _httpClient;
  final Uri _baseUri;
  final String baseUrl;
  final String? authToken;

  Future<UserProfile> fetchProfile() async {
    final response = await _httpClient.get(
      _buildUri('profile'),
      headers: _headers(),
    );
    return UserProfile.fromJson(_decodeObject(response));
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    required bool useUniformDailyTarget,
    required int dailyTargetMinutes,
    required WeekdayTargetMinutes weekdayTargetMinutes,
    required WeekdaySchedule weekdaySchedule,
    required UserWorkRules workRules,
  }) async {
    final response = await _httpClient.put(
      _buildUri('profile'),
      headers: _headers(json: true),
      body: jsonEncode({
        'fullName': fullName,
        'useUniformDailyTarget': useUniformDailyTarget,
        'dailyTargetMinutes': dailyTargetMinutes,
        'weekdayTargetMinutes': weekdayTargetMinutes.toJson(),
        'weekdaySchedule': weekdaySchedule.toJson(),
        'workRules': workRules.toJson(),
      }),
    );

    return UserProfile.fromJson(_decodeObject(response));
  }

  Future<List<WorkEntry>> fetchWorkEntries({String? month}) async {
    final response = await _httpClient.get(
      _buildUri(
        'work-entries',
        queryParameters: month == null ? null : {'month': month},
      ),
      headers: _headers(),
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
      headers: _headers(json: true),
      body: jsonEncode({
        'date': date,
        'minutes': minutes,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );

    return WorkEntry.fromJson(_decodeObject(response));
  }

  Future<List<LeaveEntry>> fetchLeaveEntries({String? month}) async {
    final response = await _httpClient.get(
      _buildUri(
        'leave-entries',
        queryParameters: month == null ? null : {'month': month},
      ),
      headers: _headers(),
    );

    final body = _decodeObject(response);
    final items = body['items'];
    if (items is! List) {
      throw ApiException('Risposta leave entries non valida.');
    }

    return items
        .map((item) => LeaveEntry.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<LeaveEntry> createLeaveEntry({
    required String date,
    required int minutes,
    required LeaveType type,
    String? note,
  }) async {
    final response = await _httpClient.post(
      _buildUri('leave-entries'),
      headers: _headers(json: true),
      body: jsonEncode({
        'date': date,
        'minutes': minutes,
        'type': type.apiValue,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );

    return LeaveEntry.fromJson(_decodeObject(response));
  }

  Future<MonthlySummary> fetchMonthlySummary({required String month}) async {
    final response = await _httpClient.get(
      _buildUri('monthly-summary/$month'),
      headers: _headers(),
    );
    return MonthlySummary.fromJson(_decodeObject(response));
  }

  Future<List<ScheduleOverride>> fetchScheduleOverrides({String? month}) async {
    final response = await _httpClient.get(
      _buildUri(
        'schedule-overrides',
        queryParameters: month == null ? null : {'month': month},
      ),
      headers: _headers(),
    );

    final body = _decodeObject(response);
    final items = body['items'];
    if (items is! List) {
      throw ApiException('Risposta schedule overrides non valida.');
    }

    return items
        .map((item) => ScheduleOverride.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ScheduleOverride> createScheduleOverride({
    required String date,
    required int targetMinutes,
    String? startTime,
    String? endTime,
    required int breakMinutes,
    String? note,
  }) async {
    final response = await _httpClient.post(
      _buildUri('schedule-overrides'),
      headers: _headers(json: true),
      body: jsonEncode({
        'date': date,
        'targetMinutes': targetMinutes,
        if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
        if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
        'breakMinutes': breakMinutes,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );

    return ScheduleOverride.fromJson(_decodeObject(response));
  }

  Future<void> deleteScheduleOverride({required String date}) async {
    final response = await _httpClient.delete(
      _buildUri('schedule-overrides/$date'),
      headers: _headers(),
    );
    _decodeResponse(response);
  }

  Future<SupportTicketThread> createSupportTicket({
    required SupportTicketCategory category,
    String? name,
    String? email,
    required String subject,
    required String message,
    String? appVersion,
    List<SupportTicketUploadAttachment> attachments = const [],
  }) async {
    final response = await _httpClient.post(
      _buildUri('tickets'),
      headers: _headers(json: true),
      body: jsonEncode({
        'category': category.apiValue,
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        'subject': subject,
        'message': message,
        if (appVersion != null && appVersion.isNotEmpty)
          'appVersion': appVersion,
        if (attachments.isNotEmpty)
          'attachments': attachments
              .map(
                (attachment) => {
                  'fileName': attachment.fileName,
                  'contentType': attachment.contentType,
                  'base64Data': base64Encode(attachment.bytes),
                },
              )
              .toList(growable: false),
      }),
    );

    return SupportTicketThread.fromJson(_decodeObject(response));
  }

  Future<SupportTicketThread> fetchSupportTicket({
    required String ticketId,
  }) async {
    final response = await _httpClient.get(
      _buildUri('tickets/$ticketId'),
      headers: _headers(),
    );
    return SupportTicketThread.fromJson(_decodeObject(response));
  }

  Future<SupportTicketThread> replyToSupportTicket({
    required String ticketId,
    required String message,
  }) async {
    final response = await _httpClient.post(
      _buildUri('tickets/$ticketId/replies'),
      headers: _headers(json: true),
      body: jsonEncode({'message': message}),
    );

    return SupportTicketThread.fromJson(_decodeObject(response));
  }

  Future<AccountSession> register({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      _buildUri('auth/register'),
      headers: _headers(json: true),
      body: jsonEncode({'email': email, 'password': password}),
    );

    return AccountSession.fromJson(_decodeObject(response));
  }

  Future<AccountSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      _buildUri('auth/login'),
      headers: _headers(json: true),
      body: jsonEncode({'email': email, 'password': password}),
    );

    return AccountSession.fromJson(_decodeObject(response));
  }

  Future<AccountRecoveryQuestions> fetchRecoveryQuestions({
    required String email,
  }) async {
    final response = await _httpClient.post(
      _buildUri('auth/recovery-questions'),
      headers: _headers(json: true),
      body: jsonEncode({
        'email': email,
      }),
    );

    return AccountRecoveryQuestions.fromJson(_decodeObject(response));
  }

  Future<void> configureRecoveryQuestions({
    required String questionOne,
    required String answerOne,
    required String questionTwo,
    required String answerTwo,
  }) async {
    final response = await _httpClient.put(
      _buildUri('me/recovery-questions'),
      headers: _headers(json: true),
      body: jsonEncode({
        'questionOne': questionOne,
        'answerOne': answerOne,
        'questionTwo': questionTwo,
        'answerTwo': answerTwo,
      }),
    );

    _decodeResponse(response);
  }

  Future<void> recoverPassword({
    required String email,
    required String answerOne,
    required String answerTwo,
    required String newPassword,
  }) async {
    final response = await _httpClient.post(
      _buildUri('auth/recover-password'),
      headers: _headers(json: true),
      body: jsonEncode({
        'email': email,
        'answerOne': answerOne,
        'answerTwo': answerTwo,
        'newPassword': newPassword,
      }),
    );
    _decodeResponse(response);
  }

  Future<void> logout() async {
    final response = await _httpClient.delete(
      _buildUri('auth/session'),
      headers: _headers(),
    );
    _decodeResponse(response);
  }

  Future<CloudBackupBundle?> fetchCloudBackup() async {
    final response = await _httpClient.get(
      _buildUri('me/backup'),
      headers: _headers(),
    );

    final body = _decodeObject(response);
    final hasBackup = body['hasBackup'] as bool? ?? false;
    if (!hasBackup || body['bundle'] == null) {
      return null;
    }

    return CloudBackupBundle.fromJson(body['bundle'] as Map<String, dynamic>);
  }

  Future<CloudBackupStatus> fetchCloudBackupStatus() async {
    final response = await _httpClient.get(
      _buildUri('me/backup/meta'),
      headers: _headers(),
    );
    final body = _decodeObject(response);
    return CloudBackupStatus(
      hasBackup: body['hasBackup'] as bool? ?? false,
      updatedAt: _parseDateTimeOrNull(body['updatedAt']),
    );
  }

  Future<CloudBackupStatus> saveCloudBackup(CloudBackupBundle bundle) async {
    final response = await _httpClient.put(
      _buildUri('me/backup'),
      headers: _headers(json: true),
      body: jsonEncode(bundle.toJson()),
    );

    final body = _decodeObject(response);
    return CloudBackupStatus(
      hasBackup: true,
      updatedAt:
          _parseDateTimeOrNull(body['savedAt']) ??
          _parseDateTimeOrNull(
            (body['bundle'] as Map<String, dynamic>?)?['updatedAt'],
          ),
    );
  }

  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    return _baseUri.resolve(path).replace(queryParameters: queryParameters);
  }

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (authToken != null && authToken!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${authToken!.trim()}';
    }
    return headers;
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

  DateTime? _parseDateTimeOrNull(Object? rawValue) {
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(rawValue).toLocal();
    } catch (_) {
      return null;
    }
  }

  static Uri _normalizeBaseUri(String baseUrl) {
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBaseUrl);
  }
}
