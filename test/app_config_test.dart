import 'package:flutter_test/flutter_test.dart';
import 'package:raams_crm/app_config.dart';

void main() {
  group('AppConfig', () {
    test('development permits a missing API URL for local mode', () {
      final config = AppConfig.fromValues(environment: 'development');

      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUri, isNull);
    });

    test('non-development environments require a secure API URL', () {
      expect(
        () => AppConfig.fromValues(environment: 'staging'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          apiBaseUrl: 'http://api.example.test',
          supabaseUrl: 'https://project.supabase.co',
          supabasePublishableKey: 'sb_publishable_test',
        ),
        throwsFormatException,
      );
    });

    test('accepts HTTPS API URLs for staging and production', () {
      final config = AppConfig.fromValues(
        environment: 'staging',
        apiBaseUrl: 'https://staging-api.example.test',
        supabaseUrl: 'https://project.supabase.co/',
        supabasePublishableKey: 'sb_publishable_test',
      );

      expect(config.environment, AppEnvironment.staging);
      expect(config.apiBaseUri?.scheme, 'https');
      expect(config.supabaseUrl?.host, 'project.supabase.co');
      expect(config.supabasePublishableKey, 'sb_publishable_test');
    });

    test('validates auth redirects for HTTPS and native app schemes', () {
      final webConfig = AppConfig.fromValues(
        environment: 'production',
        apiBaseUrl: 'https://api.example.test',
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: 'sb_publishable_test',
        authRedirectUrl: 'https://app.example.test/auth/callback',
      );
      final nativeConfig = AppConfig.fromValues(
        environment: 'development',
        authRedirectUrl: 'raamscrm://login-callback/',
      );

      expect(webConfig.authRedirectUri?.scheme, 'https');
      expect(nativeConfig.authRedirectUri?.scheme, 'raamscrm');
    });

    test('rejects insecure production and executable auth redirects', () {
      for (final redirect in [
        'http://app.example.test/auth/callback',
        'javascript://login-callback',
        'raamscrm:login-callback',
      ]) {
        expect(
          () => AppConfig.fromValues(
            environment: 'production',
            apiBaseUrl: 'https://api.example.test',
            supabaseUrl: 'https://project.supabase.co',
            supabasePublishableKey: 'sb_publishable_test',
            authRedirectUrl: redirect,
          ),
          throwsFormatException,
          reason: redirect,
        );
      }
    });

    test('requires both Supabase public client settings outside development',
        () {
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          apiBaseUrl: 'https://api.example.test',
        ),
        throwsFormatException,
      );
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          apiBaseUrl: 'https://api.example.test',
          supabaseUrl: 'https://project.supabase.co',
        ),
        throwsFormatException,
      );
    });

    test('rejects credentials and query parameters in the API URL', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          apiBaseUrl: 'https://user:password@example.test',
        ),
        throwsFormatException,
      );
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          apiBaseUrl: 'https://example.test?token=secret',
        ),
        throwsFormatException,
      );
    });
  });
}
