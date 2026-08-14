import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/cloud/open_router_invoice_prompt.dart';

void main() {
  test('strips markdown fences around JSON', () {
    const wrapped = '''
```json
{"merchant":"بي تك","products":[]}
```
''';
    expect(
      OpenRouterInvoicePrompt.extractJsonObject(wrapped),
      '{"merchant":"بي تك","products":[]}',
    );
  });

  test('keeps the outermost JSON object when prose surrounds it', () {
    const noisy = 'Here you go:\n{"merchant":"X","products":[]}\nThanks';
    expect(
      OpenRouterInvoicePrompt.extractJsonObject(noisy),
      '{"merchant":"X","products":[]}',
    );
  });
}
