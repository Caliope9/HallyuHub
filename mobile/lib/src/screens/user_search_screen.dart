import 'discover_people_screen.dart';

/// User-focused search entry point used from profile surfaces.
///
/// It intentionally reuses DiscoverPeopleScreen's real profile source,
/// blocking filters, debounce, follow actions and profile navigation.
class UserSearchScreen extends DiscoverPeopleScreen {
  const UserSearchScreen({
    super.key,
    super.currentUser,
    super.followService,
    super.postService,
    super.storyService,
    super.dropService,
    super.fancamService,
    super.chatService,
    super.contentCategoryService,
    super.userTagService,
    super.artistTagService,
    super.safetyService,
    super.storeProfileService,
  }) : super(title: 'Buscar usuarios', searchHint: 'Buscar usuarios...');
}
