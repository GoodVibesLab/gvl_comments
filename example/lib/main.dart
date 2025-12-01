import 'package:flutter/material.dart';
import 'package:gvl_comments/gvl_comments.dart';

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
      home: Scaffold(
        appBar: AppBar(title: const Text('GVL Comments Demo')),
        body: GvlCommentsList(
          threadKey: 'post:123',
          user: UserProfile(
            id: 'user_9',
            name: 'Joris43',
            avatarUrl:
                'https://robohash.org/58266d40197a5e045353e8faad9368a9?set=set4&bgset=&size=400x400',
          ),
          theme: GvlCommentsTheme.of(context).copyWith(
            avatarSize: 40.0,
            bubbleColor: Colors.blue.shade50,
          ),
          avatarBuilder: (context, comment, size) {
            return CircleAvatar(
              radius: size / 2,
              backgroundImage:comment.avatarUrl != null ? NetworkImage(comment.avatarUrl!) : null,
              backgroundColor: Colors.grey.shade300,
            );
          },
        ),
      ),
    );
  }
}
