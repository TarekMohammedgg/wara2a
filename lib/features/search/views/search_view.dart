import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/invoice_card.dart';
import '../../../l10n/app_localizations.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late final TextEditingController _controller;
  bool _hasQuery = false;
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    setState(() => _hasQuery = query.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      children: [
        Text(l10n.search, style: textTheme.headlineSmall),
        const SizedBox(height: 7),
        Text(l10n.searchModelNote, style: textTheme.bodyMedium),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          onChanged: (value) =>
              setState(() => _hasQuery = value.trim().isNotEmpty),
          onSubmitted: (value) =>
              setState(() => _hasQuery = value.trim().isNotEmpty),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _hasQuery
                ? IconButton(
                    onPressed: () => _setQuery(''),
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 24),
        if (!_hasQuery) ...[
          Text(l10n.recentSearches, style: textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: [
              _QueryChip(
                label: l10n.recentQueryMerchant,
                onTap: () => _setQuery(l10n.recentQueryMerchant),
              ),
              _QueryChip(
                label: l10n.recentQueryAmount,
                onTap: () => _setQuery(l10n.recentQueryAmount),
              ),
              _QueryChip(
                label: l10n.recentQueryCategory,
                onTap: () => _setQuery(l10n.recentQueryCategory),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _SearchEmptyState(title: l10n.noResults, body: l10n.noResultsBody),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(l10n.searchResults, style: textTheme.titleMedium),
              ),
              Text(
                l10n.searchMatches(MockData.searchResults.length),
                style: textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: l10n.filter,
                  icon: Icons.tune_rounded,
                  selected: _selectedFilter == 0,
                  onTap: () => setState(() => _selectedFilter = 0),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.amount,
                  selected: _selectedFilter == 1,
                  onTap: () => setState(() => _selectedFilter = 1),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.date,
                  selected: _selectedFilter == 2,
                  onTap: () => setState(() => _selectedFilter = 2),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.documentType,
                  selected: _selectedFilter == 3,
                  onTap: () => setState(() => _selectedFilter = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...MockData.searchResults.map(
            (invoice) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 6,
                      bottom: 7,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          l10n.semanticMatch,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InvoiceCard(
                    invoice: invoice,
                    onTap: () => context.push('/details'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QueryChip extends StatelessWidget {
  const _QueryChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(Icons.history_rounded, size: 17),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
      showCheckmark: false,
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
