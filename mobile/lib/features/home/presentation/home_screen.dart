import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/insight_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../checkin/providers/checkin_provider.dart';
import '../../insights/providers/insights_provider.dart';
import '../../surveys/providers/surveys_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final insightsAsync = ref.watch(insightsStreamProvider);
    final cooldownAsync = ref.watch(checkinCooldownProvider);
    // First active survey the user hasn't answered yet (null while loading,
    // on error, or when none are pending) — drives the "Yeni anket" card.
    final pendingSurveys =
        ref.watch(pendingSurveysProvider).valueOrNull ?? const [];
    final nextSurvey = pendingSurveys.isEmpty ? null : pendingSurveys.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final firstName = user?.displayName?.split(' ').first ?? 'Merhaba';
    final initials = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName!
            .trim()
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join()
        : '?';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(insightsStreamProvider);
            ref.invalidate(checkinCooldownProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── App bar ──────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 20, 0),
                  child: Row(
                    children: [
                      // PoM logo mark
                      _PomLogoMark(),
                      const SizedBox(width: 8),
                      Text(
                        'PoM',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const Spacer(),
                      // Bell icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: border),
                        ),
                        child: Icon(Icons.notifications_outlined,
                            size: 18, color: ink2),
                      ),
                      const SizedBox(width: 10),
                      // Avatar
                      GestureDetector(
                        onTap: () => _showProfileSheet(context, ref,
                            user: user, isDark: isDark, ink: ink, ink2: ink2,
                            surface: surface, border: border),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: isDark
                              ? AppColors.sageSoftDark
                              : AppColors.sageSoft,
                          backgroundImage: user?.avatarUrl != null
                              ? NetworkImage(user!.avatarUrl!)
                              : null,
                          child: user?.avatarUrl == null
                              ? Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 12,
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

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Greeting ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}, $firstName',
                        style: TextStyle(fontSize: 14, color: ink3),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Bu hafta nasıl\n',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: ink,
                                letterSpacing: -0.5,
                                height: 1.15,
                              ),
                            ),
                            TextSpan(
                              text: 'hissediyorsun?',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                color: AppColors.blue,
                                letterSpacing: -0.5,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Check-in hero card ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: cooldownAsync.when(
                    loading: () => _SkeletonCard(height: 120, isDark: isDark),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (remaining) => _HeroCheckinCard(
                      remaining: remaining,
                      onTap: () => context.go('/checkin'),
                      isDark: isDark,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── Insights card ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: insightsAsync.when(
                    loading: () => _SkeletonCard(height: 200, isDark: isDark),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (insights) {
                      if (insights == null) return const SizedBox.shrink();
                      return _InsightsCard(
                        insights: insights,
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

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── Bottom row: Company pulse + Survey card ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: insightsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (insights) => Row(
                      children: [
                        Expanded(
                          child: _CompanyPulseCard(
                            companyAvg: insights?.companyAverage ?? 0,
                            sectorAvg: insights?.benchmarkAverage ?? 0,
                            isDark: isDark,
                            ink: ink,
                            ink2: ink2,
                            ink3: ink3,
                            surface: surface,
                            border: border,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NewSurveyCard(
                            survey: nextSurvey,
                            isDark: isDark,
                            ink: ink,
                            ink3: ink3,
                            surface: surface,
                            border: border,
                            onTap: () => context.go('/surveys'),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  void _showProfileSheet(
    BuildContext context,
    WidgetRef ref, {
    required dynamic user,
    required bool isDark,
    required Color ink,
    required Color ink2,
    required Color surface,
    required Color border,
  }) {
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
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            CircleAvatar(
              radius: 32,
              backgroundColor:
                  isDark ? AppColors.sageSoftDark : AppColors.sageSoft,
              backgroundImage: user?.avatarUrl != null
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null
                  ? Text(
                      (user?.displayName?.isNotEmpty == true)
                          ? user!.displayName![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700, color: ink),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ?? 'İsimsiz Kullanıcı',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: ink),
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

// ─── PoM Logo Mark ────────────────────────────────────────────────────────────

class _PomLogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.blue,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.sage,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Check-in Card ───────────────────────────────────────────────────────

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
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              // Decorative circle
              Positioned(
                right: -10,
                bottom: -10,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.blueDeep.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('✦', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(width: 6),
                      Text(
                        'HAFTALIK CHECK-IN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '60 saniyen var mı?',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '5 hızlı soru · anonim',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Başla',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.blue),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Cooldown
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final mins = remaining.inMinutes % 60;
    final timeStr = days > 0
        ? '$days gün $hours saat'
        : hours > 0
            ? '$hours saat $mins dk'
            : '$mins dakika';

    final isDarkLocal = isDark;
    final bgColor =
        isDarkLocal ? AppColors.darkSurface : AppColors.lightSurface;
    final ink2 = isDarkLocal ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink = isDarkLocal ? AppColors.darkInk : AppColors.lightInk;
    final border = isDarkLocal ? AppColors.borderDark : AppColors.borderLight;

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
              color: isDarkLocal ? AppColors.blueWashDark : AppColors.blueWash,
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
                      fontSize: 14, fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 3),
                Text('$timeStr sonra',
                    style: TextStyle(fontSize: 13, color: ink2)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/insights'),
            child: Text('İçgörüler',
                style: TextStyle(fontSize: 13, color: AppColors.blue)),
          ),
        ],
      ),
    );
  }
}

// ─── Insights card (radar + scores + chips) ───────────────────────────────────

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({
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

  static const _dimensions = [
    ('😊', 'Ruh Hali'),
    ('😌', 'Stres'),
    ('🤝', 'Takım'),
    ('🌱', 'Gelişim'),
    ('⚖️', 'Denge'),
  ];

  @override
  Widget build(BuildContext context) {
    final avg = insights.personalAverage;
    final trend = insights.trend;
    final scores = insights.personalList; // list of 5 values 1-5
    final normalized = scores.map((s) => (s / 5.0).clamp(0.0, 1.0)).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Radar + score row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pentagon radar chart
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _RadarPainter(
                    values: normalized,
                    color: AppColors.blue,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GEÇEN HAFTA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ink3,
                        letterSpacing: 0.5,
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
                            fontWeight: FontWeight.w700,
                            color: ink,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('/5',
                              style: TextStyle(fontSize: 14, color: ink3)),
                        ),
                      ],
                    ),
                    if (trend != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: trend >= 0
                              ? (isDark
                                  ? AppColors.sageSoftDark
                                  : AppColors.sageSoft)
                              : (isDark
                                  ? AppColors.amberSoftDark
                                  : AppColors.amberSoft),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          trend > 0
                              ? '↑ Geçen haftaya göre'
                              : trend < 0
                                  ? '↓ Geçen haftaya göre'
                                  : '→ Sabit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: trend >= 0
                                ? AppColors.sageDeep
                                : AppColors.amberDeep,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dimension emoji chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_dimensions.length, (i) {
              final (emoji, label) = _dimensions[i];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: ink2,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Radar chart painter ─────────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.values,
    required this.color,
    required this.isDark,
  });

  final List<double> values;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;
    final n = values.length;

    // Grid
    final gridPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.15 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 3; ring++) {
      final path = Path();
      for (int j = 0; j < n; j++) {
        final angle = (j * 2 * pi / n) - pi / 2;
        final r = radius * ring / 3;
        final pt = Offset(
            center.dx + r * cos(angle), center.dy + r * sin(angle));
        if (j == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Data fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final dataPath = Path();
    final dots = <Offset>[];
    for (int i = 0; i < n; i++) {
      final angle = (i * 2 * pi / n) - pi / 2;
      final r = radius * values[i];
      final pt =
          Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      dots.add(pt);
      if (i == 0) {
        dataPath.moveTo(pt.dx, pt.dy);
      } else {
        dataPath.lineTo(pt.dx, pt.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // Dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final pt in dots) {
      canvas.drawCircle(pt, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values != values || old.isDark != isDark;
}

// ─── Company pulse card ───────────────────────────────────────────────────────

class _CompanyPulseCard extends StatelessWidget {
  const _CompanyPulseCard({
    required this.companyAvg,
    required this.sectorAvg,
    required this.isDark,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.surface,
    required this.border,
  });

  final double companyAvg;
  final double sectorAvg;
  final bool isDark;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ŞİRKET NABZI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ink3,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: ink3),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            companyAvg > 0 ? companyAvg.toStringAsFixed(1) : '—',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: ink,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sectorAvg > 0
                ? 'Sektör ort. ${sectorAvg.toStringAsFixed(1)}'
                : 'Sektör verisi yok',
            style: TextStyle(fontSize: 12, color: ink3),
          ),
        ],
      ),
    );
  }
}

// ─── New survey card ──────────────────────────────────────────────────────────

class _NewSurveyCard extends StatelessWidget {
  const _NewSurveyCard({
    required this.survey,
    required this.isDark,
    required this.ink,
    required this.ink3,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  /// First pending survey, or null when none are pending (or still loading).
  final SurveyModel? survey;
  final bool isDark;
  final Color ink;
  final Color ink3;
  final Color surface;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = survey;

    // No pending survey → honest empty state (no fabricated "new survey").
    if (s == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ANKETLER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ink3,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bekleyen anket yok',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yeni anket gelince burada',
                style: TextStyle(fontSize: 11, color: ink3),
              ),
            ],
          ),
        ),
      );
    }

    final source = s.isAdminSurvey ? 'PoM' : 'Şirket';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.amberSoftDark : AppColors.amberWash,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'YENİ ANKET',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amber,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$source · ${s.questionCount} soru',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.amberDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton card ────────────────────────────────────────────────────────────

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
