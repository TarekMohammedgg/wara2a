import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = AppControllerScope.of(context);
    final isDark = controller.themeMode == ThemeMode.dark;
    final isArabic = controller.locale.languageCode == 'ar';
    return ListView(
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
                    ButtonSegment<bool>(value: true, label: Text(l10n.arabic)),
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
        Text(l10n.modelStatus, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _ModelCard(l10n: l10n),
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
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.mint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.modelReady,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: AppColors.mint),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            l10n.modelSize,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 1,
              minHeight: 6,
              backgroundColor: Color(0x3349D9BF),
              valueColor: AlwaysStoppedAnimation(AppColors.mint),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(l10n.installModel),
            ),
          ),
        ],
      ),
    );
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
