import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);
    final user = authState.user;
    final walletAsync = ref.watch(walletStreamProvider(user?.uid ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('PoM'),
        actions: [
          // Credit balance chip
          walletAsync.when(
            data: (wallet) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                avatar: const Icon(Icons.stars, size: 16),
                label: Text('${wallet?.balance ?? 0} kr'),
                visualDensity: VisualDensity.compact,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
            onPressed: () async {
              await ref.read(authStateNotifierProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Merhaba, ${user?.displayName?.split(' ').first ?? 'Kullanıcı'} 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _planLabel(user?.role ?? 'free'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Quick action grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _ActionCard(
                      icon: Icons.sentiment_satisfied_alt,
                      label: 'Check-in Yap',
                      color: Colors.green,
                      onTap: () => context.push(AppRoutes.checkin),
                    ),
                    _ActionCard(
                      icon: Icons.radar,
                      label: 'Görüşlerim',
                      color: Colors.blue,
                      onTap: () => context.push(AppRoutes.insights),
                    ),
                    _ActionCard(
                      icon: Icons.compare_arrows,
                      label: 'Karşılaştır',
                      color: Colors.purple,
                      onTap: () => context.push(AppRoutes.benchmarking),
                    ),
                    _ActionCard(
                      icon: Icons.account_balance_wallet,
                      label: 'Cüzdan',
                      color: Colors.orange,
                      onTap: () => context.push(AppRoutes.wallet),
                    ),
                    _ActionCard(
                      icon: Icons.workspace_premium,
                      label: 'Abonelik',
                      color: Colors.amber,
                      onTap: () => context.push(AppRoutes.subscription),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _planLabel(String role) {
    return switch (role) {
      'pro' => 'Pro üye',
      'enterprise' => 'Kurumsal üye',
      'daas' => 'DaaS üye',
      _ => 'Ücretsiz üye',
    };
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
