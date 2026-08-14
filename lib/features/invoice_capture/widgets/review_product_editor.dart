import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/invoice_draft.dart';

class EditableInvoiceItemControllers {
  EditableInvoiceItemControllers.fromDraft(InvoiceItemDraft draft)
    : name = TextEditingController(text: draft.name),
      quantity = TextEditingController(text: _formatNumber(draft.quantity)),
      unitPrice = TextEditingController(
        text: _formatMinor(draft.unitPriceMinor),
      ),
      lineTotal = TextEditingController(
        text: _formatMinor(draft.lineTotalMinor),
      );

  EditableInvoiceItemControllers.empty()
    : name = TextEditingController(),
      quantity = TextEditingController(),
      unitPrice = TextEditingController(),
      lineTotal = TextEditingController();

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController lineTotal;

  InvoiceItemDraft toDraft() => InvoiceItemDraft(
    name: nullableText(name.text),
    quantity: parseNullableNumber(quantity.text),
    unitPriceMinor: parseNullableMinor(unitPrice.text),
    lineTotalMinor: parseNullableMinor(lineTotal.text),
  );

  bool get hasValue => <TextEditingController>[
    name,
    quantity,
    unitPrice,
    lineTotal,
  ].any((controller) => controller.text.trim().isNotEmpty);

  void dispose() {
    name.dispose();
    quantity.dispose();
    unitPrice.dispose();
    lineTotal.dispose();
  }
}

class ReviewProductEditor extends StatelessWidget {
  const ReviewProductEditor({
    required this.index,
    required this.controllers,
    required this.onRemove,
    super.key,
  });

  final int index;
  final EditableInvoiceItemControllers controllers;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.product} ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.delete),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers.name,
            decoration: InputDecoration(
              labelText: l10n.productName,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers.quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => _validateNumber(l10n, value),
                  decoration: InputDecoration(
                    labelText: l10n.quantity,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controllers.unitPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => _validateMoney(l10n, value),
                  decoration: InputDecoration(
                    labelText: l10n.unitPrice,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers.lineTotal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) => _validateMoney(l10n, value),
            decoration: InputDecoration(
              labelText: l10n.lineTotal,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  String? _validateNumber(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = parseNullableNumber(value);
    return parsed == null || parsed < 0 ? l10n.invalidValue : null;
  }

  String? _validateMoney(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = parseNullableMinor(value);
    return parsed == null || parsed < 0 ? l10n.invalidValue : null;
  }
}

String? nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

double? parseNullableNumber(String value) {
  final normalized = normalizeDigits(value).replaceAll(',', '').trim();
  return normalized.isEmpty ? null : double.tryParse(normalized);
}

int? parseNullableMinor(String value) {
  final amount = parseNullableNumber(value);
  return amount == null ? null : (amount * 100).round();
}

String normalizeDigits(String value) {
  const source = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
  const target = '01234567890123456789';
  return value.split('').map((character) {
    final index = source.indexOf(character);
    return index < 0 ? character : target[index];
  }).join();
}

String _formatNumber(num? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

String _formatMinor(int? minor) {
  if (minor == null) return '';
  final amount = minor / 100;
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}
