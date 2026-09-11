// Contenuto delle schede aspetto: tema, colori, tipografia.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/rgb_color_editor.dart';

class ThemeAppearanceTab extends StatelessWidget {
  const ThemeAppearanceTab({
    super.key,
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onDarkThemeChanged,
    required this.onAppearanceSettingsChanged,
  });

  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tema',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('Chiaro')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Scuro')),
            ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
          ],
          selected: {appearanceSettings.themeMode},
          onSelectionChanged: isUpdatingThemeMode
              ? null
              : (selection) => unawaited(
                  onAppearanceSettingsChanged(
                    appearanceSettings.copyWith(themeMode: selection.first),
                  ),
                ),
        ),
      ],
    );
  }
}

class ColorsAppearanceTab extends StatelessWidget {
  const ColorsAppearanceTab({
    super.key,
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onAppearanceSettingsChanged,
  });

  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor =
        appearanceSettings.textColor ?? Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RgbColorEditor(
          title: 'Colore principale',
          color: appearanceSettings.primaryColor,
          enabled: !isUpdatingThemeMode,
          onChanged: (color) => unawaited(
            onAppearanceSettingsChanged(
              appearanceSettings.copyWith(primaryColor: color),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 18),
        RgbColorEditor(
          title: 'Colore secondario',
          color: appearanceSettings.secondaryColor,
          enabled: !isUpdatingThemeMode,
          onChanged: (color) => unawaited(
            onAppearanceSettingsChanged(
              appearanceSettings.copyWith(secondaryColor: color),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 18),
        RgbColorEditor(
          title: 'Colore testo',
          color: effectiveTextColor,
          enabled: !isUpdatingThemeMode,
          onChanged: (color) => unawaited(
            onAppearanceSettingsChanged(
              appearanceSettings.copyWith(textColor: color),
            ),
          ),
        ),
      ],
    );
  }
}

class TypographyAppearanceTab extends StatelessWidget {
  const TypographyAppearanceTab({
    super.key,
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onAppearanceSettingsChanged,
  });

  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Font',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<AppFontFamily>(
          key: ValueKey(appearanceSettings.fontFamily),
          initialValue: appearanceSettings.fontFamily,
          decoration: const InputDecoration(labelText: 'Font del testo'),
          items: const [
            DropdownMenuItem(
              value: AppFontFamily.system,
              child: Text('Sistema'),
            ),
            DropdownMenuItem(
              value: AppFontFamily.sansSerif,
              child: Text('Sans serif'),
            ),
            DropdownMenuItem(value: AppFontFamily.serif, child: Text('Serif')),
            DropdownMenuItem(
              value: AppFontFamily.monospace,
              child: Text('Mono'),
            ),
            DropdownMenuItem(
              value: AppFontFamily.rounded,
              child: Text('Rounded'),
            ),
            DropdownMenuItem(
              value: AppFontFamily.condensed,
              child: Text('Condensed'),
            ),
          ],
          onChanged: isUpdatingThemeMode
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  unawaited(
                    onAppearanceSettingsChanged(
                      appearanceSettings.copyWith(fontFamily: value),
                    ),
                  );
                },
        ),
        const SizedBox(height: 18),
        Text(
          'Dimensione testo',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Slider(
          value: appearanceSettings.textScale,
          min: 0.8,
          max: 1.5,
          divisions: 14,
          onChanged: isUpdatingThemeMode
              ? null
              : (value) => unawaited(
                  onAppearanceSettingsChanged(
                    appearanceSettings.copyWith(textScale: value),
                  ),
                ),
        ),
        Text(
          '${textScaleLabel(appearanceSettings.textScale)} (${(appearanceSettings.textScale * 100).round()}%)',
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Testo standard',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Anteprima dal vivo del font e della dimensione scelta.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String textScaleLabel(double value) {
  if (value <= 0.95) {
    return 'Testo compatto';
  }
  if (value >= 1.18) {
    return 'Testo grande';
  }

  return 'Testo standard';
}
