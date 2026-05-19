import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          'Profil',
          style: TextStyle(color: ink, fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: isDark ? AppColors.sageSoftDark : AppColors.sageSoft,
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          (user?.displayName?.isNotEmpty == true)
                              ? user!.displayName![0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.sageDark : AppColors.sageDeep,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'İsimsiz Kullanıcı',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    letterSpacing: -0.3,
                  ),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.email!,
                    style: TextStyle(fontSize: 14, color: ink3),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.blueSoftDark : AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _planLabel(user?.role ?? 'free').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Settings section
          _SectionHeader(label: 'HESAP', ink3: ink3),
          const SizedBox(height: 8),
          _ListCard(
            surface: surface,
            border: border,
            children: [
              _SettingRow(
                icon: Icons.star_rounded,
                label: 'Abonelik',
                ink: ink,
                ink2: ink2,
                onTap: () => context.go('/subscription'),
              ),
              Divider(height: 1, color: border),
              _SettingRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Cüzdanım',
                ink: ink,
                ink2: ink2,
                onTap: () => context.go('/wallet'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _SectionHeader(label: 'GİZLİLİK', ink3: ink3),
          const SizedBox(height: 8),
          _ListCard(
            surface: surface,
            border: border,
            children: [
              _SettingRow(
                icon: Icons.description_outlined,
                label: 'KVKK Aydınlatma Metni',
                ink: ink,
                ink2: ink2,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          _SectionHeader(label: 'OTURUM', ink3: ink3),
          const SizedBox(height: 8),
          _ListCard(
            surface: surface,
            border: border,
            children: [
              _SettingRow(
                icon: Icons.logout_rounded,
                label: 'Çıkış Yap',
                ink: AppColors.rose,
                ink2: AppColors.rose,
                onTap: () async {
                  await ref.read(authStateNotifierProvider.notifier).signOut();
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 4,
        onDestinationSelected: (index) {
          const routes = ['/', '/checkin', '/insights', '/surveys', '/profile'];
          context.go(routes[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Check-in',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'İçgörüler',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Anketler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  String _planLabel(String role) {
    return switch (role) {
      'pro' => 'Pro Üye',
      'enterprise' => 'Kurumsal Üye',
      'daas' => 'DaaS Üye',
      _ => 'Ücretsiz Üye',
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.ink3});
  final String label;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ink3,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.surface,
    required this.border,
    required this.children,
  });

  final Color surface;
  final Color border;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.ink,
    required this.ink2,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color ink;
  final Color ink2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ink2),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: ink2),
          ],
        ),
      ),
    );
  }
}
