import 'package:flutter/cupertino.dart';

enum CommentsLogLevel {
  off,
  error,
  info,
  debug,
  trace,
}

class CommentsLogger {
  static CommentsLogLevel level = CommentsLogLevel.error;

  static void error(String msg) {
    if (level.index >= CommentsLogLevel.error.index) {
      debugPrint('gvl_comments: ERROR – $msg');
    }
  }

  static void info(String msg) {
    if (level.index >= CommentsLogLevel.info.index) {
      debugPrint('gvl_comments: $msg');
    }
  }

  static void debug(String msg) {
    if (level.index >= CommentsLogLevel.debug.index) {
      debugPrint('gvl_comments: $msg');
    }
  }

  static void trace(String msg) {
    if (level.index >= CommentsLogLevel.trace.index) {
      debugPrint('gvl_comments: TRACE – $msg');
    }
  }
}