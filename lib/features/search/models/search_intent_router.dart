import '../../../core/utils/arabic_query_normalization/arabic_query_normalizer.dart';
import 'search_filters.dart';
import 'search_intent.dart';
import 'search_route_type.dart';

typedef SearchClock = DateTime Function();

class SearchIntentRouter {
  SearchIntentRouter({SearchClock? clock, this.minimumFilterConfidence = 0.85})
    : _clock = clock ?? DateTime.now;

  final SearchClock _clock;
  final double minimumFilterConfidence;

  SearchIntent parse(String rawQuery) {
    final normalized = ArabicQueryNormalizer.normalize(rawQuery);
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        rawQuery,
        'rawQuery',
        'Query must not be empty.',
      );
    }

    final issues = <SearchParseIssue>[];
    final inferences = <SearchFilterInference>[];
    final removedSpans = <_Span>[];

    SearchAmountRange? amount;
    SearchDateRange? purchaseDate;
    SearchDateRange? warrantyEndDate;
    String? currencyCode;
    SearchDocumentType? documentType;

    final amountParse = _parseAmount(normalized);
    if (amountParse.issue != null) {
      issues.add(amountParse.issue!);
    } else if (amountParse.value != null) {
      if (_accept(amountParse.confidence, issues)) {
        amount = amountParse.value;
        removedSpans.addAll(amountParse.spans);
        inferences.add(
          SearchFilterInference(
            field: SearchFilterField.amount,
            confidence: amountParse.confidence,
            evidence: amountParse.evidence,
          ),
        );
      }
    }

    // An approximate or negated amount phrase is intentionally left entirely
    // to semantic search, including its adjacent currency wording.
    if (amountParse.issue != SearchParseIssue.ambiguousAmount) {
      final currencyParse = _parseCurrency(normalized);
      if (currencyParse.issue != null) {
        issues.add(currencyParse.issue!);
      } else if (currencyParse.value != null &&
          _accept(currencyParse.confidence, issues)) {
        currencyCode = currencyParse.value;
        removedSpans.addAll(currencyParse.spans);
        inferences.add(
          SearchFilterInference(
            field: SearchFilterField.currency,
            confidence: currencyParse.confidence,
            evidence: currencyParse.evidence,
          ),
        );
      }
    }

    final temporalParse = _parseTemporal(normalized, _clock());
    if (temporalParse.issue != null) {
      issues.add(temporalParse.issue!);
    } else if (temporalParse.value != null &&
        _accept(temporalParse.confidence, issues)) {
      removedSpans.addAll(temporalParse.spans);
      if (temporalParse.isWarranty) {
        warrantyEndDate = temporalParse.value;
        inferences.add(
          SearchFilterInference(
            field: SearchFilterField.warrantyEndDate,
            confidence: temporalParse.confidence,
            evidence: temporalParse.evidence,
          ),
        );
      } else {
        purchaseDate = temporalParse.value;
        inferences.add(
          SearchFilterInference(
            field: SearchFilterField.purchaseDate,
            confidence: temporalParse.confidence,
            evidence: temporalParse.evidence,
          ),
        );
      }
    }

    final documentParse = _parseDocumentType(normalized);
    if (documentParse.issue != null) {
      issues.add(documentParse.issue!);
    } else if (documentParse.value != null &&
        _accept(documentParse.confidence, issues)) {
      documentType = documentParse.value;
      removedSpans.addAll(documentParse.spans);
      inferences.add(
        SearchFilterInference(
          field: SearchFilterField.documentType,
          confidence: documentParse.confidence,
          evidence: documentParse.evidence,
        ),
      );
    }

    final filters = SearchFilters(
      amount: amount,
      purchaseDate: purchaseDate,
      warrantyEndDate: warrantyEndDate,
      currencyCode: currencyCode,
      documentType: documentType,
    );
    final contentQuery = _contentQuery(_removeSpans(normalized, removedSpans));
    final semanticContent = _isSemantic(
      rawQuery: rawQuery,
      normalizedQuery: normalized,
      contentQuery: contentQuery,
      issues: issues,
    );
    final route = filters.isNotEmpty
        ? (semanticContent
              ? SearchRouteType.hybrid
              : SearchRouteType.structured)
        : (semanticContent
              ? SearchRouteType.semantic
              : SearchRouteType.keyword);
    final filterConfidence = inferences.isEmpty
        ? 1.0
        : inferences
              .map((inference) => inference.confidence)
              .reduce((left, right) => left < right ? left : right);
    final confidence = switch (route) {
      SearchRouteType.keyword =>
        _looksLikeIdentifier(contentQuery) ? 0.98 : 0.9,
      SearchRouteType.structured => filterConfidence,
      SearchRouteType.semantic => 0.82,
      SearchRouteType.hybrid =>
        filterConfidence < 0.86 ? filterConfidence : 0.86,
    };

    return SearchIntent(
      rawQuery: rawQuery,
      normalizedQuery: normalized,
      contentQuery: contentQuery,
      route: route,
      filters: filters,
      confidence: confidence,
      inferences: inferences,
      issues: issues,
    );
  }

  bool _accept(double confidence, List<SearchParseIssue> issues) {
    if (confidence >= minimumFilterConfidence) return true;
    if (!issues.contains(SearchParseIssue.lowConfidenceFilter)) {
      issues.add(SearchParseIssue.lowConfidenceFilter);
    }
    return false;
  }
}

