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
          user: UserProfile(
            id: 'user_14',
            name: 'Joris43',
            avatarUrl:
                'https://robohash.org/58266d40197a5e045353e8faad9368a9?set=set4&bgset=&size=400x400',
          ),
          theme: GvlCommentsTheme.of(context).copyWith(
            avatarSize: 20.0,
            bubbleColor: Colors.blue.shade50,
            showAvatars: false,
          ),
        ),
      ),
    );
  }
}
