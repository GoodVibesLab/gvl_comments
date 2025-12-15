import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

/// Minimal HTTP helper for the Comments SDK.
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

      // Accept both array and single-object payloads.
      if (decoded is List && decoded.isNotEmpty) {
        return Map<String, dynamic>.from(decoded.first as Map);
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      } else if (res.body.isEmpty) {
        // Handles empty body (e.g., 204 responses).
        return {};
      }

      throw StateError('Unexpected JSON response: ${res.body}');
    }

    throw HttpException(res.statusCode, res.body);
  }

  Future<List<Map<String, dynamic>>> getList(
      Uri url, {
        Map<String, String>? headers,
      }) async {
    final res = await _http.get(url, headers: headers);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>() // filtre au cas où
            .map<Map<String, dynamic>>(
                (m) => Map<String, dynamic>.from(m))
            .toList();
      }
      throw StateError('Expected a JSON array, got: ${res.body}');
    }
    throw HttpException(res.statusCode, res.body);
  }

  Future<Map<String, dynamic>> getJson(
      Uri url, {
        Map<String, String>? headers,
      }) async {
    final res = await _http.get(url, headers: headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      throw StateError('Expected a JSON object, got: ${res.body}');
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