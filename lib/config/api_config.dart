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
  /// Padrão: localhost do emulador Android (10.0.2.2) ou dispositivo físico na
  /// mesma rede — troque por 192.168.x.x para testes em dispositivo real.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
