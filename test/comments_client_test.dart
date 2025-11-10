import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gvl_comments/comments_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'https://example.com';
  const apiKey = 'cmt_live_demo';
  final user = CommentsExternalUser(id: 'user-1', name: 'Jane');

  test('listComments parses payload and reuses issued token', () async {
    var tokenCalls = 0;
    var commentsCalls = 0;

    final mockClient = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/api/token')) {
        tokenCalls += 1;
        return http.Response(
          jsonEncode({
            'access_token': 'abc',
            'token_type': 'bearer',
            'expires_in': 3600,
            'tenant_id': 'tenant-123',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/api/comments')) {
        commentsCalls += 1;
        expect(request.headers['authorization'], 'Bearer abc');
        return http.Response(
          jsonEncode([
            {
              'id': 'comment-1',
              'thread_id': 'thread-1',
              'external_user_id': 'user-1',
              'author_name': 'Jane',
              'author_avatar_url': null,
              'body': 'Hello world',
              'parent_id': null,
              'status': 'approved',
              'is_deleted': false,
              'is_flagged': false,
              'metadata': {'likes': 5},
              'created_at': '2023-01-01T00:00:00Z',
              'updated_at': '2023-01-01T00:00:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not found', 404);
    });

    final client = CommentsClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
      externalUser: user,
      httpClient: mockClient,
    );

    final comments = await client.listComments(threadId: 'thread-1');
    expect(comments, hasLength(1));
    expect(comments.first.body, 'Hello world');

    await client.listComments(threadId: 'thread-1');

    expect(tokenCalls, 1, reason: 'Token should be cached');
    expect(commentsCalls, 2);
  });
}
