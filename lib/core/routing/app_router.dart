import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';
import '../../l10n/app_localizations.dart';
import '../../features/home/views/home_view.dart';
import '../../features/search/views/search_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../../features/invoice_capture/views/image_preview_view.dart';
import '../../features/invoice_capture/views/processing_view.dart';
import '../../features/invoice_capture/views/review_view.dart';
import '../../features/invoice_details/views/invoice_details_view.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeView()),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchView(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsView(),
          ),
        ],
      ),
      GoRoute(
        path: '/preview',
        builder: (context, state) => const ImagePreviewView(),
      ),
      GoRoute(
        path: '/processing',
        builder: (context, state) => const ProcessingView(),
      ),
      GoRoute(path: '/review', builder: (context, state) => const ReviewView()),
      GoRoute(
        path: '/details',
        builder: (context, state) => const InvoiceDetailsView(),
      ),
    ],
    errorBuilder: (context, state) => const _UnknownRouteView(),
  );
}

class _UnknownRouteView extends StatelessWidget {
  const _UnknownRouteView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.home),
        ),
      ),
    );
  }
}
