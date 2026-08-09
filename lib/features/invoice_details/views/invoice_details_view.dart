import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/models/invoice_mock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';

class InvoiceDetailsView extends StatelessWidget {
  const InvoiceDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invoice = MockData.invoices.first;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        title: Text(l10n.detailsTitle),
        actions: [
          IconButton(
            onPressed: () => context.push('/review'),
            tooltip: l10n.edit,
            icon: const Icon(Icons.edit_outlined),
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
                  invoice.merchant,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _StatusBadge(text: l10n.detailsStoredLocally),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${invoice.category} · ${invoice.date}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          _SummaryCard(invoice: invoice),
          const SizedBox(height: 22),
          Text(l10n.products, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _DetailProduct(
            name: 'Samsung Galaxy A56',
            meta: l10n.invoicesCount(1),
            price: '24,999 ج.م',
          ),
          const SizedBox(height: 8),
          _DetailProduct(name: 'ضمان ممتد', meta: invoice.warranty, price: '—'),
          const SizedBox(height: 22),
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

  final InvoiceMock invoice;

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
              'BT-2026-0841',
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

  final InvoiceMock invoice;

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
              value: '${invoice.total} ${invoice.currency}',
              accent: true,
            ),
            _DetailLine(label: l10n.purchaseDate, value: invoice.date),
            _DetailLine(label: l10n.invoiceNumber, value: invoice.number),
            _DetailLine(
              label: l10n.warranty,
              value: invoice.warranty,
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
            borderRadius: BorderRadius.all(Radius.circular(13)),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softMint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF169C75)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF167A61),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        color: const Color(0xFFE4EAF2),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Center(
        child: Container(
          width: 110,
          height: 126,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.09),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 42, height: 8, color: AppColors.blue),
              const SizedBox(height: 15),
              ...List.generate(
                6,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    height: 4,
                    width: index.isEven ? 60 : 45,
                    color: const Color(0xFFDDE4EC),
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