const String _amountNumber = r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';

_FilterParse<SearchAmountRange> _parseAmount(String query) {
  final hasNumber = RegExp(r'[0-9]').hasMatch(query);
  final ambiguous = RegExp(
    r'(?:حوالي|تقريبا|نحو|بين|\babout\b|\baround\b|approximately|\bbetween\b|'
    r'مش\s+(?:فوق|تحت|اكثر|اكتر|اقل)|\bnot\s+(?:over|under|above|below|more|less))',
  ).hasMatch(query);
  if (hasNumber && ambiguous) {
    return const _FilterParse(issue: SearchParseIssue.ambiguousAmount);
  }

  final patterns = <_AmountPattern>[
    _AmountPattern(
      RegExp(
        '${r'(?:^|\s)(?:>=|علي\s+الاقل|بحد\s+ادني|at\s+least)\s*'}'
        '$_amountNumber',
      ),
      _AmountBound.minimumInclusive,
    ),
    _AmountPattern(
      RegExp(
        '${r'(?:^|\s)(?:<=|لحد|بحد\s+اقصي|at\s+most)\s*'}'
        '$_amountNumber',
      ),
      _AmountBound.maximumInclusive,
    ),
    _AmountPattern(
      RegExp(
        '${r'(?:^|\s)(?:>|فوق|اكثر\s+من|اكتر\s+من|اعلي\s+من|اغلي\s+من|'}'
        '${r'over|above|more\s+than|greater\s+than)\s*'}'
        '$_amountNumber',
      ),
      _AmountBound.minimumExclusive,
    ),
    _AmountPattern(
      RegExp(
        '${r'(?:^|\s)(?:<|تحت|اقل\s+من|ارخص\s+من|under|below|less\s+than)\s*'}'
        '$_amountNumber',
      ),
      _AmountBound.maximumExclusive,
    ),
    _AmountPattern(
      RegExp(
        '${r'(?:^|\s)(?:=|بالضبط|يساوي|بقيمة|exactly|equal\s+to)\s*'}'
        '$_amountNumber',
      ),
      _AmountBound.exact,
    ),
  ];

  final matches = <(_AmountPattern, RegExpMatch)>[];
  for (final pattern in patterns) {
    for (final match in pattern.expression.allMatches(query)) {
      matches.add((pattern, match));
    }
  }
  if (matches.isEmpty) return const _FilterParse();
  if (matches.length > 1) {
    return const _FilterParse(issue: SearchParseIssue.conflictingAmountBounds);
  }
  final pattern = matches.single.$1;
  final match = matches.single.$2;
  final minor = _parseMinor(match.group(1)!);
  if (minor == null) {
    return const _FilterParse(issue: SearchParseIssue.ambiguousAmount);
  }
  final range = switch (pattern.bound) {
    _AmountBound.minimumInclusive => SearchAmountRange(minimumMinor: minor),
    _AmountBound.minimumExclusive => SearchAmountRange(
      minimumMinor: minor,
      minimumInclusive: false,
    ),
    _AmountBound.maximumInclusive => SearchAmountRange(maximumMinor: minor),
    _AmountBound.maximumExclusive => SearchAmountRange(
      maximumMinor: minor,
      maximumInclusive: false,
    ),
    _AmountBound.exact => SearchAmountRange(
      minimumMinor: minor,
      maximumMinor: minor,
    ),
  };
  return _FilterParse(
    value: range,
    confidence: 0.98,
    evidence: match.group(0)!.trim(),
    spans: [_Span(match.start, match.end)],
  );
}

