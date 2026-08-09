import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/invoice_summary.dart';
import '../repositories/home_invoice_repository.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.invoices = const [],
    this.errorMessage,
  });

  final HomeStatus status;
  final List<InvoiceSummary> invoices;
  final String? errorMessage;

  int get thisMonthCount {
    final prefix = DateTime.now().toLocal().toIso8601String().substring(0, 7);
    return invoices.where((invoice) => invoice.date.startsWith(prefix)).length;
  }

  @override
  List<Object?> get props => [status, invoices, errorMessage];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository) : super(const HomeState());

  final HomeInvoiceRepository _repository;
  StreamSubscription<List<InvoiceSummary>>? _subscription;

  Future<void> watchInvoices() async {
    emit(const HomeState(status: HomeStatus.loading));
    await _subscription?.cancel();
    _subscription = _repository.watchRecent().listen(
      (invoices) =>
          emit(HomeState(status: HomeStatus.success, invoices: invoices)),
      onError: (Object error, StackTrace stackTrace) => emit(
        HomeState(status: HomeStatus.failure, errorMessage: error.toString()),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
