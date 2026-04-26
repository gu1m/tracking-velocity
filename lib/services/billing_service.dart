import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Serviço de billing usando Mercado Pago como gateway.
///
/// Fluxo recomendado para assinatura recorrente (preapproval):
///  1. Backend cria um plano (preapproval_plan) no Mercado Pago.
///  2. Backend cria uma assinatura (preapproval) para o usuário e devolve
///     a `init_point` (URL de checkout).
///  3. App abre essa URL no navegador via url_launcher.
///  4. Mercado Pago dispara um webhook para o backend confirmando o
///     status (`authorized`, `paused`, `cancelled`).
///  5. Backend atualiza o status do usuário; o app consulta isso na
///     próxima abertura.
///
/// Documentação: https://www.mercadopago.com.br/developers/pt/docs/subscriptions
class BillingService extends ChangeNotifier {
  static const double monthlyPriceBrl = 13.99;
  static const String currency = 'BRL';
  static const String planName = 'Tracking Velocidade Premium';

  /// Endpoint do seu backend que cria a assinatura no Mercado Pago.
  /// Substitua pela URL do seu servidor.
  static const String _subscriptionEndpoint =
      'https://api.seu-backend.com.br/billing/mercadopago/subscribe';

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Inicia o checkout abrindo o link de pagamento do Mercado Pago.
  ///
  /// Em produção, esse `initPoint` vem do seu backend após criar a
  /// preapproval. Aqui está mockado para fins de demonstração.
  Future<bool> startCheckout({required String userId}) async {
    _isProcessing = true;
    notifyListeners();

    try {
      // TODO: Trocar pela chamada real ao backend:
      //
      // final resp = await http.post(
      //   Uri.parse(_subscriptionEndpoint),
      //   headers: {'Authorization': 'Bearer $jwt'},
      //   body: jsonEncode({'userId': userId, 'plan': 'monthly'}),
      // );
      // final initPoint = jsonDecode(resp.body)['init_point'] as String;

      await Future.delayed(const Duration(seconds: 1));
      const initPoint =
          'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=DEMO';

      final uri = Uri.parse(initPoint);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok;
    } catch (e) {
      debugPrint('Erro no checkout: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Cancela a assinatura. Em produção, chama o backend que executa
  /// um PUT em /preapproval/{id} com status=cancelled.
  Future<bool> cancelSubscription({required String userId}) async {
    _isProcessing = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));
    _isProcessing = false;
    notifyListeners();
    return true;
  }
}
