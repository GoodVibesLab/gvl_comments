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
        body: const GvlCommentsList(threadKey: 'post:123',
          user: UserProfile(id: 'user_1', name: 'Joris2', avatarUrl: 'https://gravatar.com/avatar/4084956992ad3ad41e36a53473b1e94f?s=400&d=robohash&r=x'),),
      ),
    );
  }
}