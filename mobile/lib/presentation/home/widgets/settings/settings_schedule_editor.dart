// Editor dell'orario settimanale nelle impostazioni.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/logic/rule_value_labels.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/settings_section_panel.dart';

class DayScheduleEditorRow extends StatelessWidget {
  const DayScheduleEditorRow({
    super.key,
    required this.weekday,
    required this.targetController,
    required this.startTimeController,
    required this.endTimeController,
    required this.breakController,
    required this.hasLunchBreak,
    this.lunchBreakToggleKey,
    required this.onLunchBreakChanged,
    required this.onPickTarget,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickBreak,
  });

  final WeekdayKey weekday;
  final TextEditingController targetController;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final TextEditingController breakController;
  final bool hasLunchBreak;
  final Key? lunchBreakToggleKey;
  final ValueChanged<bool> onLunchBreakChanged;
  final Future<void> Function() onPickTarget;
  final Future<void> Function() onPickStartTime;
  final Future<void> Function() onPickEndTime;
  final Future<void> Function() onPickBreak;

  @override
  Widget build(BuildContext context) {
    return SettingsScheduleEditor(
      title: weekday.label,
      targetText: targetController.text,
      startTimeText: startTimeController.text,
      endTimeText: endTimeController.text,
      breakText: breakController.text,
      hasLunchBreak: hasLunchBreak,
      lunchBreakToggleKey: lunchBreakToggleKey,
      onLunchBreakChanged: onLunchBreakChanged,
      onPickTarget: onPickTarget,
      onPickStartTime: onPickStartTime,
      onPickEndTime: onPickEndTime,
      onPickBreak: onPickBreak,
    );
  }
}

class WorkingWeekdaySelector extends StatelessWidget {
  const WorkingWeekdaySelector({
    super.key,
    required this.selectedWeekdays,
    required this.onChanged,
  });

  final Set<WeekdayKey> selectedWeekdays;
  final void Function(WeekdayKey weekday, bool isWorking) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (var index = 0; index < WeekdayKey.values.length; index++) ...[
            Expanded(
              child: WorkingWeekdayToggle(
                key: ValueKey(
                  'work-settings-working-day-toggle-${WeekdayKey.values[index].name}',
                ),
                label: compactWeekdayLabel(WeekdayKey.values[index]),
                isSelected: selectedWeekdays.contains(WeekdayKey.values[index]),
                onTap: () => onChanged(
                  WeekdayKey.values[index],
                  !selectedWeekdays.contains(WeekdayKey.values[index]),
                ),
              ),
            ),
            if (index < WeekdayKey.values.length - 1)
              Container(
                width: 1,
                height: 28,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
              ),
          ],
        ],
      ),
    );
  }
}

class WorkingWeekdayToggle extends StatelessWidget {
  const WorkingWeekdayToggle({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScheduleEditor extends StatelessWidget {
  const SettingsScheduleEditor({
    super.key,
    required this.title,
    required this.targetText,
    required this.startTimeText,
    required this.endTimeText,
    required this.breakText,
    required this.hasLunchBreak,
    this.lunchBreakToggleKey,
    required this.onLunchBreakChanged,
    required this.onPickTarget,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickBreak,
  });

  final String title;
  final String targetText;
  final String startTimeText;
  final String endTimeText;
  final String breakText;
  final bool hasLunchBreak;
  final Key? lunchBreakToggleKey;
  final ValueChanged<bool> onLunchBreakChanged;
  final Future<void> Function() onPickTarget;
  final Future<void> Function() onPickStartTime;
  final Future<void> Function() onPickEndTime;
  final Future<void> Function() onPickBreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = <Widget>[
      SlimSettingsScheduleValue(
        label: 'Durata giornata',
        value: targetText.isEmpty ? '--' : targetText,
        icon: Icons.timelapse_rounded,
        kind: SettingsValueKind.duration,
        onTap: onPickTarget,
      ),
      SlimSettingsScheduleValue(
        label: 'Entrata',
        value: startTimeText.isEmpty ? '--:--' : startTimeText,
        icon: Icons.login_rounded,
        kind: SettingsValueKind.schedule,
        onTap: onPickStartTime,
      ),
      SlimSettingsScheduleValue(
        label: 'Uscita',
        value: endTimeText.isEmpty ? '--:--' : endTimeText,
        icon: Icons.logout_rounded,
        kind: SettingsValueKind.schedule,
        onTap: onPickEndTime,
      ),
    ];
    if (hasLunchBreak) {
      values.add(
        SlimSettingsScheduleValue(
          label: 'Pausa',
          value: formatSettingsBreakValue(breakText, isMinimumBreak: false),
          icon: Icons.coffee_outlined,
          kind: SettingsValueKind.duration,
          onTap: onPickBreak,
        ),
      );
    }
    final lunchBreakToggle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox.adaptive(
          key: lunchBreakToggleKey,
          value: hasLunchBreak,
          visualDensity: VisualDensity.compact,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onLunchBreakChanged(value);
          },
        ),
        Text(
          hasLunchBreak ? 'Si pausa pranzo' : 'Nessuna pausa pranzo',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: hasLunchBreak
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useHorizontalLayout = constraints.maxWidth >= 720;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (useHorizontalLayout)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          lunchBreakToggle,
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.start,
                            children: values,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                lunchBreakToggle,
                const SizedBox(height: 8),
                CenteredSettingsValuesWrap(
                  constraints: constraints,
                  values: values,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
