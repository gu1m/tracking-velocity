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
  /// checkout no navegador externo. Retorna true se o link foi aberto.
  Future<bool> startCheckout({required String userId}) async {
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
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        final err = jsonDecode(resp.body)['error'] ?? 'Erro desconhecido';
        throw Exception(err);
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final initPoint = data['init_point'] as String?;
      if (initPoint == null) throw Exception('Backend não retornou init_point.');

      final uri = Uri.parse(initPoint);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('[BillingService] startCheckout erro: $e');
      return false;
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
