import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:raams_crm/backend/backend_api_client.dart';

void main() {
  group('BackendApiClient', () {
    test('checks API and database readiness', () async {
      final requests = <http.Request>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/health') {
          return http.Response(
            jsonEncode({'status': 'ok', 'environment': 'staging'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({'status': 'ready', 'database': 'connected'}),
          200,
        );
      });
      final api = BackendApiClient(
        baseUri: Uri.parse('https://staging.example.test'),
        client: mockClient,
      );

      final status = await api.checkStatus();

      expect(status.environment, 'staging');
      expect(status.databaseConnected, isTrue);
      expect(requests.map((request) => request.url.path), [
        '/api/health',
        '/api/ready',
      ]);
      mockClient.close();
    });

    test(
      'distinguishes an available API from an unavailable database',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/health') {
            return http.Response(
              jsonEncode({'status': 'ok', 'environment': 'production'}),
              200,
            );
          }
          return http.Response(
            jsonEncode({'status': 'not_ready', 'database': 'unavailable'}),
            503,
          );
        });
        final api = BackendApiClient(
          baseUri: Uri.parse('https://crm.example.test'),
          client: mockClient,
        );

        final status = await api.checkStatus();

        expect(status.environment, 'production');
        expect(status.databaseConnected, isFalse);
        mockClient.close();
      },
    );

    test('rejects malformed health responses', () async {
      final mockClient = MockClient(
        (request) async => http.Response('not-json', 200),
      );
      final api = BackendApiClient(
        baseUri: Uri.parse('https://staging.example.test'),
        client: mockClient,
      );

      await expectLater(api.checkStatus(), throwsA(isA<BackendApiException>()));
      mockClient.close();
    });
  });
}
