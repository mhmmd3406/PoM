import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(authServiceProvider).signInWithLinkedIn();
      if (!mounted) return;
      if (result.isNewUser) {
        context.go('/onboarding/profile');
      } else {
        context.go('/home');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Text('Your voice,\nanonymously.',
                        style: Theme.of(context).textTheme.displayLarge)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 12),
                Text(
                  'Rate your bank. See where you stand.\nNo names, no traces.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                ).animate(delay: 100.ms).fadeIn(duration: 500.ms),
                const Spacer(flex: 3),
                _PrivacyBadges()
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 32),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.negative, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _signIn,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.link_rounded, size: 20),
                  label: Text(_loading ? 'Connecting…' : 'Continue with LinkedIn'),
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'We never store your name or email.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textMuted, fontSize: 12),
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      );
}

class _PrivacyBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          _Badge(icon: Icons.lock_outline_rounded, label: 'Zero-Knowledge'),
          _Badge(icon: Icons.fingerprint_rounded, label: 'ID Hashed'),
          _Badge(icon: Icons.visibility_off_rounded, label: 'No PII Stored'),
        ],
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.positive),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
