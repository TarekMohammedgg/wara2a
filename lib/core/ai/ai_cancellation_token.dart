import 'dart:async';

class AiCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const AiCancelledException();
  }
}

class AiCancelledException implements Exception {
  const AiCancelledException();

  @override
  String toString() => 'The local AI operation was cancelled.';
}
