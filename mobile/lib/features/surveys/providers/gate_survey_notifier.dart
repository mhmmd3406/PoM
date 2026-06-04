import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'surveys_provider.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class GateSurveyState {
  const GateSurveyState({
    this.pendingSurvey,
    this.isLoading = true,
    this.dismissedInSession = false,
  });

  final SurveyModel? pendingSurvey;
  final bool isLoading;
  // User tapped "Atla" in the current session; don't redirect again.
  final bool dismissedInSession;

  bool get shouldShow =>
      !isLoading && pendingSurvey != null && !dismissedInSession;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class GateSurveyNotifier extends Notifier<GateSurveyState>
    implements Listenable {
  final List<VoidCallback> _listeners = [];
  // Persists across build() re-runs as an instance field.
  bool _dismissed = false;

  @override
  GateSurveyState build() {
    ref.listen<AsyncValue<SurveyModel?>>(pendingGateSurveyProvider, (_, next) {
      state = _fromAsync(next);
      _notifyListeners();
    });
    return const GateSurveyState(isLoading: true);
  }

  GateSurveyState _fromAsync(AsyncValue<SurveyModel?> async) => async.when(
        data: (s) => GateSurveyState(
          pendingSurvey: s,
          isLoading: false,
          dismissedInSession: _dismissed,
        ),
        loading: () => const GateSurveyState(isLoading: true),
        error: (_, __) => const GateSurveyState(isLoading: false),
      );

  /// Called when the user taps "Atla". Suppresses the gate for this session.
  void dismiss() {
    _dismissed = true;
    state = GateSurveyState(
      pendingSurvey: state.pendingSurvey,
      isLoading: false,
      dismissedInSession: true,
    );
    _notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final l in _listeners) l();
  }
}

final gateSurveyNotifierProvider =
    NotifierProvider<GateSurveyNotifier, GateSurveyState>(
        GateSurveyNotifier.new);
