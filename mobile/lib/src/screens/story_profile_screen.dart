import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models.dart';
import '../services/local_chat_service.dart';
import '../services/local_drop_service.dart';
import '../services/local_fancam_service.dart';
import '../services/local_follow_service.dart';
import '../services/local_post_service.dart';
import '../services/local_story_service.dart';
import '../theme/app_theme.dart';
import 'public_profile_screen.dart';

class StoryProfileScreen extends StatelessWidget {
  const StoryProfileScreen({
    super.key,
    required this.story,
    this.currentUser,
    this.followService = const LocalFollowService(),
    this.postService = const LocalPostService(),
    this.storyService = const LocalStoryService(),
    this.dropService = const LocalDropService(),
    this.fancamService = const LocalFancamService(),
    this.chatService = const LocalChatService(),
  });

  final Story story;
  final AuthUser? currentUser;
  final LocalFollowService followService;
  final LocalPostService postService;
  final LocalStoryService storyService;
  final LocalDropService dropService;
  final LocalFancamService fancamService;
  final LocalChatService chatService;

  @override
  Widget build(BuildContext context) {
    return PublicProfileScreen(
      profile: _profileFromStory(story),
      currentUser: currentUser,
      followService: followService,
      postService: postService,
      storyService: storyService,
      dropService: dropService,
      fancamService: fancamService,
      chatService: chatService,
    );
  }

  CommunityProfile _profileFromStory(Story story) {
    if (!followService.usesRealProfiles && !story.isOwn) {
      return demoProfileById(story.authorId);
    }
    return CommunityProfile(
      id: story.authorId.isEmpty
          ? story.isOwn
                ? 'local-user'
                : _usernameFor(story)
          : story.authorId,
      name: story.isOwn ? currentUser?.name ?? story.name : story.name,
      username: story.isOwn
          ? currentUser?.username ?? _usernameFor(story)
          : _usernameFor(story),
      city: currentUser?.contentRegion ?? '',
      country: currentUser?.country ?? '',
      fandom: story.fandom.isEmpty
          ? currentUser?.fandom ?? 'HallyuHub'
          : story.fandom,
      favoriteGroup: currentUser?.favoriteGroup ?? '',
      bio: story.detail.isNotEmpty
          ? story.detail
          : 'Compartiendo historias en HallyuHub.',
      avatarAsset: story.avatarAsset,
      followers: '',
      posts: '',
      colors: const [AppTheme.rose, AppTheme.cyan, AppTheme.violet],
      online: story.isLive,
    );
  }

  String _usernameFor(Story story) {
    final normalized = story.name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.|\.$'), '');
    return normalized.isEmpty ? '@hallyu.fan' : '@$normalized';
  }
}
