import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/wallet_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/wallet_repository.dart';

final walletBalanceProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();

  final repo = ref.watch(walletRepositoryProvider);
  return repo.watchBalance(user.uid);
});

final walletTransactionsProvider =
    StreamProvider.autoDispose<List<WalletTransactionModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();

  final repo = ref.watch(walletRepositoryProvider);
  return repo.watchTransactions(user.uid);
});
