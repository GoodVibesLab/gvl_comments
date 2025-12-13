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
          threadKey: 'post:test',
          newestAtBottom: false,
          limit: 10,
          user: UserProfile(
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
