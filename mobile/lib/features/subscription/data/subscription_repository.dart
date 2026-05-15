import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/subscription_model.dart';

class SubscriptionRepository {
  SubscriptionRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Stream the user's active subscription.
  Stream<SubscriptionModel?> watchSubscription(String uid) {
    return _firestore
        .collection(AppConstants.subscriptionsCollection)
        .where('uid', isEqualTo: uid)
        .where('status', whereIn: ['active', 'trialing'])
        .orderBy('currentPeriodEnd', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : SubscriptionModel.fromFirestore(snap.docs.first));
  }

  /// Create or update a subscription via Cloud Function.
  /// Returns a Stripe PaymentIntent clientSecret for the initial payment.
  Future<String> createSubscription(String planId) async {
    final callable = _functions.httpsCallable('createSubscription');
    final result = await callable.call<Map<String, dynamic>>({
      'planId': planId,
    });
    return result.data['clientSecret'] as String;
  }

  /// Cancel the current subscription (cancel at period end).
  Future<void> cancelSubscription(String subscriptionId) async {
    final callable = _functions.httpsCallable('cancelSubscription');
    await callable.call<void>({'subscriptionId': subscriptionId});
  }
}

final subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(cloudFunctionsProvider),
  );
});
