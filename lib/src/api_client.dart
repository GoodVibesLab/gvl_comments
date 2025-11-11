import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _http;
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<Map<String, dynamic>> postJson(
      Uri url,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
      }) async {
    final res = await _http.post(
      url,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);

      // ✅ Tolère les deux formats : tableau ou objet unique
      if (decoded is List && decoded.isNotEmpty) {
        return Map<String, dynamic>.from(decoded.first as Map);
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      } else if (res.body.isEmpty) {
        // cas 204 ou retour vide
        return {};
      }

      throw StateError('Unexpected JSON response: ${res.body}');
    }

    throw HttpException(res.statusCode, res.body);
  }

  Future<List<dynamic>> getList(Uri url, {Map<String, String>? headers}) async {
    final res = await _http.get(url, headers: headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw HttpException(res.statusCode, res.body);
  }

  Future<Map<String, dynamic>> getJson(Uri url,
      {Map<String, String>? headers}) async {
    final res = await _http.get(url, headers: headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw HttpException(res.statusCode, res.body);
  }
}

class HttpException implements Exception {
  final int status;
  final String body;
  HttpException(this.status, this.body);
  @override
  String toString() => 'HttpException($status): $body';
}