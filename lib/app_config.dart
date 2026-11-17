enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig._({
    required this.environment,
    required this.apiBaseUri,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.authRedirectUri,
  });

  final AppEnvironment environment;
  final Uri? apiBaseUri;
  final Uri? supabaseUrl;
  final String? supabasePublishableKey;
  final Uri? authRedirectUri;

  Uri get requiredApiBaseUri =>
      apiBaseUri ?? (throw StateError('API_BASE_URL is not configured.'));
  Uri get requiredSupabaseUrl =>
      supabaseUrl ?? (throw StateError('SUPABASE_URL is not configured.'));
  String get requiredSupabasePublishableKey =>
      supabasePublishableKey ??
      (throw StateError('SUPABASE_PUBLISHABLE_KEY is not configured.'));

  String get appTitle => switch (environment) {
    AppEnvironment.development => 'Sravya — Studio CRM (Development)',
    AppEnvironment.staging => 'Sravya — Studio CRM (Staging)',
    AppEnvironment.production => 'Sravya — Studio CRM',
  };

  factory AppConfig.fromBuildEnvironment() => AppConfig.fromValues(
    environment: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey:
        const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    authRedirectUrl: const String.fromEnvironment('AUTH_REDIRECT_URL'),
  );

  factory AppConfig.fromValues({
    required String environment,
    String apiBaseUrl = '',
    String supabaseUrl = '',
    String supabasePublishableKey = '',
    String authRedirectUrl = '',
  }) {
    final parsedEnvironment = switch (environment.trim().toLowerCase()) {
      'development' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw FormatException('Unsupported APP_ENV "$environment".'),
    };

    final normalizedApiBaseUrl = apiBaseUrl.trim();
    Uri? apiBaseUri;
    if (normalizedApiBaseUrl.isNotEmpty) {
      apiBaseUri = Uri.tryParse(normalizedApiBaseUrl);
      if (apiBaseUri == null ||
          !apiBaseUri.hasAuthority ||
          apiBaseUri.host.isEmpty ||
          apiBaseUri.userInfo.isNotEmpty ||
          apiBaseUri.hasQuery ||
          apiBaseUri.hasFragment ||
          !const ['http', 'https'].contains(apiBaseUri.scheme)) {
        throw const FormatException(
          'API_BASE_URL must be a valid HTTP(S) URL.',
        );
      }
      if (parsedEnvironment != AppEnvironment.development &&
          apiBaseUri.scheme != 'https') {
        throw const FormatException(
          'API_BASE_URL must use HTTPS outside development.',
        );
      }
    } else if (parsedEnvironment != AppEnvironment.development) {
      throw const FormatException(
        'API_BASE_URL is required outside development.',
      );
    }

    final normalizedSupabaseUrl = supabaseUrl.trim();
    final normalizedSupabasePublishableKey = supabasePublishableKey.trim();
    Uri? parsedSupabaseUrl;
    if (normalizedSupabaseUrl.isNotEmpty) {
      parsedSupabaseUrl = Uri.tryParse(normalizedSupabaseUrl);
      if (parsedSupabaseUrl == null ||
          !parsedSupabaseUrl.hasAuthority ||
          parsedSupabaseUrl.host.isEmpty ||
          parsedSupabaseUrl.userInfo.isNotEmpty ||
          parsedSupabaseUrl.hasQuery ||
          parsedSupabaseUrl.hasFragment ||
          (parsedSupabaseUrl.path.isNotEmpty &&
              parsedSupabaseUrl.path != '/') ||
          !const ['http', 'https'].contains(parsedSupabaseUrl.scheme) ||
          (parsedEnvironment != AppEnvironment.development &&
              parsedSupabaseUrl.scheme != 'https')) {
        throw const FormatException(
          'SUPABASE_URL must be an HTTPS project URL outside development.',
        );
      }
    }
    if (normalizedSupabaseUrl.isEmpty !=
        normalizedSupabasePublishableKey.isEmpty) {
      throw const FormatException(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be configured together.',
      );
    }
    if (parsedEnvironment != AppEnvironment.development &&
        parsedSupabaseUrl == null) {
      throw const FormatException(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required outside development.',
      );
    }

    final normalizedAuthRedirectUrl = authRedirectUrl.trim();
    Uri? authRedirectUri;
    if (normalizedAuthRedirectUrl.isNotEmpty) {
      authRedirectUri = Uri.tryParse(normalizedAuthRedirectUrl);
      if (authRedirectUri == null ||
          !authRedirectUri.isAbsolute ||
          authRedirectUri.scheme.isEmpty ||
          authRedirectUri.userInfo.isNotEmpty ||
          authRedirectUri.hasQuery ||
          authRedirectUri.hasFragment ||
          ((authRedirectUri.scheme == 'http' ||
                  authRedirectUri.scheme == 'https') &&
              (authRedirectUri.host.isEmpty ||
                  (parsedEnvironment != AppEnvironment.development &&
                      authRedirectUri.scheme != 'https'))) ||
          (authRedirectUri.scheme != 'http' &&
              authRedirectUri.scheme != 'https' &&
              (!RegExp(r'^[a-z][a-z0-9+.-]*$')
                      .hasMatch(authRedirectUri.scheme) ||
                  const {
                    'javascript',
                    'data',
                    'file',
                    'content',
                    'intent',
                  }.contains(authRedirectUri.scheme) ||
                  authRedirectUri.host.isEmpty))) {
        throw const FormatException(
          'AUTH_REDIRECT_URL must be an HTTPS URL or a valid app URI scheme.',
        );
      }
    }

    return AppConfig._(
      environment: parsedEnvironment,
      apiBaseUri: apiBaseUri,
      supabaseUrl: parsedSupabaseUrl,
      supabasePublishableKey: normalizedSupabasePublishableKey.isEmpty
          ? null
          : normalizedSupabasePublishableKey,
      authRedirectUri: authRedirectUri,
    );
  }
}
