import 'package:path_provider/path_provider.dart';

import '../features/home/repositories/home_invoice_repository.dart';
import '../features/invoice_capture/repositories/invoice_capture_repository.dart';
import '../features/invoice_capture/repositories/invoice_extraction_repository.dart';
import '../features/invoice_details/repositories/invoice_repository.dart';
import '../features/invoice_details/repositories/objectbox_invoice_repository.dart';
import '../features/settings/repositories/settings_repository.dart';
import 'database/objectbox_database.dart';
import 'ai/extraction/method_channel_qwen_interpreter.dart';
import 'ai/model_management/model_coordinator.dart';
import 'ai/ocr/method_channel_ocr_engine.dart';
import 'storage/invoice_file_cleaner.dart';

class AppDependencies {
  AppDependencies({
    required this.database,
    required this.settings,
    required this.invoices,
    required this.homeInvoices,
    required this.invoiceCapture,
  });

  final ObjectBoxDatabase database;
  final SettingsRepository settings;
  final InvoiceRepository invoices;
  final HomeInvoiceRepository homeInvoices;
  final InvoiceCaptureRepository invoiceCapture;

  static Future<AppDependencies> production() async {
    final documents = await getApplicationDocumentsDirectory();
    final database = await ObjectBoxDatabase.open(
      directory: '${documents.path}/wara2a-objectbox',
    );
    return AppDependencies.fromDatabase(
      database,
      settings: SharedPreferencesSettingsRepository(),
      fileCleaner: LocalInvoiceFileCleaner(managedRoot: documents.path),
    );
  }

  factory AppDependencies.fromDatabase(
    ObjectBoxDatabase database, {
    required SettingsRepository settings,
    InvoiceFileCleaner fileCleaner = const NoOpInvoiceFileCleaner(),
  }) {
    final invoices = ObjectBoxInvoiceRepository(
      store: database.invoices,
      fileCleaner: fileCleaner,
    );
    return AppDependencies(
      database: database,
      settings: settings,
      invoices: invoices,
      homeInvoices: LocalHomeInvoiceRepository(invoices),
      invoiceCapture: LocalInvoiceCaptureRepository(invoices),
    );
  }

  InvoiceExtractionRepository createInvoiceExtractionRepository() =>
      LocalInvoiceExtractionRepository(
        ModelCoordinator(
          ocrEngineFactory: PlatformOcrEngine.new,
          interpreterFactory: PlatformQwenTextInterpreter.new,
        ),
      );

  void dispose() => database.close();
}
