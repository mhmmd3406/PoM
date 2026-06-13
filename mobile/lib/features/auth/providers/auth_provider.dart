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

// ─── Debug users (debug bypass only) ─────────────────────────────────────────

const _kDebugUsers = [
  UserModel(
    uid: 'debug_free',
    linkedinHash: 'hash_free',
    displayName: 'Ayşe Kaya',
    email: 'ayse.kaya@pom.app',
    role: 'free',
    kvkkAccepted: true,
    kvkkVersion: '1.0',
    creditBalance: 0,
    companyId: 'startup_co',
    department: 'Pazarlama',
  ),
  UserModel(
    uid: 'debug_pro',
    linkedinHash: 'hash_pro',
    displayName: 'Mehmet Demir',
    email: 'mehmet.demir@pom.app',
    role: 'pro',
    kvkkAccepted: true,
    kvkkVersion: '1.0',
    creditBalance: 150,
    companyId: 'garanti_bbva',
    department: 'Ürün',
  ),
  UserModel(
    uid: 'debug_enterprise',
    linkedinHash: 'hash_enterprise',
    displayName: 'Zeynep Arslan',
    email: 'zeynep.arslan@pom.app',
    role: 'enterprise',
    kvkkAccepted: true,
    kvkkVersion: '1.0',
    creditBalance: 500,
    companyId: 'turkcell',
    department: 'İnsan Kaynakları',
  ),
  UserModel(
    uid: 'debug_daas',
    linkedinHash: 'hash_daas',
    displayName: 'Can Öztürk',
    email: 'can.ozturk@pom.app',
    role: 'daas',
    kvkkAccepted: true,
    kvkkVersion: '1.0',
    creditBalance: 1200,
    companyId: 'akbank',
    department: 'Teknoloji',
  ),
];

// ignore: prefer_const_declarations
final _testUser = _kDebugUsers[1]; // pro kullanıcı varsayılan

/// Tüm debug kullanıcılarına dışarıdan erişim (ProfileScreen için).
const kDebugUsers = _kDebugUsers;

// ─── Auth State Notifier ──────────────────────────────────────────────────────

class AuthStateNotifier extends Notifier<AuthState> implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  AuthState build() {
    // In debug builds, bypass LinkedIn login with a test user.
    if (kDebugMode && AppConstants.debugBypassAuth) {
      return AuthState(user: _testUser);
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

  Future<void> acceptKvkk(String version) async {
    final uid = state.user?.uid;
    if (uid == null) return;
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.acceptKvkk(uid, version);
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

  /// Debug-only: instantly switch to any test persona.
  void switchDebugUser(UserModel user) {
    assert(kDebugMode, 'switchDebugUser is only available in debug mode');
    state = AuthState(user: user);
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
