import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/api_config.dart';
import '../models/app_user.dart';

/// Gerencia autenticação via Firebase Auth (email, Google, Apple, SMS).
///
/// Após o login, busca o status de assinatura do backend e monta o [AppUser].
/// Fica escutando [FirebaseAuth.authStateChanges] para reagir a logout remoto.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthService() {
    // Reconecta sessão existente (app reaberto) e reage a logout remoto.
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  // ── Auth state ────────────────────────────────────────────────────────────

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
    } else {
      _currentUser = await _buildAppUser(firebaseUser);
    }
    notifyListeners();
  }

  /// Monta o [AppUser] unindo dados do Firebase e assinatura do backend.
  Future<AppUser> _buildAppUser(User firebaseUser) async {
    SubscriptionStatus subscription = SubscriptionStatus.trial;
    DateTime? renewsAt;
    String? preapprovalId;

    try {
      final token = await firebaseUser.getIdToken();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/users/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        subscription = _parseStatus(data['status'] as String?);
        final renewsRaw = data['renewsAt'] as String?;
        if (renewsRaw != null) renewsAt = DateTime.parse(renewsRaw);
        preapprovalId = data['preapprovalId'] as String?;
      }
    } catch (e) {
      debugPrint('[AuthService] Não foi possível buscar assinatura: $e');
      // Falha silenciosa — default trial.
    }

    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      phone: firebaseUser.phoneNumber,
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
      subscription: subscription,
      subscriptionRenewsAt: renewsAt,
      preapprovalId: preapprovalId,
    );
  }

  // ── Login / Cadastro ──────────────────────────────────────────────────────

  /// Login com e-mail e senha.
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _buildAppUser(cred.user!);
    });
  }

  /// Cadastro com e-mail, senha e nome.
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    return _run(() async {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.updateDisplayName(name);
      await cred.user!.reload();
      return _buildAppUser(_auth.currentUser!);
    });
  }

  /// Login com conta Google.
  Future<AppUser> signInWithGoogle() async {
    return _run(() async {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Login cancelado.');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      return _buildAppUser(cred.user!);
    });
  }

  /// Login com Apple ID (obrigatório na App Store se houver Google Sign-In).
  Future<AppUser> signInWithApple() async {
    return _run(() async {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final cred = await _auth.signInWithCredential(oauthCredential);

      // Apple só envia o nome no primeiro login — atualiza se disponível.
      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((s) => s != null && s.isNotEmpty).join(' ');
      if (fullName.isNotEmpty && cred.user!.displayName == null) {
        await cred.user!.updateDisplayName(fullName);
      }
      return _buildAppUser(cred.user!);
    });
  }

  // ── Autenticação por SMS ──────────────────────────────────────────────────

  /// Envia o código SMS para o número (formato internacional: +5511999999999).
  /// Retorna o verificationId que deve ser passado para [verifySmsCode].
  Future<String> sendSmsCode(String phoneNumber) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      // Android: auto-verifica sem código (SMS Retriever API).
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (!completer.isCompleted) completer.complete('auto');
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(_translateError(e));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      timeout: const Duration(seconds: 60),
    );

    return completer.future;
  }

  /// Valida o código SMS e retorna o usuário autenticado.
  Future<AppUser> verifySmsCode({
    required String verificationId,
    required String code,
    // ignore: unused_element
    String? phoneNumber,
  }) async {
    return _run(() async {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      final cred = await _auth.signInWithCredential(credential);
      return _buildAppUser(cred.user!);
    });
  }

  // ── Exclusão de conta (LGPD Art. 18) ─────────────────────────────────────

  /// Exclui a conta do usuário: dados no Supabase + registro no Firebase Auth.
  /// Após o sucesso, o usuário é desconectado localmente.
  Future<void> deleteAccount() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    final token = await firebaseUser.getIdToken();

    final resp = await http
        .delete(
          Uri.parse('${ApiConfig.baseUrl}/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      final msg = jsonDecode(resp.body)['error'] ?? 'Erro ao excluir conta.';
      throw Exception(msg);
    }

    _currentUser = null;
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    notifyListeners();
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  /// Retorna o Firebase ID Token do usuário atual (renovado se expirado).
  /// Retorna null se não há usuário autenticado.
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    _currentUser = null;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Executa [fn] gerenciando o estado de loading e erros.
  Future<AppUser> _run(Future<AppUser> Function() fn) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await fn();
      _currentUser = user;
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateError(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  SubscriptionStatus _parseStatus(String? status) {
    return switch (status) {
      'active' => SubscriptionStatus.active,
      'past_due' => SubscriptionStatus.pastDue,
      'canceled' => SubscriptionStatus.canceled,
      'expired' => SubscriptionStatus.expired,
      _ => SubscriptionStatus.trial,
    };
  }

  /// Traduz códigos de erro do Firebase para português.
  String _translateError(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' => 'Usuário não encontrado.',
      'wrong-password' || 'invalid-credential' => 'E-mail ou senha incorretos.',
      'email-already-in-use' => 'E-mail já cadastrado. Faça login.',
      'weak-password' => 'Senha fraca. Use ao menos 6 caracteres.',
      'invalid-email' => 'E-mail inválido.',
      'user-disabled' => 'Conta desativada. Contate o suporte.',
      'too-many-requests' => 'Muitas tentativas. Aguarde alguns minutos.',
      'network-request-failed' => 'Sem conexão com a internet.',
      'invalid-phone-number' => 'Número de telefone inválido.',
      'invalid-verification-code' => 'Código SMS incorreto.',
      'session-expired' => 'Código SMS expirado. Solicite um novo.',
      _ => 'Erro: ${e.message ?? e.code}',
    };
  }
}
