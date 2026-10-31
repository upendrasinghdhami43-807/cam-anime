import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base URL of the optional test backend gateway. For a USB phone run `adb reverse tcp:8080 tcp:8080`
/// and keep the default; for an emulator use `--dart-define=BACKEND_URL=http://10.0.2.2:8080`.
const backendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:8080',
);

class BackendException implements Exception {
  const BackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackendHealth {
  const BackendHealth({
    required this.gateway,
    required this.api,
    required this.database,
  });

  factory BackendHealth.fromJson(Map<String, Object?> json) {
    final upstream = (json['upstream'] as Map<String, Object?>?) ?? const {};
    return BackendHealth(
      gateway: json['status'] as String? ?? 'unknown',
      api: upstream['status'] as String? ?? 'unknown',
      database: upstream['db'] as String? ?? 'unknown',
    );
  }

  final String gateway;
  final String api;
  final String database;

  bool get healthy => gateway == 'ok' && api == 'ok' && database == 'ok';
}

class CartoonStyleInfo {
  const CartoonStyleInfo({
    required this.id,
    required this.name,
    required this.version,
  });

  factory CartoonStyleInfo.fromJson(Map<String, Object?> json) =>
      CartoonStyleInfo(
        id: json['id']! as String,
        name: json['name']! as String,
        version: (json['version'] as num?)?.toInt() ?? 1,
      );

  final String id;
  final String name;
  final int version;
}

/// Client for the single public API (the gateway). The app never needs it to work: camera, styles,
/// capture and storage are fully offline. The release build has no INTERNET permission.
class BackendClient {
  BackendClient({http.Client? client, String baseUrl = backendBaseUrl})
    : _client = client ?? http.Client(),
      _base = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _base;
  static const _timeout = Duration(seconds: 5);

  Uri _uri(String path) => _base.replace(path: path);

  Future<Map<String, Object?>> _json(Future<http.Response> request) async {
    try {
      final response = await request.timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendException('HTTP ${response.statusCode}');
      }
      return jsonDecode(response.body) as Map<String, Object?>;
    } on BackendException {
      rethrow;
    } on Object catch (e) {
      throw BackendException('Backend unreachable: ${e.runtimeType}');
    }
  }

  Future<BackendHealth> health() async =>
      BackendHealth.fromJson(await _json(_client.get(_uri('/health'))));

  Future<List<CartoonStyleInfo>> styles() async {
    final body = await _json(_client.get(_uri('/v1/styles')));
    return [
      for (final item in (body['items'] as List<Object?>? ?? const []))
        CartoonStyleInfo.fromJson(item! as Map<String, Object?>),
    ];
  }

  Future<String> sendFeedback({
    required String message,
    required String appVersion,
    String? device,
  }) async {
    final body = await _json(
      _client.post(
        _uri('/v1/feedback'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'appVersion': appVersion,
          'device': ?device,
        }),
      ),
    );
    return body['id']! as String;
  }

  void close() => _client.close();
}
