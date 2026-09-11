// Card impostazioni della vista giorno.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';

class DayCalendarSettingsCard extends StatelessWidget {
  const DayCalendarSettingsCard({
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

    Future<void> updateSettings(AppAppearanceSettings nextSettings) {
      return onAppearanceSettingsChanged(nextSettings);
    }

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sezione Oggi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Decidi cosa vuoi vedere e in che ordine nella sezione Oggi.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Formato layout',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<DayCalendarLayoutMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: DayCalendarLayoutMode.quickEditorFirst,
                  label: Text('Rapido sopra'),
                ),
                ButtonSegment(
                  value: DayCalendarLayoutMode.agendaFirst,
                  label: Text('Agenda sopra'),
                ),
              ],
              selected: {appearanceSettings.dayCalendarLayoutMode},
              onSelectionChanged: isUpdatingThemeMode
                  ? null
                  : (selection) => unawaited(
                      updateSettings(
                        appearanceSettings.copyWith(
                          dayCalendarLayoutMode: selection.first,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: appearanceSettings.showDayWorkdayCard,
              onChanged: isUpdatingThemeMode
                  ? null
                  : (value) => unawaited(
                      updateSettings(
                        appearanceSettings.copyWith(showDayWorkdayCard: value),
                      ),
                    ),
              title: const Text('Mostra "Giornata di oggi"'),
              subtitle: const Text(
                'Se preferisci, puoi usare solo modifica rapida e agenda oraria.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Campi della modifica rapida',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Entrata e durata restano sempre visibili. Attiva solo i campi opzionali che ti servono davvero.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  label: const Text('Uscita'),
                  selected: appearanceSettings.showDayEndTime,
                  onSelected: isUpdatingThemeMode
                      ? null
                      : (selected) => unawaited(
                          updateSettings(
                            appearanceSettings.copyWith(
                              showDayEndTime: selected,
                            ),
                          ),
                        ),
                ),
                FilterChip(
                  label: const Text('Pausa'),
                  selected: appearanceSettings.showDayBreakMinutes,
                  onSelected: isUpdatingThemeMode
                      ? null
                      : (selected) => unawaited(
                          updateSettings(
                            appearanceSettings.copyWith(
                              showDayBreakMinutes: selected,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
