import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gvl_comments/src/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient', () {
    group('postJson', () {
      test('returns parsed JSON object on 200', () async {
        final mock = MockClient((req) async {
          return http.Response(
            jsonEncode({'id': 'c-1', 'status': 'ok'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final api = ApiClient(httpClient: mock);
        final result = await api.postJson(
          Uri.parse('https://api.test/comments'),
          {'body': 'Hello'},
        );

        expect(result['id'], 'c-1');
        expect(result['status'], 'ok');
      });

      test('returns first item when API returns a list', () async {
        final mock = MockClient((req) async {
          return http.Response(
            jsonEncode([
              {'id': 'r-1', 'data': 'first'},
              {'id': 'r-2', 'data': 'second'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final api = ApiClient(httpClient: mock);
        final result = await api.postJson(
          Uri.parse('https://api.test/report'),
          {'commentId': 'c-1'},
        );

        expect(result['id'], 'r-1');
      });

      test('returns empty map for empty body on 200', () async {
        final mock = MockClient((req) async {
          return http.Response('', 200);
        });

        final api = ApiClient(httpClient: mock);
        final result = await api.postJson(
          Uri.parse('https://api.test/react'),
          {'reaction': 'like'},
        );

        expect(result, isEmpty);
      });

      test('throws HttpException on 4xx', () async {
        final mock = MockClient((req) async {
          return http.Response('{"error":"unauthorized"}', 401);
        });

        final api = ApiClient(httpClient: mock);

        expect(
          () => api.postJson(
            Uri.parse('https://api.test/comments'),
            {'body': 'fail'},
          ),
          throwsA(isA<HttpException>()),
        );
      });

      test('throws HttpException on 500', () async {
        final mock = MockClient((req) async {
          return http.Response('Internal Server Error', 500);
        });

        final api = ApiClient(httpClient: mock);

        expect(
          () => api.postJson(
            Uri.parse('https://api.test/comments'),
            {'body': 'fail'},
          ),
          throwsA(isA<HttpException>()),
        );
      });

      test('sends Content-Type and custom headers', () async {
        Map<String, String>? capturedHeaders;

        final mock = MockClient((req) async {
          capturedHeaders = req.headers;
          return http.Response('{}', 200);
        });

        final api = ApiClient(httpClient: mock);
        await api.postJson(
          Uri.parse('https://api.test/token'),
          {'apiKey': 'key'},
          headers: {'Authorization': 'Bearer tok'},
        );

        expect(capturedHeaders?['content-type'], 'application/json');
        expect(capturedHeaders?['authorization'], 'Bearer tok');
      });
    });

    group('getJson', () {
      test('returns parsed JSON object', () async {
        final mock = MockClient((req) async {
          return http.Response(
            jsonEncode({'userReportsEnabled': true}),
            200,
          );
        });

        final api = ApiClient(httpClient: mock);
        final result = await api.getJson(
          Uri.parse('https://api.test/settings'),
        );

        expect(result['userReportsEnabled'], true);
      });

      test('throws HttpException on error status', () async {
        final mock = MockClient((req) async {
          return http.Response('Not found', 404);
        });

        final api = ApiClient(httpClient: mock);

        expect(
          () => api.getJson(Uri.parse('https://api.test/missing')),
          throwsA(isA<HttpException>()),
        );
      });
    });

    group('getList', () {
      test('returns list of maps', () async {
        final mock = MockClient((req) async {
          return http.Response(
            jsonEncode([
              {'id': 'c-1', 'body': 'Hello'},
              {'id': 'c-2', 'body': 'World'},
            ]),
            200,
          );
        });

        final api = ApiClient(httpClient: mock);
        final result = await api.getList(
          Uri.parse('https://api.test/comments'),
        );

        expect(result, hasLength(2));
        expect(result[0]['id'], 'c-1');
        expect(result[1]['body'], 'World');
      });

      test('returns empty list for empty body', () async {
        final mock = MockClient((req) async {
          return http.Response('', 200);
        });

        final api = ApiClient(httpClient: mock);
        final result = await api.getList(
          Uri.parse('https://api.test/comments'),
        );

        expect(result, isEmpty);
      });
    });

    group('decodeListResponse', () {
      test('decodes JSON array from response', () async {
        final res = http.Response(
          jsonEncode([
            {'id': 'a'},
            {'id': 'b'},
          ]),
          200,
        );

        final api = ApiClient(httpClient: MockClient((_) async => res));
        final result = await api.decodeListResponse(res);

        expect(result, hasLength(2));
      });

      test('returns empty list for empty body', () async {
        final res = http.Response('', 200);
        final api = ApiClient(httpClient: MockClient((_) async => res));
        final result = await api.decodeListResponse(res);
        expect(result, isEmpty);
      });

      test('returns empty list for non-list JSON', () async {
        final res = http.Response('{"key": "value"}', 200);
        final api = ApiClient(httpClient: MockClient((_) async => res));
        final result = await api.decodeListResponse(res);
        expect(result, isEmpty);
      });

      test('throws StateError on error status', () async {
        final res = http.Response('Server Error', 500);
        final api = ApiClient(httpClient: MockClient((_) async => res));

        expect(
          () => api.decodeListResponse(res),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('HttpException', () {
      test('toString includes status and body', () {
        final e = HttpException(404, 'Not found');
        expect(e.toString(), 'HttpException(404): Not found');
        expect(e.status, 404);
        expect(e.body, 'Not found');
      });
    });
  });
}