int? _parseMinor(String value) {
  final normalized = value.replaceAll(',', '');
  final parts = normalized.split('.');
  if (parts.length > 2 || parts.first.isEmpty) return null;
  final major = int.tryParse(parts.first);
  if (major == null) return null;
  final fractionText = parts.length == 1 ? '' : parts[1];
  if (fractionText.length > 2) return null;
  final fraction = fractionText.isEmpty
      ? 0
      : int.tryParse(fractionText.padRight(2, '0'));
  if (fraction == null) return null;
  return major * 100 + fraction;
}

_FilterParse<String> _parseCurrency(String query) {
  final candidates = <_ValuePattern<String>>[
    _ValuePattern('GBP', RegExp(r'(?:\bgbp\b|جنيه\s+استرليني|£)')),
    _ValuePattern(
      'EGP',
      RegExp(r'(?:\begp\b|جنيه(?:ات)?(?:\s+مصري(?:ه)?)?|ج\s*\.?\s*م)'),
    ),
    _ValuePattern('USD', RegExp(r'(?:\busd\b|دولار(?:\s+امريكي)?|\$)')),
    _ValuePattern('EUR', RegExp(r'(?:\beur\b|يورو|€)')),
    _ValuePattern('SAR', RegExp(r'(?:\bsar\b|ريال\s+سعودي|ر\s*\.?\s*س)')),
    _ValuePattern('AED', RegExp(r'(?:\baed\b|درهم\s+اماراتي)')),
  ];
  return _singleValueParse(
    query,
    candidates,
    ambiguity: SearchParseIssue.ambiguousCurrency,
    confidence: 0.97,
  );
}

_FilterParse<SearchDocumentType> _parseDocumentType(String query) {
  return _singleValueParse(
    query,
    [
      _ValuePattern(
        SearchDocumentType.warrantyCertificate,
        RegExp(r'(?:شهاد[ةه]\s+ضمان|warranty\s+certificate)'),
      ),
      _ValuePattern(
        SearchDocumentType.creditNote,
        RegExp(r'(?:اشعار\s+داين|credit\s+note)'),
      ),
      _ValuePattern(
        SearchDocumentType.purchaseInvoice,
        RegExp(r'(?:فاتور[ةه]\s+شراء|purchase\s+invoice)'),
      ),
      _ValuePattern(SearchDocumentType.receipt, RegExp(r'(?:ايصال|receipt)')),
    ],
    ambiguity: SearchParseIssue.ambiguousDocumentType,
    confidence: 0.96,
  );
}

_FilterParse<T> _singleValueParse<T>(
  String query,
  List<_ValuePattern<T>> patterns, {
  required SearchParseIssue ambiguity,
  required double confidence,
}) {
  final accepted = <(T, RegExpMatch)>[];
  for (final candidate in patterns) {
    for (final match in candidate.expression.allMatches(query)) {
      final overlaps = accepted.any(
        (entry) => match.start < entry.$2.end && match.end > entry.$2.start,
      );
      if (!overlaps) accepted.add((candidate.value, match));
    }
  }
  if (accepted.isEmpty) return const _FilterParse();
  final values = accepted.map((entry) => entry.$1).toSet();
  if (values.length > 1) return _FilterParse(issue: ambiguity);
  return _FilterParse(
    value: accepted.first.$1,
    confidence: confidence,
    evidence: accepted.map((entry) => entry.$2.group(0)!).join(' '),
    spans: accepted
        .map((entry) => _Span(entry.$2.start, entry.$2.end))
        .toList(growable: false),
  );
}

