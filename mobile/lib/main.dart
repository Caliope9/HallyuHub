import 'package:flutter/material.dart';

import 'src/hallyu_hub_app.dart';
import 'src/screens/beta_signup_screen.dart';
import 'src/services/auth_service.dart';
import 'src/services/beta_signup_service.dart';
import 'src/services/backend_config.dart';
import 'src/services/feedback_report_service.dart';
import 'src/services/local_follow_service.dart';
import 'src/services/local_post_service.dart';
import 'src/services/local_story_service.dart';
import 'src/services/local_chat_service.dart';
import 'src/services/local_content_category_service.dart';
import 'src/services/local_drop_service.dart';
import 'src/services/local_fancam_service.dart';
import 'src/services/local_notification_service.dart';
import 'src/services/local_safety_service.dart';
import 'src/services/local_user_tag_service.dart';
import 'src/services/local_artist_tag_service.dart';
import 'src/services/supabase_bootstrap.dart';
import 'src/services/account_deletion_service.dart';
import 'src/services/content_moderation_service.dart';
import 'src/services/supabase_chat_service.dart';
import 'src/services/supabase_content_category_service.dart';
import 'src/services/supabase_drop_service.dart';
import 'src/services/supabase_fancam_service.dart';
import 'src/services/supabase_follow_service.dart';
import 'src/services/supabase_notification_service.dart';
import 'src/services/supabase_post_service.dart';
import 'src/services/supabase_safety_service.dart';
import 'src/services/supabase_story_service.dart';
import 'src/services/supabase_user_tag_service.dart';
import 'src/services/supabase_artist_tag_service.dart';
import 'src/services/store_profile_service.dart';
import 'src/services/public_access_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backendConfig = BackendConfig.fromEnvironment();
  final isReleaseBuild = const bool.fromEnvironment('dart.vm.product');
  final isPublicAccessRoute = isPublicAccessPath(Uri.base.path);
  final startupMode = resolveBackendStartupMode(
    backendConfig,
    isReleaseBuild: isReleaseBuild,
    isPublicAccessRoute: isPublicAccessRoute,
  );
  switch (startupMode) {
    case BackendStartupMode.configurationError:
      runApp(const _BackendConfigurationErrorApp());
      return;
    case BackendStartupMode.publicAccessUnavailable:
      // The public page remains visible, but no local/demo services or
      // unauthenticated fake backend are constructed in release.
      runApp(
        MaterialApp(
          title: 'HallyuHub',
          debugShowCheckedModeBanner: false,
          home: const BetaSignupScreen(
            betaSignupService: UnavailableBetaSignupService(),
          ),
        ),
      );
      return;
    case BackendStartupMode.localDevelopment:
    case BackendStartupMode.supabase:
      break;
  }
  debugPrint(
    'APP_BACKEND_CONFIG mode=${backendConfig.mode.name} '
    'supabase_url=${backendConfig.supabaseUrlForLogs} '
    'has_anon_key=${backendConfig.hasSupabaseAnonKey}',
  );
  final supabaseReady = await SupabaseBootstrap.initializeIfConfigured(
    backendConfig,
  );
  debugPrint(
    'APP_BACKEND_READY supabase_ready=$supabaseReady '
    'mode=${supabaseReady ? 'supabase' : 'local_development'}',
  );

  runApp(
    HallyuHubApp(
      authService: supabaseReady
          ? SupabaseAuthService()
          : const LocalAuthService(),
      postService: supabaseReady
          ? SupabasePostService()
          : const LocalPostService(),
      followService: supabaseReady
          ? SupabaseFollowService()
          : const LocalFollowService(),
      storyService: supabaseReady
          ? SupabaseStoryService()
          : const LocalStoryService(),
      chatService: supabaseReady
          ? SupabaseChatService()
          : const LocalChatService(),
      contentCategoryService: supabaseReady
          ? SupabaseContentCategoryService()
          : const LocalContentCategoryService(),
      userTagService: supabaseReady
          ? SupabaseUserTagService()
          : const LocalUserTagService(),
      artistTagService: supabaseReady
          ? SupabaseArtistTagService()
          : const LocalArtistTagService(),
      dropService: supabaseReady
          ? SupabaseDropService()
          : const LocalDropService(),
      fancamService: supabaseReady
          ? SupabaseFancamService()
          : const LocalFancamService(),
      notificationService: supabaseReady
          ? SupabaseNotificationService()
          : const LocalNotificationService(),
      safetyService: supabaseReady
          ? SupabaseSafetyService()
          : const LocalSafetyService(),
      betaSignupService: supabaseReady
          ? SupabaseBetaSignupService()
          : const LocalBetaSignupService(),
      feedbackReportService: supabaseReady
          ? SupabaseFeedbackReportService()
          : const LocalFeedbackReportService(),
      storeProfileService: supabaseReady
          ? SupabaseStoreProfileService()
          : const LocalStoreProfileService(),
      accountDeletionService: supabaseReady
          ? SupabaseAccountDeletionService()
          : const LocalAccountDeletionService(),
      contentModerationService: supabaseReady
          ? SupabaseContentModerationService()
          : const UnavailableContentModerationService(),
    ),
  );
}

class _BackendConfigurationErrorApp extends StatelessWidget {
  const _BackendConfigurationErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HallyuHub',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0015),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'HallyuHub no está configurado para producción.\n\nConfigurá las credenciales de Supabase antes de iniciar esta versión.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
