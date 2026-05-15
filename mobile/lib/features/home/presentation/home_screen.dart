import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../checkin/providers/checkin_provider.dart';
import '../../insights/providers/insights_provider.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../wallet/providers/wallet_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final insightsAsync = ref.watch(insightsStreamProvider);
    final cooldownAsync = ref.watch(checkinCooldownProvider);
    final balanceAsync = ref.watch(walletBalanceProvider);
    final subscriptionAsync = ref.watch(subscriptionStreamProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'PoM',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Peace of Mind'),
          ],
        ),
        actions: [
          // Credit balance chip
          balanceAsync.when(
            data: (balance) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                avatar: Icon(Icons.stars_rounded,
                    size: 14, color: scheme.primary),
                label: Text('$balance kr',
                    style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: scheme.primaryContainer,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Avatar
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showProfileSheet(context, ref),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: scheme.secondaryContainer,
                backgroundImage: user?.avatarUrl != null
                    ? NetworkImage(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? Text(
                        user?.displayName
                                ?.substring(0, 1)
                                .toUpperCase() ??
                            '?',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(insightsStreamProvider);
          ref.invalidate(checkinCooldownProvider);
          ref.invalidate(walletBalanceProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                '${_greeting()},',
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
              ),
              Text(
                user?.displayName?.split(' ').first ??
                    'Hoş Geldiniz',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _planLabel(user?.role ?? 'free'),
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),

              // Check-in CTA card
              cooldownAsync.when(
                loading: () => const _CheckinCardSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (remaining) => _CheckinCtaCard(
                  remaining: remaining,
                  onTap: () => context.go('/checkin'),
                ),
              ),
              const SizedBox(height: 20),

              // Quick stats row
              insightsAsync.when(
                loading: () => const _StatsSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (insights) {
                  if (insights == null) return const SizedBox.shrink();
                  return Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Refah Skoru',
                          value: insights.personalAverage
                              .toStringAsFixed(1),
                          suffix: '/5',
                          icon: '😊',
                          color: _scoreColor(insights.personalAverage),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Check-in',
                          value: insights.totalCheckins.toString(),
                          suffix: '',
                          icon: '✅',
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Trend',
                          value: insights.trend == null
                              ? '--'
                              : insights.trend! > 0
                                  ? '↑'
                                  : insights.trend! < 0
                                      ? '↓'
                                      : '→',
                          suffix: '',
                          icon: '📈',
                          color: insights.trend != null &&
                                  insights.trend! > 0
                              ? const Color(0xFF4CAF50)
                              : insights.trend != null &&
                                      insights.trend! < 0
                                  ? const Color(0xFFF44336)
                                  : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Quick Actions grid
              Text(
                'Hızlı Erişim',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _QuickActionCard(
                    icon: Icons.insights_rounded,
                    label: 'İçgörülerim',
                    color: const Color(0xFF2196F3),
                    onTap: () => context.go('/insights'),
                  ),
                  _QuickActionCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Cüzdanım',
                    color: const Color(0xFF4CAF50),
                    onTap: () => context.go('/wallet'),
                  ),
                  _QuickActionCard(
                    icon: Icons.star_rounded,
                    label: 'Abonelik',
                    color: const Color(0xFFFF9800),
                    onTap: () => context.go('/subscription'),
                  ),
                  _QuickActionCard(
                    icon: Icons.compare_arrows_rounded,
                    label: 'Karşılaştır',
                    color: const Color(0xFF9C27B0),
                    onTap: () => context.go('/benchmarking'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          const routes = ['/', '/checkin', '/insights', '/wallet'];
          context.go(routes[index]);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              label: 'Check-in'),
          NavigationDestination(
              icon: Icon(Icons.insights_rounded), label: 'İçgörüler'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Cüzdan'),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 4) return const Color(0xFF4CAF50);
    if (score >= 3) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  String _planLabel(String role) {
    return switch (role) {
      'pro' => 'Pro üye',
      'enterprise' => 'Kurumsal üye',
      'daas' => 'DaaS üye',
      _ => 'Ücretsiz üye',
    };
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: scheme.secondaryContainer,
              backgroundImage: user?.avatarUrl != null
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null
                  ? Text(
                      user?.displayName
                              ?.substring(0, 1)
                              .toUpperCase() ??
                          '?',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ?? 'İsimsiz Kullanıcı',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (user?.email != null) ...[
              const SizedBox(height: 4),
              Text(user!.email!,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            Chip(
              label: Text(_planLabel(user?.role ?? 'free').toUpperCase()),
              backgroundColor: scheme.primaryContainer,
              side: BorderSide.none,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Çıkış Yap'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await ref
                    .read(authStateNotifierProvider.notifier)
                    .signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Check-in CTA Card ────────────────────────────────────────────────────────

class _CheckinCtaCard extends StatelessWidget {
  const _CheckinCtaCard({
    required this.remaining,
    required this.onTap,
  });

  final Duration remaining;
  final VoidCallback onTap;

  bool get _canCheckin => remaining == Duration.zero;

  String _cooldownText() {
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    if (days > 0) return '$days gün $hours saat sonra';
    final mins = remaining.inMinutes % 60;
    return '$hours saat $mins dakika sonra';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _canCheckin ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: _canCheckin
              ? LinearGradient(
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, Colors.blue, 0.3)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    scheme.surfaceContainerHighest,
                    scheme.surfaceContainerHighest,
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _canCheckin
              ? [
                  BoxShadow(
                    color: scheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              _canCheckin ? '😊' : '⏳',
              style: const TextStyle(fontSize: 38),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _canCheckin
                        ? 'Haftalık Check-in Hazır!'
                        : 'Bir Sonraki Check-in',
                    style: TextStyle(
                      color: _canCheckin
                          ? Colors.white
                          : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _canCheckin
                        ? 'Bu haftaki ruh halinizi kaydedin.'
                        : _cooldownText(),
                    style: TextStyle(
                      color: _canCheckin
                          ? Colors.white70
                          : scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (_canCheckin)
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String suffix;
  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (suffix.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Skeletons ────────────────────────────────────────────────────────────────

class _CheckinCardSkeleton extends StatelessWidget {
  const _CheckinCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