_TemporalParse _parseTemporal(String query, DateTime reference) {
  if (RegExp(
    r'(?:\bbetween\b|بين)\s+\S+\s+(?:and|و)\s+\S+|'
    r'(?:\bfrom\b|من)\s+\S+\s+(?:to|الي|حتي)\s+\S+',
  ).hasMatch(query)) {
    return const _TemporalParse(issue: SearchParseIssue.ambiguousDate);
  }

  final temporal = _matchTemporalRange(query, reference);
  if (temporal == null) return const _TemporalParse();
  final warrantyMatches = RegExp(
    r'(?:ضمان(?:ها|ه)?|الضمان|warranty)',
  ).allMatches(query).toList();
  final expiryMatches = RegExp(
    r'(?:هيخلص|هتخلص|هينتهي|هتنتهي|ينتهي|تنتهي|انتهاء|نهاي[ةه]|expires?|expiring|ends?|ending)',
  ).allMatches(query).toList();
  if (warrantyMatches.isNotEmpty && expiryMatches.isEmpty) {
    return const _TemporalParse(issue: SearchParseIssue.ambiguousWarrantyDate);
  }
  final spans = <_Span>[temporal.span];
  final isWarranty = warrantyMatches.isNotEmpty && expiryMatches.isNotEmpty;
  if (isWarranty) {
    spans.addAll(
      [
        ...warrantyMatches,
        ...expiryMatches,
      ].map((match) => _Span(match.start, match.end)),
    );
  }
  return _TemporalParse(
    value: temporal.range,
    confidence: temporal.confidence,
    evidence: temporal.evidence,
    spans: spans,
    isWarranty: isWarranty,
  );
}

_TemporalMatch? _matchTemporalRange(String query, DateTime reference) {
  _TemporalMatch monthRange(
    RegExpMatch match,
    int year,
    int month,
    double score,
  ) {
    return _TemporalMatch(
      SearchDateRange(
        startInclusive: DateTime.utc(year, month),
        endExclusive: DateTime.utc(year, month + 1),
      ),
      _Span(match.start, match.end),
      match.group(0)!.trim(),
      score,
    );
  }

  var match = RegExp(
    r'(?:الشهر\s+(?:ده|دا|الحالي)|this\s+month)',
  ).firstMatch(query);
  if (match != null) {
    return monthRange(match, reference.year, reference.month, 0.98);
  }

  match = RegExp(
    r'(?:الشهر\s+اللي\s+فات|الشهر\s+الماضي|last\s+month)',
  ).firstMatch(query);
  if (match != null) {
    final previous = DateTime.utc(reference.year, reference.month - 1);
    return monthRange(match, previous.year, previous.month, 0.97);
  }

  match = RegExp(
    r'(?:السن[ةه]\s+(?:دي|الحالي[ةه])|هذا\s+العام|this\s+year)',
  ).firstMatch(query);
  if (match != null) return _yearRange(match, reference.year, 0.97);

  match = RegExp(
    r'(?:السن[ةه]\s+اللي\s+فاتت|السن[ةه]\s+الماضي[ةه]|last\s+year)',
  ).firstMatch(query);
  if (match != null) return _yearRange(match, reference.year - 1, 0.97);

  match = RegExp(
    r'(?:^|\s)(20[0-9]{2})-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])(?:\s|$)',
  ).firstMatch(query);
  if (match != null) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final start = DateTime.utc(year, month, day);
    if (start.year == year && start.month == month && start.day == day) {
      return _TemporalMatch(
        SearchDateRange(
          startInclusive: start,
          endExclusive: start.add(const Duration(days: 1)),
        ),
        _Span(match.start, match.end),
        match.group(0)!.trim(),
        0.99,
      );
    }
  }

  final monthNames = _monthNames.keys.map(RegExp.escape).join('|');
  match = RegExp(
    '(?:^|\\s)(?:في\\s+|in\\s+)?($monthNames)(?:\\s+(20[0-9]{2}))?(?:\\s|\$)',
  ).firstMatch(query);
  if (match != null) {
    final month = _monthNames[match.group(1)!]!;
    final explicitYear = match.group(2);
    return monthRange(
      match,
      explicitYear == null ? reference.year : int.parse(explicitYear),
      month,
      explicitYear == null ? 0.88 : 0.96,
    );
  }

  match = RegExp(
    r'(?:^|\s)(?:سن[ةه]|السن[ةه]|عام|year|in|في)\s+(20[0-9]{2})(?:\s|$)',
  ).firstMatch(query);
  if (match != null) return _yearRange(match, int.parse(match.group(1)!), 0.95);
  return null;
}

_TemporalMatch _yearRange(RegExpMatch match, int year, double confidence) {
  return _TemporalMatch(
    SearchDateRange(
      startInclusive: DateTime.utc(year),
      endExclusive: DateTime.utc(year + 1),
    ),
    _Span(match.start, match.end),
    match.group(0)!.trim(),
    confidence,
  );
}

