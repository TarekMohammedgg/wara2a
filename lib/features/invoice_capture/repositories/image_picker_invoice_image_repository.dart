import 'package:image_picker/image_picker.dart';

import '../../../core/storage/app_image_storage.dart';
import '../../../core/storage/image_validation.dart';
import '../models/invoice_image_draft.dart';
import 'invoice_image_repository.dart';

class ImagePickerInvoiceImageRepository implements InvoiceImageRepository {
  ImagePickerInvoiceImageRepository({
    ImagePicker? picker,
    AppImageStorage? storage,
    ImageFileValidator? validator,
  }) : _picker = picker ?? ImagePicker(),
       _storage = storage ?? AppImageStorage(),
       _validator = validator ?? const ImageFileValidator();

  final ImagePicker _picker;
  final AppImageStorage _storage;
  final ImageFileValidator _validator;

  @override
  Future<InvoiceImageDraft?> pickImage(InvoiceImageSource source) async {
    await _storage.recordPendingSource(source);

    try {
      final file = await _picker.pickImage(
        source: source == InvoiceImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: ImageFileValidator.maximumDimension.toDouble(),
        maxHeight: ImageFileValidator.maximumDimension.toDouble(),
        imageQuality: 92,
      );
      if (file == null) {
        await _storage.clearPendingSource();
        return null;
      }

      return await _validateAndStore(file, source);
    } catch (_) {
      // A killed process never reaches this catch; its marker remains for
      // retrieveLostData. Ordinary picker failures must not leave stale state.
      await _storage.clearPendingSource();
      rethrow;
    }
  }

  @override
  Future<InvoiceImageDraft?> recoverLostData() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) {
      await _storage.clearPendingSource();
      return null;
    }
    if (response.exception != null) {
      await _storage.clearPendingSource();
      throw CaptureImageException(
        CaptureImageFailureType.picker,
        response.exception!.code,
      );
    }

    final file = response.file;
    if (file == null) {
      await _storage.clearPendingSource();
      return null;
    }

    final source = await _storage.takePendingSource();
    if (source == null) {
      throw const CaptureImageException(
        CaptureImageFailureType.recovery,
        'The capture source could not be recovered. Please choose the image again.',
      );
    }
    return _validateAndStore(file, source, clearPendingSource: false);
  }

  @override
  Future<void> discardDraft(InvoiceImageDraft draft) =>
      _storage.deleteDraft(draft.path);

  Future<InvoiceImageDraft> _validateAndStore(
    XFile file,
    InvoiceImageSource source, {
    bool clearPendingSource = true,
  }) async {
    try {
      final validated = await _validator.validate(file);
      final path = await _storage.copyToDraft(file, validated.extension);
      return InvoiceImageDraft(
        id: AppImageStorage.newDraftId(),
        path: path,
        source: source,
        mimeType: validated.mimeType,
        byteLength: validated.byteLength,
        width: validated.width,
        height: validated.height,
        createdAt: DateTime.now(),
      );
    } finally {
      if (clearPendingSource) {
        await _storage.clearPendingSource();
      }
    }
  }
}
