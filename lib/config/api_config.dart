/// Configuração central de URLs do backend.
///
/// Em desenvolvimento o app usa o servidor local.
/// Em produção, passe o valor via --dart-define na hora do build:
///
///   flutter run  --dart-define=API_BASE_URL=https://api.trackingvelocidade.com.br
///   flutter build apk --dart-define=API_BASE_URL=https://api.trackingvelocidade.com.br
class ApiConfig {
  ApiConfig._();

  /// URL base do backend Node.js.
  /// Padrão: Railway em produção.
  /// Para desenvolvimento local, passe via --dart-define:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tracking-velocity-production.up.railway.app',
  );
}
