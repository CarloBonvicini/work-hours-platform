// Pannello aspetto con schede tema/colori/tipografia.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/appearance_tabs.dart';

enum AppearanceTab { theme, colors, typography }

class AppearanceSettingsPanel extends StatefulWidget {
  const AppearanceSettingsPanel({
    super.key,
    required this.isDarkTheme,
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onDarkThemeChanged,
    required this.onAppearanceSettingsChanged,
  });

  final bool isDarkTheme;
  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  State<AppearanceSettingsPanel> createState() =>
      AppearanceSettingsPanelState();
}

class AppearanceSettingsPanelState extends State<AppearanceSettingsPanel> {
  AppearanceTab _selectedTab = AppearanceTab.theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aspetto app',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        AppearanceTabs(
          selectedTab: _selectedTab,
          onTabChanged: (tab) => setState(() {
            _selectedTab = tab;
          }),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(_selectedTab),
            child: AppearanceTabContent(
              tab: _selectedTab,
              appearanceSettings: widget.appearanceSettings,
              isUpdatingThemeMode: widget.isUpdatingThemeMode,
              onDarkThemeChanged: widget.onDarkThemeChanged,
              onAppearanceSettingsChanged: widget.onAppearanceSettingsChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class AppearanceTabs extends StatelessWidget {
  const AppearanceTabs({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final AppearanceTab selectedTab;
  final ValueChanged<AppearanceTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (final tab in AppearanceTab.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AppearanceTabButton(
                  label: switch (tab) {
                    AppearanceTab.theme => 'Tema',
                    AppearanceTab.colors => 'Colori',
                    AppearanceTab.typography => 'Tipografia',
                  },
                  selected: selectedTab == tab,
                  onTap: () => onTabChanged(tab),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppearanceTabButton extends StatelessWidget {
  const AppearanceTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class AppearanceTabContent extends StatelessWidget {
  const AppearanceTabContent({
    super.key,
    required this.tab,
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onDarkThemeChanged,
    required this.onAppearanceSettingsChanged,
  });

  final AppearanceTab tab;
  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: switch (tab) {
        AppearanceTab.theme => ThemeAppearanceTab(
          appearanceSettings: appearanceSettings,
          isUpdatingThemeMode: isUpdatingThemeMode,
          onDarkThemeChanged: onDarkThemeChanged,
          onAppearanceSettingsChanged: onAppearanceSettingsChanged,
        ),
        AppearanceTab.colors => ColorsAppearanceTab(
          appearanceSettings: appearanceSettings,
          isUpdatingThemeMode: isUpdatingThemeMode,
          onAppearanceSettingsChanged: onAppearanceSettingsChanged,
        ),
        AppearanceTab.typography => TypographyAppearanceTab(
          appearanceSettings: appearanceSettings,
          isUpdatingThemeMode: isUpdatingThemeMode,
          onAppearanceSettingsChanged: onAppearanceSettingsChanged,
        ),
      },
    );
  }
}
