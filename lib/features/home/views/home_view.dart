import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/invoice_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../../l10n/app_localizations.dart';
import '../../invoice_capture/models/invoice_image_draft.dart';
import '../../invoice_capture/view_models/invoice_capture_cubit.dart';
import '../../invoice_capture/view_models/invoice_capture_state.dart';
import '../../invoice_capture/widgets/capture_error_message.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<void> _selectImage(
    BuildContext context,
    BuildContext sheetContext,
    InvoiceImageSource source,
  ) async {
    Navigator.pop(sheetContext);
    final draft = await context.read<InvoiceCaptureCubit>().selectImage(source);
    if (draft != null && context.mounted) {
      context.push('/preview');
    }
  }

  void _showAddInvoiceSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.addInvoiceTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.addInvoiceBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _SourceTile(
                  icon: Icons.camera_alt_rounded,
                  title: l10n.useCamera,
                  color: AppColors.softBlue,
                  iconColor: AppColors.blue,
                  onTap: () => _selectImage(
                    context,
                    sheetContext,
                    InvoiceImageSource.camera,
                  ),
                ),
                const SizedBox(height: 10),
                _SourceTile(
                  icon: Icons.photo_library_rounded,
                  title: l10n.chooseGallery,
                  color: AppColors.softCyan,
                  iconColor: AppColors.cyan,
                  onTap: () => _selectImage(
                    context,
                    sheetContext,
                    InvoiceImageSource.gallery,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(l10n.cancel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<InvoiceCaptureCubit, InvoiceCaptureState>(
      listenWhen: (previous, current) =>
          current is InvoiceCaptureFailure ||
          current is InvoiceCaptureRecovered,
      listener: (context, state) {
        if (state is InvoiceCaptureRecovered) {
          context.push('/preview');
          return;
        }
        final failure = state as InvoiceCaptureFailure;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(captureErrorMessage(l10n, failure.type))),
        );
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(l10n.greeting, style: textTheme.headlineSmall),
                const SizedBox(height: 7),
                Text(l10n.greetingSubtitle, style: textTheme.bodyMedium),
                const SizedBox(height: 22),
                _HeroCard(onAdd: () => _showAddInvoiceSheet(context)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.receipt_long_rounded,
                        value: '24',
                        label: l10n.totalInvoices,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.trending_up_rounded,
                        value: '08',
                        label: l10n.thisMonth,
                        color: AppColors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SectionTitle(
                  title: l10n.recentInvoices,
                  action: l10n.viewAll,
                  onAction: () => context.go('/search'),
                ),
                const SizedBox(height: 10),
                ...MockData.invoices.map(
                  (invoice) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InvoiceCard(
                      invoice: invoice,
                      onTap: () => context.push('/details'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _PrivacyCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF1D4E91)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -34,
            top: -38,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 22,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: AppColors.mint,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          l10n.privateBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appTagline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.captureBody,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: l10n.addInvoice,
                icon: Icons.add_rounded,
                onPressed: onAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softMint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFF169C75)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.offlineFirst,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF167A61),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.noCloud,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF318E78),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_rounded,
            size: 20,
            color: Color(0xFF169C75),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(Icons.arrow_back_rounded, color: iconColor),
          ],
        ),
      ),
    );
  }
}
