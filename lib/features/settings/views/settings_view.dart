import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../models/local_ai_status.dart';
import '../repositories/local_ai_status_repository.dart';
import '../view_models/local_ai_status_cubit.dart';
import '../view_models/settings_cubit.dart';
import '../view_models/embedding_status_cubit.dart';
import '../../../core/ai/embedding/embedding_engine.dart';
import '../../../core/ai/model_management/model_lifecycle_state.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsCubit>().state.settings;
    final controller = context.read<SettingsCubit>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final isArabic = settings.localeCode == 'ar';
    final embeddingEngine = context.read<EmbeddingStatusCubit>().engine;
    return BlocProvider<LocalAiStatusCubit>(
      create: (_) => LocalAiStatusCubit(
        DeviceLocalAiStatusRepository(embeddingEngine: embeddingEngine),
      )..refresh(),
      child: BlocListener<LocalAiStatusCubit, LocalAiStatusState>(
        listenWhen: (previous, current) =>
            (previous is LocalAiStatusInstalling ||
                previous is LocalAiStatusRemoving) &&
            (current is LocalAiStatusLoaded || current is LocalAiStatusFailure),
        listener: (context, state) {
          context.read<EmbeddingStatusCubit>().refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Text(
              l10n.settingsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 22),
            Text(l10n.appearance, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: isDark,
                    onChanged: (value) => controller.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    ),
                    secondary: _SettingsIcon(
                      icon: Icons.dark_mode_outlined,
                      color: AppColors.blue,
                    ),
                    title: Text(l10n.darkMode),
                  ),
                  Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 18,
                    color: Theme.of(context).dividerColor,
                  ),
                  ListTile(
                    leading: _SettingsIcon(
                      icon: Icons.translate_rounded,
                      color: AppColors.cyan,
                    ),
                    title: Text(l10n.language),
                    trailing: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(l10n.arabic),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(l10n.english),
                        ),
                      ],
                      selected: {isArabic},
                      onSelectionChanged: (selection) => controller.setLocale(
                        Locale(selection.first ? 'ar' : 'en'),
                      ),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              l10n.modelStatus,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _ModelCard(l10n: l10n),
            const SizedBox(height: 14),
            const _EmbeddingModelCard(),
            const SizedBox(height: 26),
            Text(l10n.privacy, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SettingsIcon(
                      icon: Icons.shield_outlined,
                      color: Color(0xFF169C75),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.privacy,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.privacyBody,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(l10n.about, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.appName),
              subtitle: Text(l10n.version),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbeddingModelCard extends StatelessWidget {
  const _EmbeddingModelCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<EmbeddingStatusCubit, EmbeddingStatusState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        final title = switch (snapshot.capability) {
          EmbeddingCapability.ready => l10n.embeddingReady,
          EmbeddingCapability.modelNotInstalled => l10n.embeddingNotInstalled,
          EmbeddingCapability.unsupportedPlatform => l10n.embeddingUnsupported,
          EmbeddingCapability.runtimeFailure => l10n.embeddingRuntimeFailure,
          EmbeddingCapability.supported ||
          EmbeddingCapability.modelAccessRequired => l10n.embeddingWorking,
        };
        final details = snapshot.capability == EmbeddingCapability.ready
            ? l10n.embeddingReadyDetails(state.pendingInvoiceCount)
            : snapshot.capability == EmbeddingCapability.modelNotInstalled
            ? l10n.embeddingInstallRequirement
            : l10n.embeddingModelDetails;
        final showProgress =
            snapshot.progress != null &&
            (snapshot.status == ModelLifecycleStatus.downloading ||
                snapshot.status == ModelLifecycleStatus.verifying ||
                snapshot.status == ModelLifecycleStatus.loading ||
                snapshot.status == ModelLifecycleStatus.running ||
                snapshot.status == ModelLifecycleStatus.cancelling);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _SettingsIcon(
                      icon: Icons.manage_search_rounded,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.embeddingSearchModel,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      snapshot.canEmbed
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: snapshot.canEmbed
                          ? const Color(0xFF169C75)
                          : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(details, style: Theme.of(context).textTheme.bodySmall),
                if (snapshot.message?.trim().isNotEmpty == true &&
                    (snapshot.status == ModelLifecycleStatus.failed ||
                        snapshot.capability ==
                            EmbeddingCapability.runtimeFailure)) ...[
                  const SizedBox(height: 8),
                  Text(
                    snapshot.message!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (showProgress) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: snapshot.progress),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    if (state.busy &&
                        snapshot.status != ModelLifecycleStatus.cancelling)
                      TextButton(
                        onPressed: context.read<EmbeddingStatusCubit>().cancel,
                        child: Text(l10n.modelCancelInstall),
                      ),
                    TextButton(
                      onPressed: state.busy
                          ? null
                          : context.read<EmbeddingStatusCubit>().refresh,
                      child: Text(l10n.modelRefresh),
                    ),
                    if (snapshot.canEmbed && state.pendingInvoiceCount > 0)
                      FilledButton.tonal(
                        onPressed: state.busy
                            ? null
                            : context.read<EmbeddingStatusCubit>().reindex,
                        child: Text(l10n.reindexInvoices),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalAiStatusCubit, LocalAiStatusState>(
      builder: (context, state) {
        final presentation = _ModelStatusPresentation.fromState(l10n, state);
        return _buildCard(context, presentation);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    _ModelStatusPresentation presentation,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF1D4E91)],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.memory_rounded, color: AppColors.mint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  presentation.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(presentation.icon, color: presentation.iconColor),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            presentation.details,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          if (presentation.showProgress) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: presentation.progress,
                minHeight: 6,
                backgroundColor: const Color(0x3349D9BF),
                valueColor: const AlwaysStoppedAnimation(AppColors.mint),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              children: [
                if (presentation.canCancel)
                  TextButton(
                    onPressed: () =>
                        context.read<LocalAiStatusCubit>().cancelInstallation(),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(l10n.modelCancelInstall),
                  ),
                if (presentation.canInstall)
                  FilledButton.tonal(
                    onPressed: () =>
                        context.read<LocalAiStatusCubit>().installRequired(),
                    child: Text(l10n.modelInstall),
                  ),
                if (presentation.canRemove)
                  TextButton(
                    onPressed: () => _confirmRemoval(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.softWarning,
                    ),
                    child: Text(l10n.modelRemove),
                  ),
                if (presentation.canRefresh)
                  TextButton(
                    onPressed: () =>
                        context.read<LocalAiStatusCubit>().refresh(),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(l10n.modelRefresh),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoval(BuildContext context) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.modelRemove),
        content: Text(l10n.modelRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.modelRemove),
          ),
        ],
      ),
    );
    if (shouldRemove == true && context.mounted) {
      await context.read<LocalAiStatusCubit>().removeRequired();
    }
  }
}

class _ModelStatusPresentation {
  const _ModelStatusPresentation({
    required this.title,
    required this.details,
    required this.icon,
    required this.iconColor,
    required this.showProgress,
    required this.canRefresh,
    required this.canInstall,
    required this.canRemove,
    required this.canCancel,
    this.progress,
  });

  final String title;
  final String details;
  final IconData icon;
  final Color iconColor;
  final bool showProgress;
  final bool canRefresh;
  final bool canInstall;
  final bool canRemove;
  final bool canCancel;
  final double? progress;

  factory _ModelStatusPresentation.fromState(
    AppLocalizations l10n,
    LocalAiStatusState state,
  ) {
    if (state is LocalAiStatusLoading || state is LocalAiStatusInitial) {
      return _ModelStatusPresentation(
        title: l10n.modelChecking,
        details: l10n.modelRequirement,
        icon: Icons.hourglass_top_rounded,
        iconColor: AppColors.mint,
        showProgress: true,
        canRefresh: false,
        canInstall: false,
        canRemove: false,
        canCancel: false,
      );
    }
    if (state is LocalAiStatusInstalling) {
      final progress = state.progress;
      final downloaded = (progress.completedBytes / (1024 * 1024))
          .toStringAsFixed(1);
      final total = (progress.totalBytes / (1024 * 1024)).toStringAsFixed(1);
      return _ModelStatusPresentation(
        title: l10n.modelInstalling,
        details: '$downloaded / $total MiB',
        icon: Icons.downloading_rounded,
        iconColor: AppColors.mint,
        showProgress: true,
        progress: progress.fraction,
        canRefresh: false,
        canInstall: false,
        canRemove: false,
        canCancel: true,
      );
    }
    if (state is LocalAiStatusRemoving) {
      return _ModelStatusPresentation(
        title: l10n.modelRemoving,
        details: l10n.modelRemoveConfirm,
        icon: Icons.delete_sweep_outlined,
        iconColor: AppColors.warning,
        showProgress: true,
        canRefresh: false,
        canInstall: false,
        canRemove: false,
        canCancel: false,
      );
    }
    if (state is LocalAiStatusFailure) {
      final detail = state.message.trim();
      return _ModelStatusPresentation(
        title: l10n.modelError,
        details: detail.isEmpty
            ? l10n.modelInstallFailed
            : '${l10n.modelInstallFailed}\n$detail',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.warning,
        showProgress: false,
        canRefresh: true,
        canInstall: true,
        canRemove: false,
        canCancel: false,
      );
    }
    final readiness = (state as LocalAiStatusLoaded).status.readiness;
    return switch (readiness) {
      LocalAiReadiness.ready => _ModelStatusPresentation(
        title: l10n.modelReady,
        details: l10n.modelReadyDetails,
        icon: Icons.check_circle_rounded,
        iconColor: AppColors.mint,
        showProgress: true,
        progress: 1,
        canRefresh: true,
        canInstall: false,
        canRemove: true,
        canCancel: false,
      ),
      LocalAiReadiness.modelsNotInstalled => _ModelStatusPresentation(
        title: l10n.modelNotInstalled,
        details: l10n.modelRequirement,
        icon: Icons.download_for_offline_outlined,
        iconColor: AppColors.warning,
        showProgress: false,
        canRefresh: true,
        canInstall: true,
        canRemove: false,
        canCancel: false,
      ),
      LocalAiReadiness.modelVerificationFailed => _ModelStatusPresentation(
        title: l10n.modelVerificationFailed,
        details: l10n.modelRequirement,
        icon: Icons.gpp_bad_outlined,
        iconColor: AppColors.warning,
        showProgress: false,
        canRefresh: true,
        canInstall: true,
        canRemove: false,
        canCancel: false,
      ),
      LocalAiReadiness.interpreterArtifactIncompatible =>
        _ModelStatusPresentation(
          title: l10n.modelArtifactBlocked,
          details: l10n.modelRequirement,
          icon: Icons.extension_off_outlined,
          iconColor: AppColors.warning,
          showProgress: false,
          canRefresh: true,
          canInstall: false,
          canRemove: false,
          canCancel: false,
        ),
      LocalAiReadiness.unsupportedPlatform => _ModelStatusPresentation(
        title: l10n.modelUnsupported,
        details: l10n.modelRequirement,
        icon: Icons.phonelink_erase_rounded,
        iconColor: AppColors.warning,
        showProgress: false,
        canRefresh: true,
        canInstall: false,
        canRemove: false,
        canCancel: false,
      ),
      LocalAiReadiness.runtimeUnavailable => _ModelStatusPresentation(
        title: l10n.modelRuntimeUnavailable,
        details: l10n.modelRequirement,
        icon: Icons.memory_outlined,
        iconColor: AppColors.warning,
        showProgress: false,
        canRefresh: true,
        canInstall: false,
        canRemove: false,
        canCancel: false,
      ),
    };
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color),
    );
  }
}
