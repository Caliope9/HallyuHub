import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/messages_inbox_screen.dart';
import 'package:hallyuhub/src/screens/story_viewer_screen.dart';
import 'package:hallyuhub/src/services/local_chat_service.dart';
import 'package:hallyuhub/src/services/local_safety_service.dart';
import 'package:hallyuhub/src/widgets/comments_sheet.dart';
import 'package:hallyuhub/src/widgets/community_chat_message_tile.dart';

class _SafetyFixture extends LocalSafetyService {
  final reports = <Map<String, Object?>>[];

  @override
  Future<void> reportContent({
    required String contentType,
    String contentId = '',
    String reportedUserId = '',
    required String reason,
    String details = '',
    Map<String, Object?> metadata = const {},
  }) async {
    reports.add({
      'content_type': contentType,
      'content_id': contentId,
      'reported_user_id': reportedUserId,
      'reason': reason,
      'metadata': metadata,
    });
  }
}

class _ChatFixture extends LocalChatService {
  const _ChatFixture(this.conversation);

  final DirectConversation conversation;

  @override
  Future<List<DirectConversation>> markRead(String profileId) async => [
    conversation,
  ];
}

CommunityProfile _profile() => const CommunityProfile(
  id: '22222222-2222-4222-8222-222222222222',
  name: 'Otra fan',
  username: '@otra.fan',
  city: '',
  country: '',
  fandom: 'Multi fandom',
  favoriteGroup: '',
  bio: '',
  avatarAsset: '',
  followers: '0',
  posts: '0',
  colors: [Colors.purple, Colors.cyan],
);

Future<void> _submitOpenReport(WidgetTester tester) async {
  final submitButton = find.text('Enviar reporte');
  await tester.ensureVisible(submitButton);
  await tester.pump();
  await tester.tap(submitButton);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 50,
}) async {
  for (
    var attempt = 0;
    attempt < attempts && finder.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

void main() {
  testWidgets('comments and replies expose a report action that persists', (
    tester,
  ) async {
    final safety = _SafetyFixture();
    const commentId = '11111111-1111-4111-8111-111111111111';
    const authorId = '22222222-2222-4222-8222-222222222222';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentsSheet(
            threadId: '33333333-3333-4333-8333-333333333333',
            subtitle: 'Publicación',
            initialComments: const [
              PostComment(
                id: commentId,
                authorId: authorId,
                author: 'Otra fan',
                username: '@otra.fan',
                avatarAsset: '',
                body: 'Comentario reportable',
                time: 'Ahora',
              ),
            ],
            safetyService: safety,
            onChanged: (_) {},
            onCommentAdded: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('comment-report-$commentId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reportar comentario'), findsOneWidget);
    await _submitOpenReport(tester);

    expect(safety.reports.single['content_type'], 'comment');
    expect(safety.reports.single['content_id'], commentId);
    expect(safety.reports.single['reported_user_id'], authorId);
  });

  testWidgets('a story exposes reporting for another author', (tester) async {
    final safety = _SafetyFixture();
    const storyId = '44444444-4444-4444-8444-444444444444';
    const authorId = '22222222-2222-4222-8222-222222222222';
    await tester.pumpWidget(
      MaterialApp(
        home: StoryViewerScreen(
          stories: const [
            Story(
              id: storyId,
              authorId: authorId,
              name: 'Otra fan',
              fandom: 'Multi fandom',
              avatarAsset: '',
              imageAsset: '',
              text: 'Historia reportable',
              contentType: StoryContentType.text,
            ),
          ],
          initialIndex: 0,
          recipients: const [],
          starredStoryIds: const {},
          onViewed: (_) {},
          onToggleStar: (_) {},
          onReply: (_, _) {},
          safetyService: safety,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const ValueKey('story-report')));
    await tester.pumpAndSettle();
    expect(find.text('Reportar historia'), findsOneWidget);
    await _submitOpenReport(tester);

    expect(safety.reports.single['content_type'], 'story');
    expect(safety.reports.single['content_id'], storyId);
  });

  testWidgets('an incoming direct message can be reported independently', (
    tester,
  ) async {
    final safety = _SafetyFixture();
    final profile = _profile();
    const messageId = '55555555-5555-4555-8555-555555555555';
    final conversation = DirectConversation(
      profileId: profile.id,
      name: profile.name,
      username: profile.username,
      avatarAsset: profile.avatarAsset,
      messages: [
        DirectMessage(
          id: messageId,
          senderId: profile.id,
          recipientId: 'local-user',
          body: 'Mensaje reportable',
          createdAt: DateTime(2026),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatScreen(
          profile: profile,
          chatService: _ChatFixture(conversation),
          safetyService: safety,
        ),
      ),
    );
    final reportButton = find.byKey(
      const ValueKey('dm-report-$messageId'),
    );
    await _pumpUntilFound(tester, reportButton);

    await tester.tap(reportButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reportar mensaje'), findsOneWidget);
    await _submitOpenReport(tester);

    expect(safety.reports.single['content_type'], 'direct_message');
    expect(safety.reports.single['content_id'], messageId);
  });

  testWidgets('community chat message offers a visible report callback', (
    tester,
  ) async {
    var reports = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityChatMessageTile(
            profile: _profile(),
            body: 'Mensaje comunitario',
            timeLabel: '10:30',
            isCurrentUser: false,
            onReport: () => reports++,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey(
          'community-message-report-22222222-2222-4222-8222-222222222222',
        ),
      ),
    );
    expect(reports, 1);
  });

  test('backend hardening covers bilateral blocks, teens and moderation', () {
    final sql = File(
      'docs/supabase_google_play_ugc_hardening_v1_review.sql',
    ).readAsStringSync();
    expect(sql, contains('hallyu_moderate_report_v1'));
    expect(sql, contains('hallyu_admin_set_enforcement_v1'));
    expect(sql, contains('hallyu_enforce_teen_privacy_v1'));
    expect(sql, contains('hallyu_users_blocked_v1'));
    expect(sql, contains('as restrictive'));
    expect(sql, isNot(contains('service_role')));
  });

  test('account deletion worker covers retained PII and relationships', () {
    final worker = File(
      'supabase/functions/process-account-deletion/index.ts',
    ).readAsStringSync();
    for (final value in const [
      'feedback_reports',
      'feedback_attachments',
      'beta_access',
      'artist_suggestions',
      'kpop_entity_suggestions',
      'content_user_tags',
      'community_members',
      'community_messages',
      'conversations',
      'message_media',
    ]) {
      expect(worker, contains(value), reason: 'missing deletion coverage: $value');
    }
    expect(worker.indexOf('removeOwnedStorage(userId)'),
        lessThan(worker.indexOf('admin.auth.admin.deleteUser(userId)')));
  });
}
