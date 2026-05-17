import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/wallet_model.dart';

class WalletRepository {
  WalletRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Stream the user's credit balance from the wallets collection.
  Stream<int> watchBalance(String uid) {
    return _firestore
        .collection('wallets')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data()?['credits'] as int? ?? 0);
  }

  /// Stream the user's wallet transactions (stored in 'transactions' collection).
  Stream<List<WalletTransactionModel>> watchTransactions(String uid) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) =>
            snap.docs.map(WalletTransactionModel.fromFirestore).toList());
  }

  /// Create a payment intent for purchasing credits via Cloud Function.
  /// Returns the clientSecret string.
  Future<String> createCreditPaymentIntent({
    required int priceInTry,
    required int creditAmount,
  }) async {
    final callable = _functions.httpsCallable('createPaymentIntent');
    final result = await callable.call<Map<String, dynamic>>({
      'amount': priceInTry * 100, // convert to kuruş
      'currency': 'try',
      'creditAmount': creditAmount,
    });
    return result.data['clientSecret'] as String;
  }

  /// Optimistically update balance in UI (before webhook confirmation).
  Future<void> optimisticCreditUpdate(String uid, int addedCredits) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'creditBalance': FieldValue.increment(addedCredits)});
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(cloudFunctionsProvider),
  );
});
