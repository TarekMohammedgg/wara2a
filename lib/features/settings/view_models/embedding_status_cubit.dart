import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ai/embedding/embedding_engine.dart';
import '../../search/repositories/invoice_embedding_indexer.dart';

class EmbeddingStatusState {
  const EmbeddingStatusState({
    required this.snapshot,
    this.pendingInvoiceCount = 0,
    this.busy = false,
    this.errorMessage,
  });

  final EmbeddingEngineSnapshot snapshot;
  final int pendingInvoiceCount;
  final bool busy;
  final String? errorMessage;
}

class EmbeddingStatusCubit extends Cubit<EmbeddingStatusState> {
  EmbeddingStatusCubit(this.engine, this.indexer)
    : super(EmbeddingStatusState(snapshot: engine.snapshot)) {
    _subscription = engine.snapshots.listen((snapshot) {
      if (!isClosed) {
        emit(
          EmbeddingStatusState(
            snapshot: snapshot,
            pendingInvoiceCount: state.pendingInvoiceCount,
            busy: state.busy,
            errorMessage: state.errorMessage,
          ),
        );
      }
    });
  }

  final EmbeddingEngine engine;
  final InvoiceEmbeddingIndexer indexer;
  StreamSubscription<EmbeddingEngineSnapshot>? _subscription;

  Future<void> refresh() async {
    emit(
      EmbeddingStatusState(
        snapshot: state.snapshot,
        pendingInvoiceCount: state.pendingInvoiceCount,
        busy: true,
      ),
    );
    try {
      final snapshot = await engine.refresh();
      final pending = await indexer.pendingCount();
      if (!isClosed) {
        emit(
          EmbeddingStatusState(
            snapshot: snapshot,
            pendingInvoiceCount: pending,
          ),
        );
      }
    } on Object catch (error) {
      if (!isClosed) {
        emit(
          EmbeddingStatusState(
            snapshot: engine.snapshot,
            pendingInvoiceCount: state.pendingInvoiceCount,
            errorMessage: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> install() async {
    if (state.busy) return;
    emit(
      EmbeddingStatusState(
        snapshot: state.snapshot,
        pendingInvoiceCount: state.pendingInvoiceCount,
        busy: true,
      ),
    );
    try {
      await engine.install();
      await reindex();
    } on Object catch (error) {
      if (!isClosed) {
        emit(
          EmbeddingStatusState(
            snapshot: engine.snapshot,
            pendingInvoiceCount: state.pendingInvoiceCount,
            errorMessage: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> reindex() async {
    if (!engine.snapshot.canEmbed) return;
    emit(
      EmbeddingStatusState(
        snapshot: engine.snapshot,
        pendingInvoiceCount: state.pendingInvoiceCount,
        busy: true,
      ),
    );
    try {
      await indexer.reindexPending();
      await refresh();
    } on Object catch (error) {
      if (!isClosed) {
        emit(
          EmbeddingStatusState(
            snapshot: engine.snapshot,
            pendingInvoiceCount: state.pendingInvoiceCount,
            errorMessage: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> cancel() async {
    await indexer.cancelReindex();
    if (!isClosed) {
      emit(
        EmbeddingStatusState(
          snapshot: engine.snapshot,
          pendingInvoiceCount: state.pendingInvoiceCount,
          busy: false,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await engine.unload();
    return super.close();
  }
}
