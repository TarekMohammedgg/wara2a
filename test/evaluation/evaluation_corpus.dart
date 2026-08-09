import 'dart:convert';

const evaluationCorpusVersion = 'wara2a-eval-2026-08-09-v1';

class EvaluationCorpus {
  const EvaluationCorpus({required this.invoices, required this.queries});

  factory EvaluationCorpus.fromJsonLines({
    required String invoicesJsonl,
    required String queriesJsonl,
  }) {
    return EvaluationCorpus(
      invoices: _decodeLines(
        invoicesJsonl,
      ).map(InvoiceEvaluationCase.fromMap).toList(growable: false),
      queries: _decodeLines(
        queriesJsonl,
      ).map(SearchQueryEvaluationCase.fromMap).toList(growable: false),
    );
  }

  final List<InvoiceEvaluationCase> invoices;
  final List<SearchQueryEvaluationCase> queries;
}

class InvoiceEvaluationCase {
  InvoiceEvaluationCase({
    required this.corpusVersion,
    required this.caseId,
    required this.language,
    required this.layout,
    required this.source,
    required this.conditions,
    required this.obscuredFields,
    required this.nullFields,
    required this.expected,
    required this.search,
  });

  factory InvoiceEvaluationCase.fromMap(Map<String, Object?> map) {
    return InvoiceEvaluationCase(
      corpusVersion: _string(map, 'corpusVersion'),
      caseId: _string(map, 'caseId'),
      language: _string(map, 'language'),
      layout: _string(map, 'layout'),
      source: _map(map, 'source'),
      conditions: _map(map, 'conditions'),
      obscuredFields: _strings(map, 'obscuredFields'),
      nullFields: _strings(map, 'nullFields'),
      expected: _map(map, 'expected'),
      search: _map(map, 'search'),
    );
  }

  final String caseId;
  final String corpusVersion;
  final String language;
  final String layout;
  final Map<String, Object?> source;
  final Map<String, Object?> conditions;
  final List<String> obscuredFields;
  final List<String> nullFields;
  final Map<String, Object?> expected;
  final Map<String, Object?> search;

  String get digitScript => source['digitScript']! as String;
  String get glare => conditions['glare']! as String;
  String get contrast => conditions['contrast']! as String;
}

class SearchQueryEvaluationCase {
  SearchQueryEvaluationCase({
    required this.corpusVersion,
    required this.queryId,
    required this.text,
    required this.language,
    required this.expectedRoute,
    required this.expectedInvoiceIds,
    required this.filters,
  });

  factory SearchQueryEvaluationCase.fromMap(Map<String, Object?> map) {
    return SearchQueryEvaluationCase(
      corpusVersion: _string(map, 'corpusVersion'),
      queryId: _string(map, 'queryId'),
      text: _string(map, 'text'),
      language: _string(map, 'language'),
      expectedRoute: _string(map, 'expectedRoute'),
      expectedInvoiceIds: _strings(map, 'expectedInvoiceIds'),
      filters: _map(map, 'filters'),
    );
  }

  final String queryId;
  final String corpusVersion;
  final String text;
  final String language;
  final String expectedRoute;
  final List<String> expectedInvoiceIds;
  final Map<String, Object?> filters;
}

