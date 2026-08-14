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
            onPressed: () => _showNotifications(context),
            tooltip: l10n.notifications,
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
            selectedIcon: const Icon(Icons.search_rounded),
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

  void _showNotifications(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.notifications,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      tooltip: l10n.cancel,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noNotifications,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.notificationsBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