const Map<String, int> _monthNames = {
  'يناير': 1,
  'january': 1,
  'jan': 1,
  'فبراير': 2,
  'february': 2,
  'feb': 2,
  'مارس': 3,
  'march': 3,
  'mar': 3,
  'ابريل': 4,
  'april': 4,
  'apr': 4,
  'مايو': 5,
  'may': 5,
  'يونيو': 6,
  'june': 6,
  'jun': 6,
  'يوليو': 7,
  'july': 7,
  'jul': 7,
  'اغسطس': 8,
  'august': 8,
  'aug': 8,
  'سبتمبر': 9,
  'september': 9,
  'sep': 9,
  'اكتوبر': 10,
  'october': 10,
  'oct': 10,
  'نوفمبر': 11,
  'november': 11,
  'nov': 11,
  'ديسمبر': 12,
  'december': 12,
  'dec': 12,
};

String _removeSpans(String query, List<_Span> spans) {
  if (spans.isEmpty) return query;
  final ordered = [...spans]
    ..sort((left, right) => left.start.compareTo(right.start));
  final buffer = StringBuffer();
  var cursor = 0;
  for (final span in ordered) {
    if (span.end <= cursor) continue;
    final start = span.start < cursor ? cursor : span.start;
    if (start > cursor) buffer.write(query.substring(cursor, start));
    buffer.write(' ');
    cursor = span.end;
  }
  if (cursor < query.length) buffer.write(query.substring(cursor));
  return ArabicQueryNormalizer.normalize(buffer.toString());
}

String _contentQuery(String query) {
  const generic = {
    'فاتورة',
    'الفاتورة',
    'فاتوره',
    'الفاتوره',
    'فواتير',
    'الفواتير',
    'ايصال',
    'الايصال',
    'invoice',
    'invoices',
    'receipt',
    'receipts',
    'bill',
    'bills',
    'اللي',
    'التي',
    'that',
    'which',
    'ابحث',
    'دور',
    'search',
    'find',
  };
  return query
      .split(' ')
      .where((token) => token.isNotEmpty && !generic.contains(token))
      .join(' ')
      .trim();
}

bool _isSemantic({
  required String rawQuery,
  required String normalizedQuery,
  required String contentQuery,
  required List<SearchParseIssue> issues,
}) {
  if (issues.isNotEmpty) return true;
  if (RegExp(r'''["“”«»].+?["“”«»]''').hasMatch(rawQuery)) return false;
  if (RegExp(
    r'(?:بتاع[ةه]|بتاع|اشتريته|اشتريتها|من\s+فتر[ةه]|فاكر|عايز|فين|'
    r'looking\s+for|i\s+bought|we\s+bought|a\s+while\s+ago|remember)',
  ).hasMatch(normalizedQuery)) {
    return true;
  }
  if (_looksLikeIdentifier(contentQuery)) return false;
  if (contentQuery.isEmpty) return false;
  return contentQuery.split(' ').length >= 5;
}

bool _looksLikeIdentifier(String query) {
  if (query.isEmpty) return false;
  for (final token in query.split(' ')) {
    if (RegExp(r'[a-z]').hasMatch(token) && RegExp(r'[0-9]').hasMatch(token)) {
      return true;
    }
  }
  return RegExp(r'^[a-z]{1,8}-?[0-9][a-z0-9/-]*$').hasMatch(query);
}

enum _AmountBound {
  minimumInclusive,
  minimumExclusive,
  maximumInclusive,
  maximumExclusive,
  exact,
}

class _AmountPattern {
  const _AmountPattern(this.expression, this.bound);

  final RegExp expression;
  final _AmountBound bound;
}

class _ValuePattern<T> {
  const _ValuePattern(this.value, this.expression);

  final T value;
  final RegExp expression;
}

class _Span {
  const _Span(this.start, this.end);

  final int start;
  final int end;
}

class _FilterParse<T> {
  const _FilterParse({
    this.value,
    this.confidence = 0,
    this.evidence = '',
    this.spans = const [],
    this.issue,
  });

  final T? value;
  final double confidence;
  final String evidence;
  final List<_Span> spans;
  final SearchParseIssue? issue;
}

class _TemporalParse extends _FilterParse<SearchDateRange> {
  const _TemporalParse({
    super.value,
    super.confidence,
    super.evidence,
    super.spans,
    super.issue,
    this.isWarranty = false,
  });

  final bool isWarranty;
}

class _TemporalMatch {
  const _TemporalMatch(this.range, this.span, this.evidence, this.confidence);

  final SearchDateRange range;
  final _Span span;
  final String evidence;
  final double confidence;
}
