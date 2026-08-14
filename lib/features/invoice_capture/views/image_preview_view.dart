import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../models/invoice_image_draft.dart';
import '../view_models/invoice_capture_cubit.dart';
import '../view_models/invoice_capture_state.dart';
import '../widgets/capture_error_message.dart';

class ImagePreviewView extends StatelessWidget {
  const ImagePreviewView({super.key});

  Future<void> _selectReplacement(
    BuildContext context,
    InvoiceImageSource source,
  ) async {
    await context.read<InvoiceCaptureCubit>().selectImage(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<InvoiceCaptureCubit, InvoiceCaptureState>(
      listenWhen: (previous, current) => current is InvoiceCaptureFailure,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              captureErrorMessage(l10n, (state as InvoiceCaptureFailure).type),
            ),
          ),
        );
      },
      child: BlocBuilder<InvoiceCaptureCubit, InvoiceCaptureState>(
        builder: (context, state) {
          final draft = state.draft;
          if (draft == null) {
            return Scaffold(
              appBar: AppBar(title: Text(l10n.previewTitle)),
              body: Center(
                child: TextButton(
                  onPressed: () => context.go('/'),
                  child: Text(l10n.addInvoice),
                ),
              ),
            );
          }

          final isSelecting = state is InvoiceCaptureSelecting;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () async {
                  await context
                      .read<InvoiceCaptureCubit>()
                      .discardCurrentDraft();
                  if (context.mounted) context.pop();
                },
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              title: Text(l10n.previewTitle),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.previewBody,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    _InvoiceImagePreview(draft: draft),
                    const SizedBox(height: 12),
                    _ImageMetadata(draft: draft),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSelecting
                                ? null
                                : () =>
                                      _selectReplacement(context, draft.source),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.retake),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: l10n.useImage,
                            icon: Icons.arrow_back_rounded,
                            singleLine: true,
                            onPressed: isSelecting
                                ? null
                                : () => context.push('/processing'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.center,
                      child: TextButton.icon(
                        onPressed: isSelecting
                            ? null
                            : () => _selectReplacement(
                                context,
                                draft.source == InvoiceImageSource.camera
                                    ? InvoiceImageSource.gallery
                                    : InvoiceImageSource.camera,
                              ),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(l10n.chooseAnotherSource),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceImagePreview extends StatelessWidget {
  const _InvoiceImagePreview({required this.draft});

  final InvoiceImageDraft draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 520),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE4EAF2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Image.file(
        File(draft.path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          height: 260,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: AppColors.danger),
          ),
        ),
      ),
    );
  }
}

class _ImageMetadata extends StatelessWidget {
  const _ImageMetadata({required this.draft});

  final InvoiceImageDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = draft.source == InvoiceImageSource.camera
        ? l10n.sourceCamera
        : l10n.sourceGallery;
    final sizeInMegabytes = (draft.byteLength / (1024 * 1024)).toStringAsFixed(
      1,
    );
    return Text(
      '$source - ${draft.width} × ${draft.height} - $sizeInMegabytes MB',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
    );
  }
}
