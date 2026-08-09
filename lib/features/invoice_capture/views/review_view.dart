import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';

class ReviewView extends StatefulWidget {
  const ReviewView({super.key});

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _numberController;
  late final TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: MockData.draft.merchant);
    _numberController = TextEditingController(text: MockData.draft.number);
    _totalController = TextEditingController(text: MockData.draft.total);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _numberController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) context.go('/details');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
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
                      value: MockData.draft.documentType,
                      icon: Icons.description_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReadOnlyField(
                      label: l10n.purchaseDate,
                      value: MockData.draft.date,
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
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
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
                      value: MockData.draft.currency,
                      icon: Icons.currency_exchange_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _ReadOnlyField(
                label: l10n.warranty,
                value: MockData.draft.warranty,
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
              const _ProductRow(
                name: 'Samsung Galaxy A56',
                quantity: '1 × 24,999 ج.م',
              ),
              const SizedBox(height: 8),
              const _ProductRow(name: 'ضمان ممتد', quantity: '12 شهر'),
              const SizedBox(height: 26),
              PrimaryButton(
                label: l10n.saveInvoice,
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ],
          ),
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
              ? [
                  const TextSpan(
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
