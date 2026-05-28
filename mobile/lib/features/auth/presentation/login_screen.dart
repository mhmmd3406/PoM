import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _startLinkedInOAuth() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.launchLinkedInOAuth();
      // Deep-link callback handled by GoRouter & AuthStateNotifier
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LinkedIn bağlantısı açılamadı: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authStateNotifierProvider);

    // Show error from auth state
    ref.listen(authStateNotifierProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: scheme.error,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo & branding
              SlideTransition(
                position: _logoSlide,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            'PoM',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Peace of Mind',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Çalışan refahı platformu',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
              // Tagline cards
              _FeatureRow(
                icon: Icons.insights_rounded,
                text: 'Kişisel refah içgörüleri',
                color: scheme.primary,
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.groups_rounded,
                text: 'Şirket karşılaştırmalı analizler',
                color: scheme.secondary,
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.security_rounded,
                text: 'KVKK uyumlu, tam gizli',
                color: scheme.tertiary,
              ),
              const Spacer(flex: 2),
              // LinkedIn login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || authState.isLoading)
                      ? null
                      : _startLinkedInOAuth,
                  icon: (_isLoading || authState.isLoading)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(
                    (_isLoading || authState.isLoading)
                        ? 'Bağlanıyor...'
                        : 'LinkedIn ile Giriş Yap',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A66C2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (kDebugMode)
                TextButton(
                  onPressed: () => ref
                      .read(authStateNotifierProvider.notifier)
                      .signInAsTestUser(),
                  child: const Text(
                    '🛠 Test Girişi (Debug)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Giriş yaparak KVKK aydınlatma metnini\nokumayı ve onaylamayı kabul etmiş olursunuz.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
