import 'package:path_provider/path_provider.dart';

import '../features/search/models/search_intent_router.dart';
import '../features/search/repositories/invoice_embedding_indexer.dart';
import '../features/search/repositories/objectbox_search_repository.dart';
import '../features/search/repositories/search_repository.dart';
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
import 'ai/embedding/embedding_engine.dart';
import 'ai/embedding/method_channel_e5_embedding_engine.dart';
import 'ai/embedding/multilingual_e5_artifact.dart';
import 'ai/embedding/multilingual_e5_calibration.dart';
import 'ai/model_management/model_lifecycle_state.dart';
import 'storage/invoice_file_cleaner.dart';

class AppDependencies {
  AppDependencies({
    required this.database,
    required this.settings,
    required this.invoices,
    required this.homeInvoices,
    required this.invoiceCapture,
    required this.embeddingEngine,
    required this.embeddingIndexer,
    required this.search,
  });

  final ObjectBoxDatabase database;
  final SettingsRepository settings;
  final InvoiceRepository invoices;
  final HomeInvoiceRepository homeInvoices;
  final InvoiceCaptureRepository invoiceCapture;
  final EmbeddingEngine embeddingEngine;
  final InvoiceEmbeddingIndexer embeddingIndexer;
  final SearchRepository search;
  Future<void>? _disposeFuture;

  static Future<AppDependencies> production() async {
    final documents = await getApplicationDocumentsDirectory();
    final database = await ObjectBoxDatabase.open(
      directory: '${documents.path}/wara2a-objectbox',
    );
    final embeddingEngine = await _productionEmbeddingEngine();
    return AppDependencies.fromDatabase(
      database,
      settings: SharedPreferencesSettingsRepository(),
      fileCleaner: LocalInvoiceFileCleaner(managedRoot: documents.path),
      embeddingEngine: embeddingEngine,
    );
  }

  factory AppDependencies.fromDatabase(
    ObjectBoxDatabase database, {
    required SettingsRepository settings,
    InvoiceFileCleaner fileCleaner = const NoOpInvoiceFileCleaner(),
    EmbeddingEngine? embeddingEngine,
  }) {
    final resolvedEmbeddingEngine =
        embeddingEngine ??
        UnavailableEmbeddingEngine(
          modelId: MultilingualE5Artifact.modelId,
          reason: 'Embedding runtime is not configured for this app scope.',
          capability: EmbeddingCapability.modelNotInstalled,
        );
    final invoices = ObjectBoxInvoiceRepository(
      store: database.invoices,
      fileCleaner: fileCleaner,
    );
    final embeddingIndexer = InvoiceEmbeddingIndexer(
      store: database.invoices,
      engine: resolvedEmbeddingEngine,
    );
    final search = ObjectBoxSearchRepository(
      store: database.invoices,
      engine: resolvedEmbeddingEngine,
      indexer: embeddingIndexer,
      intentRouter: SearchIntentRouter(),
      // Host Recall@K is not Android approval. Keep semantic results gated
      // until RMX3636 offline evidence binds a threshold to this contract.
      calibration: MultilingualE5Calibration.production,
    );
    return AppDependencies(
      database: database,
      settings: settings,
      invoices: invoices,
      homeInvoices: LocalHomeInvoiceRepository(invoices),
      invoiceCapture: LocalInvoiceCaptureRepository(
        invoices,
        indexer: embeddingIndexer,
      ),
      embeddingEngine: resolvedEmbeddingEngine,
      embeddingIndexer: embeddingIndexer,
      search: search,
    );
  }

  InvoiceExtractionRepository createInvoiceExtractionRepository() =>
      LocalInvoiceExtractionRepository(
        ModelCoordinator(
          ocrEngineFactory: PlatformOcrEngine.new,
          interpreterFactory: PlatformQwenTextInterpreter.new,
        ),
      );

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    try {
      await embeddingIndexer.waitForIdle();
      await embeddingEngine.dispose();
    } finally {
      database.close();
    }
  }

  static Future<EmbeddingEngine> _productionEmbeddingEngine() async {
    if (!MethodChannelE5EmbeddingEngine.supportsCurrentPlatform) {
      return UnavailableEmbeddingEngine(
        modelId: MultilingualE5Artifact.modelId,
        reason: 'The offline E5 runtime is available on Android arm64 only.',
      );
    }
    try {
      return await MethodChannelE5EmbeddingEngine.create();
    } on Object {
      return UnavailableEmbeddingEngine(
        modelId: MultilingualE5Artifact.modelId,
        reason: 'The local E5 embedding runtime could not be initialized.',
        capability: EmbeddingCapability.runtimeFailure,
        status: ModelLifecycleStatus.failed,
      );
    }
  }
}
