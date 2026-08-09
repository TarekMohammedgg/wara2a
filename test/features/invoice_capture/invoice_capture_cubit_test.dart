import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_image_draft.dart';
import 'package:wara2a/features/invoice_capture/repositories/invoice_image_repository.dart';
import 'package:wara2a/features/invoice_capture/view_models/invoice_capture_cubit.dart';
import 'package:wara2a/features/invoice_capture/view_models/invoice_capture_state.dart';

void main() {
  test(
    'replaces an uncommitted draft and cleans up the old owned image',
    () async {
      final first = _draft('first');
      final second = _draft('second');
      final repository = _FakeInvoiceImageRepository(results: [first, second]);
      final cubit = InvoiceCaptureCubit(repository);

      await cubit.selectImage(InvoiceImageSource.camera);
      await cubit.selectImage(InvoiceImageSource.gallery);

      expect(cubit.state, isA<InvoiceCaptureReady>());
      expect(cubit.state.draft?.path, second.path);
      expect(repository.discardedPaths, [first.path]);
      await cubit.close();
    },
  );

  test('keeps the current draft when reselecting is cancelled', () async {
    final first = _draft('first');
    final repository = _FakeInvoiceImageRepository(results: [first, null]);
    final cubit = InvoiceCaptureCubit(repository);

    await cubit.selectImage(InvoiceImageSource.camera);
    final result = await cubit.selectImage(InvoiceImageSource.gallery);

    expect(result, isNull);
    expect(cubit.state, isA<InvoiceCaptureReady>());
    expect(cubit.state.draft?.path, first.path);
    expect(repository.discardedPaths, isEmpty);
    await cubit.close();
  });

  test(
    'restores Android lost picker data through the repository boundary',
    () async {
      final recovered = _draft('recovered');
      final repository = _FakeInvoiceImageRepository(recovered: recovered);
      final cubit = InvoiceCaptureCubit(repository);

      final result = await cubit.recoverLostData();

      expect(result?.path, recovered.path);
      expect(cubit.state, isA<InvoiceCaptureReady>());
      expect(cubit.state.draft?.source, InvoiceImageSource.camera);
      await cubit.close();
    },
  );
}

InvoiceImageDraft _draft(String id) => InvoiceImageDraft(
  id: id,
  path: '/app-owned/$id.jpg',
  source: InvoiceImageSource.camera,
  mimeType: 'image/jpeg',
  byteLength: 1024,
  width: 1000,
  height: 1500,
  createdAt: DateTime(2026),
);

class _FakeInvoiceImageRepository implements InvoiceImageRepository {
  _FakeInvoiceImageRepository({
    List<InvoiceImageDraft?> results = const [],
    this.recovered,
  }) : _results = List.of(results);

  final List<InvoiceImageDraft?> _results;
  final InvoiceImageDraft? recovered;
  final discardedPaths = <String>[];

  @override
  Future<void> discardDraft(InvoiceImageDraft draft) async {
    discardedPaths.add(draft.path);
  }

  @override
  Future<InvoiceImageDraft?> pickImage(InvoiceImageSource source) async {
    return _results.removeAt(0);
  }

  @override
  Future<InvoiceImageDraft?> recoverLostData() async => recovered;
}
