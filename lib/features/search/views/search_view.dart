import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/invoice_card.dart';
import '../../../core/widgets/invoice_card_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../invoice_details/models/invoice.dart';
import '../models/search_filters.dart';
import '../models/search_result.dart';
import '../repositories/search_repository.dart';
import '../view_models/search_cubit.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_refreshTextState);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refreshTextState)
      ..dispose();
    super.dispose();
  }

  void _refreshTextState() {
    if (mounted) setState(() {});
  }

  void _setQuery(String query) {
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    context.read<SearchCubit>().submit(query);
  }

  Future<void> _editFilters(SearchFilters filters) async {
    final edited = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SearchFiltersSheet(initial: filters),
    );
    if (edited != null && mounted) {
      await context.read<SearchCubit>().applyFilters(edited);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          children: [
            Text(l10n.search, style: textTheme.headlineSmall),
            const SizedBox(height: 7),
            Text(l10n.searchModelNote, style: textTheme.bodyMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              onSubmitted: context.read<SearchCubit>().submit,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          context.read<SearchCubit>().clear();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 22),
            if (!state.hasQuery)
              _Suggestions(onSelected: _setQuery)
            else ...[
              _ResultsHeader(state: state),
              const SizedBox(height: 10),
              _FiltersBar(
                filters: state.filters,
                onEdit: () => _editFilters(state.filters),
                onRemove: context.read<SearchCubit>().removeFilter,
              ),
              if (state.status == SearchStatus.loading) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
              if (state.semanticGate != SemanticSearchGate.none) ...[
                const SizedBox(height: 14),
                _SemanticGateBanner(state: state),
              ],
              if (state.pendingEmbeddingCount > 0) ...[
                const SizedBox(height: 10),
                _InfoBanner(
                  icon: Icons.pending_actions_rounded,
                  text: l10n.searchIndexPending(state.pendingEmbeddingCount),
                ),
              ],
              const SizedBox(height: 18),
              if (state.status == SearchStatus.failure)
                _SearchEmptyState(
                  title: l10n.searchError,
                  body: state.errorMessage ?? l10n.noResultsBody,
                )
              else if (state.status == SearchStatus.empty)
                _SearchEmptyState(
                  title: l10n.noResults,
                  body: l10n.noResultsBody,
                )
              else
                ...state.results.map(
                  (result) => _SearchResultTile(result: result),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.searchSuggestions,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 9,
          children: [
            for (final query in [
              l10n.recentQueryMerchant,
              l10n.recentQueryAmount,
              l10n.recentQueryCategory,
            ])
              ActionChip(
                onPressed: () => onSelected(query),
                avatar: const Icon(Icons.search_rounded, size: 17),
                label: Text(query),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
              ),
          ],
        ),
        const SizedBox(height: 30),
        _SearchEmptyState(title: l10n.noResults, body: l10n.noResultsBody),
      ],
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.searchResults,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          l10n.searchMatches(state.results.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.filters,
    required this.onEdit,
    required this.onRemove,
  });

  final SearchFilters filters;
  final VoidCallback onEdit;
  final ValueChanged<SearchFilterField> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          avatar: const Icon(Icons.tune_rounded, size: 17),
          label: Text(l10n.filter),
          onPressed: onEdit,
        ),
        if (filters.amount != null)
          _RemovableFilterChip(
            label: _amountFilterLabel(filters.amount!, filters.currencyCode),
            onRemoved: () => onRemove(SearchFilterField.amount),
          ),
        if (filters.purchaseDate != null)
          _RemovableFilterChip(
            label:
                '${l10n.purchaseDate}: ${_dateRangeLabel(filters.purchaseDate!)}',
            onRemoved: () => onRemove(SearchFilterField.purchaseDate),
          ),
        if (filters.warrantyEndDate != null)
          _RemovableFilterChip(
            label:
                '${l10n.warranty}: ${_dateRangeLabel(filters.warrantyEndDate!)}',
            onRemoved: () => onRemove(SearchFilterField.warrantyEndDate),
          ),
        if (filters.currencyCode != null)
          _RemovableFilterChip(
            label: filters.currencyCode!,
            onRemoved: () => onRemove(SearchFilterField.currency),
          ),
        if (filters.documentType != null)
          _RemovableFilterChip(
            label: _documentTypeLabel(l10n, filters.documentType!),
            onRemoved: () => onRemove(SearchFilterField.documentType),
          ),
      ],
    );
  }
}

class _RemovableFilterChip extends StatelessWidget {
  const _RemovableFilterChip({required this.label, required this.onRemoved});

  final String label;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemoved,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
    );
  }
}

