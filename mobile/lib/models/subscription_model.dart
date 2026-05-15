import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionStatus { active, inactive, canceled, pastDue, trialing }

class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.uid,
    required this.plan,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    this.cancelAtPeriodEnd = false,
    this.trialEnd,
  });

  final String id;
  final String uid;

  /// 'free' | 'pro' | 'enterprise' | 'daas'
  final String plan;
  final SubscriptionStatus status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final String? stripeSubscriptionId;
  final String? stripeCustomerId;
  final bool cancelAtPeriodEnd;
  final DateTime? trialEnd;

  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trialing;

  int get pricePerMonth {
    switch (plan) {
      case 'pro':
        return 199;
      case 'enterprise':
        return 999;
      default:
        return 0;
    }
  }

  String get planDisplayName {
    switch (plan) {
      case 'pro':
        return 'Pro';
      case 'enterprise':
        return 'Enterprise';
      case 'daas':
        return 'DaaS';
      default:
        return 'Ücretsiz';
    }
  }

  String get statusLabel {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Aktif';
      case SubscriptionStatus.inactive:
        return 'Pasif';
      case SubscriptionStatus.canceled:
        return 'İptal Edildi';
      case SubscriptionStatus.pastDue:
        return 'Ödeme Bekliyor';
      case SubscriptionStatus.trialing:
        return 'Deneme Süresi';
    }
  }

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      plan: data['plan'] as String? ?? 'free',
      status: _parseStatus(data['status'] as String? ?? 'inactive'),
      currentPeriodStart: data['currentPeriodStart'] != null
          ? (data['currentPeriodStart'] as Timestamp).toDate()
          : DateTime.now(),
      currentPeriodEnd: data['currentPeriodEnd'] != null
          ? (data['currentPeriodEnd'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      stripeSubscriptionId: data['stripeSubscriptionId'] as String?,
      stripeCustomerId: data['stripeCustomerId'] as String?,
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] as bool? ?? false,
      trialEnd: data['trialEnd'] != null
          ? (data['trialEnd'] as Timestamp).toDate()
          : null,
    );
  }

  static SubscriptionStatus _parseStatus(String raw) {
    switch (raw) {
      case 'active':
        return SubscriptionStatus.active;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'trialing':
        return SubscriptionStatus.trialing;
      default:
        return SubscriptionStatus.inactive;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'plan': plan,
      'status': status.name,
      'currentPeriodStart': Timestamp.fromDate(currentPeriodStart),
      'currentPeriodEnd': Timestamp.fromDate(currentPeriodEnd),
      if (stripeSubscriptionId != null)
        'stripeSubscriptionId': stripeSubscriptionId,
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      if (trialEnd != null) 'trialEnd': Timestamp.fromDate(trialEnd!),
    };
  }
}
