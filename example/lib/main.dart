import 'package:flutter/material.dart';
import 'package:gvl_comments/gvl_comments.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GvlComments().initialize(
    const CommentsConfig(
      installKey: 'cmt_live_6GR78fxknl7eFxZ3rOwK344t5DwupcQW',
      externalUserId: 'user_1',
      externalUserName: 'Joris',
    ),
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
        body: const GvlCommentsList(threadKey: 'demo-thread'),
      ),
    );
  }
}