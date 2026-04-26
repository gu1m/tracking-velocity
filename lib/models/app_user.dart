/// Usuário autenticado do app.
class AppUser {
  final String uid;
  final String? email;
  final String? phone;
  final String? displayName;
  final String? photoUrl;
  final SubscriptionStatus subscription;
  final DateTime? subscriptionRenewsAt;

  const AppUser({
    required this.uid,
    this.email,
    this.phone,
    this.displayName,
    this.photoUrl,
    this.subscription = SubscriptionStatus.trial,
    this.subscriptionRenewsAt,
  });

  bool get isPremium =>
      subscription == SubscriptionStatus.active ||
      subscription == SubscriptionStatus.trial;
}

enum SubscriptionStatus {
  /// Período gratuito de avaliação (ex: 7 dias)
  trial,

  /// Assinatura ativa e em dia
  active,

  /// Pagamento atrasado/falhou
  pastDue,

  /// Cancelada (ainda pode ter acesso até a data de renovação)
  canceled,

  /// Expirada (sem acesso)
  expired,
}
