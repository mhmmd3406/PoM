import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/checkin_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/checkin_repository.dart';

// ─── Check-in flow state ────────────────────────────────────────────────────────

class CheckinFlowState {
  const CheckinFlowState({
    this.currentStep = 0,
    this.overallMood,
    this.workStress,
    this.teamHarmony,
    this.personalGrowth,
    this.workLifeBalance,
    this.isSubmitting = false,
    this.isComplete = false,
    this.error,
  });

  final int currentStep;
  final int? overallMood;
  final int? workStress;
  final int? teamHarmony;
  final int? personalGrowth;
  final int? workLifeBalance;
  final bool isSubmitting;
  final bool isComplete;
  final String? error;

  CheckinFlowState copyWith({
    int? currentStep,
    int? overallMood,
    int? workStress,
    int? teamHarmony,
    int? personalGrowth,
    int? workLifeBalance,
    bool? isSubmitting,
    bool? isComplete,
    String? error,
    bool clearError = false,
  }) {
    return CheckinFlowState(
      currentStep: currentStep ?? this.currentStep,
      overallMood: overallMood ?? this.overallMood,
      workStress: workStress ?? this.workStress,
      teamHarmony: teamHarmony ?? this.teamHarmony,
      personalGrowth: personalGrowth ?? this.personalGrowth,
      workLifeBalance: workLifeBalance ?? this.workLifeBalance,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isComplete: isComplete ?? this.isComplete,
      error: clearError ? null : error ?? this.error,
    );
  }

  int? valueForStep(int step) {
    switch (step) {
      case 0:
        return overallMood;
      case 1:
        return workStress;
      case 2:
        return teamHarmony;
      case 3:
        return personalGrowth;
      case 4:
        return workLifeBalance;
      default:
        return null;
    }
  }

  bool get isCurrentStepAnswered => valueForStep(currentStep) != null;

  static const int totalSteps = 5;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CheckinFlowNotifier extends Notifier<CheckinFlowState> {
  @override
  CheckinFlowState build() => const CheckinFlowState();

  void selectAnswer(int value) {
    switch (state.currentStep) {
      case 0:
        state = state.copyWith(overallMood: value);
        break;
      case 1:
        state = state.copyWith(workStress: value);
        break;
      case 2:
        state = state.copyWith(teamHarmony: value);
        break;
      case 3:
        state = state.copyWith(personalGrowth: value);
        break;
      case 4:
        state = state.copyWith(workLifeBalance: value);
        break;
    }
  }

  void nextStep() {
    if (state.currentStep < CheckinFlowState.totalSteps - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<CheckinModel?> submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;

    if (state.overallMood == null ||
        state.workStress == null ||
        state.teamHarmony == null ||
        state.personalGrowth == null ||
        state.workLifeBalance == null) {
      state = state.copyWith(error: 'Lütfen tüm adımları tamamlayın.');
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    // In debug bypass mode, simulate a successful submission without Firestore.
    if (kDebugMode && AppConstants.debugBypassAuth) {
      await Future.delayed(const Duration(milliseconds: 600));
      final mock = CheckinModel(
        id: 'debug_${DateTime.now().millisecondsSinceEpoch}',
        uid: user.uid,
        overallMood: state.overallMood!,
        workStress: state.workStress!,
        teamHarmony: state.teamHarmony!,
        personalGrowth: state.personalGrowth!,
        workLifeBalance: state.workLifeBalance!,
        createdAt: DateTime.now(),
        companyId: user.companyId,
        department: user.department,
      );
      state = state.copyWith(isSubmitting: false, isComplete: true);
      return mock;
    }

    try {
      final repo = ref.read(checkinRepositoryProvider);
      final checkin = await repo.submitCheckin(
        uid: user.uid,
        overallMood: state.overallMood!,
        workStress: state.workStress!,
        teamHarmony: state.teamHarmony!,
        personalGrowth: state.personalGrowth!,
        workLifeBalance: state.workLifeBalance!,
        companyId: user.companyId,
        department: user.department,
      );
      state = state.copyWith(isSubmitting: false, isComplete: true);
      return checkin;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Gönderme başarısız: ${e.toString()}',
      );
      return null;
    }
  }

  void reset() {
    state = const CheckinFlowState();
  }
}

final checkinFlowProvider =
    NotifierProvider<CheckinFlowNotifier, CheckinFlowState>(
        CheckinFlowNotifier.new);

// ─── Cooldown provider ─────────────────────────────────────────────────────────

final checkinCooldownProvider =
    FutureProvider.autoDispose<Duration>((ref) async {
  // In debug bypass mode, always allow check-in (no cooldown).
  if (kDebugMode && AppConstants.debugBypassAuth) return Duration.zero;

  final user = ref.watch(currentUserProvider);
  if (user == null) return Duration.zero;

  final repo = ref.watch(checkinRepositoryProvider);
  return repo.remainingCooldown(user.uid);
});
