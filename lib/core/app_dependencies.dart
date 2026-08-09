import 'package:path_provider/path_provider.dart';

import '../features/search/models/search_intent_router.dart';
import '../features/search/repositories/invoice_embedding_indexer.dart';
import '../features/search/repositories/objectbox_search_repository.dart';
import '../features/search/repositories/search_repository.dart';
import '../features/home/repositories/home_invoice_repository.dart';
import '../features/invoice_capture/repositories/invoice_capture_repository.dart';
import '../features/invoice_details/repositories/invoice_repository.dart';
import '../features/invoice_details/repositories/objectbox_invoice_repository.dart';
import '../features/settings/repositories/settings_repository.dart';
import 'database/objectbox_database.dart';
import 'ai/embedding/embedding_engine.dart';
import 'ai/embedding/embedding_gemma_artifact.dart';
import 'ai/embedding/flutter_gemma_embedding_engine.dart';
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
          modelId: EmbeddingGemmaArtifact.modelId,
          reason: 'Embedding runtime is not configured for this app scope.',
          capability: EmbeddingCapability.modelAccessRequired,
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
    if (!FlutterGemmaEmbeddingEngine.supportsCurrentPlatform) {
      return UnavailableEmbeddingEngine(
        modelId: EmbeddingGemmaArtifact.modelId,
        reason: 'EmbeddingGemma is unsupported on this CPU architecture.',
      );
    }
    try {
      return await FlutterGemmaEmbeddingEngine.create();
    } on Object {
      return UnavailableEmbeddingEngine(
        modelId: EmbeddingGemmaArtifact.modelId,
        reason: 'The local EmbeddingGemma runtime could not be initialized.',
        capability: EmbeddingCapability.runtimeFailure,
        status: ModelLifecycleStatus.failed,
      );
    }
  }
}
