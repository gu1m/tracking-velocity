import '../models/app_user.dart';

/// Centraliza todas as bifurcações Free vs Premium.
///
/// Uso:
///   final flags = FeatureFlags(user.subscription);
///   if (flags.hasUnlimitedHistory) { ... }
class FeatureFlags {
  final SubscriptionStatus status;

  const FeatureFlags(this.status);

  factory FeatureFlags.fromUser(AppUser? user) =>
      FeatureFlags(user?.subscription ?? SubscriptionStatus.expired);

  /// Premium = trial ativo ou assinatura ativa
  bool get isPremium =>
      status == SubscriptionStatus.trial ||
      status == SubscriptionStatus.active;

  // ── Tracking ──────────────────────────────────────────────────────────────

  /// Free: GPS em background desativado (apenas foreground).
  /// Premium: GPS em background ilimitado.
  bool get hasBackgroundTracking => isPremium;

  /// Free: tracking máximo de 30 min por sessão.
  /// Premium: ilimitado.
  Duration? get maxSessionDuration =>
      isPremium ? null : const Duration(minutes: 30);

  // ── Histórico ────────────────────────────────────────────────────────────

  /// Free: apenas últimos 7 dias de histórico.
  /// Premium: histórico completo.
  bool get hasUnlimitedHistory => isPremium;

  DateTime get historyLimitDate => isPremium
      ? DateTime(2000) // sem limite na prática
      : DateTime.now().subtract(const Duration(days: 7));

  /// Free: máximo de 10 viagens listadas.
  /// Premium: sem limite.
  int? get maxTripsPerPage => isPremium ? null : 10;

  // ── Exportação ───────────────────────────────────────────────────────────

  /// Free: não pode exportar relatórios.
  bool get canExportReports => isPremium;

  // ── Anúncios ─────────────────────────────────────────────────────────────

  /// Free: exibe banners AdMob.
  bool get showAds => !isPremium;

  // ── Sync ────────────────────────────────────────────────────────────────

  /// Free: sync manual apenas.
  /// Premium: sync automático em background.
  bool get hasAutoSync => isPremium;
}
