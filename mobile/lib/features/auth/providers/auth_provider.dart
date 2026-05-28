import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../data/auth_repository.dart';

// ─── Auth State ───────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ─── Test user (debug bypass only) ───────────────────────────────────────────

const _testUser = UserModel(
  uid: 'test_user_001',
  linkedinHash: 'debug_hash_000',
  displayName: 'Test Kullanıcı',
  role: 'pro',
  kvkkAccepted: true,
  kvkkVersion: '1.0',
  creditBalance: 150,
  companyId: 'garanti_bbva',
  department: 'hq_it',
);

// ─── Auth State Notifier ──────────────────────────────────────────────────────

class AuthStateNotifier extends Notifier<AuthState> implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  AuthState build() {
    // In debug builds, bypass LinkedIn login with a test user.
    if (kDebugMode && AppConstants.debugBypassAuth) {
      return const AuthState(user: _testUser);
    }

    ref.listen(authStateProvider, (previous, next) {
      next.when(
        data: (firebaseUser) async {
          if (firebaseUser == null) {
            state = const AuthState();
            _notifyListeners();
          } else {
            state = state.copyWith(isLoading: true);
            try {
              final repo = ref.read(authRepositoryProvider);
              final user = await repo.getUser(firebaseUser.uid);
              state = AuthState(user: user);
            } catch (e) {
              state = AuthState(error: e.toString());
            }
            _notifyListeners();
          }
        },
        loading: () {
          state = state.copyWith(isLoading: true);
        },
        error: (err, stack) {
          state = AuthState(error: err.toString());
          _notifyListeners();
        },
      );
    });

    return const AuthState(isLoading: true);
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final l in _listeners) l();
  }

  Future<void> signInWithLinkedIn(String authCode) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithLinkedInCode(authCode);
      state = AuthState(user: user);
      _notifyListeners();
    } catch (e) {
      state = AuthState(error: _mapError(e));
      _notifyListeners();
    }
  }

  Future<void> acceptKvkk() async {
    final uid = state.user?.uid;
    if (uid == null) return;
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.acceptKvkk(uid, '1.0');
      final updated = await repo.getUser(uid);
      state = AuthState(user: updated);
      _notifyListeners();
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
    }
  }

  Future<void> signOut() async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
      state = const AuthState();
      _notifyListeners();
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
    }
  }

  void refreshUser(UserModel updated) {
    state = AuthState(user: updated);
    _notifyListeners();
  }

  // ignore: avoid_field_initializers_in_const_classes
  void signInAsTestUser() {
    state = AuthState(
      user: const UserModel(
        uid: 'test-uid-001',
        linkedinHash: 'test-hash',
        displayName: 'Test Kullanıcı',
        email: 'test@pom.app',
        role: 'pro',
        kvkkAccepted: true,
        kvkkVersion: '1.0',
        creditBalance: 100,
      ),
    );
    _notifyListeners();
  }

  String _mapError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('unavailable')) {
      return 'Ağ bağlantısı hatası. Lütfen internet bağlantınızı kontrol edin.';
    }
    if (msg.contains('token') || msg.contains('invalid')) {
      return 'Oturum açma başarısız. Lütfen tekrar deneyin.';
    }
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}

final authStateNotifierProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authStateNotifierProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
