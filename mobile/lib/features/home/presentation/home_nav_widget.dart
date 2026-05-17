import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeNavWidget extends StatelessWidget {
  const HomeNavWidget({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Ana Sayfa', route: '/'),
    _NavItem(
        icon: Icons.add_circle_outline_rounded,
        label: 'Check-in',
        route: '/checkin'),
    _NavItem(
        icon: Icons.insights_rounded, label: 'İçgörüler', route: '/insights'),
    _NavItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Cüzdan',
        route: '/wallet'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          context.go(_items[index].route);
        },
        destinations: _items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}
