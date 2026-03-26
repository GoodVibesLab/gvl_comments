import 'package:flutter_test/flutter_test.dart';
import 'package:gvl_comments/src/token_store.dart';

void main() {
  group('TokenStore', () {
    late TokenStore store;

    setUp(() {
      store = TokenStore();
    });

    test('returns null when empty', () {
      expect(store.validBearer(), isNull);
      expect(store.plan, isNull);
    });

    test('returns token after save', () {
      store.save('tok-abc', 3600);
      expect(store.validBearer(), 'tok-abc');
    });

    test('stores plan', () {
      store.save('tok-abc', 3600, plan: 'pro');
      expect(store.plan, 'pro');
    });

    test('returns null for expired token (short TTL)', () {
      // Save with TTL of 30 seconds — the 30s safety margin makes it
      // expire immediately (30 - 30 = 0).
      store.save('tok-expired', 30);
      expect(store.validBearer(), isNull);
    });

    test('returns null for very short TTL', () {
      // TTL smaller than safety margin → already expired.
      store.save('tok-tiny', 10);
      expect(store.validBearer(), isNull);
    });

    test('clear removes everything', () {
      store.save('tok-abc', 3600, plan: 'starter');
      store.clear();
      expect(store.validBearer(), isNull);
      expect(store.plan, isNull);
    });

    test('save overwrites previous token', () {
      store.save('tok-1', 3600, plan: 'free');
      store.save('tok-2', 3600, plan: 'pro');
      expect(store.validBearer(), 'tok-2');
      expect(store.plan, 'pro');
    });

    test('plan is null when not provided', () {
      store.save('tok-abc', 3600);
      expect(store.plan, isNull);
    });
  });
}
