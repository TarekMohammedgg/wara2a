import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onError(BlocBase<Object?> bloc, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('${bloc.runtimeType}: $error');
    }
    super.onError(bloc, error, stackTrace);
  }
}
