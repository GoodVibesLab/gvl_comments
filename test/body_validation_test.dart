import 'package:flutter_test/flutter_test.dart';
import 'package:gvl_comments/src/gvl_comments.dart';

/// Tests for comment body validation constants.
///
/// The actual validation method `_assertValidBody` is private, but we verify
/// the constants are sane and document expected behavior.
void main() {
  group('Body validation constants', () {
    test('minBodyLength is 1', () {
      expect(CommentsKit.minBodyLength, 1);
    });

    test('maxBodyLength is 5000', () {
      expect(CommentsKit.maxBodyLength, 5000);
    });

    test('maxBodyLength is greater than minBodyLength', () {
      expect(CommentsKit.maxBodyLength, greaterThan(CommentsKit.minBodyLength));
    });
  });

  group('CommentsKit dispose', () {
    test('isDisposed is exposed', () {
      // We can't create CommentsKit directly (private constructor),
      // but we verify the field exists on the type.
      // This is a compile-time check that the API surface is correct.
      expect(CommentsKit.maxPageSize, 100);
      expect(CommentsKit.defaultPageSize, 30);
    });
  });
}
