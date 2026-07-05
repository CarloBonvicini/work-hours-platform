import 'package:http/http.dart' as http;

/// Limita il tempo di attesa della risposta (header) cosi le richieste non
/// restano appese per sempre quando il server e irraggiungibile.
/// Lo streaming del body (es. download APK) non viene limitato.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, {this.timeout = const Duration(seconds: 30)});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() {
    _inner.close();
  }
}
