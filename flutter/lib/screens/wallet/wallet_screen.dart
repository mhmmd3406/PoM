import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

// ── Screen ─────────────────────────────────────────────────────────────────

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (user) => user == null
            ? const SizedBox.shrink()
            : _WalletBody(user: user),
      ),
    );
  }
}

class _WalletBody extends ConsumerWidget {
  const _WalletBody({required this.user});
  final PomUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CustomScrollView(
        slivers: [
          _VaultAppBar(credits: user.credits),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _SectionLabel('How to Earn ✦'),
                const SizedBox(height: 12),
                const _EarnCard(
                  icon: '🎉',
                  title: 'Welcome Bonus',
                  subtitle: 'One-time reward for joining',
                  credits: 3,
                  done: true,
                ),
                const SizedBox(height: 10),
                const _EarnCard(
                  icon: '📊',
                  title: 'Weekly Pulse',
                  subtitle: 'Submit your check-in every week',
                  credits: 2,
                ),
                const SizedBox(height: 10),
                _ReferralCard(),
                const SizedBox(height: 28),
                _SectionLabel('Unlock Insights 🔓'),
                const SizedBox(height: 4),
                Text(
                  'Use your credits or pay once for instant access. '
                  'Your data stays anonymous — always.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                _UnlockCard(
                  icon: '☀️',
                  title: 'Day Pass',
                  subtitle: 'Explore all banks for 24 hours',
                  price: '\$2.99',
                  creditCost: null,
                  accent: AppColors.accent,
                  sessionType: 'day_pass',
                  bankIds: const [],
                ),
                const SizedBox(height: 10),
                _UnlockCard(
                  icon: '🏦',
                  title: 'Bank Spotlight',
                  subtitle: 'Deep-dive into one bank — 30 days',
                  price: '\$1.49',
                  creditCost: null,
                  accent: const Color(0xFF60A5FA),
                  sessionType: 'bank_unlock',
                  bankIds: const ['select-bank'],
                ),
                const SizedBox(height: 10),
                _UnlockCard(
                  icon: '⚡',
                  title: 'Use 1 Credit',
                  subtitle: 'Single query with your earned credits',
                  price: null,
                  creditCost: 1,
                  accent: AppColors.positive,
                  sessionType: 'credit',
                  bankIds: const [],
                ),
                const SizedBox(height: 28),
                _CreditHistorySection(),
              ]),
            ),
          ),
        ],
      );
}

// ── Vault app bar (collapsible credit orb) ────────────────────────────────

class _VaultAppBar extends StatelessWidget {
  const _VaultAppBar({required this.credits});
  final int credits;

  @override
  Widget build(BuildContext context) => SliverAppBar(
        expandedHeight: 220,
        pinned: true,
        backgroundColor: AppColors.bg0,
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D0C2B), Color(0xFF1A1040)],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  // Credit orb
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withOpacity(0.15),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$credits',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ).animate().scale(
                      begin: const Offset(0.7, 0.7),
                      curve: Curves.elasticOut,
                      duration: 700.ms),
                  const SizedBox(height: 12),
                  const Text('✦  PoM Credits',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ),
          collapseMode: CollapseMode.parallax,
        ),
        title: const Text('Vault'),
      );
}

// ── Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
      );
}

// ── Earn cards ────────────────────────────────────────────────────────────

class _EarnCard extends StatelessWidget {
  const _EarnCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.credits,
    this.done = false,
  });
  final String icon;
  final String title;
  final String subtitle;
  final int credits;
  final bool done;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (done)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.positive, size: 22)
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.positive.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('+$credits ✦',
                    style: const TextStyle(
                        color: AppColors.positive,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      );
}

class _ReferralCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentDim.withOpacity(0.6),
              AppColors.accent.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentDim),
        ),
        child: Row(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite a Colleague',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text('Earn 3 ✦ when they submit first pulse',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Share.share(
                  'I\'ve been anonymously rating my workplace on PoM. '
                  'Join and help shape the banking industry\'s happiness index. '
                  'https://pom.app/join',
                  subject: 'Join PoM — Peace of Mind',
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accent.withOpacity(0.2),
                foregroundColor: AppColors.accentLight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

// ── Unlock cards ──────────────────────────────────────────────────────────

class _UnlockCard extends ConsumerWidget {
  const _UnlockCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.creditCost,
    required this.accent,
    required this.sessionType,
    required this.bankIds,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String? price;
  final int? creditCost;
  final Color accent;
  final String sessionType;
  final List<String> bankIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _UnlockButton(
              price: price,
              creditCost: creditCost,
              accent: accent,
              sessionType: sessionType,
              bankIds: bankIds,
            ),
          ],
        ),
      );
}

