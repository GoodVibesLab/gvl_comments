import 'package:flutter_test/flutter_test.dart';
import 'package:gvl_comments/src/models.dart';

void main() {
  group('CommentModel', () {
    group('fromJson', () {
      test('parses a complete JSON payload', () {
        final json = {
          'id': 'c-001',
          'external_user_id': 'user-42',
          'author_name': 'Alice',
          'body': 'Hello world',
          'created_at': '2025-06-15T10:30:00Z',
          'avatar_url_canonical': 'https://cdn.example.com/alice.png',
          'is_flagged': false,
          'status': 'approved',
          'viewer_reaction': 'like',
          'reaction_counts': {'like': 3, 'love': 1},
          'reaction_total': 4,
        };

        final c = CommentModel.fromJson(json);

        expect(c.id, 'c-001');
        expect(c.externalUserId, 'user-42');
        expect(c.authorName, 'Alice');
        expect(c.body, 'Hello world');
        expect(c.createdAt, DateTime.utc(2025, 6, 15, 10, 30));
        expect(c.avatarUrl, 'https://cdn.example.com/alice.png');
        expect(c.isFlagged, false);
        expect(c.status, 'approved');
        expect(c.viewerReaction, 'like');
        expect(c.reactionCounts, {'like': 3, 'love': 1});
        expect(c.reactionTotal, 4);
      });

      test('uses safe defaults for missing optional fields', () {
        final json = {
          'id': 'c-002',
          'external_user_id': 'user-1',
          'created_at': '2025-01-01T00:00:00Z',
        };

        final c = CommentModel.fromJson(json);

        expect(c.authorName, isNull);
        expect(c.body, '');
        expect(c.avatarUrl, isNull);
        expect(c.isFlagged, false);
        expect(c.status, 'pending');
        expect(c.viewerReaction, isNull);
        expect(c.reactionCounts, isEmpty);
        expect(c.reactionTotal, 0);
      });

      test('handles created_at as epoch millis', () {
        final json = {
          'id': 'c-003',
          'external_user_id': 'user-1',
          'created_at': 1700000000000, // 2023-11-14T22:13:20Z
        };

        final c = CommentModel.fromJson(json);
        expect(c.createdAt.isUtc, true);
        expect(c.createdAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      });

      test('falls back to epoch for invalid created_at', () {
        final json = {
          'id': 'c-004',
          'external_user_id': 'user-1',
          'created_at': null,
        };

        final c = CommentModel.fromJson(json);
        expect(c.createdAt, DateTime.utc(1970));
      });

      test('handles DateTime object in created_at', () {
        final dt = DateTime(2025, 3, 20, 14, 30);
        final json = {
          'id': 'c-005',
          'external_user_id': 'user-1',
          'created_at': dt,
        };

        final c = CommentModel.fromJson(json);
        expect(c.createdAt.isUtc, true);
        expect(c.createdAt, dt.toUtc());
      });

      test('trims whitespace-only viewerReaction to null', () {
        final json = {
          'id': 'c-006',
          'external_user_id': 'user-1',
          'created_at': '2025-01-01T00:00:00Z',
          'viewer_reaction': '   ',
        };

        final c = CommentModel.fromJson(json);
        expect(c.viewerReaction, isNull);
      });

      test('trims viewerReaction', () {
        final json = {
          'id': 'c-007',
          'external_user_id': 'user-1',
          'created_at': '2025-01-01T00:00:00Z',
          'viewer_reaction': ' love ',
        };

        final c = CommentModel.fromJson(json);
        expect(c.viewerReaction, 'love');
      });

      test('ignores non-positive reaction counts', () {
        final json = {
          'id': 'c-008',
          'external_user_id': 'user-1',
          'created_at': '2025-01-01T00:00:00Z',
          'reaction_counts': {'like': 3, 'love': 0, 'sad': -1},
        };

        final c = CommentModel.fromJson(json);
        expect(c.reactionCounts, {'like': 3});
      });

      test('computes reactionTotal from counts when not provided', () {
        final json = {
          'id': 'c-009',
          'external_user_id': 'user-1',
          'created_at': '2025-01-01T00:00:00Z',
          'reaction_counts': {'like': 5, 'love': 2},
        };

        final c = CommentModel.fromJson(json);
        expect(c.reactionTotal, 7);
      });

      test('handles non-Map reaction_counts gracefully', () {
        final json = {
          'id': 'c-010',
          'external_user_id': 'user-1',
          'created_at': '2025-01-01T00:00:00Z',
          'reaction_counts': 'invalid',
        };

        final c = CommentModel.fromJson(json);
        expect(c.reactionCounts, isEmpty);
        expect(c.reactionTotal, 0);
      });
    });

    group('moderation helpers', () {
      CommentModel _make({
        CommentStatus commentStatus = CommentStatus.approved,
        bool isFlagged = false,
      }) {
        return CommentModel(
          id: 'c-test',
          externalUserId: 'u-1',
          body: 'test',
          createdAt: DateTime.now(),
          commentStatus: commentStatus,
          isFlagged: isFlagged,
        );
      }

      test('isReported is true when pending + flagged', () {
        final c = _make(commentStatus: CommentStatus.pending, isFlagged: true);
        expect(c.isReported, true);
      });

      test('isReported is false when approved + flagged', () {
        final c = _make(commentStatus: CommentStatus.approved, isFlagged: true);
        expect(c.isReported, false);
      });

      test('isReported is false when pending + not flagged', () {
        final c = _make(commentStatus: CommentStatus.pending, isFlagged: false);
        expect(c.isReported, false);
      });

      test('isModerated is true when rejected', () {
        final c = _make(commentStatus: CommentStatus.rejected);
        expect(c.isModerated, true);
      });

      test('isModerated is false when approved', () {
        final c = _make(commentStatus: CommentStatus.approved);
        expect(c.isModerated, false);
      });

      test('isVisibleNormally when approved and not flagged', () {
        final c = _make(commentStatus: CommentStatus.approved, isFlagged: false);
        expect(c.isVisibleNormally, true);
      });

      test('isVisibleNormally is false when reported', () {
        final c = _make(commentStatus: CommentStatus.pending, isFlagged: true);
        expect(c.isVisibleNormally, false);
      });

      test('isVisibleNormally is false when moderated', () {
        final c = _make(commentStatus: CommentStatus.rejected);
        expect(c.isVisibleNormally, false);
      });
    });

    group('copyWith', () {
      final original = CommentModel(
        id: 'c-orig',
        externalUserId: 'u-1',
        authorName: 'Bob',
        body: 'Original body',
        createdAt: DateTime.utc(2025, 1, 1),
        avatarUrl: 'https://cdn.example.com/bob.png',
        isFlagged: false,
        commentStatus: CommentStatus.approved,
        viewerReaction: 'like',
        reactionCounts: {'like': 1},
        reactionTotal: 1,
      );

      test('returns identical copy when no args', () {
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.body, original.body);
        expect(copy.viewerReaction, original.viewerReaction);
        expect(copy.reactionCounts, original.reactionCounts);
      });

      test('overrides specified fields', () {
        final copy = original.copyWith(
          body: 'Updated body',
          isFlagged: true,
          commentStatus: CommentStatus.pending,
        );

        expect(copy.body, 'Updated body');
        expect(copy.isFlagged, true);
        expect(copy.commentStatus, CommentStatus.pending);
        // Unchanged fields preserved.
        expect(copy.id, original.id);
        expect(copy.authorName, original.authorName);
      });

      test('can set viewerReaction to null', () {
        final copy = original.copyWith(viewerReaction: null);
        expect(copy.viewerReaction, isNull);
      });

      test('can change viewerReaction', () {
        final copy = original.copyWith(viewerReaction: 'love');
        expect(copy.viewerReaction, 'love');
      });

      test('preserves viewerReaction when not passed', () {
        final copy = original.copyWith(body: 'changed');
        expect(copy.viewerReaction, 'like');
      });
    });
  });

  group('UserProfile', () {
    test('creates with required id only', () {
      const u = UserProfile(id: 'user-1');
      expect(u.id, 'user-1');
      expect(u.name, isNull);
      expect(u.avatarUrl, isNull);
    });

    test('creates with all fields', () {
      const u = UserProfile(
        id: 'user-2',
        name: 'Alice',
        avatarUrl: 'https://cdn.example.com/alice.png',
      );
      expect(u.id, 'user-2');
      expect(u.name, 'Alice');
      expect(u.avatarUrl, 'https://cdn.example.com/alice.png');
    });
  });

  group('ModerationSettings', () {
    test('fromJson with full payload', () {
      final json = {
        'userReportsEnabled': false,
        'softHideAfterReports': 5,
        'hardHideAfterReports': 15,
        'aiMode': 'strict',
        'aiAutoFlag': false,
        'aiSensitivity': 0.8,
      };

      final s = ModerationSettings.fromJson(json);

      expect(s.userReportsEnabled, false);
      expect(s.softHideAfterReports, 5);
      expect(s.hardHideAfterReports, 15);
      expect(s.aiMode, 'strict');
      expect(s.aiAutoFlag, false);
      expect(s.aiSensitivity, 0.8);
    });

    test('fromJson uses defaults for missing fields', () {
      final s = ModerationSettings.fromJson({});

      expect(s.userReportsEnabled, true);
      expect(s.softHideAfterReports, 3);
      expect(s.hardHideAfterReports, 10);
      expect(s.aiMode, 'none');
      expect(s.aiAutoFlag, true);
      expect(s.aiSensitivity, 0.5);
    });
  });
}
