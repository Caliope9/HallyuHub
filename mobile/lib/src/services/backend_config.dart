enum HallyuBackendMode { localDemo, supabaseBeta }

enum BackendStartupMode {
  localDevelopment,
  supabase,
  publicAccessUnavailable,
  configurationError,
}

BackendStartupMode resolveBackendStartupMode(
  BackendConfig config, {
  required bool isReleaseBuild,
  required bool isPublicAccessRoute,
}) {
  if (config.hasSupabaseCredentials) return BackendStartupMode.supabase;
  if (!isReleaseBuild) return BackendStartupMode.localDevelopment;
  if (isPublicAccessRoute) return BackendStartupMode.publicAccessUnavailable;
  return BackendStartupMode.configurationError;
}

class BackendConfig {
  const BackendConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory BackendConfig.fromEnvironment() {
    return const BackendConfig(
      supabaseUrl: String.fromEnvironment('HALLYUHUB_SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('HALLYUHUB_SUPABASE_ANON_KEY'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabaseCredentials =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  bool get hasSupabaseAnonKey => supabaseAnonKey.trim().isNotEmpty;

  String get supabaseUrlForLogs {
    final trimmed = supabaseUrl.trim();
    return trimmed.isEmpty ? 'missing' : trimmed;
  }

  HallyuBackendMode get mode => hasSupabaseCredentials
      ? HallyuBackendMode.supabaseBeta
      : HallyuBackendMode.localDemo;
}
