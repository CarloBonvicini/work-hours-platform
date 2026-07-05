import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:work_hours_mobile/data/api/timeout_http_client.dart';

class _NeverRespondingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}

class _ImmediateClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"status":"ok"}')),
      200,
    );
  }
}

void main() {
  test('interrompe le richieste senza risposta entro il timeout', () async {
    final client = TimeoutHttpClient(
      _NeverRespondingClient(),
      timeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      client.get(Uri.parse('http://example.invalid/health')),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('lascia passare le risposte arrivate entro il timeout', () async {
    final client = TimeoutHttpClient(
      _ImmediateClient(),
      timeout: const Duration(seconds: 5),
    );

    final response = await client.get(
      Uri.parse('http://example.invalid/health'),
    );

    expect(response.statusCode, 200);
    expect(response.body, '{"status":"ok"}');
  });
}
