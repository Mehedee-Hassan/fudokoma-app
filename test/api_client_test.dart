import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:follo_cart/services/api_client.dart';
import 'package:follo_cart/services/backend_service.dart';

void main() {
  test('sends JSON requests to the versioned API path', () async {
    http.BaseRequest? capturedRequest;
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:18000'),
      client: _CallbackClient((request) async {
        capturedRequest = request;
        return _response(201, '{"id":"user-1"}');
      }),
    );

    final response = await client.post('users', {'name': 'Maya'});

    expect(
        capturedRequest?.url.toString(), 'http://localhost:18000/api/v1/users');
    expect(capturedRequest?.headers['Content-Type'], 'application/json');
    expect((capturedRequest as http.Request).body, '{"name":"Maya"}');
    expect(response, {'id': 'user-1'});
  });

  test('surfaces backend errors', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:18000'),
      client: _CallbackClient(
        (_) async => _response(404, '{"detail":"Cart not found"}'),
      ),
    );

    await expectLater(
      client.get('carts/missing'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.message, 'message', 'Cart not found'),
      ),
    );
  });

  test('sends a Firebase bearer token when one is available', () async {
    http.BaseRequest? capturedRequest;
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:18000'),
      tokenProvider: () async => 'firebase-id-token',
      client: _CallbackClient((request) async {
        capturedRequest = request;
        return _response(200, '{}');
      }),
    );

    await client.get('users/me');

    expect(
      capturedRequest?.headers['Authorization'],
      'Bearer firebase-id-token',
    );
  });

  test('creates a cart with backend field names', () async {
    http.BaseRequest? capturedRequest;
    final service = BackendService(
      apiClient: ApiClient(
        baseUri: Uri.parse('http://localhost:18000'),
        client: _CallbackClient((request) async {
          capturedRequest = request;
          return _response(
            201,
            '{"id":"cart-1","owner_id":"owner-1","name":"Inage Eats",'
            '"description":"Near Inage-Kaigan Station",'
            '"category":"Street food","is_open":true,'
            '"latitude":35.6327,"longitude":140.0908,'
            '"schedule":"11 AM - 8 PM","image_url":null,'
            '"followers_count":0,"updated_at":"2026-10-02T10:00:00"}',
          );
        }),
      ),
    );
    addTearDown(service.close);

    final cart = await service.createCart(
      name: 'Inage Eats',
      category: 'Street food',
      locationLabel: 'Near Inage-Kaigan Station',
      schedule: '11 AM - 8 PM',
      isOpen: true,
      latitude: 35.6327,
      longitude: 140.0908,
    );
    final payload = jsonDecode((capturedRequest as http.Request).body)
        as Map<String, dynamic>;

    expect(capturedRequest?.url.path, '/api/v1/carts');
    expect(payload.containsKey('owner_id'), isFalse);
    expect(payload['description'], 'Near Inage-Kaigan Station');
    expect(payload['latitude'], 35.6327);
    expect(payload['longitude'], 140.0908);
    expect(cart.id, 'cart-1');
  });

  test('requests carts within the supplied device-location radius', () async {
    http.BaseRequest? capturedRequest;
    final service = BackendService(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.example.com'),
        client: _CallbackClient((request) async {
          capturedRequest = request;
          return _response(200, '[]');
        }),
      ),
    );
    addTearDown(service.close);

    await service.fetchFoodCarts(
      latitude: 35.6327,
      longitude: 140.0908,
      radiusKm: 5,
    );

    expect(
      capturedRequest?.url.path,
      '/api/v1/carts',
    );
    expect(capturedRequest?.url.queryParameters, {
      'latitude': '35.6327',
      'longitude': '140.0908',
      'radius_km': '5.0',
    });
  });
}

class _CallbackClient extends http.BaseClient {
  _CallbackClient(this._respond);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _respond;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _respond(request);
}

http.StreamedResponse _response(int statusCode, String body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
