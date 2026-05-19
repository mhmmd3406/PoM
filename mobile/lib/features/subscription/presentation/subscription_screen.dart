import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/subscription_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/subscription_repository.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String? _subscribingPlan;
  bool _isCanceling = false;

  Future<void> _subscribe(String planId) async {
    if (_subscribingPlan != null) return;
    setState(() => _subscribingPlan = planId);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);

      final clientSecret = await repo.createSubscription(planId);

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'PoM',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (mounted) {
        _showSuccess('${_planName(planId)} planına başarıyla geçtiniz!');
        ref.invalidate(subscriptionStreamProvider);
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        _showError(
          'Ödeme başarısız: ${e.error.localizedMessage ?? e.error.message ?? 'Bilinmeyen hata'}',
        );
      }
    } catch (e) {
      if (mounted) _showError('Hata: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _subscribingPlan = null);
    }
  }

  Future<void> _cancelSubscription(SubscriptionModel sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aboneliği İptal Et'),
        content: Text(
          'Aboneliğiniz dönem sonunda (${_formatDate(sub.currentPeriodEnd)}) iptal edilecektir. '
          'Bu süre zarfında tüm özelliklerden yararlanmaya devam edebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCanceling = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.cancelSubscription(sub.stripeSubscriptionId ?? sub.id);
      if (mounted) {
        _showSuccess('Aboneliğiniz dönem sonunda iptal edilecektir.');
        ref.invalidate(subscriptionStreamProvider);
      }
    } catch (e) {
      if (mounted) _showError('İptal başarısız: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isCanceling = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _planName(String planId) {
    switch (planId) {
      case 'pro':
        return 'Pro';
      case 'enterprise':
        return 'Enterprise';
      default:
        return planId;
    }
  }

  String _formatDate(DateTime dt) => '${dt.day}.${dt.month}.${dt.year}';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final subscriptionAsync = ref.watch(subscriptionStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonelik'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (activeSub) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeSub != null) ...[
                  _CurrentPlanCard(
                    subscription: activeSub,
                    isCanceling: _isCanceling,
                    onCancel: () => _cancelSubscription(activeSub),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Planlar',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ..._plans.map((plan) {
                  final currentPlan = user?.role ?? 'free';
                  final isCurrentPlan = currentPlan == plan.id;
                  final isSubscribing = _subscribingPlan == plan.id;
                  final isAnySubscribing = _subscribingPlan != null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(
                      plan: plan,
                      isCurrentPlan: isCurrentPlan,
                      isSubscribing: isSubscribing,
                      isDisabled: isAnySubscribing && !isSubscribing,
                      onSubscribe: plan.price > 0
                          ? () => _subscribe(plan.id)
                          : plan.id == 'daas'
                              ? _contactDaas
                              : null,
                    ),
                  );
                }),
                const SizedBox(height: 24),
                _BillingNote(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _contactDaas() async {
    final uri = Uri.parse('mailto:sales@pom.app?subject=DaaS%20İletişim');
    if (!await launchUrl(uri)) {
      if (mounted) _showError('E-posta uygulaması açılamadı');
    }
  }
}

class _PlanData {
  const _PlanData({
    required this.id,
    required this.name,
    required this.price,
    required this.priceLabel,
    required this.features,
    required this.badgeColor,
    required this.icon,
    this.isHighlighted = false,
  });

  final String id;
  final String name;
  final int price;
  final String priceLabel;
  final List<String> features;
  final Color badgeColor;
  final String icon;
  final bool isHighlighted;
}

const _plans = [
  _PlanData(
    id: 'free',
    name: 'Ücretsiz',
    price: 0,
    priceLabel: '₺0 / ay',
    icon: '🌱',
    badgeColor: Color(0xFF9E9E9E),
    features: [
      'Ayda 3 check-in',
      'Temel içgörüler',
      'Kişisel radar grafiği',
    ],
  ),
  _PlanData(
    id: 'pro',
    name: 'Pro',
    price: 199,
    priceLabel: '₺199 / ay',
    icon: '⭐',
    badgeColor: Color(0xFF2196F3),
    isHighlighted: true,
    features: [
      'Sınırsız check-in',
      'Gelişmiş içgörüler',
      'Radar grafik + şirket karşılaştırması',
      'Sektör benchmark',
      'Öncelikli destek',
    ],
  ),
  _PlanData(
    id: 'enterprise',
    name: 'Enterprise',
    price: 999,
    priceLabel: '₺999 / ay',
    icon: '🏢',
    badgeColor: Color(0xFF9C27B0),
    features: [
      'Pro özelliklerin tümü',
      'Ekip yönetimi paneli',
      'Departman karşılaştırması',
      'Özel raporlama',
      'SSO entegrasyonu',
      'Adanmış hesap yöneticisi',
    ],
  ),
  _PlanData(
    id: 'daas',
    name: 'DaaS',
    price: 0,
    priceLabel: 'İletişim',
    icon: '💎',
    badgeColor: Color(0xFFFF9800),
    features: [
      'Enterprise özelliklerin tümü',
      'API erişimi',
      'White-label widget',
      'Özel entegrasyonlar',
      'SLA garantisi',
    ],
  ),
];

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.subscription,
    required this.isCanceling,
    required this.onCancel,
  });

  final SubscriptionModel subscription;
  final bool isCanceling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final endDate =
        '${subscription.currentPeriodEnd.day}.${subscription.currentPeriodEnd.month}.${subscription.currentPeriodEnd.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.secondary, scheme.secondary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Aktif Plan',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                subscription.statusLabel,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subscription.planDisplayName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800),
          ),
          Text('Dönem sonu: $endDate',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13)),
          if (subscription.cancelAtPeriodEnd) ...[
            const SizedBox(height: 8),
            const Text(
              '⚠ Abonelik dönem sonunda iptal edilecek.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: isCanceling ? null : onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.15),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: isCanceling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Aboneliği İptal Et',
                      style: TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.isSubscribing,
    required this.isDisabled,
    required this.onSubscribe,
  });

  final _PlanData plan;
  final bool isCurrentPlan;
  final bool isSubscribing;
  final bool isDisabled;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: plan.isHighlighted && !isCurrentPlan
            ? BorderSide(color: scheme.primary, width: 2)
            : isCurrentPlan
                ? BorderSide(color: scheme.secondary, width: 2)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plan.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (plan.isHighlighted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Önerilen',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                          if (isCurrentPlan) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.secondary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Mevcut',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        plan.priceLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: plan.badgeColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 18, color: plan.badgeColor),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(f,
                            style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!isCurrentPlan)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isDisabled || isSubscribing) ? null : onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plan.badgeColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: plan.badgeColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSubscribing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(plan.id == 'daas'
                          ? 'İletişime Geç'
                          : plan.price == 0
                              ? 'Ücretsiz Başla'
                              : '${plan.name} Planına Geç'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BillingNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security_rounded, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tüm ödemeler Stripe altyapısıyla güvenli şekilde işlenir. '
              'Abonelikler dönem sonunda otomatik yenilenir. '
              'İptal işlemi dönem bitimine kadar hizmetinizi etkilemez.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
