import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/subscription_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/subscription_repository.dart';

final subscriptionStreamProvider =
    StreamProvider.autoDispose<SubscriptionModel?>((ref) {
  // In debug bypass mode, return null (no active sub) so the plan selection
  // UI renders without hitting Firestore (no real Firebase Auth session).
  if (kDebugMode && AppConstants.debugBypassAuth) {
    return Stream.value(null);
  }

  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.empty();

  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.watchSubscription(user.uid);
});
