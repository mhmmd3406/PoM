import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
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

      await repo.optimisticCreditUpdate(user.uid, credits);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$credits kredi başarıyla eklendi!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF4CAF50),
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
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cüzdanım')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletBalanceProvider);
          ref.invalidate(walletTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              balanceAsync.when(
                loading: () => _BalanceSkeleton(),
                error: (e, _) => _BalanceCard(balance: 0, isError: true),
                data: (balance) => _BalanceCard(balance: balance),
              ),
              const SizedBox(height: 28),
              Text(
                'Kredi Satın Al',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Krediler özellik kilidi açmak ve premium araçlara erişmek için kullanılır.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              ...AppConstants.creditPacks.asMap().entries.map((entry) {
                final pack = entry.value;
                final credits = pack['credits'] as int;
                final price = pack['price'] as int;
                final packLabel = pack['label'] as String;
                final isPopular = entry.key == 1;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CreditPackCard(
                    credits: credits,
                    priceInTry: price,
                    label: packLabel,
                    isPopular: isPopular,
                    isLoading: _purchasingPackLabel == packLabel,
                    isDisabled: _purchasingPackLabel != null &&
                        _purchasingPackLabel != packLabel,
                    onPurchase: () => _purchaseCredits(
                      credits: credits,
                      priceInTry: price,
                      label: packLabel,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 28),
              Text(
                'İşlem Geçmişi',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              transactionsAsync.when(
                loading: () => const _TransactionsSkeleton(),
                error: (e, _) => Center(
                  child: Text('İşlem geçmişi yüklenemedi',
                      style: TextStyle(color: scheme.error)),
                ),
                data: (transactions) {
                  if (transactions.isEmpty) return const _EmptyTransactions();
                  return Column(
                    children: transactions
                        .map((t) => _TransactionTile(transaction: t))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.security_rounded,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ödemeler Stripe altyapısıyla güvenli şekilde işlenir. '
                        'Kart bilgileriniz PoM sunucularında saklanmaz.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, this.isError = false});

  final int balance;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.blue, 0.25)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text('Kredi Bakiyesi',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isError ? '--' : '$balance',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w800,
                height: 1),
          ),
          const SizedBox(height: 4),
          const Text('kullanılabilir kredi',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

class _BalanceSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _CreditPackCard extends StatelessWidget {
  const _CreditPackCard({
    required this.credits,
    required this.priceInTry,
    required this.label,
    required this.isPopular,
    required this.onPurchase,
    required this.isLoading,
    required this.isDisabled,
  });

  final int credits;
  final int priceInTry;
  final String label;
  final bool isPopular;
  final VoidCallback onPurchase;
  final bool isLoading;
  final bool isDisabled;

  double get _pricePerCredit => priceInTry / credits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPopular
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      credits >= 100 ? '💎' : credits >= 50 ? '⭐' : '✨',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '₺${_pricePerCredit.toStringAsFixed(2)} / kredi',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₺$priceInTry',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 88,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: (isDisabled || isLoading) ? null : onPurchase,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Satın Al',
                                style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isPopular)
          Positioned(
            top: 0,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8)),
              ),
              child: const Text('Popüler',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = transaction.isCredit;
    final color =
        isCredit ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final dateStr =
        DateFormat('dd MMM yyyy', 'tr_TR').format(transaction.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCredit
                ? Icons.add_circle_outline_rounded
                : Icons.remove_circle_outline_rounded,
            color: color,
          ),
        ),
        title: Text(transaction.typeLabel,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          transaction.description ?? dateStr,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: Text(
          '${isCredit ? '+' : ''}${transaction.amount}',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Henüz işlem yok',
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TransactionsSkeleton extends StatelessWidget {
  const _TransactionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
