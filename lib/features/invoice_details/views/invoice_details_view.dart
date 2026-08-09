import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_versions.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../models/invoice.dart';
import '../view_models/invoice_details_cubit.dart';

class InvoiceDetailsView extends StatelessWidget {
  const InvoiceDetailsView({required this.invoiceId, super.key});

  const InvoiceDetailsView.preview({super.key}) : invoiceId = null;

  final int? invoiceId;

  @override
  Widget build(BuildContext context) {
    if (invoiceId == null) return _LoadedInvoiceDetails(invoice: _preview());
    return BlocBuilder<InvoiceDetailsCubit, InvoiceDetailsState>(
      builder: (context, state) {
        if (state.status == InvoiceDetailsStatus.loading ||
            state.status == InvoiceDetailsStatus.initial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.invoice == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
            body: Center(child: Text(AppLocalizations.of(context).noResults)),
          );
        }
        return _LoadedInvoiceDetails(invoice: state.invoice!);
      },
    );
  }
}

class _LoadedInvoiceDetails extends StatelessWidget {
  const _LoadedInvoiceDetails({required this.invoice});

  final Invoice invoice;

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.detailsTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await context.read<InvoiceDetailsCubit>().delete();
    if (deleted && context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final persisted = invoice.id > 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        title: Text(l10n.detailsTitle),
        actions: [
          if (persisted)
            IconButton(
              onPressed: () => context.push('/review?invoiceId=${invoice.id}'),
              tooltip: l10n.edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (persisted)
            IconButton(
              onPressed: () => _delete(context),
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _DetailsHero(invoice: invoice),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.merchant ?? '—',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _StatusBadge(text: l10n.detailsStoredLocally),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${invoice.documentType ?? '—'} · ${_formatDate(invoice.purchaseDate)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          _SummaryCard(invoice: invoice),
          const SizedBox(height: 22),
          Text(l10n.products, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...invoice.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DetailProduct(
                name: item.name,
                meta: item.quantity?.toString() ?? '—',
                price: _formatMoney(
                  item.lineTotalMinor ?? item.unitPriceMinor,
                  invoice.currencyCode,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.invoiceImage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          const _SmallInvoiceImage(),
          const SizedBox(height: 22),
          PrimaryButton(
            label: l10n.scanAgain,
            icon: Icons.add_a_photo_rounded,
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.softBlue, AppColors.softCyan],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(height: 8, width: 34, color: AppColors.blue),
                const SizedBox(height: 11),
                ...List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Container(
                      height: 4,
                      width: index.isEven ? 42 : 28,
                      color: const Color(0xFFDDE4EC),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              invoice.invoiceNumber ?? '—',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.navy),
            ),
          ),
          const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.blue,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          children: [
            _DetailLine(
              label: l10n.total,
              value: _formatMoney(invoice.totalMinor, invoice.currencyCode),
              accent: true,
            ),
            _DetailLine(
              label: l10n.purchaseDate,
              value: _formatDate(invoice.purchaseDate),
            ),
            _DetailLine(
              label: l10n.invoiceNumber,
              value: invoice.invoiceNumber ?? '—',
            ),
            _DetailLine(
              label: l10n.warranty,
              value: invoice.warrantyMonths?.toString() ?? '—',
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.accent = false,
    this.last = false,
  });

  final String label;
  final String value;
  final bool accent;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: accent ? AppColors.blue : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailProduct extends StatelessWidget {
  const _DetailProduct({
    required this.name,
    required this.meta,
    required this.price,
  });

  final String name;
  final String meta;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.softBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.inventory_2_outlined, color: AppColors.blue),
        ),
        title: Text(name),
        subtitle: Text(meta),
        trailing: Text(price, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softMint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF167A61),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallInvoiceImage extends StatelessWidget {
  const _SmallInvoiceImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Center(
        child: Icon(
          Icons.receipt_long_rounded,
          size: 54,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

String _formatMoney(int? minor, String? currency) {
  if (minor == null) return '—';
  final amount = minor / 100;
  final value = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return currency == null || currency.isEmpty ? value : '$value $currency';
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

Invoice _preview() {
  final draft = MockData.draft;
  final reviewedAt = DateTime.utc(2026, 8, 9);
  return Invoice(
    merchant: draft.merchant,
    documentType: draft.documentType,
    purchaseDate: draft.purchaseDate,
    totalMinor: draft.totalMinor,
    currencyCode: draft.currencyCode,
    warrantyMonths: draft.warrantyMonths,
    invoiceNumber: draft.invoiceNumber,
    rawExtractedText: draft.rawExtractedText,
    searchableText: '',
    keywordText: '',
    imagePath: draft.imagePath,
    thumbnailPath: draft.thumbnailPath,
    sourceType: draft.sourceType,
    searchTextSchemaVersion: DatabaseVersions.searchTextSchema,
    extractionModelId: draft.extractionModelId,
    createdAt: reviewedAt,
    updatedAt: reviewedAt,
    reviewedAt: reviewedAt,
    items: draft.items
        .map(
          (item) => InvoiceItem(
            name: item.name,
            quantity: item.quantity,
            unitPriceMinor: item.unitPriceMinor,
            lineTotalMinor: item.lineTotalMinor,
          ),
        )
        .toList(growable: false),
  );
}
