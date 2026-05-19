import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/insight_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../checkin/providers/checkin_provider.dart';
import '../../insights/providers/insights_provider.dart';
import '../../wallet/providers/wallet_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final insightsAsync = ref.watch(insightsStreamProvider);
    final cooldownAsync = ref.watch(checkinCooldownProvider);
    final balanceAsync = ref.watch(walletBalanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final firstName = user?.displayName?.split(' ').first ?? 'Merhaba';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(insightsStreamProvider);
            ref.invalidate(checkinCooldownProvider);
            ref.invalidate(walletBalanceProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: ink3,
                              ),
                            ),
                            Text(
                              firstName,
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: ink,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Credit chip
                      balanceAsync.whenOrNull(
                        data: (balance) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.blueSoftDark
                                : AppColors.blueSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded,
                                  size: 14, color: AppColors.blue),
                              const SizedBox(width: 4),
                              Text(
                                '$balance kr',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ) ?? const SizedBox.shrink(),
                      const SizedBox(width: 8),
                      // Avatar
                      GestureDetector(
                        onTap: () => _showProfileSheet(context, ref),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: isDark
                              ? AppColors.sageSoftDark
                              : AppColors.sageSoft,
                          backgroundImage: user?.avatarUrl != null
                              ? NetworkImage(user!.avatarUrl!)
                              : null,
                          child: user?.avatarUrl == null
                              ? Text(
                                  (user?.displayName?.isNotEmpty == true)
                                      ? user!.displayName![0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.sageDark
                                        : AppColors.sageDeep,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Hero check-in card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: cooldownAsync.when(
                    loading: () => _SkeletonCard(height: 110, isDark: isDark),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (remaining) => _HeroCheckinCard(
                      remaining: remaining,
                      onTap: () => context.go('/checkin'),
                      isDark: isDark,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Last check-in stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: insightsAsync.when(
                    loading: () => _SkeletonCard(height: 80, isDark: isDark),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (insights) {
                      if (insights == null) return const SizedBox.shrink();
                      return _LastCheckinCard(
                        insights: insights!,
                        surface: surface,
                        border: border,
                        ink: ink,
                        ink2: ink2,
                        ink3: ink3,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Quick actions header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Hızlı Erişim',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Quick action grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.65,
                  children: [
                    _QuickActionCard(
                      emoji: '📊',
                      label: 'İçgörülerim',
                      bg: isDark ? AppColors.blueSoftDark : AppColors.blueSoft,
                      labelColor: isDark ? AppColors.blueDark : AppColors.blueDeep,
                      onTap: () => context.go('/insights'),
                    ),
                    _QuickActionCard(
                      emoji: '📋',
                      label: 'Anketler',
                      bg: isDark ? AppColors.sageSoftDark : AppColors.sageSoft,
                      labelColor: isDark ? AppColors.sageDark : AppColors.sageDeep,
                      onTap: () => context.go('/surveys'),
                    ),
                    _QuickActionCard(
                      emoji: '💳',
                      label: 'Cüzdanım',
                      bg: isDark ? AppColors.amberSoftDark : AppColors.amberSoft,
                      labelColor: AppColors.amberDeep,
                      onTap: () => context.go('/wallet'),
                    ),
                    _QuickActionCard(
                      emoji: '🏅',
                      label: 'Karşılaştır',
                      bg: isDark ? AppColors.darkSurfaceSoft : AppColors.lightSurfaceSoft,
                      labelColor: ink2,
                      onTap: () => context.go('/benchmarking'),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın,';
    if (hour < 18) return 'İyi günler,';
    return 'İyi akşamlar,';
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            CircleAvatar(
              radius: 32,
              backgroundColor: isDark ? AppColors.sageSoftDark : AppColors.sageSoft,
              backgroundImage: user?.avatarUrl != null
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null
                  ? Text(
                      (user?.displayName?.isNotEmpty == true)
                          ? user!.displayName![0].toUpperCase()
                          : '?',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ?? 'İsimsiz Kullanıcı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            if (user?.email != null) ...[
              const SizedBox(height: 4),
              Text(user!.email!, style: TextStyle(color: ink2, fontSize: 14)),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: ink2),
              title: Text('Çıkış Yap', style: TextStyle(color: ink)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await ref.read(authStateNotifierProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Check-in Card ────────────────────────────────────────────────────────

class _HeroCheckinCard extends StatelessWidget {
  const _HeroCheckinCard({
    required this.remaining,
    required this.onTap,
    required this.isDark,
  });

  final Duration remaining;
  final VoidCallback onTap;
  final bool isDark;

  bool get _canCheckin => remaining == Duration.zero;

  @override
  Widget build(BuildContext context) {
    if (_canCheckin) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.blue, AppColors.blueDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Bu haftanın sorusu hazır',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '60 saniyen\nvar mı?',
                      style: TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Check-in\'i Başlat',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text('✨', style: TextStyle(fontSize: 52)),
            ],
          ),
        ),
      );
    }

    // Cooldown state
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final mins = remaining.inMinutes % 60;
    final timeStr = days > 0
        ? '$days gün $hours saat'
        : hours > 0
            ? '$hours saat $mins dk'
            : '$mins dakika';

    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.blueWashDark : AppColors.blueWash,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schedule_rounded,
                color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bir Sonraki Check-in',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$timeStr sonra',
                  style: TextStyle(fontSize: 13, color: ink2),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/insights'),
            child: Text(
              'İçgörüler',
              style: TextStyle(fontSize: 13, color: AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Last Check-in Card ───────────────────────────────────────────────────────

class _LastCheckinCard extends StatelessWidget {
  const _LastCheckinCard({
    required this.insights,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.isDark,
  });

  final InsightModel insights;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final bool isDark;

  Color _scoreColor(double score) {
    if (score >= 4) return AppColors.sage;
    if (score >= 3) return AppColors.amber;
    return AppColors.rose;
  }

  @override
  Widget build(BuildContext context) {
    final avg = insights.personalAverage;
    final total = insights.totalCheckins;
    final trend = insights.trend;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Son Check-in',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ink3,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: _scoreColor(avg),
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/5',
                      style: TextStyle(fontSize: 14, color: ink3),
                    ),
                  ),
                ],
              ),
              if (trend != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: trend >= 0
                        ? (isDark ? AppColors.sageSoftDark : AppColors.sageSoft)
                        : (isDark ? AppColors.amberSoftDark : AppColors.amberSoft),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend > 0 ? '↑ İyileşiyor' : trend < 0 ? '↓ Düşüyor' : '→ Sabit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: trend >= 0 ? AppColors.sageDeep : AppColors.amberDeep,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 20),
          // Divider
          Container(width: 1, height: 60, color: border),
          const SizedBox(width: 20),
          // Stats
          Expanded(
            child: Column(
              children: [
                _StatRow(
                  label: 'Toplam',
                  value: '$total check-in',
                  ink: ink,
                  ink3: ink3,
                ),
                const SizedBox(height: 8),
                _StatRow(
                  label: 'Streak',
                  value: '3 hafta',
                  ink: ink,
                  ink3: ink3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.ink,
    required this.ink3,
  });

  final String label;
  final String value;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: ink3)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ],
    );
  }
}

// ─── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.emoji,
    required this.label,
    required this.bg,
    required this.labelColor,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color bg;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height, required this.isDark});
  final double height;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.5)
            : AppColors.lightBgAlt,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
