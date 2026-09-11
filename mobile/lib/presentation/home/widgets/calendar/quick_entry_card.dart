// Card di inserimento rapido di ore o causali.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/entry_fields.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/section_cards.dart';

enum QuickEntryMode { work, leave }

class QuickEntryCard extends StatelessWidget {
  const QuickEntryCard({
    super.key,
    required this.formKey,
    required this.selectedEntryMode,
    required this.onEntryModeChanged,
    required this.selectedLeaveType,
    required this.onLeaveTypeChanged,
    required this.dateController,
    required this.minutesController,
    required this.noteController,
    required this.minutePresets,
    required this.onMinutePresetSelected,
    required this.isBusy,
    required this.onPickDate,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final QuickEntryMode selectedEntryMode;
  final ValueChanged<QuickEntryMode> onEntryModeChanged;
  final LeaveType selectedLeaveType;
  final ValueChanged<LeaveType> onLeaveTypeChanged;
  final TextEditingController dateController;
  final TextEditingController minutesController;
  final TextEditingController noteController;
  final List<int> minutePresets;
  final ValueChanged<int> onMinutePresetSelected;
  final bool isBusy;
  final Future<void> Function() onPickDate;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final isWorkMode = selectedEntryMode == QuickEntryMode.work;

    return SectionCard(
      title: 'Inserimento rapido',
      subtitle: isWorkMode
          ? 'Registra le ore di oggi in pochi tocchi.'
          : 'Registra subito ferie o permessi.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Ore lavorate'),
                  selected: isWorkMode,
                  onSelected: isBusy
                      ? null
                      : (_) => onEntryModeChanged(QuickEntryMode.work),
                ),
                ChoiceChip(
                  label: const Text('Ferie o permesso'),
                  selected: !isWorkMode,
                  onSelected: isBusy
                      ? null
                      : (_) => onEntryModeChanged(QuickEntryMode.leave),
                ),
              ],
            ),
            if (!isWorkMode) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: LeaveType.values
                    .map(
                      (leaveType) => ChoiceChip(
                        label: Text(leaveType.label),
                        selected: leaveType == selectedLeaveType,
                        onSelected: isBusy
                            ? null
                            : (_) => onLeaveTypeChanged(leaveType),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 18),
            DateField(controller: dateController, onPickDate: onPickDate),
            const SizedBox(height: 14),
            MinutesField(
              controller: minutesController,
              label: isWorkMode ? 'Minuti lavorati' : 'Minuti di assenza',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: minutePresets
                  .map(
                    (minutes) => ActionChip(
                      label: Text(formatHours(minutes)),
                      onPressed: () => onMinutePresetSelected(minutes),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isWorkMode ? 'Nota opzionale' : 'Motivo opzionale',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: isBusy ? null : () => onSubmit(),
              icon: Icon(
                isWorkMode
                    ? Icons.add_task_outlined
                    : Icons.event_available_outlined,
              ),
              label: Text(
                isBusy
                    ? 'Invio...'
                    : isWorkMode
                    ? 'Registra ore'
                    : 'Registra assenza',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
