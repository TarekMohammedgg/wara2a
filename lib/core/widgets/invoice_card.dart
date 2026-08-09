import 'package:flutter/material.dart';

import '../models/invoice_mock.dart';
import '../theme/app_colors.dart';

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({required this.invoice, this.onTap, super.key});

  final InvoiceMock invoice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(invoice.icon),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: Color(invoice.accent),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.merchant,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${invoice.category} · ${invoice.date}',
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    invoice.total,
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(invoice.currency, style: textTheme.bodySmall),
                ],
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_left_rounded,
                color: AppColors.muted.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
