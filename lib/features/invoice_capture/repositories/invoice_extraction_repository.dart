import '../../../core/ai/model_management/model_coordinator.dart';
import '../../../core/ai/model_management/model_lifecycle_state.dart';

abstract interface class InvoiceExtractionRepository {
  Stream<ModelLifecycleState> get states;
  Future<InvoiceExtractionResult> extract(InvoiceExtractionRequest request);
  Future<void> cancel();
  Future<void> close();
}

class LocalInvoiceExtractionRepository implements InvoiceExtractionRepository {
  LocalInvoiceExtractionRepository(this.coordinator);

  final ModelCoordinator coordinator;

  @override
  Stream<ModelLifecycleState> get states => coordinator.states;

  @override
  Future<InvoiceExtractionResult> extract(InvoiceExtractionRequest request) =>
      coordinator.extract(request);

  @override
  Future<void> cancel() => coordinator.cancel();

  @override
  Future<void> close() => coordinator.dispose();
}
