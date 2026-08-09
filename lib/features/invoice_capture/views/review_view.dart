import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../models/invoice_draft.dart';
import '../view_models/review_cubit.dart';
import '../widgets/review_product_editor.dart';

class ReviewView extends StatefulWidget {
  const ReviewView({this.invoiceId, super.key});

  final int? invoiceId;

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchant;
  late final TextEditingController _documentType;
  late final TextEditingController _purchaseDate;
  late final TextEditingController _invoiceNumber;
  late final TextEditingController _total;
  late final TextEditingController _currency;
  late final TextEditingController _warrantyMonths;
  late InvoiceDraft _draft;
  final List<EditableInvoiceItemControllers> _products = [];

  @override
  void initState() {
    super.initState();
    _draft =
        context.read<ReviewCubit>().state.draft ??
        InvoiceDraft.manualFallback(rawText: '');
    _merchant = TextEditingController();
    _documentType = TextEditingController();
    _purchaseDate = TextEditingController();
    _invoiceNumber = TextEditingController();
    _total = TextEditingController();
    _currency = TextEditingController();
    _warrantyMonths = TextEditingController();
    _replaceDraft(_draft, rebuild: false);
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _merchant,
      _documentType,
      _purchaseDate,
      _invoiceNumber,
      _total,
      _currency,
      _warrantyMonths,
    ]) {
      controller.dispose();
    }
    for (final product in _products) {
      product.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final products = _products
        .where((product) => product.hasValue)
        .map((product) => product.toDraft())
        .toList(growable: false);
    await context.read<ReviewCubit>().save(
      _draft.copyWith(
        merchant: nullableText(_merchant.text),
        documentType: nullableText(_documentType.text),
        purchaseDate: _parseDate(_purchaseDate.text),
        invoiceNumber: nullableText(_invoiceNumber.text),
        totalMinor: parseNullableMinor(_total.text),
        currency: nullableText(_currency.text)?.toUpperCase(),
        warrantyMonths: _parseInteger(_warrantyMonths.text),
        products: products,
        requiresManualReview: false,
      ),
    );
  }

  void _replaceDraft(InvoiceDraft draft, {bool rebuild = true}) {
    void update() {
      _draft = draft;
      _merchant.text = draft.merchant ?? '';
      _documentType.text = draft.documentType ?? '';
      _purchaseDate.text = _formatDate(draft.purchaseDate);
      _invoiceNumber.text = draft.invoiceNumber ?? '';
      _total.text = _formatMinor(draft.totalMinor);
      _currency.text = draft.currency ?? '';
      _warrantyMonths.text = draft.warrantyMonths?.toString() ?? '';
      for (final product in _products) {
        product.dispose();
      }
      _products
        ..clear()
        ..addAll(draft.products.map(EditableInvoiceItemControllers.fromDraft));
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reviewState = context.watch<ReviewCubit>().state;
    if (reviewState.status == ReviewStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return BlocListener<ReviewCubit, ReviewState>(
      listener: (context, state) {
        if (state.status == ReviewStatus.ready &&
            state.draft != null &&
            state.draft != _draft) {
          _replaceDraft(state.draft!);
        } else if (state.status == ReviewStatus.saved &&
            state.savedInvoiceId != null) {
          context.go('/details/${state.savedInvoiceId}');
        } else if (state.status == ReviewStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          title: Text(l10n.reviewTitle),
        ),
        body: Form(
          key: _formKey,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
              children: [
                _ReviewNotice(
                  text: _draft.origin == InvoiceDraftOrigin.manualFallback
                      ? l10n.manualReviewNotice
                      : l10n.reviewSubtitle,
                ),
                const SizedBox(height: 18),
                _EditableField(
                  controller: _merchant,
                  label: l10n.merchant,
                  icon: Icons.storefront_rounded,
                ),
                _EditableField(
                  controller: _documentType,
                  label: l10n.documentType,
                  icon: Icons.description_outlined,
                ),
                _EditableField(
                  controller: _purchaseDate,
                  label: l10n.purchaseDate,
                  icon: Icons.calendar_today_rounded,
                  hint: 'YYYY-MM-DD',
                  validator: (value) => _validateDate(l10n, value),
                ),
                _EditableField(
                  controller: _invoiceNumber,
                  label: l10n.invoiceNumber,
                  icon: Icons.tag_rounded,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _EditableField(
                        controller: _total,
                        label: l10n.total,
                        icon: Icons.payments_outlined,
                        number: true,
                        validator: (value) => _validateMoney(l10n, value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EditableField(
                        controller: _currency,
                        label: l10n.currency,
                        icon: Icons.currency_exchange_rounded,
                        validator: (value) => _validateCurrency(l10n, value),
                      ),
                    ),
                  ],
                ),
                _EditableField(
                  controller: _warrantyMonths,
                  label: l10n.warranty,
                  icon: Icons.verified_outlined,
                  number: true,
                  validator: (value) => _validateWarranty(l10n, value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.products,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _products.add(
                          EditableInvoiceItemControllers.empty(),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.addProduct),
                    ),
                  ],
                ),
                ...List.generate(
                  _products.length,
                  (index) => ReviewProductEditor(
                    index: index,
                    controllers: _products[index],
                    onRemove: () => setState(() {
                      _products.removeAt(index).dispose();
                    }),
                  ),
                ),
                if (_draft.rawText.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(l10n.rawOcrText),
                    children: [
                      SelectableText(
                        _draft.rawText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: l10n.saveInvoice,
                  icon: Icons.check_rounded,
                  onPressed: reviewState.status == ReviewStatus.saving
                      ? null
                      : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateDate(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _parseDate(value) == null ? l10n.invalidValue : null;
  }

  String? _validateMoney(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = parseNullableMinor(value);
    return parsed == null || parsed < 0 ? l10n.invalidValue : null;
  }

  String? _validateCurrency(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^[A-Za-z]{3}$').hasMatch(value.trim())
        ? null
        : l10n.currencyCodeHint;
  }

  String? _validateWarranty(AppLocalizations l10n, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = _parseInteger(value);
    return parsed == null || parsed < 0 ? l10n.invalidValue : null;
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.number = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool number;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softWarning,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_note_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9A681C)),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _parseDate(String value) {
  final normalized = normalizeDigits(value).trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) return null;
  final parsed = DateTime.tryParse('${normalized}T00:00:00Z');
  return parsed?.toUtc();
}

int? _parseInteger(String value) {
  final number = parseNullableNumber(value);
  if (number == null || number != number.roundToDouble()) return null;
  return number.toInt();
}

String _formatMinor(int? minor) {
  if (minor == null) return '';
  final amount = minor / 100;
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
