# GVL Comments (Flutter)

A production‑ready Flutter comments UI for **GoodVibesLab Comments SaaS**.

You initialize the SDK once with an **install key**, then drop a ready‑to‑use widget (`GvlCommentsList`) anywhere in your app. The widget handles pagination, optimistic posting, moderation-aware rendering, reporting and theming.

To use the SDK, you must create an account on the dashboard to obtain an install key.

---

## ✨ Features

- ⚡ Fast comment loading (Supabase + Edge)
- 🔐 Tenant‑isolated data with strict RLS
- 🧠 Moderation-aware UI (pending / moderated / reported)
- 🤖 AI moderation (paid plans)
- 📣 User reporting (when enabled by your plan/settings)
- 🔁 Cursor-based pagination
- 🧵 Threaded comments keyed by `threadKey`
- 🎨 Customizable UI via builders + theme overrides

---

## 📦 Installation

### From pub.dev

```yaml
dependencies:
  gvl_comments: ^<latest>
```

### Local path (monorepo)

```yaml
dependencies:
  gvl_comments:
    path: packages/gvl_comments
```

Then:

```sh
flutter pub get
```

---

## 🚀 Quick start

1) Get your **install key** from the dashboard.

2) Initialize the SDK once at app startup:

```dart
import 'package:flutter/material.dart';
import 'package:gvl_comments/gvl_comments.dart';
import 'package:gvl_comments/l10n/gvl_comments_l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CommentsKit.initialize(
    installKey: const String.fromEnvironment('GVL_INSTALL_KEY'),
  );

  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GVL Comments Demo',
      localizationsDelegates: GvlCommentsL10n.localizationsDelegates,
      home: Scaffold(
        appBar: AppBar(title: const Text('GVL Comments Demo')),
        body: GvlCommentsList(
          threadKey: 'your_post_id_or_other_unique_key',
          newestAtBottom: false,
          limit: 10,
          user: UserProfile(
            id: 'user_id_string',
            name: 'John Doe',
            avatarUrl:
                'https://example.com/path/to/avatar.jpg',
          ),

          theme: GvlCommentsThemeData.bubble(context),
        ),
      ),
    );
  }
}
```

That’s it: you get a complete comments UI (list + composer) with pagination.

---

## 🧵 Thread keys

Flutter uses `threadKey` (a string like `post:123`, `article:abc`, `video:xyz`).

- A thread is created/resolved server-side by `threadKey`.
- You do **not** need a UUID thread id in the Flutter widget.

Choose a deterministic key from your domain model (post id, screen id, etc.).

---

## 👤 User profile

`GvlCommentsList` requires a `UserProfile` so the SDK can:

- identify the user server-side
- attach author metadata to posted comments
- apply moderation/reporting rules consistently

At minimum you provide an `id`. `name` and `avatarUrl` are optional but strongly recommended.

---

## 🔁 Updating the current user

If your user changes (login/logout, account switch), call `identify()` again.

```dart
final newUser = UserProfile(
  id: 'user_99',
  name: 'New Name',
  avatarUrl: 'https://…',
);

await CommentsKit.instance.identify(newUser);
```
`CommentsKit.I()` is equivalent — `instance` is just a nicer alias.

If you want to force a fresh auth token when switching users:

```dart
CommentsKit.instance.invalidateToken();
await CommentsKit.instance.identify(newUser);
```

---

## 🎨 Customization

`GvlCommentsList` is ready-to-use, but exposes builder hooks for full control:

- `commentItemBuilder` — fully override comment row rendering
- `avatarBuilder` — custom avatar widget
- `sendButtonBuilder` — custom send button
- `composerBuilder` — replace the whole composer
- `separatorBuilder` — separators between items

You can also override styling with:

- `theme: GvlCommentsThemeData...` (e.g. `GvlCommentsThemeData.bubble(context)`)
- `GvlCommentsTheme` wrapper for local theme overrides

---

## 🛠 Support

For help, reach out at:

**contact@goodvibeslab.app**

---

## 📝 License

Proprietary / commercial license, included with all GoodVibesLab paid plans.
A free tier may be available for evaluation.
