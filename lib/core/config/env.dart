abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static const siteUrl = String.fromEnvironment('SITE_URL');

  static const demo = bool.fromEnvironment('DEMO');
}
