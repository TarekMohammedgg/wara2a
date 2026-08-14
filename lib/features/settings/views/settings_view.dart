import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../view_models/settings_cubit.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsCubit>().state.settings;
    final controller = context.read<SettingsCubit>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final isArabic = settings.localeCode == 'ar';
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
        Text(
          l10n.openRouterApiKeyLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _OpenRouterApiKeyCard(
          apiKey: settings.openRouterApiKey,
          onApiKeyChanged: controller.setOpenRouterApiKey,
        ),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          value: settings.cloudProcessingConsent,
          onChanged: controller.setCloudProcessingConsent,
          title: Text(l10n.cloudProcessingConsentTitle),
          subtitle: Text(l10n.cloudProcessingConsentBody),
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
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          leading: const Icon(Icons.shield_outlined),
          title: Text(l10n.privacy),
          subtitle: Text(l10n.privacyBody),
        ),
      ],
    );
  }
}

class _OpenRouterApiKeyCard extends StatefulWidget {
  const _OpenRouterApiKeyCard({
    required this.apiKey,
    required this.onApiKeyChanged,
  });

  final String? apiKey;
  final ValueChanged<String?> onApiKeyChanged;

  @override
  State<_OpenRouterApiKeyCard> createState() => _OpenRouterApiKeyCardState();
}

class _OpenRouterApiKeyCardState extends State<_OpenRouterApiKeyCard> {
  late final TextEditingController _apiKeyController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.apiKey ?? '');
  }

  @override
  void didUpdateWidget(covariant _OpenRouterApiKeyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.apiKey ?? '';
    if (next != _apiKeyController.text) {
      _apiKeyController.text = next;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.extractionModeCloudDetails,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: l10n.openRouterApiKeyHint,
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                  icon: Icon(
                    _obscureApiKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onChanged: widget.onApiKeyChanged,
              onSubmitted: widget.onApiKeyChanged,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.openRouterExperimentalNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
