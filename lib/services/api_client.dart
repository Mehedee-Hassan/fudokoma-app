import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiClient {
  ApiClient({http.Client? client, Uri? baseUri})
      : _client = client ?? http.Client(),
        _baseUri = baseUri ?? Uri.parse(ApiConfig.baseUrl);

  final http.Client _client;
  final Uri _baseUri;

  void close() => _client.close();

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body: body);

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = _baseUri.resolve('/api/v1/$normalizedPath');
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final streamedResponse = await _client.send(request).timeout(
          const Duration(seconds: 10),
        );
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ApiException(response.statusCode, 'The backend returned invalid JSON.');
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on FormatException {
      // Use the status code when the backend response is not JSON.
    }
    return 'Backend request failed with HTTP ${response.statusCode}.';
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'API error ($statusCode): $message';
}
