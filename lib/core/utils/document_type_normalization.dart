import 'text_normalization.dart';

abstract final class DocumentTypeNormalization {
  static const purchaseInvoice = 'purchase_invoice';
  static const receipt = 'receipt';
  static const creditNote = 'credit_note';
  static const warrantyCertificate = 'warranty_certificate';

  static String? normalize(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = TextNormalization.normalize(value);
    if (_containsAny(normalized, const [
      'شهاده ضمان',
      'شهادة ضمان',
      'warranty certificate',
    ])) {
      return warrantyCertificate;
    }
    if (_containsAny(normalized, const [
      'اشعار دائن',
      'اشعار داين',
      'credit note',
    ])) {
      return creditNote;
    }
    if (_containsAny(normalized, const ['ايصال', 'receipt'])) {
      return receipt;
    }
    if (_containsAny(normalized, const [
      'فاتوره شراء',
      'فاتورة شراء',
      'purchase invoice',
    ])) {
      return purchaseInvoice;
    }
    return normalized;
  }

  static bool _containsAny(String value, Iterable<String> candidates) =>
      candidates.any(
        (candidate) => value.contains(TextNormalization.normalize(candidate)),
      );
}
