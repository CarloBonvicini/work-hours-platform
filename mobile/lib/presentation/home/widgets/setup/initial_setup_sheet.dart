// Primo avvio: le tre domande che bastano a far funzionare la giornata.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/logic/initial_setup_answers.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/settings_schedule_editor.dart';

/// Chiede giorni, orari e pausa al primo avvio.
///
/// Restituisce le risposte da salvare, oppure `null` se si rimanda: in quel
/// caso restano i valori di default e si configura piu tardi dalle
/// impostazioni.
Future<InitialSetupAnswers?> showInitialSetupSheet(BuildContext context) {
  return showDialog<InitialSetupAnswers>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const InitialSetupSheet(),
  );
}

class InitialSetupSheet extends StatefulWidget {
  const InitialSetupSheet({super.key});

  @override
  State<InitialSetupSheet> createState() => _InitialSetupSheetState();
}

class _InitialSetupSheetState extends State<InitialSetupSheet> {
  InitialSetupAnswers _answers = InitialSetupAnswers.defaults;

  Future<void> _pickTime({required bool isStart}) async {
    final currentMinutes = isStart
        ? _answers.startMinutes
        : _answers.endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
      helpText: isStart ? 'A che ora entri?' : 'A che ora esci?',
    );
    if (picked == null) {
      return;
    }

    final pickedMinutes = (picked.hour * 60) + picked.minute;
    setState(() {
      _answers = isStart
          ? _answers.copyWith(startMinutes: pickedMinutes)
          : _answers.copyWith(endMinutes: pickedMinutes);
    });
  }

  void _setWorkingDay(WeekdayKey weekday, bool isWorking) {
    final nextDays = Set<WeekdayKey>.from(_answers.workingDays);
    if (isWorking) {
      nextDays.add(weekday);
    } else {
      nextDays.remove(weekday);
    }
    setState(() {
      _answers = _answers.copyWith(workingDays: nextDays);
    });
  }

  void _setBreakMinutes(int minutes) {
    setState(() {
      _answers = _answers.copyWith(breakMinutes: minutes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _answers.problem;

    return AlertDialog(
      key: const ValueKey('initial-setup-sheet'),
      title: const Text('Come lavori di solito?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tre risposte e l app sa dirti quando puoi uscire. '
              'Puoi cambiarle quando vuoi da Orari e permessi.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _Question(label: 'Che giorni lavori?'),
            const SizedBox(height: 10),
            WorkingWeekdaySelector(
              selectedWeekdays: _answers.workingDays,
              onChanged: _setWorkingDay,
            ),
            const SizedBox(height: 20),
            _Question(label: 'Con che orario?'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    fieldKey: const ValueKey('initial-setup-start-time'),
                    label: 'Entrata',
                    value: formatTimeInput(_answers.startMinutes),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    fieldKey: const ValueKey('initial-setup-end-time'),
                    label: 'Uscita',
                    value: formatTimeInput(_answers.endMinutes),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Question(label: 'Quanta pausa?'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final minutes in const [0, 30, 60, 90])
                  ChoiceChip(
                    key: ValueKey('initial-setup-break-$minutes'),
                    selected: _answers.breakMinutes == minutes,
                    label: Text(minutes == 0 ? 'Nessuna' : '$minutes min'),
                    onSelected: (_) => _setBreakMinutes(minutes),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _Outcome(answers: _answers, problem: problem),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('initial-setup-skip-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Lo faccio dopo'),
        ),
        FilledButton(
          key: const ValueKey('initial-setup-confirm-button'),
          onPressed: problem == null
              ? () => Navigator.of(context).pop(_answers)
              : null,
          child: const Text('Inizia'),
        ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      key: fieldKey,
      onPressed: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Conferma in parole cosa comportano le risposte date finora.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.answers, required this.problem});

  final InitialSetupAnswers answers;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (problem != null) {
      return Text(
        problem!,
        key: const ValueKey('initial-setup-problem'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Text(
      'Farai ${formatHoursInput(answers.dailyTargetMinutes)} al giorno, '
      'per ${answers.workingDays.length} giorni a settimana.',
      key: const ValueKey('initial-setup-outcome'),
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
