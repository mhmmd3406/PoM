import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/insight_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/insights_repository.dart';

final insightsStreamProvider = StreamProvider.autoDispose<InsightModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.empty();

  final repo = ref.watch(insightsRepositoryProvider);
  return repo.watchInsights(user.uid);
});
