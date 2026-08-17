import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../l10n/app_localizations.dart';

class LandingView extends StatelessWidget {
  const LandingView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.softCyan, AppColors.canvas],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const BrandLogo(),
                    const SizedBox(height: 48),
                    Container(
                      width: 172,
                      height: 172,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(42),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blue.withValues(alpha: 0.14),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        AppImages.wara2aAppIcon,
                        semanticLabel: l10n.appName,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      l10n.landingTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.landingBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 28),
                    _Highlights(
                      labels: [
                        l10n.landingCapture,
                        l10n.landingSearch,
                        l10n.landingOrganize,
                      ],
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(l10n.landingStart),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.camera_alt_outlined,
      Icons.search_rounded,
      Icons.folder_open_outlined,
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        labels.length,
        (index) => Chip(
          avatar: Icon(icons[index], size: 17, color: AppColors.blue),
          label: Text(labels[index]),
        ),
      ),
    );
  }
}
