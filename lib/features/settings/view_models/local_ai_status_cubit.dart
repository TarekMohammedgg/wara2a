import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/local_ai_status.dart';
import '../repositories/local_ai_status_repository.dart';

sealed class LocalAiStatusState {
  const LocalAiStatusState();
}

class LocalAiStatusInitial extends LocalAiStatusState {
  const LocalAiStatusInitial();
}

class LocalAiStatusLoading extends LocalAiStatusState {
  const LocalAiStatusLoading();
}

class LocalAiStatusLoaded extends LocalAiStatusState {
  const LocalAiStatusLoaded(this.status);

  final LocalAiStatus status;
}

class LocalAiStatusFailure extends LocalAiStatusState {
  const LocalAiStatusFailure(this.message);

  final String message;
}

class LocalAiStatusCubit extends Cubit<LocalAiStatusState> {
  LocalAiStatusCubit(this.repository) : super(const LocalAiStatusInitial());

  final LocalAiStatusRepository repository;

  Future<void> refresh() async {
    emit(const LocalAiStatusLoading());
    try {
      emit(LocalAiStatusLoaded(await repository.inspect()));
    } on Object catch (error) {
      emit(LocalAiStatusFailure(error.toString()));
    }
  }
}
