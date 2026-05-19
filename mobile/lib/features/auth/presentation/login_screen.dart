import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startLinkedInOAuth() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.launchLinkedInOAuth();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('LinkedIn bağlantısı açılamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(authStateNotifierProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // Logo mark
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'PoM',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Headline
                  Text(
                    'Çalışma hayatında\niç huzuru bul.',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: ink,
                      letterSpacing: -1.0,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Haftada 5 soru · Tamamen anonim · KVKK uyumlu',
                    style: TextStyle(
                      fontSize: 14,
                      color: ink3,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(),

                  // Feature cards
                  _FeatureCard(
                    emoji: '📊',
                    title: 'Kişisel içgörüler',
                    subtitle: 'Ruh halini takip et, trendleri keşfet',
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                  ),
                  const SizedBox(height: 10),
                  _FeatureCard(
                    emoji: '🔒',
                    title: 'Gizliliğin korunur',
                    subtitle: 'Şirket sadece anonim toplamı görür',
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                  ),
                  const SizedBox(height: 10),
                  _FeatureCard(
                    emoji: '🌿',
                    title: 'Sektörel kıyaslama',
                    subtitle: 'Kendini benzer şirketlerle karşılaştır',
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                  ),

                  const Spacer(),

                  // LinkedIn button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isLoading || authState.isLoading)
                          ? null
                          : _startLinkedInOAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.linkedIn,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        shadowColor: AppColors.linkedIn.withValues(alpha: 0.4),
                      ).copyWith(
                        elevation: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.pressed) ? 0 : 4,
                        ),
                      ),
                      child: (_isLoading || authState.isLoading)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _LinkedInIcon(),
                                const SizedBox(width: 10),
                                Text(
                                  'LinkedIn ile Giriş Yap',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Giriş yaparak KVKK aydınlatma metnini kabul etmiş olursunuz.',
                    style: TextStyle(fontSize: 12, color: ink3, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: ink2,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedInIcon extends StatelessWidget {
  const _LinkedInIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'in',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.linkedIn,
            height: 1,
          ),
        ),
      ),
    );
  }
}
