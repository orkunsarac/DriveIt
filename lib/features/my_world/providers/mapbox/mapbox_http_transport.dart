import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MapboxHttpResponse {
  final int statusCode;
  final String body;

  const MapboxHttpResponse({required this.statusCode, required this.body});
}

abstract interface class MapboxHttpTransport {
  Future<MapboxHttpResponse> post({
    required Uri uri,
    required String formBody,
    required Duration timeout,
  });
}

class IoMapboxHttpTransport implements MapboxHttpTransport {
  final HttpClient _client;

  IoMapboxHttpTransport({HttpClient? client})
    : _client = client ?? HttpClient();

  @override
  Future<MapboxHttpResponse> post({
    required Uri uri,
    required String formBody,
    required Duration timeout,
  }) async {
    final request = await _client.postUrl(uri).timeout(timeout);
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write(formBody);
    final response = await request.close().timeout(timeout);
    final body = await utf8.decoder.bind(response).join().timeout(timeout);
    return MapboxHttpResponse(statusCode: response.statusCode, body: body);
  }
}
