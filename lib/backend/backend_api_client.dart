import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendStatus {
  const BackendStatus({
    required this.environment,
    required this.databaseConnected,
  });

  final String environment;
  final bool databaseConnected;
}

class BackendApiException implements Exception {
  const BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendApiClient {
  BackendApiClient({required this.baseUri, http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _requestTimeout = Duration(seconds: 10);

  final Uri baseUri;
  final http.Client _client;
  final bool _ownsClient;

  Future<BackendStatus> checkStatus({String? expectedEnvironment}) async {
    final healthResponse = await _get(_endpoint('health'));
    if (healthResponse.statusCode != 200) {
      throw BackendApiException(
        'Backend health check returned HTTP ${healthResponse.statusCode}.',
      );
    }

    final health = _decodeResponse(healthResponse);
    final environment = health['environment'];
    if (health['status'] != 'ok' ||
        environment is! String ||
        !const ['development', 'staging', 'production'].contains(environment)) {
      throw const BackendApiException(
        'Backend health check returned an invalid response.',
      );
    }
    if (expectedEnvironment != null && environment != expectedEnvironment) {
      throw BackendApiException(
        'The app targets $expectedEnvironment, but the API reports $environment.',
      );
    }

    final readinessResponse = await _get(_endpoint('ready'));
    if (readinessResponse.statusCode != 200 &&
        readinessResponse.statusCode != 503) {
      throw BackendApiException(
        'Backend readiness check returned HTTP ${readinessResponse.statusCode}.',
      );
    }

    final readiness = _decodeResponse(readinessResponse);
    final connected = readinessResponse.statusCode == 200;
    if ((connected &&
            (readiness['status'] != 'ready' ||
                readiness['database'] != 'connected')) ||
        (!connected &&
            (readiness['status'] != 'not_ready' ||
                readiness['database'] != 'unavailable'))) {
      throw const BackendApiException(
        'Backend readiness check returned an invalid response.',
      );
    }

    return BackendStatus(
      environment: environment,
      databaseConnected: connected,
    );
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_requestTimeout);
    } on http.ClientException catch (error) {
      throw BackendApiException(
        'Could not reach ${uri.path}: ${error.message}',
      );
    } on TimeoutException {
      throw BackendApiException('The request to ${uri.path} timed out.');
    }
  }

  Uri _endpoint(String name) => baseUri.resolve('/api/$name');

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const BackendApiException('Backend returned invalid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackendApiException('Backend returned an invalid response.');
    }
    return decoded;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
