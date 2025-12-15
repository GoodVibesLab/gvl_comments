import 'package:flutter/material.dart';
import 'package:gvl_comments/gvl_comments.dart';
import 'package:gvl_comments/l10n/gvl_comments_l10n.dart';

const _envInstallKey = String.fromEnvironment('GVL_INSTALL_KEY');

// Public demo key for the example app only (bound to example package/bundle).
const _demoInstallKey = 'cmt_live_EyuFlFVL682oiBVMealY2TfykRvJSDlF4Hbb8G2inhw';

String get _installKey =>
    _envInstallKey.isNotEmpty ? _envInstallKey : _demoInstallKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    _installKey.isNotEmpty,
    'GVL_INSTALL_KEY is missing. Run:\n'
    'flutter run --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"',
  );

  await CommentsKit.initialize(installKey: _installKey);

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
            name: 'Demo User',
            avatarUrl: 'https://api.dicebear.com/7.x/identicon/png?seed=demo',
          ),
          theme: GvlCommentsThemeData.bubble(context),
        ),
      ),
    );
  }
}
