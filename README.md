# comments_client

Flutter helper to integrate the multi-tenant Comments SaaS backend.

## Installation

Add the local package to your workspace `pubspec.yaml`:

```yaml
dependencies:
  comments_client:
    path: packages/comments_client
```

Then run `flutter pub get`.

## Quick start

1. Generate an API key from the dashboard.
2. Create a thread from the dashboard and keep the thread identifier handy.
3. Provide the production base URL of your hosted API (the same hostname serving `/api/token`).

```dart
final client = CommentsClient(
  baseUrl: 'https://your-project.vercel.app',
  apiKey: 'cmt_live_xxx',
  externalUser: CommentsExternalUser(
    id: 'user-123',
    name: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  ),
);

final comments = await client.listComments(threadId: '4e9e9b31-bbe2-4e62-a836-8d361521b3a0');
final created = await client.createComment(
  threadId: '4e9e9b31-bbe2-4e62-a836-8d361521b3a0',
  body: 'First! 🎉',
);
```

See the [example](example/lib/main.dart) for a complete Flutter widget.

### Thread identifiers

The REST API expects the UUID of the thread (not the thread key). You can
retrieve the identifier via the dashboard or through the admin API. The client
automatically injects the tenant identifier, user identifier and optional
profile metadata when creating new comments.
