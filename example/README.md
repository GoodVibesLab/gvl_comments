# GVL Comments – Flutter Example

This is a minimal demo app for the `gvl_comments` Flutter package.

- ✅ Targets **Android + iOS** (this repo intentionally removes macOS/web from the example)
- ✅ Shows a single `GvlCommentsList` bound to a `threadKey`
- ✅ Reads your install key from `--dart-define` (recommended)

## 1) Set your install key

Create an install key in the GoodVibesLab dashboard, then run the example with a compile-time define.

### Android / iOS (debug)

```bash
flutter run \
  --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"
```

### iOS (release)

```bash
flutter run --release \
  --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"
```

> Why `--dart-define`?
> - It avoids hardcoding secrets in source control.
> - Works on CI and for multiple environments.

## 2) Example `main.dart`

This example expects `GVL_INSTALL_KEY` to be provided via `--dart-define`.

```dart
import 'package:flutter/material.dart';
import 'package:gvl_comments/gvl_comments.dart';
import 'package:gvl_comments/l10n/gvl_comments_l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Provided via: --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"
  const installKey = String.fromEnvironment('GVL_INSTALL_KEY');

  assert(
    installKey.isNotEmpty,
    'Missing GVL_INSTALL_KEY. Run with: --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"',
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
          threadKey: 'post:test',
          newestAtBottom: false,
          limit: 10,
          user: const UserProfile(
            id: 'user_14',
            name: 'Joris43',
            avatarUrl:
                'https://gravatar.com/avatar/e26490ee50f3b620ef39386cc893b12c?s=400&d=retro&r=pg',
          ),
          theme: GvlCommentsThemeData.bubble(context),
        ),
      ),
    );
  }
}
```

## 3) Production notes

- **Install keys** are meant to be shipped in client apps, but you should still:
  - keep them out of your public repository
  - rotate them if you suspect leakage
- If you want different keys per environment, use:
  - `cmt_live_...` for production
  - `cmt_test_...` (or another install) for staging

## Support

Email: contact@goodvibeslab.app
