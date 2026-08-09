import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ai/ai_runtime_error.dart';
import '../../../core/ai/model_management/model_coordinator.dart';
import '../../../core/ai/model_management/model_lifecycle_state.dart';
import '../repositories/invoice_extraction_repository.dart';

sealed class InvoiceExtractionState {
  const InvoiceExtractionState();
}

class InvoiceExtractionInitial extends InvoiceExtractionState {
  const InvoiceExtractionInitial();
}

class InvoiceExtractionRunning extends InvoiceExtractionState {
  const InvoiceExtractionRunning(this.lifecycle);

  final ModelLifecycleState lifecycle;
}

class InvoiceExtractionReady extends InvoiceExtractionState {
  const InvoiceExtractionReady(this.result);

  final InvoiceExtractionResult result;
}

class InvoiceExtractionManualReview extends InvoiceExtractionState {
  const InvoiceExtractionManualReview(this.result);

  final InvoiceExtractionResult result;
}

class InvoiceExtractionCancelled extends InvoiceExtractionState {
  const InvoiceExtractionCancelled();
}

class InvoiceExtractionFailure extends InvoiceExtractionState {
  const InvoiceExtractionFailure(this.error);

  final AiRuntimeException error;
}

class InvoiceExtractionCubit extends Cubit<InvoiceExtractionState> {
  InvoiceExtractionCubit(this.repository)
    : super(const InvoiceExtractionInitial()) {
    _lifecycleSubscription = repository.states.listen((lifecycle) {
      final isActive =
          lifecycle.status == ModelLifecycleStatus.loading ||
          lifecycle.status == ModelLifecycleStatus.running ||
          lifecycle.status == ModelLifecycleStatus.cancelling;
      if (!isClosed && isActive) {
        emit(InvoiceExtractionRunning(lifecycle));
      }
    });
  }

  final InvoiceExtractionRepository repository;
  late final StreamSubscription<ModelLifecycleState> _lifecycleSubscription;

  Future<void> extract(InvoiceExtractionRequest request) async {
    try {
      final result = await repository.extract(request);
      if (isClosed) return;
      emit(
        result.manualFallback
            ? InvoiceExtractionManualReview(result)
            : InvoiceExtractionReady(result),
      );
    } on AiRuntimeException catch (error) {
      if (isClosed) return;
      emit(
        error.code == AiErrorCode.cancelled
            ? const InvoiceExtractionCancelled()
            : InvoiceExtractionFailure(error),
      );
    }
  }

  Future<void> cancel() => repository.cancel();

  @override
  Future<void> close() async {
    await repository.cancel();
    await _lifecycleSubscription.cancel();
    await repository.close();
    return super.close();
  }
}
