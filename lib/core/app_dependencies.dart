import 'dart:async';

import 'package:path_provider/path_provider.dart';

import '../features/search/models/search_intent_router.dart';
import '../features/search/repositories/invoice_embedding_indexer.dart';
import '../features/search/repositories/objectbox_search_repository.dart';
import '../features/search/repositories/search_repository.dart';
import '../features/home/repositories/home_invoice_repository.dart';
import '../features/invoice_capture/repositories/invoice_capture_repository.dart';
import '../features/invoice_capture/repositories/invoice_extraction_repository.dart';
import '../features/invoice_capture/repositories/open_router_gemini_extraction_repository.dart';
import '../features/invoice_details/repositories/invoice_repository.dart';
import '../features/invoice_details/repositories/objectbox_invoice_repository.dart';
import '../features/settings/repositories/settings_repository.dart';
import 'ai/embedding/embedding_engine.dart';
import 'ai/embedding/open_router_embedding_artifact.dart';
import 'ai/embedding/open_router_embedding_calibration.dart';
import 'ai/embedding/open_router_embedding_engine.dart';
import 'database/objectbox_database.dart';
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
  Future<PendingEmbeddingSyncResult>? _pendingEmbeddingSync;

  static Future<AppDependencies> production() async {
    final documents = await getApplicationDocumentsDirectory();
    final settings = SharedPreferencesSettingsRepository();
    final database = await ObjectBoxDatabase.open(
      directory: '${documents.path}/wara2a-objectbox',
    );
    final embeddingEngine = OpenRouterEmbeddingEngine(
      resolveApiKey: () async {
        final loaded = await settings.load();
        return loaded.cloudProcessingConsent ? loaded.openRouterApiKey : null;
      },
    );
    return AppDependencies.fromDatabase(
      database,
      settings: settings,
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
          modelId: OpenRouterEmbeddingArtifact.modelId,
          reason: 'OpenRouter embedding runtime is not configured.',
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
      calibration: OpenRouterEmbeddingCalibration.production,
    );
    late final AppDependencies dependencies;
    dependencies = AppDependencies(
      database: database,
      settings: settings,
      invoices: invoices,
      homeInvoices: LocalHomeInvoiceRepository(invoices),
      invoiceCapture: LocalInvoiceCaptureRepository(
        invoices,
        indexer: embeddingIndexer,
        onIndexingScheduled: () {
          dependencies.syncPendingEmbeddingsInBackground();
        },
      ),
      embeddingEngine: resolvedEmbeddingEngine,
      embeddingIndexer: embeddingIndexer,
      search: search,
    );
    return dependencies;
  }

  InvoiceExtractionRepository createInvoiceExtractionRepository() =>
      OpenRouterGeminiExtractionRepository(
        resolveApiKey: () async {
          final loaded = await settings.load();
          return loaded.cloudProcessingConsent ? loaded.openRouterApiKey : null;
        },
      );

  Future<PendingEmbeddingSyncResult> syncPendingEmbeddings() {
    return _pendingEmbeddingSync ??= search
        .reindexPendingEmbeddings()
        .whenComplete(() => _pendingEmbeddingSync = null);
  }

  void syncPendingEmbeddingsInBackground() {
    unawaited(syncPendingEmbeddings());
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
}