abstract final class EvaluationCorpusValidator {
  static List<String> validate(EvaluationCorpus corpus) {
    final issues = <String>[];
    final invoiceIds = <String>{};
    final queryIds = <String>{};

    if (corpus.invoices.length < 50) {
      issues.add('Expected at least 50 invoice cases.');
    }
    if (corpus.queries.length < 100) {
      issues.add('Expected at least 100 search queries.');
    }

    for (final invoice in corpus.invoices) {
      if (invoice.corpusVersion != evaluationCorpusVersion) {
        issues.add('${invoice.caseId} has an unsupported corpus version.');
      }
      if (!invoiceIds.add(invoice.caseId)) {
        issues.add('Duplicate invoice case ID: ${invoice.caseId}.');
      }
      _validateInvoice(invoice, issues);
    }

    for (final query in corpus.queries) {
      if (query.corpusVersion != evaluationCorpusVersion) {
        issues.add('${query.queryId} has an unsupported corpus version.');
      }
      if (!queryIds.add(query.queryId)) {
        issues.add('Duplicate query ID: ${query.queryId}.');
      }
      if (query.text.trim().isEmpty) {
        issues.add('${query.queryId} has empty text.');
      }
      if (!{'ar', 'mixed'}.contains(query.language)) {
        issues.add('${query.queryId} must be Arabic or mixed-language.');
      }
      if (!{
        'keyword',
        'structured',
        'semantic',
        'hybrid',
      }.contains(query.expectedRoute)) {
        issues.add('${query.queryId} has an unsupported route.');
      }
      if (query.expectedInvoiceIds.isEmpty) {
        issues.add('${query.queryId} has no expected invoice reference.');
      }
      for (final invoiceId in query.expectedInvoiceIds) {
        if (!invoiceIds.contains(invoiceId)) {
          issues.add('${query.queryId} references unknown invoice $invoiceId.');
        }
      }
      if (query.expectedRoute == 'structured' && query.filters.isEmpty) {
        issues.add('${query.queryId} structured route has no filters.');
      }
      if (query.expectedRoute == 'hybrid' && query.filters.isEmpty) {
        issues.add('${query.queryId} hybrid route has no filters.');
      }
      if ((query.expectedRoute == 'keyword' ||
              query.expectedRoute == 'semantic') &&
          query.filters.isNotEmpty) {
        issues.add(
          '${query.queryId} ${query.expectedRoute} route has filters.',
        );
      }
    }

    _requireCoverage(
      'invoice language',
      corpus.invoices.map((invoice) => invoice.language).toSet(),
      {'ar', 'en', 'mixed'},
      issues,
    );
    _requireCoverage(
      'invoice layout',
      corpus.invoices.map((invoice) => invoice.layout).toSet(),
      {'thermal', 'a4'},
      issues,
    );
    _requireCoverage(
      'digit script',
      corpus.invoices.map((invoice) => invoice.digitScript).toSet(),
      {'latin', 'arabic-indic', 'persian'},
      issues,
    );
    _requireCoverage(
      'glare condition',
      corpus.invoices.map((invoice) => invoice.glare).toSet(),
      {'none', 'mild', 'strong'},
      issues,
    );
    _requireCoverage(
      'contrast condition',
      corpus.invoices.map((invoice) => invoice.contrast).toSet(),
      {'normal', 'low'},
      issues,
    );
    _requireCoverage(
      'query route',
      corpus.queries.map((query) => query.expectedRoute).toSet(),
      {'keyword', 'structured', 'semantic', 'hybrid'},
      issues,
    );
    if (!corpus.invoices.any((invoice) => invoice.obscuredFields.isNotEmpty)) {
      issues.add('Corpus has no obscured-field cases.');
    }
    if (!corpus.invoices.any((invoice) => invoice.nullFields.isNotEmpty)) {
      issues.add('Corpus has no absent/null-field cases.');
    }
    return issues;
  }

