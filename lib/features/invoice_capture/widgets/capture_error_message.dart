import '../../../core/storage/image_validation.dart';
import '../../../l10n/app_localizations.dart';

String captureErrorMessage(
  AppLocalizations l10n,
  CaptureImageFailureType type,
) {
  return switch (type) {
    CaptureImageFailureType.unsupportedFormat => l10n.captureUnsupportedImage,
    CaptureImageFailureType.tooLarge => l10n.captureImageTooLarge,
    CaptureImageFailureType.invalidDimensions => l10n.captureInvalidDimensions,
    CaptureImageFailureType.corrupted => l10n.captureCorruptedImage,
    CaptureImageFailureType.picker => l10n.capturePickerError,
    CaptureImageFailureType.recovery => l10n.captureRecoveryError,
  };
}
