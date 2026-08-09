import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'brand_logo.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _selectedIndex(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 1:
        context.go('/search');
      case 2:
        context.go('/settings');
      default:
        context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const BrandLogo(compact: true),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            tooltip: l10n.settings,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(location),
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            selectedIcon: const Icon(Icons.manage_search_rounded),
            label: l10n.search,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_rounded),
            selectedIcon: const Icon(Icons.tune_rounded),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
