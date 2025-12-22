# GVL Comments (Flutter)

<p align="center">
  <img src="screenshots/flutter_comments_light.png" width="360" />
  &nbsp;&nbsp;
  <img src="screenshots/flutter_comments_dark.png" width="360" />
</p>

A production‑ready **Flutter comments UI** for **GoodVibesLab Comments SaaS** — *backend‑less by design*.

Initialize the SDK once with an **install key**, then drop a ready‑to‑use widget (`GvlCommentsList`) anywhere in your app.  
The widget handles **pagination, optimistic posting, moderation‑aware rendering, reporting, and full theming** out of the box.

To use the SDK, you need an **install key**.

👉 Dashboard: https://goodvibeslab.cloud

---

## ✨ Features

- ⚡ Fast comment loading (Supabase + Edge)
- 🔐 Tenant‑isolated data with strict RLS
- 🧠 Moderation‑aware UI (pending / moderated / reported)
- 🤖 AI moderation (paid plans)
- 📣 User reporting (when enabled by your plan/settings)
- ❤️ Built‑in reactions (with optimistic UI, optional per thread)
- 🔁 Cursor‑based pagination
- 🧵 Threaded comments keyed by `threadKey`
- 🎨 Fully themeable (Material 3 compatible)

---

## 📦 Installation

### From pub.dev

```yaml
dependencies:
  gvl_comments: ^<latest>
```

Then:

```sh
flutter pub get
```

---

## 🚀 Quick start (in your app)

### 1) Provide your install key

You can inject the key via build‑time environment variables:

```sh
flutter run --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"
```

### 2) Initialize the SDK

```dart
import 'package:flutter/material.dart';
import 'package:gvl_comments/gvl_comments.dart';
import 'package:gvl_comments/l10n/gvl_comments_l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const installKey = String.fromEnvironment('GVL_INSTALL_KEY');

  assert(
    installKey.isNotEmpty,
    'GVL_INSTALL_KEY is missing. Run:\n'
    'flutter run --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"',
  );

  await CommentsKit.initialize(installKey: installKey);

  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GVL Comments Demo',
      localizationsDelegates: GvlCommentsL10n.localizationsDelegates,
      supportedLocales: GvlCommentsL10n.supportedLocales,
      home: Scaffold(
        appBar: AppBar(title: const Text('GVL Comments Demo')),
        body: GvlCommentsList(
          threadKey: 'post:example',
          newestAtBottom: false,
          limit: 10,
          user: UserProfile(
            id: 'user_1',
            name: 'John Doe',
            avatarUrl: 'https://example.com/avatar.png',
          ),
          theme: GvlCommentsThemeData.bubble(context),
        ),
      ),
    );
  }
}
```

That’s it — you now have a complete comments UI (list + composer).

---

## ▶️ Run the example app

The repository includes a full **example app** showcasing GVL Comments in a real Flutter environment.

### 1) Clone the repo

```sh
git clone https://github.com/goodvibeslab/gvl_comments.git
cd gvl_comments
```

### 2) Run the example

```sh
cd example
flutter pub get
flutter run
```

The example app:
- generates a **stable guest user** per device/emulator
- supports light & dark mode
- demonstrates pagination, optimistic posting, links, and theming


---

## 🧵 Thread keys

Flutter uses a simple string `threadKey` (e.g. `post:123`, `article:abc`).

- Threads are created/resolved server‑side
- No UUID or pre‑creation required

Choose a deterministic key from your domain model.

---

## 👤 User profile

`GvlCommentsList` requires a `UserProfile` so the SDK can:

- identify the user server‑side
- attach author metadata to posted comments
- apply moderation and reporting rules

At minimum, provide a stable `id`.  
`name` and `avatarUrl` are optional but strongly recommended.

---

## 🔁 Updating the current user

If the active user changes (login/logout, account switch):

```dart
final newUser = UserProfile(
  id: 'user_99',
  name: 'New Name',
  avatarUrl: 'https://…',
);

await CommentsKit.instance.identify(newUser);
```

To force a fresh auth token:

```dart
CommentsKit.instance.invalidateToken();
await CommentsKit.instance.identify(newUser);
```

---

## 🎨 Customization

You can fully customize rendering using builder hooks:

- `commentItemBuilder`
- `avatarBuilder`
- `sendButtonBuilder`
- `composerBuilder`
- `separatorBuilder`

And style everything via:

```dart
theme: GvlCommentsThemeData.bubble(context)
```

or with a local `GvlCommentsTheme` wrapper.

---

## 🛠 Troubleshooting

### “API key not valid”
- Ensure `GVL_INSTALL_KEY` is set at build time
- Ensure the key starts with `cmt_live_` or `cmt_test_`
- Create or copy a valid key from the dashboard

👉 https://goodvibeslab.cloud

---

## 🛠 Support

**contact@goodvibeslab.app**

---

## 📝 License

Proprietary / commercial license, included with all GoodVibesLab paid plans.  
A free tier may be available for evaluation.