class _SemanticGateBanner extends StatelessWidget {
  const _SemanticGateBanner({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = switch (state.semanticGate) {
      SemanticSearchGate.calibrationRequired =>
        l10n.semanticCalibrationRequired,
      SemanticSearchGate.modelUnavailable => l10n.semanticModelUnavailable,
      SemanticSearchGate.queryTooLong => l10n.semanticQueryTooLong,
      SemanticSearchGate.runtimeFailure => l10n.semanticRuntimeFailure,
      SemanticSearchGate.none => '',
    };
    return _InfoBanner(
      icon: Icons.info_outline_rounded,
      text: state.usedKeywordFallback ? '$text ${l10n.keywordFallback}' : text,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result});

  final SearchResult<Invoice> result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (result.matchKind) {
      SearchMatchKind.exact => l10n.exactMatch,
      SearchMatchKind.filtered => l10n.filteredMatch,
      SearchMatchKind.semantic || SearchMatchKind.hybrid => l10n.semanticMatch,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 7),
            child: Row(
              children: [
                Icon(
                  result.distance == null
                      ? Icons.check_circle_outline_rounded
                      : Icons.auto_awesome_rounded,
                  size: 14,
                  color: AppColors.blue,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          InvoiceCard(
            invoice: _InvoiceSearchCardData(result.value),
            onTap: () => context.push('/details/${result.invoiceId}'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceSearchCardData implements InvoiceCardData {
  _InvoiceSearchCardData(this.invoice);

  final Invoice invoice;

  @override
  String get merchant => _visible(invoice.merchant);

  @override
  String get category => _visible(invoice.documentType);

  @override
  String get date => _formatDate(invoice.purchaseDate ?? invoice.reviewedAt);

  @override
  String get total => _formatMinor(invoice.totalMinor, invoice.currencyCode);

  @override
  String get currency => invoice.currencyCode ?? '';

  @override
  int get accent => 0xFF246BFD;

  @override
  int get icon => 0xFFEAF1FF;
}

class _SearchFiltersSheet extends StatefulWidget {
  const _SearchFiltersSheet({required this.initial});

  final SearchFilters initial;

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late bool _minimumInclusive;
  late bool _maximumInclusive;
  String? _currency;
  SearchDocumentType? _documentType;
  SearchDateRange? _purchaseDate;
  SearchDateRange? _warrantyEndDate;

  @override
  void initState() {
    super.initState();
    _minimum = TextEditingController(
      text: _majorText(widget.initial.amount?.minimumMinor),
    );
    _maximum = TextEditingController(
      text: _majorText(widget.initial.amount?.maximumMinor),
    );
    _minimumInclusive = widget.initial.amount?.minimumInclusive ?? true;
    _maximumInclusive = widget.initial.amount?.maximumInclusive ?? true;
    _currency = widget.initial.currencyCode;
    _documentType = widget.initial.documentType;
    _purchaseDate = widget.initial.purchaseDate;
    _warrantyEndDate = widget.initial.warrantyEndDate;
  }

  @override
  void dispose() {
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  Future<void> _pickRange({required bool warranty}) async {
    final current = warranty ? _warrantyEndDate : _purchaseDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: current == null
          ? null
          : DateTimeRange(
              start: current.startInclusive.toLocal(),
              end: current.endExclusive
                  .subtract(const Duration(days: 1))
                  .toLocal(),
            ),
    );
    if (picked == null || !mounted) return;
    final range = SearchDateRange(
      startInclusive: DateTime.utc(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      ),
      endExclusive: DateTime.utc(
        picked.end.year,
        picked.end.month,
        picked.end.day + 1,
      ),
    );
    setState(() {
      if (warranty) {
        _warrantyEndDate = range;
      } else {
        _purchaseDate = range;
      }
    });
  }

  void _apply() {
    final minimum = _minorValue(_minimum.text);
    final maximum = _minorValue(_maximum.text);
    final emptyRange =
        minimum != null &&
        maximum != null &&
        (minimum > maximum ||
            (minimum == maximum && (!_minimumInclusive || !_maximumInclusive)));
    if (emptyRange) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).invalidAmountRange),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      SearchFilters(
        amount: minimum == null && maximum == null
            ? null
            : SearchAmountRange(
                minimumMinor: minimum,
                minimumInclusive: _minimumInclusive,
                maximumMinor: maximum,
                maximumInclusive: _maximumInclusive,
              ),
        purchaseDate: _purchaseDate,
        warrantyEndDate: _warrantyEndDate,
        currencyCode: _currency,
        documentType: _documentType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.filter, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AmountBoundField(
                    controller: _minimum,
                    label: l10n.minimumAmount,
                    inclusive: _minimumInclusive,
                    inclusiveSymbol: '≥',
                    exclusiveSymbol: '>',
                    onInclusiveChanged: (value) =>
                        setState(() => _minimumInclusive = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AmountBoundField(
                    controller: _maximum,
                    label: l10n.maximumAmount,
                    inclusive: _maximumInclusive,
                    inclusiveSymbol: '≤',
                    exclusiveSymbol: '<',
                    onInclusiveChanged: (value) =>
                        setState(() => _maximumInclusive = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _currency,
              decoration: InputDecoration(labelText: l10n.currency),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.allCurrencies),
                ),
                for (final code in const [
                  'EGP',
                  'USD',
                  'EUR',
                  'SAR',
                  'AED',
                  'GBP',
                ])
                  DropdownMenuItem<String?>(value: code, child: Text(code)),
              ],
              onChanged: (value) => setState(() => _currency = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SearchDocumentType?>(
              initialValue: _documentType,
              decoration: InputDecoration(labelText: l10n.documentType),
              items: [
                DropdownMenuItem<SearchDocumentType?>(
                  value: null,
                  child: Text(l10n.allDocumentTypes),
                ),
                for (final type in SearchDocumentType.values)
                  DropdownMenuItem<SearchDocumentType?>(
                    value: type,
                    child: Text(_documentTypeLabel(l10n, type)),
                  ),
              ],
              onChanged: (value) => setState(() => _documentType = value),
            ),
            const SizedBox(height: 12),
            _DateRangeField(
              label: l10n.purchaseDateFilter,
              value: _purchaseDate,
              onTap: () => _pickRange(warranty: false),
              onClear: () => setState(() => _purchaseDate = null),
            ),
            const SizedBox(height: 8),
            _DateRangeField(
              label: l10n.warrantyEndDateFilter,
              value: _warrantyEndDate,
              onTap: () => _pickRange(warranty: true),
              onClear: () => setState(() => _warrantyEndDate = null),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const SearchFilters()),
                  child: Text(l10n.clearFilters),
                ),
                const Spacer(),
                FilledButton(onPressed: _apply, child: Text(l10n.applyFilters)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountBoundField extends StatelessWidget {
  const _AmountBoundField({
    required this.controller,
    required this.label,
    required this.inclusive,
    required this.inclusiveSymbol,
    required this.exclusiveSymbol,
    required this.onInclusiveChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool inclusive;
  final String inclusiveSymbol;
  final String exclusiveSymbol;
  final ValueChanged<bool> onInclusiveChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: DropdownButtonHideUnderline(
          child: DropdownButton<bool>(
            value: inclusive,
            padding: const EdgeInsetsDirectional.only(start: 12),
            items: [
              DropdownMenuItem(value: true, child: Text(inclusiveSymbol)),
              DropdownMenuItem(value: false, child: Text(exclusiveSymbol)),
            ],
            onChanged: (value) {
              if (value != null) onInclusiveChanged(value);
            },
          ),
        ),
      ),
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final SearchDateRange? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final end = value?.endExclusive.subtract(const Duration(days: 1));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.date_range_rounded),
      title: Text(label),
      subtitle: Text(
        value == null
            ? AppLocalizations.of(context).selectRange
            : '${_formatDate(value!.startInclusive)} – ${_formatDate(end!)}',
      ),
      trailing: value == null
          ? const Icon(Icons.chevron_right_rounded)
          : IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
      onTap: onTap,
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              color: AppColors.softBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              size: 30,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _documentTypeLabel(AppLocalizations l10n, SearchDocumentType type) =>
    switch (type) {
      SearchDocumentType.purchaseInvoice => l10n.purchaseInvoice,
      SearchDocumentType.receipt => l10n.receipt,
      SearchDocumentType.creditNote => l10n.creditNote,
      SearchDocumentType.warrantyCertificate => l10n.warrantyCertificate,
    };

String _visible(String? value) =>
    value?.trim().isNotEmpty == true ? value!.trim() : '—';

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _formatMinor(int? value, String? currency) {
  if (value == null) return '—';
  final digits =
      const {'BHD': 3, 'JOD': 3, 'KWD': 3, 'OMR': 3, 'JPY': 0}[currency] ?? 2;
  var divisor = 1;
  for (var index = 0; index < digits; index++) {
    divisor *= 10;
  }
  if (digits == 0) return value.toString();
  final sign = value < 0 ? '-' : '';
  final absolute = value.abs();
  return '$sign${absolute ~/ divisor}.'
      '${(absolute % divisor).toString().padLeft(digits, '0')}';
}

String _amountFilterLabel(SearchAmountRange amount, String? currency) {
  final suffix = currency == null ? '' : ' $currency';
  final minimum = amount.minimumMinor;
  final maximum = amount.maximumMinor;
  if (minimum != null && maximum != null && minimum == maximum) {
    return '= ${_formatMinor(minimum, currency)}$suffix';
  }
  final parts = <String>[];
  if (minimum != null) {
    final operator = amount.minimumInclusive ? '≥' : '>';
    parts.add('$operator ${_formatMinor(minimum, currency)}$suffix');
  }
  if (maximum != null) {
    final operator = amount.maximumInclusive ? '≤' : '<';
    parts.add('$operator ${_formatMinor(maximum, currency)}$suffix');
  }
  return parts.join(' · ');
}

String _dateRangeLabel(SearchDateRange range) {
  final inclusiveEnd = range.endExclusive.subtract(const Duration(days: 1));
  return '${_formatDate(range.startInclusive)} – ${_formatDate(inclusiveEnd)}';
}

String _majorText(int? minor) {
  if (minor == null) return '';
  final whole = minor ~/ 100;
  final fraction = minor.abs() % 100;
  return fraction == 0
      ? whole.toString()
      : '$whole.${fraction.toString().padLeft(2, '0')}';
}

int? _minorValue(String source) {
  final value = double.tryParse(source.trim().replaceAll(',', ''));
  if (value == null || !value.isFinite || value < 0) return null;
  return (value * 100).round();
}
