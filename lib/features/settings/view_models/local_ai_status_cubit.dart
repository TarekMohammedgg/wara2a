import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ai/ai_cancellation_token.dart';
import '../../../core/ai/ai_runtime_error.dart';
import '../../../core/ai/model_management/secure_model_installer.dart';
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

class LocalAiStatusInstalling extends LocalAiStatusState {
  const LocalAiStatusInstalling(this.progress);

  final ModelInstallProgress progress;
}

class LocalAiStatusRemoving extends LocalAiStatusState {
  const LocalAiStatusRemoving();
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
      emit(LocalAiStatusFailure(_describe(error)));
    }
  }

  Future<void> installRequired() async {
    emit(const LocalAiStatusLoading());
    try {
      await repository.installRequired((progress) {
        if (!isClosed) emit(LocalAiStatusInstalling(progress));
      });
      if (!isClosed) await refresh();
    } on AiCancelledException {
      if (!isClosed) await refresh();
    } on Object catch (error) {
      if (!isClosed) emit(LocalAiStatusFailure(_describe(error)));
    }
  }

  Future<void> cancelInstallation() => repository.cancelInstallation();

  Future<void> removeRequired() async {
    emit(const LocalAiStatusRemoving());
    try {
      await repository.removeRequired();
      if (!isClosed) await refresh();
    } on Object catch (error) {
      if (!isClosed) emit(LocalAiStatusFailure(_describe(error)));
    }
  }

  static String _describe(Object error) {
    if (error is AiRuntimeException) return error.message;
    return error.toString();
  }

  @override
  Future<void> close() async {
    await repository.close();
    return super.close();
  }
}
