import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static bool _initialized = false;

  static Future<bool> initializeIfConfigured(BackendConfig config) async {
    if (!config.hasSupabaseCredentials) {
      debugPrint(
        'SUPABASE_INIT_SKIPPED url=${config.supabaseUrlForLogs} '
        'has_anon_key=${config.hasSupabaseAnonKey}',
      );
      return false;
    }
    if (_initialized) {
      debugPrint('SUPABASE_INIT_REUSED url=${config.supabaseUrlForLogs}');
      return true;
    }

    debugPrint('SUPABASE_INIT_START url=${config.supabaseUrlForLogs}');
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
      );
    } catch (error) {
      debugPrint(
        'SUPABASE_INIT_ERROR url=${config.supabaseUrlForLogs} error=$error',
      );
      rethrow;
    }
    _initialized = true;
    debugPrint(
      'SUPABASE_INIT_OK url=${config.supabaseUrlForLogs} '
      'session=${Supabase.instance.client.auth.currentSession != null}',
    );
    return true;
  }
}
