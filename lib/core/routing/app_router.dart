import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app_dependencies.dart';
import '../widgets/app_shell.dart';
import '../../l10n/app_localizations.dart';
import '../../features/home/views/home_view.dart';
import '../../features/search/views/search_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../../features/invoice_capture/views/image_preview_view.dart';
import '../../features/invoice_capture/views/processing_view.dart';
import '../../features/invoice_capture/views/review_view.dart';
import '../../features/invoice_details/views/invoice_details_view.dart';
import '../../features/home/view_models/home_cubit.dart';
import '../../features/invoice_capture/view_models/review_cubit.dart';
import '../../features/invoice_capture/view_models/invoice_capture_cubit.dart';
import '../../features/invoice_capture/view_models/invoice_extraction_cubit.dart';
import '../../features/invoice_capture/models/review_route_args.dart';
import '../../features/invoice_details/view_models/invoice_details_cubit.dart';
import '../../features/search/view_models/search_cubit.dart';

GoRouter buildAppRouter(AppDependencies dependencies) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => BlocProvider(
              create: (_) =>
                  HomeCubit(dependencies.homeInvoices)..watchInvoices(),
              child: const HomeView(),
            ),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => BlocProvider(
              create: (_) => SearchCubit(dependencies.search),
              child: const SearchView(),
            ),
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
        builder: (context, state) {
          final image = context.read<InvoiceCaptureCubit>().state.draft;
          if (image == null) return const _UnknownRouteView();
          return BlocProvider(
            create: (_) => InvoiceExtractionCubit(
              dependencies.createInvoiceExtractionRepository(),
            )..extract(image),
            child: ProcessingView(image: image),
          );
        },
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) {
          final invoiceId = int.tryParse(
            state.uri.queryParameters['invoiceId'] ?? '',
          );
          final routeArgs = state.extra is ReviewRouteArgs
              ? state.extra! as ReviewRouteArgs
              : null;
          return BlocProvider(
            create: (_) => ReviewCubit(
              dependencies.invoiceCapture,
              initialDraft: routeArgs?.draft,
              invoiceIdToLoad: invoiceId,
            ),
            child: ReviewView(invoiceId: invoiceId),
          );
        },
      ),
      GoRoute(
        path: '/details',
        builder: (context, state) => const InvoiceDetailsView.preview(),
      ),
      GoRoute(
        path: '/details/:invoiceId',
        builder: (context, state) {
          final invoiceId = int.tryParse(
            state.pathParameters['invoiceId'] ?? '',
          );
          if (invoiceId == null || invoiceId <= 0) {
            return const _UnknownRouteView();
          }
          return BlocProvider(
            create: (_) =>
                InvoiceDetailsCubit(dependencies.invoices)..load(invoiceId),
            child: InvoiceDetailsView(invoiceId: invoiceId),
          );
        },
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
