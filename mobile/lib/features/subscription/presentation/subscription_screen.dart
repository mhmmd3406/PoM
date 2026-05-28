import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/subscription_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/subscription_repository.dart';
import '../providers/subscription_provider.dart';

// ─── Plan data ────────────────────────────────────────────────────────────────

class _PlanData {
  const _PlanData({
    required this.id,
    required this.name,
    required this.price,
    required this.priceLabel,
    required this.features,
    this.isPopular = false,
  });

  final String id;
  final String name;
  final int price;
  final String priceLabel;
  final List<String> features;
  final bool isPopular;
}

const _plans = [
  _PlanData(
    id: 'free',
    name: 'Ücretsiz',
    price: 0,
    priceLabel: 'Ücretsiz',
    features: [
      'Haftalık check-in',
      'Kişisel içgörü',
      'Şirket nabzı (toplu)',
    ],
  ),
  _PlanData(
    id: 'pro',
    name: 'Pro',
    price: 199,
    priceLabel: '₺199 / ay',
    isPopular: true,
    features: [
      'Tüm Ücretsiz özellikler',
      'Sınırsız anket cevaplama',
      'Trend analizi',
      'Anonim sertifika',
    ],
  ),
  _PlanData(
    id: 'enterprise',
    name: 'Kurumsal',
    price: 999,
    priceLabel: '₺999 / ay',
    features: [
      'Tüm Pro özellikler',
      'Ekip yönetimi paneli',
      'Departman karşılaştırması',
      'Özel raporlama & SSO',
    ],
  ),
  _PlanData(
    id: 'daas',
    name: 'DaaS',
    price: 0,
    priceLabel: 'İletişim',
    features: [
      'Tüm Kurumsal özellikler',
      'API erişimi & white-label',
      'Özel entegrasyonlar',
      'SLA garantisi',
    ],
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

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
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
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

  void _contactDaas() async {
    final uri = Uri.parse('mailto:sales@pom.app?subject=DaaS%20İletişim');
    if (!await launchUrl(uri)) {
      if (mounted) _showError('E-posta uygulaması açılamadı');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.sage,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _planName(String planId) => switch (planId) {
    'pro'        => 'Pro',
    'enterprise' => 'Kurumsal',
    'daas'       => 'DaaS',
    _            => planId,
  };

  String _formatDate(DateTime dt) =>
      '${dt.day}.${dt.month}.${dt.year}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user   = ref.watch(currentUserProvider);
    final subscriptionAsync = ref.watch(subscriptionStreamProvider);

    final bg      = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final ink     = isDark ? AppColors.darkInk      : AppColors.lightInk;
    final ink2    = isDark ? AppColors.darkInk2     : AppColors.lightInk2;
    final ink3    = isDark ? AppColors.darkInk3     : AppColors.lightInk3;
    final border  = isDark ? AppColors.borderDark   : AppColors.borderLight;
    final bgAlt   = isDark ? AppColors.darkBgAlt    : AppColors.lightBgAlt;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Abonelik',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────────
            Expanded(
              child: subscriptionAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                ),
                error: (e, _) => Center(
                  child: Text('Hata: $e',
                      style: TextStyle(color: ink2)),
                ),
                data: (activeSub) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    // ── Section header row ────────────────────────────────────
                    Row(
                      children: [
                        Text(
                          'PLANLARI KARŞILAŞTIR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ink3,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Spacer(),
                        _HeaderAction(
                          label: 'Faturalar',
                          ink: ink2,
                          border: border,
                          onTap: () {},
                        ),
                        const SizedBox(width: 6),
                        _HeaderAction(
                          label: 'Yönet',
                          ink: AppColors.blue,
                          border: AppColors.blue.withValues(alpha: 0.3),
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Current plan banner ───────────────────────────────────
                    if (activeSub != null) ...[
                      _CurrentPlanBanner(
                        subscription: activeSub,
                        isCanceling: _isCanceling,
                        onCancel: () => _cancelSubscription(activeSub),
                        surface: surface,
                        border: border,
                        ink: ink,
                        ink2: ink2,
                        ink3: ink3,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Plan cards ────────────────────────────────────────────
                    ..._plans.map((plan) {
                      final currentPlan   = user?.role ?? 'free';
                      final isCurrentPlan = currentPlan == plan.id;
                      final isSubscribing = _subscribingPlan == plan.id;
                      final isAnySubscribing = _subscribingPlan != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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
                          isDark: isDark,
                          surface: surface,
                          border: border,
                          ink: ink,
                          ink2: ink2,
                          ink3: ink3,
                          bgAlt: bgAlt,
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    // ── Security notice ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.security_rounded,
                              size: 18, color: ink3),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tüm ödemeler Stripe altyapısıyla güvenli şekilde işlenir. '
                              'Abonelikler dönem sonunda otomatik yenilenir.',
                              style: TextStyle(
                                  fontSize: 12, color: ink3, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header action button ─────────────────────────────────────────────────────

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.label,
    required this.ink,
    required this.border,
    required this.onTap,
  });

  final String label;
  final Color ink;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
      ),
    );
  }
}

// ─── Current plan banner ──────────────────────────────────────────────────────

class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({
    required this.subscription,
    required this.isCanceling,
    required this.onCancel,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final SubscriptionModel subscription;
  final bool isCanceling;
  final VoidCallback onCancel;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final endDate =
        '${subscription.currentPeriodEnd.day} ${_monthName(subscription.currentPeriodEnd.month)}';
    final daysLeft = subscription.currentPeriodEnd
        .difference(DateTime.now())
        .inDays;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      subscription.planDisplayName,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MEVCUT PLAN',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subscription.cancelAtPeriodEnd
                      ? '$endDate\'de iptal olacak'
                      : '$daysLeft gün sonra yenilenir · $endDate',
                  style: TextStyle(fontSize: 12, color: ink2),
                ),
              ],
            ),
          ),
          if (!subscription.cancelAtPeriodEnd)
            GestureDetector(
              onTap: isCanceling ? null : onCancel,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: AppColors.rose.withValues(alpha: 0.3)),
                ),
                child: isCanceling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.rose),
                      )
                    : const Text(
                        'İptal Et',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.rose,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  String _monthName(int month) => const [
        '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
        'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
      ][month];
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.isSubscribing,
    required this.isDisabled,
    required this.onSubscribe,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.bgAlt,
  });

  final _PlanData plan;
  final bool isCurrentPlan;
  final bool isSubscribing;
  final bool isDisabled;
  final VoidCallback? onSubscribe;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color bgAlt;

  @override
  Widget build(BuildContext context) {
    final highlight = plan.isPopular || isCurrentPlan;
    final borderColor = isCurrentPlan
        ? AppColors.blue
        : plan.isPopular
            ? AppColors.blue.withValues(alpha: 0.5)
            : border;
    final borderWidth = highlight ? 1.5 : 1.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: name + badges + price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.name,
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (plan.isPopular) ...[
                              const SizedBox(width: 6),
                              _Badge(label: 'Popüler', bgColor: AppColors.blue, fgColor: Colors.white),
                            ],
                            if (isCurrentPlan) ...[
                              const SizedBox(width: 6),
                              _Badge(label: 'Şu an', bgColor: AppColors.blue.withValues(alpha: 0.12), fgColor: AppColors.blue),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.priceLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: plan.isPopular ? AppColors.blue : ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Feature list
              ...plan.features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 14,
                            color: plan.isPopular || isCurrentPlan
                                ? AppColors.sage
                                : ink3),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                                fontSize: 13, color: ink2, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )),

              // CTA button (only if not current plan)
              if (!isCurrentPlan) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: FilledButton(
                    onPressed: (isDisabled || isSubscribing) ? null : onSubscribe,
                    style: FilledButton.styleFrom(
                      backgroundColor: plan.isPopular
                          ? AppColors.blue
                          : bgAlt,
                      foregroundColor: plan.isPopular ? Colors.white : ink,
                      disabledBackgroundColor: plan.isPopular
                          ? AppColors.blue.withValues(alpha: 0.4)
                          : bgAlt.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.zero,
                    ),
                    child: isSubscribing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            plan.id == 'daas'
                                ? 'İletişime Geç'
                                : plan.price == 0
                                    ? 'Ücretsiz Başla'
                                    : 'Plana Geç',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Popular badge top-center
        if (plan.isPopular && !isCurrentPlan)
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'POPÜLER',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Badge chip ───────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.fgColor,
  });

  final String label;
  final Color bgColor;
  final Color fgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: fgColor),
      ),
    );
  }
}
