import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/subscription_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/subscription_repository.dart';

final subscriptionStreamProvider =
    StreamProvider.autoDispose<SubscriptionModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();

  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.watchSubscription(user.uid);
});
