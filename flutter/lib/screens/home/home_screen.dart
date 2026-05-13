import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => context.go('/'));
          return const SizedBox.shrink();
        }
        return StreamBuilder<PomUser>(
          stream: ref.read(firestoreServiceProvider).userStream(user.uid),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            return _HomeBody(pomUser: snap.data!);
          },
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.pomUser});
  final PomUser pomUser;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('PoM'),
              backgroundColor: AppColors.bg1,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () async {
                    // sign-out handled in router redirect
                  },
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.list(
                children: [
                  _GreetingCard(pomUser: pomUser)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 16),
                  _ActionGrid(pomUser: pomUser)
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 16),
                  _StreakCard(streak: pomUser.checkinStreak)
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      );
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.pomUser});
  final PomUser pomUser;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pomUser.businessFamily ?? 'Banking Professional',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (pomUser.departmentType != null)
                    Text(
                      '${pomUser.departmentType} · ${pomUser.seniorityLevel}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted, fontSize: 12),
                    ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.accentLight, size: 16),
                  const SizedBox(width: 4),
                  Text('${pomUser.credits}',
                      style: const TextStyle(
                          color: AppColors.accentLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ]),
              ),
            ],
          ),
        ),
      );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.pomUser});
  final PomUser pomUser;

  @override
  Widget build(BuildContext context) {
    final canCheckin = pomUser.canCheckinThisWeek;

    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: canCheckin
                ? Icons.check_circle_outline_rounded
                : Icons.schedule_rounded,
            label: canCheckin ? 'Weekly Check-in' : 'Already checked in',
            sublabel: canCheckin ? 'Earn +2 credits' : 'Come back next week',
            color: canCheckin ? AppColors.positive : AppColors.textMuted,
            onTap: canCheckin ? () => context.push('/checkin') : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.bar_chart_rounded,
            label: 'My Insights',
            sublabel: 'See your bank\'s score',
            color: AppColors.accent,
            onTap: () => context.push('/insights'),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.5 : 1,
          duration: const Duration(milliseconds: 200),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 12),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$streak week streak',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    streak >= 4
                        ? 'Consistent contributor — thank you!'
                        : 'Check in weekly to grow your streak',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