class _UnlockButton extends ConsumerStatefulWidget {
  const _UnlockButton({
    required this.price,
    required this.creditCost,
    required this.accent,
    required this.sessionType,
    required this.bankIds,
  });
  final String? price;
  final int? creditCost;
  final Color accent;
  final String sessionType;
  final List<String> bankIds;

  @override
  ConsumerState<_UnlockButton> createState() => _UnlockButtonState();
}

class _UnlockButtonState extends ConsumerState<_UnlockButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      if (widget.sessionType == 'credit') {
        // deducted automatically on queryInsights call
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credits deducted on next insight query.'),
            backgroundColor: AppColors.bg3,
          ),
        );
      } else {
        await _showPaymentSheet(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPaymentSheet(BuildContext context) async {
    // Show a premium confirmation bottom sheet before calling Stripe.
    // In production: call createPaymentIntent CF → initialize flutter_stripe
    // payment sheet → presentPaymentSheet() → call confirmPurchase CF.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentBottomSheet(
        price: widget.price!,
        sessionType: widget.sessionType,
        accent: widget.accent,
        onConfirm: () async {
          Navigator.of(context).pop();
          // TODO: integrate flutter_stripe
          // final fn = ref.read(functionsProvider);
          // final res = await fn.httpsCallable('createPaymentIntent').call({...});
          // await Stripe.instance.initPaymentSheet(...);
          // await Stripe.instance.presentPaymentSheet();
          // await fn.httpsCallable('confirmPurchase').call({...});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✦ Access granted — enjoy your insights!'),
              backgroundColor: AppColors.bg3,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 80,
        height: 38,
        child: ElevatedButton(
          onPressed: _loading ? null : _onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.accent,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  widget.price ?? '${widget.creditCost} ✦',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
        ),
      );
}

// ── Payment bottom sheet (privilege-framing UX) ───────────────────────────

class _PaymentBottomSheet extends StatelessWidget {
  const _PaymentBottomSheet({
    required this.price,
    required this.sessionType,
    required this.accent,
    required this.onConfirm,
  });
  final String price;
  final String sessionType;
  final Color accent;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isDay = sessionType == 'day_pass';
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(isDay ? '☀️' : '🏦',
              style: const TextStyle(fontSize: 52))
              .animate()
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text(
            isDay ? 'Unlock All Banks for 24h' : 'Deep-Dive: One Bank for 30 Days',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isDay
                ? 'Compare any bank, any business family, full sector context.'
                : 'Track trends, benchmark, and export full reports.',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 14, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Price highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(price,
                    style: TextStyle(
                        color: accent,
                        fontSize: 32,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('one-time',
                        style: TextStyle(color: accent.withOpacity(0.7), fontSize: 12)),
                    const Text('no subscription',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Continue with $price',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outlined, size: 14, color: Colors.white38),
              const SizedBox(width: 4),
              Text('Secured by Stripe · No card stored on our servers',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Credit history ────────────────────────────────────────────────────────

class _CreditHistorySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();

    final stream =
        ref.watch(firestoreServiceProvider).creditHistoryStream(user.uid);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Recent Activity'),
            const SizedBox(height: 12),
            ...snap.data!.map((txn) => _TxnRow(txn: txn)),
          ],
        );
      },
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});
  final Map<String, dynamic> txn;

  @override
  Widget build(BuildContext context) {
    final amount = (txn['amount'] as num? ?? 0).toInt();
    final type = txn['type'] as String? ?? '';
    final isCredit = amount >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.positive : AppColors.negative)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(isCredit ? '↑' : '↓',
                  style: TextStyle(
                      color:
                          isCredit ? AppColors.positive : AppColors.negative,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}$amount ✦',
            style: TextStyle(
                color: isCredit ? AppColors.positive : AppColors.negative,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
