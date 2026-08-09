import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../models/invoice_draft.dart';
import '../view_models/review_cubit.dart';

class ReviewView extends StatefulWidget {
  const ReviewView({this.invoiceId, super.key});

  final int? invoiceId;

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _numberController;
  late final TextEditingController _totalController;
  late InvoiceDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<ReviewCubit>().state.draft ?? MockData.draft;
    _merchantController = TextEditingController(text: _draft.merchant);
    _numberController = TextEditingController(text: _draft.invoiceNumber);
    _totalController = TextEditingController(
      text: _formatMinor(_draft.totalMinor),
    );
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _numberController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(
      _totalController.text.replaceAll(',', '').trim(),
    );
    await context.read<ReviewCubit>().save(
      InvoiceDraft(
        invoiceId: _draft.invoiceId,
        merchant: _merchantController.text.trim(),
        documentType: _draft.documentType,
        purchaseDate: _draft.purchaseDate,
        totalMinor: amount == null ? null : (amount * 100).round(),
        currencyCode: _draft.currencyCode,
        warrantyMonths: _draft.warrantyMonths,
        invoiceNumber: _numberController.text.trim(),
        rawExtractedText: _draft.rawExtractedText,
        imagePath: _draft.imagePath,
        thumbnailPath: _draft.thumbnailPath,
        sourceType: _draft.sourceType,
        extractionModelId: _draft.extractionModelId,
        items: _draft.items,
      ),
    );
  }

  void _replaceDraft(InvoiceDraft draft) {
    setState(() => _draft = draft);
    _merchantController.text = draft.merchant ?? '';
    _numberController.text = draft.invoiceNumber ?? '';
    _totalController.text = _formatMinor(draft.totalMinor);
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
                _ReviewNotice(text: l10n.reviewSubtitle),
                const SizedBox(height: 18),
                _FieldLabel(label: l10n.merchant, required: true),
                TextFormField(
                  controller: _merchantController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.fieldRequired
                      : null,
                  decoration: InputDecoration(
                    hintText: l10n.merchant,
                    prefixIcon: const Icon(Icons.storefront_rounded),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _ReadOnlyField(
                        label: l10n.documentType,
                        value: _draft.documentType ?? '—',
                        icon: Icons.description_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReadOnlyField(
                        label: l10n.purchaseDate,
                        value: _formatDate(_draft.purchaseDate),
                        icon: Icons.calendar_today_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _FieldLabel(label: l10n.invoiceNumber),
                TextFormField(
                  controller: _numberController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.tag_rounded),
                    hintText: l10n.invoiceNumber,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(label: l10n.total, required: true),
                          TextFormField(
                            controller: _totalController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) =>
                                value == null ||
                                    value.trim().isEmpty ||
                                    double.tryParse(
                                          value.replaceAll(',', '').trim(),
                                        ) ==
                                        null
                                ? l10n.fieldRequired
                                : null,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.payments_outlined),
                              hintText: l10n.total,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReadOnlyField(
                        label: l10n.currency,
                        value: _draft.currencyCode ?? '—',
                        icon: Icons.currency_exchange_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _ReadOnlyField(
                  label: l10n.warranty,
                  value: _draft.warrantyMonths?.toString() ?? '—',
                  icon: Icons.verified_outlined,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.products,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.addProduct),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ..._draft.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ProductRow(
                      name: item.name,
                      quantity: item.quantity?.toString() ?? '—',
                    ),
                  ),
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
}

String _formatMinor(int? minor) {
  if (minor == null) return '';
  final amount = minor / 100;
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          text: label,
          style: Theme.of(context).textTheme.labelLarge,
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        InputDecorator(
          decoration: InputDecoration(prefixIcon: Icon(icon)),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.name, required this.quantity});

  final String name;
  final String quantity;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 3),
                  Text(quantity, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.drag_handle_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
