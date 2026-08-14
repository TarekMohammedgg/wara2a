import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/invoice_card.dart';
import '../../../l10n/app_localizations.dart';
import '../models/invoice_summary.dart';
import '../view_models/home_cubit.dart';

enum InvoiceListFilter { all, thisMonth }

class InvoiceListView extends StatelessWidget {
  const InvoiceListView({required this.filter, super.key});

  final InvoiceListFilter filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = filter == InvoiceListFilter.thisMonth
        ? l10n.thisMonth
        : l10n.totalInvoices;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        title: Text(title),
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state.status == HomeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final invoices = _filtered(state.invoices, filter);
          if (invoices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.noInvoices,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: invoices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return InvoiceCard(
                invoice: invoice,
                onTap: () => context.push('/details/${invoice.id}'),
              );
            },
          );
        },
      ),
    );
  }

  List<InvoiceSummary> _filtered(
    List<InvoiceSummary> invoices,
    InvoiceListFilter filter,
  ) {
    if (filter == InvoiceListFilter.all) return invoices;
    final prefix = DateTime.now().toLocal().toIso8601String().substring(0, 7);
    return invoices
        .where((invoice) => invoice.date.startsWith(prefix))
        .toList(growable: false);
  }
}
