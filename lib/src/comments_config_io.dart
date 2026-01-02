import 'dart:io' show Platform;

class CommentsPlatform {
  const CommentsPlatform();

  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;
}

const platform = CommentsPlatform();
