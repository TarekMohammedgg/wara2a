import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/invoice.dart';
import '../repositories/invoice_repository.dart';

enum InvoiceDetailsStatus {
  initial,
  loading,
  success,
  notFound,
  deleting,
  failure,
}

class InvoiceDetailsState extends Equatable {
  const InvoiceDetailsState({
    this.status = InvoiceDetailsStatus.initial,
    this.invoice,
    this.errorMessage,
  });

  final InvoiceDetailsStatus status;
  final Invoice? invoice;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, invoice, errorMessage];
}

class InvoiceDetailsCubit extends Cubit<InvoiceDetailsState> {
  InvoiceDetailsCubit(this._repository) : super(const InvoiceDetailsState());

  final InvoiceRepository _repository;

  Future<void> load(int invoiceId) async {
    emit(const InvoiceDetailsState(status: InvoiceDetailsStatus.loading));
    try {
      final invoice = await _repository.get(invoiceId);
      emit(
        invoice == null
            ? const InvoiceDetailsState(status: InvoiceDetailsStatus.notFound)
            : InvoiceDetailsState(
                status: InvoiceDetailsStatus.success,
                invoice: invoice,
              ),
      );
    } catch (error) {
      emit(
        InvoiceDetailsState(
          status: InvoiceDetailsStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<bool> delete() async {
    final invoice = state.invoice;
    if (invoice == null) return false;
    emit(
      InvoiceDetailsState(
        status: InvoiceDetailsStatus.deleting,
        invoice: invoice,
      ),
    );
    try {
      return await _repository.delete(invoice.id);
    } catch (error) {
      emit(
        InvoiceDetailsState(
          status: InvoiceDetailsStatus.failure,
          invoice: invoice,
          errorMessage: error.toString(),
        ),
      );
      return false;
    }
  }
}