  static void _validateInvoice(
    InvoiceEvaluationCase invoice,
    List<String> issues,
  ) {
    if (!{'ar', 'en', 'mixed'}.contains(invoice.language)) {
      issues.add('${invoice.caseId} has an unsupported language.');
    }
    if (!{'thermal', 'a4'}.contains(invoice.layout)) {
      issues.add('${invoice.caseId} has an unsupported layout.');
    }
    final sourceLines = invoice.source['textLines'];
    if (sourceLines is! List || sourceLines.isEmpty) {
      issues.add('${invoice.caseId} has no source text lines.');
    }
    final skew = invoice.conditions['skewDegrees'];
    if (skew is! num || skew < -15 || skew > 15) {
      issues.add('${invoice.caseId} has invalid skew metadata.');
    }
    if (!{'none', 'partial'}.contains(invoice.conditions['occlusion'])) {
      issues.add('${invoice.caseId} has invalid occlusion metadata.');
    }
    if (!mapKeysEqual(invoice.source, {
      'kind',
      'renderId',
      'imageWidth',
      'imageHeight',
      'digitScript',
      'dateStyle',
      'textLines',
    })) {
      issues.add(
        '${invoice.caseId} source metadata does not match the schema.',
      );
    }
    if (!mapKeysEqual(invoice.conditions, {
      'glare',
      'skewDegrees',
      'contrast',
      'occlusion',
    })) {
      issues.add(
        '${invoice.caseId} quality metadata does not match the schema.',
      );
    }

    const expectedKeys = {
      'merchant',
      'documentType',
      'purchaseDate',
      'total',
      'currency',
      'products',
      'warrantyMonths',
      'rawText',
    };
    if (!mapKeysEqual(invoice.expected, expectedKeys)) {
      issues.add('${invoice.caseId} expected fields do not match the schema.');
    }
    if (invoice.expected['rawText'] is! String) {
      issues.add('${invoice.caseId} expected rawText must be a string.');
    }
    if (invoice.expected['merchant'] is! String ||
        invoice.expected['documentType'] is! String) {
      issues.add('${invoice.caseId} merchant/documentType must be strings.');
    }
    final purchaseDate = invoice.expected['purchaseDate'];
    if (purchaseDate != null &&
        (purchaseDate is! String || !_isIsoDate(purchaseDate))) {
      issues.add('${invoice.caseId} expected purchaseDate is invalid.');
    }
    final total = invoice.expected['total'];
    if (total != null && (total is! num || total < 0)) {
      issues.add('${invoice.caseId} expected total is invalid.');
    }
    final currency = invoice.expected['currency'];
    if (currency != null &&
        (currency is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(currency))) {
      issues.add('${invoice.caseId} expected currency is invalid.');
    }
    final warrantyMonths = invoice.expected['warrantyMonths'];
    if (warrantyMonths != null &&
        (warrantyMonths is! int || warrantyMonths < 0)) {
      issues.add('${invoice.caseId} expected warrantyMonths is invalid.');
    }
    if (invoice.expected['products'] is! List ||
        (invoice.expected['products']! as List).isEmpty) {
      issues.add('${invoice.caseId} must have at least one expected product.');
    } else {
      for (final product in invoice.expected['products']! as List) {
        if (product is! Map ||
            !mapKeysEqual(product.cast<String, Object?>(), {
              'name',
              'quantity',
              'unitPrice',
              'lineTotal',
            })) {
          issues.add('${invoice.caseId} has an invalid product schema.');
        } else {
          final productMap = product.cast<String, Object?>();
          if (productMap['name'] is! String ||
              productMap['quantity'] is! num ||
              (productMap['unitPrice'] != null &&
                  productMap['unitPrice'] is! num) ||
              (productMap['lineTotal'] != null &&
                  productMap['lineTotal'] is! num)) {
            issues.add('${invoice.caseId} has invalid product field types.');
          }
        }
      }
    }
    if (!mapKeysEqual(invoice.search, {
      'invoiceNumber',
      'merchant',
      'product',
      'purchaseDate',
      'currency',
      'documentType',
      'warrantyEndDate',
    })) {
      issues.add(
        '${invoice.caseId} search metadata does not match the schema.',
      );
    }
    for (final key in const [
      'invoiceNumber',
      'merchant',
      'product',
      'purchaseDate',
      'currency',
      'documentType',
    ]) {
      if (invoice.search[key] is! String ||
          (key == 'purchaseDate' &&
              !_isIsoDate(invoice.search[key]! as String))) {
        issues.add('${invoice.caseId} search field $key is invalid.');
      }
    }
    if (invoice.search['warrantyEndDate'] != null &&
        (invoice.search['warrantyEndDate'] is! String ||
            !_isIsoDate(invoice.search['warrantyEndDate']! as String))) {
      issues.add('${invoice.caseId} search warrantyEndDate is invalid.');
    }

    final expectedNulls = <String>{
      for (final entry in invoice.expected.entries)
        if (entry.value == null) entry.key,
    };
    for (final field in invoice.obscuredFields) {
      if (!_expectedFieldIsNull(invoice, field)) {
        issues.add(
          '${invoice.caseId} obscured field $field is not null in expected output.',
        );
      }
    }
    for (final field in invoice.nullFields) {
      if (!_expectedFieldIsNull(invoice, field)) {
        issues.add(
          '${invoice.caseId} absent field $field is not null in expected output.',
        );
      }
    }
    if (invoice.obscuredFields.isNotEmpty &&
        invoice.conditions['occlusion'] != 'partial') {
      issues.add(
        '${invoice.caseId} obscured fields require partial occlusion.',
      );
    }
    if (invoice.obscuredFields.isEmpty &&
        invoice.conditions['occlusion'] != 'none') {
      issues.add(
        '${invoice.caseId} without obscured fields requires no occlusion.',
      );
    }
    if (invoice.nullFields.any(expectedNulls.contains) == false &&
        invoice.nullFields.isNotEmpty) {
      issues.add('${invoice.caseId} null-field metadata is inconsistent.');
    }
  }

