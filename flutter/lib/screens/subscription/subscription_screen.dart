import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

// ── Tier definitions ──────────────────────────────────────────────────────────

enum _Tier { free, pro }

class _Plan {
  const _Plan({
    required this.tier,
    required this.name,
    required this.price,
    required this.period,
    required this.headline,
    required this.color,
    required this.features,
    this.stripePriceId,
  });

  final _Tier tier;
  final String name;
  final String price;
  final String period;
  final String headline;
  final Color color;
  final List<_Feature> features;
  final String? stripePriceId;
}

class _Feature {
  const _Feature(this.label, {this.included = true, this.note});
  final String label;
  final bool included;
  final String? note;
}

const _plans = [
  _Plan(
    tier: _Tier.free,
    name: 'Free',
    price: '\$0',
    period: 'forever',
    headline: 'Get started — no card required',
    color: AppColors.textMuted,
    features: [
      _Feature('Weekly Pulse check-in'),
      _Feature('Overall bank score (sector avg)'),
      _Feature('3 welcome credits'),
      _Feature('Business family breakdown', included: false),
      _Feature('Radar chart insights', included: false),
      _Feature('Credit rewards', included: false, note: 'credits expire in 90 days'),
    ],
  ),
  _Plan(
    tier: _Tier.pro,
    name: 'Pro',
    price: '\$4.99',
    period: 'per month',
    headline: 'Full insights · Cancel any time',
    color: AppColors.accent,
    stripePriceId: 'price_pro_monthly', // replace with real Stripe Price ID
    features: [
      _Feature('Everything in Free'),
      _Feature('Business family breakdown'),
      _Feature('Radar chart — bank vs. sector'),
      _Feature('Unlimited credits'),
      _Feature('Priority data refresh'),
      _Feature('6-month trend history'),
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  _Tier _selected = _Tier.pro;
  bool _loading = false;
  String? _error;

  Future<void> _subscribe() async {
    if (_selected == _Tier.free) {
      context.go('/home');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      // Calls the Cloud Function createCheckoutSession → opens Stripe Checkout
      // in the system browser. On return, the subscription webhook updates the
      // user's tier and the custom claim is refreshed on next token renewal.
      //
      // TODO: integrate with flutter_stripe or url_launcher for Stripe Checkout:
      // final fn = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
      // final result = await fn.call({
      //   'priceId': _plans[1].stripePriceId,
      //   'successUrl': 'com.pom.app://subscription/success',
      //   'cancelUrl': 'com.pom.app://subscription/cancel',
      // });
      // await launchUrl(Uri.parse(result.data['checkoutUrl']));
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  children: [
                    _Header()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.2),
                    const SizedBox(height: 32),
                    ...List.generate(_plans.length, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PlanCard(
                        plan: _plans[i],
                        selected: _selected == _plans[i].tier,
                        onSelect: () => setState(() => _selected = _plans[i].tier),
                      ).animate(delay: (80 * i).ms).fadeIn().slideY(begin: 0.1),
                    )),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.negative, fontSize: 13),
                          textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 12),
                    const _TrustRow(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _CtaBar(
              plan: _plans.firstWhere((p) => p.tier == _selected),
              loading: _loading,
              onTap: _subscribe,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.12),
              border: Border.all(color: AppColors.accent.withOpacity(0.35), width: 2),
            ),
            child: const Center(
              child: Text('✦', style: TextStyle(fontSize: 22, color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Upgrade your insight',
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Join thousands of banking professionals\nwho benchmark anonymously.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5)),
        ],
      );
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onSelect,
  });

  final _Plan plan;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: plan.color, width: 2)
        : Border.all(color: AppColors.border);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: selected
              ? plan.color.withOpacity(0.06)
              : AppColors.bg2,
          borderRadius: BorderRadius.circular(16),
          border: border,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plan.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                          if (plan.tier == _Tier.pro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('POPULAR',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(plan.headline,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(plan.price,
                        style: TextStyle(
                            color: plan.color,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    Text(plan.period,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            // Feature list
            ...plan.features.map((f) => _FeatureRow(f, plan.color)),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.feature, this.color);
  final _Feature feature;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(
              feature.included ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16,
              color: feature.included ? color : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                feature.label,
                style: TextStyle(
                  fontSize: 13,
                  color: feature.included ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ),
            if (feature.note != null)
              Text(feature.note!,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      );
}

// ── Trust row ─────────────────────────────────────────────────────────────────

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 13, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text('Secured by Stripe · Cancel any time · No hidden fees',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 11)),
        ],
      );
}

// ── CTA bar ───────────────────────────────────────────────────────────────────

class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.plan,
    required this.loading,
    required this.onTap,
  });

  final _Plan plan;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPro   = plan.tier == _Tier.pro;
    final btnColor = isPro ? AppColors.accent : AppColors.bg3;
    final label    = loading
        ? 'Processing…'
        : isPro
            ? 'Start Pro — ${plan.price}/mo'
            : 'Continue with Free';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: isPro ? 0 : 0,
            shadowColor: Colors.transparent,
          ).copyWith(
            overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)),
          ),
          onPressed: loading ? null : onTap,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
