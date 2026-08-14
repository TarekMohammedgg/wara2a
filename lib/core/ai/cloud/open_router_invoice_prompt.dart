class OpenRouterInvoicePrompt {
  const OpenRouterInvoicePrompt();

  static const String schema =
      '{"merchant":string|null,'
      '"purchaseDate":"YYYY-MM-DD"|null,"invoiceNumber":string|null,'
      '"total":number|null,'
      '"currency":string|null,"products":[{"name":string|null,'
      '"quantity":number|null,"unitPrice":number|null,'
      '"lineTotal":number|null}],"warrantyMonths":integer|null,'
      '"rawText":string|null}';

  /// Keep the prompt short: less input tokens and faster JSON generation.
  String build() =>
      '''
Extract this invoice image into one JSON object. Include every product row.
Use null when missing. Dates=YYYY-MM-DD. Money as numbers (1288.20). currency=ISO.
Set rawText to null. JSON only.

Schema:
$schema
'''
          .trim();

  /// Strips common model wrappers so the shared Dart validator can parse JSON.
  static String extractJsonObject(String modelOutput) {
    var text = modelOutput.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(
        RegExp(r'^```(?:json)?\s*', multiLine: true),
        '',
      );
      text = text.replaceFirst(RegExp(r'\s*```$', multiLine: true), '');
      text = text.trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }
}
