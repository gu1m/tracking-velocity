class AppUser {
  final String uid;
  final String? email;
  final String? phone;
  final String? displayName;
  final String? photoUrl;
  final SubscriptionStatus subscription;
  final DateTime? subscriptionRenewsAt;
  final String? preapprovalId;

  const AppUser({
    required this.uid,
    this.email,
    this.phone,
    this.displayName,
    this.photoUrl,
    this.subscription = SubscriptionStatus.trial,
    this.subscriptionRenewsAt,
    this.preapprovalId,
  });

  bool get isPremium =>
      subscription == SubscriptionStatus.active ||
      subscription == SubscriptionStatus.trial;
}

enum SubscriptionStatus {
  trial,
  active,
  pastDue,
  canceled,
  expired,
}
