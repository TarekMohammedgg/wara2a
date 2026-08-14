import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../invoice_details/models/invoice.dart';
import '../models/search_filters.dart';
import '../models/search_result.dart';
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
        final showResults =
            state.hasQuery &&
            state.status != SearchStatus.failure &&
            state.status != SearchStatus.empty &&
            state.results.isNotEmpty;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(l10n.search, style: textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    onSubmitted: context.read<SearchCubit>().submit,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      isDense: true,
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
                  if (state.hasQuery) ...[
                    const SizedBox(height: 14),
                    _ResultsHeader(state: state),
                    const SizedBox(height: 8),
                    _FiltersBar(
                      filters: state.filters,
                      onEdit: () => _editFilters(state.filters),
                      onRemove: context.read<SearchCubit>().removeFilter,
                    ),
                    if (state.status == SearchStatus.loading &&
                        state.results.isEmpty) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    const SizedBox(height: 12),
                    if (state.status == SearchStatus.failure)
                      _SearchEmptyState(
                        title: l10n.searchError,
                        body: state.errorMessage ?? l10n.noResultsBody,
                      )
                    else if (state.status == SearchStatus.empty)
                      _SearchEmptyState(
                        title: l10n.noResults,
                        body: l10n.noResultsBody,
                      ),
                  ],
                ]),
              ),
            ),
            if (showResults)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.separated(
                  itemCount: state.results.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                  itemBuilder: (context, index) =>
                      _SearchResultTile(result: state.results[index]),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
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
          label: Text(l10n.filter),
          onPressed: onEdit,
          visualDensity: VisualDensity.compact,
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

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result});

  final SearchResult<Invoice> result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final invoice = result.value;
    final date = invoice.purchaseDate ?? invoice.reviewedAt;

    return InkWell(
      onTap: () => context.push('/details/${result.invoiceId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _visible(invoice.merchant),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(date),
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatMinor(invoice.totalMinor, invoice.currencyCode),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

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
