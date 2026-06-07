import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/wallet_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/wallet_repository.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String? _purchasingPackLabel;

  Future<void> _purchaseCredits({
    required int credits,
    required int priceInTry,
    required String label,
  }) async {
    if (_purchasingPackLabel != null) return;
    setState(() => _purchasingPackLabel = label);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Oturum bulunamadı');

      final repo = ref.read(walletRepositoryProvider);

      final clientSecret = await repo.createCreditPaymentIntent(
        priceInTry: priceInTry,
        creditAmount: credits,
      );

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'PoM',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Credits are granted server-side by the Stripe webhook and arrive via
      // the wallets/{uid}.credits stream ([watchBalance]) within a few seconds.
      // No optimistic client write (forbidden by rules; was a no-op anyway).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ödeme başarılı! $credits kredi birkaç saniye içinde hesabınıza yansıyacak.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.sage,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        _showErrorSnackbar(
          'Ödeme başarısız: ${e.error.localizedMessage ?? e.error.message ?? 'Bilinmeyen hata'}',
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackbar('Hata: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _purchasingPackLabel = null);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync      = ref.watch(walletBalanceProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg      = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final ink     = isDark ? AppColors.darkInk      : AppColors.lightInk;
    final ink2    = isDark ? AppColors.darkInk2     : AppColors.lightInk2;
    final ink3    = isDark ? AppColors.darkInk3     : AppColors.lightInk3;
    final border  = isDark ? AppColors.borderDark   : AppColors.borderLight;
    final divider = isDark ? AppColors.dividerDark  : AppColors.dividerLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cüzdan',
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

            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(walletBalanceProvider);
                  ref.invalidate(walletTransactionsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    // ── Balance hero ───────────────────────────────────────────
                    balanceAsync.when(
                      loading: () => _BalanceSkeleton(surface: surface, border: border),
                      error: (_, __) => _BalanceHero(balance: 0, surface: surface, border: border, ink: ink, ink3: ink3),
                      data: (balance) => _BalanceHero(balance: balance, surface: surface, border: border, ink: ink, ink3: ink3),
                    ),

                    const SizedBox(height: 18),

                    // ── Credit packs ───────────────────────────────────────────
                    Text(
                      'KREDİ SATIN AL',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink2, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: AppConstants.creditPacks.asMap().entries.map((entry) {
                        final pack = entry.value;
                        final credits  = pack['credits'] as int;
                        final price    = pack['price'] as int;
                        final packLabel = pack['label'] as String;
                        final isPopular = entry.key == 1;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: entry.key < AppConstants.creditPacks.length - 1 ? 8 : 0),
                            child: _CreditPackCell(
                              credits: credits,
                              priceInTry: price,
                              label: packLabel,
                              isPopular: isPopular,
                              isLoading: _purchasingPackLabel == packLabel,
                              isDisabled: _purchasingPackLabel != null && _purchasingPackLabel != packLabel,
                              surface: surface,
                              border: border,
                              ink: ink,
                              ink3: ink3,
                              onPurchase: () => _purchaseCredits(credits: credits, priceInTry: price, label: packLabel),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // ── Transactions ───────────────────────────────────────────
                    Text(
                      'İŞLEM GEÇMİŞİ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink2, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 10),
                    transactionsAsync.when(
                      loading: () => _TransactionsSkeleton(surface: surface),
                      error: (_, __) => Center(child: Text('İşlem geçmişi yüklenemedi', style: TextStyle(color: AppColors.rose))),
                      data: (transactions) {
                        if (transactions.isEmpty) return _EmptyTransactions(ink3: ink3);
                        return Container(
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: transactions.asMap().entries.map((e) {
                              return _TransactionTile(
                                transaction: e.value,
                                divider: divider,
                                isLast: e.key == transactions.length - 1,
                                ink: ink,
                                ink3: ink3,
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // Security notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.security_rounded, size: 18, color: ink3),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ödemeler Stripe altyapısıyla güvenli şekilde işlenir. '
                              'Kart bilgileriniz PoM sunucularında saklanmaz.',
                              style: TextStyle(fontSize: 12, color: ink3, height: 1.45),
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

// ─── Balance hero ──────────────────────────────────────────────────────────────

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final int balance;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Amber star decoration (top-right)
          Positioned(
            right: 0,
            top: 0,
            child: Opacity(
              opacity: 0.5,
              child: SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(painter: _StarPainter()),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KREDİ BAKİYESİ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$balance',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 56,
                      fontWeight: FontWeight.w500,
                      color: ink,
                      height: 1,
                      letterSpacing: -2.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('kredi', style: TextStyle(fontSize: 14, color: ink3, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '≈ ${(balance / 5).floor()} anket oluşturabilirsin · 1 anket 5 kredi',
                style: TextStyle(fontSize: 12, color: ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final outerR = size.width * 0.3;
    final innerR = outerR * 0.45;

    canvas.drawCircle(Offset(cx, cy), outerR * 1.6, Paint()..color = AppColors.amberWash);

    const points = 8;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = AppColors.amber);
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

// ─── Credit pack cell (3-col) ──────────────────────────────────────────────────

class _CreditPackCell extends StatelessWidget {
  const _CreditPackCell({
    required this.credits,
    required this.priceInTry,
    required this.label,
    required this.isPopular,
    required this.onPurchase,
    required this.isLoading,
    required this.isDisabled,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final int credits;
  final int priceInTry;
  final String label;
  final bool isPopular;
  final VoidCallback onPurchase;
  final bool isLoading;
  final bool isDisabled;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPopular ? AppColors.blue : border,
              width: isPopular ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$credits',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              Text('kredi', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ink3)),
              const SizedBox(height: 8),
              Text('₺$priceInTry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: FilledButton(
                  onPressed: (isDisabled || isLoading) ? null : onPurchase,
                  style: FilledButton.styleFrom(
                    backgroundColor: isPopular ? AppColors.blue : (ink3.withValues(alpha: 0.12)),
                    foregroundColor: isPopular ? Colors.white : ink,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                  ),
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Satın Al', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        if (isPopular)
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(5)),
                child: const Text(
                  'POPÜLER',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.divider,
    required this.isLast,
    required this.ink,
    required this.ink3,
  });

  final WalletTransactionModel transaction;
  final Color divider;
  final bool isLast;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final dateStr = DateFormat('dd MMM', 'tr_TR').format(transaction.createdAt);

    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCredit ? AppColors.sageWash : AppColors.amberWash,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              isCredit ? '+' : '−',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isCredit ? AppColors.sageDeep : AppColors.amberDeep,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.typeLabel,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  transaction.description ?? dateStr,
                  style: TextStyle(fontSize: 11, color: ink3),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}${transaction.amount} kr',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isCredit ? AppColors.sageDeep : ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton / empty states ───────────────────────────────────────────────────

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton({required this.surface, required this.border});
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
    );
  }
}

class _TransactionsSkeleton extends StatelessWidget {
  const _TransactionsSkeleton({required this.surface});
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(height: 64, decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12))),
      )),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.ink3});
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: ink3),
            const SizedBox(height: 12),
            Text('Henüz işlem yok', style: TextStyle(color: ink3)),
          ],
        ),
      ),
    );
  }
}
