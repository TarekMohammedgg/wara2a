import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';

class ImagePreviewView extends StatelessWidget {
  const ImagePreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
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
              const _InvoiceImagePlaceholder(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.pop(),
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
                      onPressed: () => context.push('/processing'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceImagePlaceholder extends StatelessWidget {
  const _InvoiceImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 430,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EAF2),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 5),
      ),
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.72,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 50,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 8,
                      color: const Color(0xFFE0E5EC),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                _Line(width: 0.72, height: 12, color: AppColors.navy),
                const SizedBox(height: 10),
                _Line(width: 0.48),
                const SizedBox(height: 26),
                ...List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _InvoiceRow(index: index),
                  ),
                ),
                const Spacer(),
                const Divider(height: 1, color: Color(0xFFE3E8EF)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _FixedLine(width: 32, height: 10),
                    const _FixedLine(
                      width: 48,
                      height: 13,
                      color: AppColors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 18, height: 18, color: const Color(0xFFF0F3F7)),
            const SizedBox(width: 8),
            _FixedLine(width: index.isEven ? 42 : 54, height: 8),
          ],
        ),
        const _FixedLine(width: 24, height: 8),
      ],
    );
  }
}

class _FixedLine extends StatelessWidget {
  const _FixedLine({
    required this.width,
    this.height = 7,
    this.color = const Color(0xFFDCE3EC),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.width,
    this.height = 7,
    this.color = const Color(0xFFDCE3EC),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