  static bool _expectedFieldIsNull(InvoiceEvaluationCase invoice, String path) {
    if (path == 'products[0].lineTotal') {
      final products = invoice.expected['products'];
      return products is List &&
          products.isNotEmpty &&
          (products.first as Map)['lineTotal'] == null;
    }
    return invoice.expected[path] == null;
  }

  static bool _isIsoDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value) != null;

  static void _requireCoverage(
    String label,
    Set<String> actual,
    Set<String> required,
    List<String> issues,
  ) {
    final missing = required.difference(actual);
    if (missing.isNotEmpty) {
      issues.add('Missing $label categories: ${missing.join(', ')}.');
    }
  }
}

class RetrievalMetrics {
  const RetrievalMetrics({
    required this.recallAt1,
    required this.recallAt5,
    required this.meanReciprocalRank,
    required this.falsePositiveRateAt5,
  });

  factory RetrievalMetrics.fromResults({
    required List<SearchQueryEvaluationCase> queries,
    required Map<String, List<String>> resultsByQueryId,
  }) {
    if (queries.isEmpty) {
      throw ArgumentError.value(queries, 'queries', 'must not be empty');
    }
    var hitsAt1 = 0;
    var hitsAt5 = 0;
    var reciprocalRankTotal = 0.0;
    var falsePositives = 0;
    var returned = 0;
    for (final query in queries) {
      final expected = query.expectedInvoiceIds.toSet();
      final results = resultsByQueryId[query.queryId] ?? const <String>[];
      if (results.take(1).any(expected.contains)) hitsAt1++;
      final topFive = results.take(5).toList(growable: false);
      if (topFive.any(expected.contains)) hitsAt5++;
      final rank = topFive.indexWhere(expected.contains);
      if (rank >= 0) reciprocalRankTotal += 1 / (rank + 1);
      falsePositives += topFive.where((id) => !expected.contains(id)).length;
      returned += topFive.length;
    }
    return RetrievalMetrics(
      recallAt1: hitsAt1 / queries.length,
      recallAt5: hitsAt5 / queries.length,
      meanReciprocalRank: reciprocalRankTotal / queries.length,
      falsePositiveRateAt5: returned == 0 ? 0 : falsePositives / returned,
    );
  }

  final double recallAt1;
  final double recallAt5;
  final double meanReciprocalRank;
  final double falsePositiveRateAt5;
}

abstract final class ExtractionMetrics {
  static bool fieldExactMatch(Object? expected, Object? actual) {
    if (expected is String && actual is String) {
      return _normalize(expected) == _normalize(actual);
    }
    if (expected is num && actual is num) return expected == actual;
    return expected == actual;
  }

  static double fieldAccuracy({
    required Map<String, Object?> expected,
    required Map<String, Object?> actual,
    required Iterable<String> fields,
  }) {
    final fieldList = fields.toList(growable: false);
    if (fieldList.isEmpty) return 0;
    final matches = fieldList
        .where((field) => fieldExactMatch(expected[field], actual[field]))
        .length;
    return matches / fieldList.length;
  }

  static double productItemF1({
    required List<Object?> expected,
    required List<Object?> actual,
  }) {
    final expectedNames = expected
        .whereType<Map>()
        .map((item) => _normalize(item['name']?.toString() ?? ''))
        .where((name) => name.isNotEmpty)
        .toSet();
    final actualNames = actual
        .whereType<Map>()
        .map((item) => _normalize(item['name']?.toString() ?? ''))
        .where((name) => name.isNotEmpty)
        .toSet();
    if (expectedNames.isEmpty && actualNames.isEmpty) return 1;
    final truePositives = expectedNames.intersection(actualNames).length;
    final precision = actualNames.isEmpty
        ? 0
        : truePositives / actualNames.length;
    final recall = expectedNames.isEmpty
        ? 0
        : truePositives / expectedNames.length;
    if (precision + recall == 0) return 0;
    return 2 * precision * recall / (precision + recall);
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

List<Map<String, Object?>> _decodeLines(String source) {
  return source
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => jsonDecode(line))
      .map((value) => (value as Map).cast<String, Object?>())
      .toList(growable: false);
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected non-empty string at $key.');
  }
  return value;
}

Map<String, Object?> _map(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! Map) throw FormatException('Expected object at $key.');
  return value.cast<String, Object?>();
}

List<String> _strings(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Expected string array at $key.');
  }
  return value.cast<String>();
}

bool mapKeysEqual(Map<Object?, Object?> map, Set<String> expected) =>
    map.keys.length == expected.length &&
    map.keys.every((key) => key is String && expected.contains(key));
