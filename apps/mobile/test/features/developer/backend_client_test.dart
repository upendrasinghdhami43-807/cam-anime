import 'dart:convert';

import 'package:camanime/features/developer/data/backend_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('health parses the gateway response', () async {
    final client = BackendClient(
      baseUrl: 'http://gw',
      client: MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'upstream': {'status': 'ok', 'db': 'ok'},
          }),
          200,
        );
      }),
    );

    expect((await client.health()).healthy, isTrue);
  });

  test('styles are read from items', () async {
    final client = BackendClient(
      baseUrl: 'http://gw',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'items': [
              {'id': 'cel_pop', 'name': 'Cel Pop', 'version': 1},
            ],
          }),
          200,
        ),
      ),
    );

    final styles = await client.styles();

    expect(styles.single.id, 'cel_pop');
  });

  test('feedback posts JSON and returns the id', () async {
    late http.Request captured;
    final client = BackendClient(
      baseUrl: 'http://gw',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'id': 'abc'}), 201);
      }),
    );

    final id = await client.sendFeedback(message: 'hi', appVersion: '1.0.0');

    expect(id, 'abc');
    expect(captured.method, 'POST');
    expect(jsonDecode(captured.body), {'message': 'hi', 'appVersion': '1.0.0'});
  });

  test('HTTP errors and network failures become BackendException', () async {
    final failing = BackendClient(
      baseUrl: 'http://gw',
      client: MockClient((request) async => http.Response('nope', 502)),
    );
    final offline = BackendClient(
      baseUrl: 'http://gw',
      client: MockClient((request) async => throw http.ClientException('down')),
    );

    expect(failing.health(), throwsA(isA<BackendException>()));
    expect(offline.health(), throwsA(isA<BackendException>()));
  });
}
