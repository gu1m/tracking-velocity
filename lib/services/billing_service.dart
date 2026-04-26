import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';

class BillingService extends ChangeNotifier {
  static const double monthlyPriceBrl = 13.99;
  static const String currency = 'BRL';
  static const String planName = 'Tracking Velocidade Premium';

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Cria a assinatura no backend (que chama o Mercado Pago) e abre o
  /// checkout no navegador externo.
  /// Lança [Exception] se o backend falhar ou a URL não puder ser aberta.
  Future<void> startCheckout({required String userId}) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Usuário não autenticado.');

      final resp = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/billing/subscribe'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[BillingService] status=${resp.statusCode} body=${resp.body}');

      if (resp.statusCode != 200) {
        String err;
        try {
          err = (jsonDecode(resp.body) as Map<String, dynamic>)['error'] as String? ??
              'Erro ${resp.statusCode}';
        } catch (_) {
          err = 'Erro ${resp.statusCode}: ${resp.body}';
        }
        throw Exception(err);
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      // Mercado Pago retorna init_point; fallback para sandbox_init_point em testes
      final initPoint = (data['init_point'] ?? data['sandbox_init_point']) as String?;
      if (initPoint == null) {
        throw Exception('Backend não retornou URL de checkout. Resposta: ${resp.body}');
      }

      final uri = Uri.parse(initPoint);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Não foi possível abrir o navegador para: $initPoint');
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Cancela a assinatura ativa do usuário via backend.
  Future<bool> cancelSubscription({
    required String userId,
    required String preapprovalId,
  }) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Usuário não autenticado.');

      final resp = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/billing/cancel'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'preapprovalId': preapprovalId}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        final err = jsonDecode(resp.body)['error'] ?? 'Erro desconhecido';
        throw Exception(err);
      }

      return true;
    } catch (e) {
      debugPrint('[BillingService] cancelSubscription erro: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
