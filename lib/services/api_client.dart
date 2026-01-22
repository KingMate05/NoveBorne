import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiClient {
  final http.Client _http;
  String? _token;

  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  void setToken(String? token) => _token = token;

  Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Uri uri(String path, {Map<String, dynamic>? query}) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v == null) return;
      q[k] = v.toString();
    });
    return Uri.https(ApiConfig.host, path, q.isEmpty ? null : q);
  }

  Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return {'raw': decoded?.toString()};
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _http.get(uri(path, query: query), headers: _headers());

    final dynamic decoded =
        res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, _asMap(decoded));
    }
    return _asMap(decoded);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _http.post(
      uri(path),
      headers: _headers(),
      body: jsonEncode(body ?? const {}),
    );

    final dynamic decoded =
        res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, _asMap(decoded));
    }
    return _asMap(decoded);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final Map<String, dynamic> body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode, $body)';
}
