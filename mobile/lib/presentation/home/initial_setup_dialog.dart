import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';

class InitialSetupConfiguration {
  const InitialSetupConfiguration({
    required this.useDarkTheme,
    required this.fullName,
    required this.useUniformDailyTarget,
    required this.dailyTargetMinutes,
    required this.weekdayTargetMinutes,
    required this.weekdaySchedule,
  });

  final bool useDarkTheme;
  final String fullName;
  final bool useUniformDailyTarget;
  final int dailyTargetMinutes;
  final WeekdayTargetMinutes weekdayTargetMinutes;
  final WeekdaySchedule weekdaySchedule;
}

class InitialSetupDialog extends StatefulWidget {
  const InitialSetupDialog({
    super.key,
    required this.initialProfile,
    required this.initialIsDarkTheme,
    required this.onCompleteInitialSetup,
    required this.onThemeModeChanged,
    required this.onSaveProfile,
  });

  final UserProfile initialProfile;
  final bool initialIsDarkTheme;
  final Future<void> Function() onCompleteInitialSetup;
  final Future<void> Function(bool useDarkTheme) onThemeModeChanged;
  final Future<void> Function(InitialSetupConfiguration configuration)
  onSaveProfile;

  @override
  State<InitialSetupDialog> createState() => _InitialSetupDialogState();
}

class _InitialSetupDialogState extends State<InitialSetupDialog> {
  final _nameController = TextEditingController();
  final _uniformDailyTargetController = TextEditingController();
  final _uniformStartTimeController = TextEditingController();
  final _uniformEndTimeController = TextEditingController();
  final _uniformBreakController = TextEditingController();
  final Map<WeekdayKey, TextEditingController> _weekdayControllers = {
    for (final weekday in WeekdayKey.values) weekday: TextEditingController(),
  };
  final Map<WeekdayKey, TextEditingController> _weekdayStartTimeControllers = {
    for (final weekday in WeekdayKey.values) weekday: TextEditingController(),
  };
  final Map<WeekdayKey, TextEditingController> _weekdayEndTimeControllers = {
    for (final weekday in WeekdayKey.values) weekday: TextEditingController(),
  };
  final Map<WeekdayKey, TextEditingController> _weekdayBreakControllers = {
    for (final weekday in WeekdayKey.values) weekday: TextEditingController(),
  };

  int _stepIndex = 0;
  bool _useDarkTheme = false;
  bool _useUniformDailyTarget = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _useDarkTheme = widget.initialIsDarkTheme;
    _useUniformDailyTarget = profile.useUniformDailyTarget;
    _nameController.text = profile.fullName;
    _uniformDailyTargetController.text = formatHoursInput(
      profile.dailyTargetMinutes,
    );
    _uniformStartTimeController.text =
        profile.weekdaySchedule.monday.startTime ?? '';
    _uniformEndTimeController.text = profile.weekdaySchedule.monday.endTime ?? '';
    _uniformBreakController.text = _formatBreakInput(
      profile.weekdaySchedule.monday.breakMinutes,
    );
    for (final weekday in WeekdayKey.values) {
      final daySchedule = profile.weekdaySchedule.forWeekday(weekday);
      _weekdayControllers[weekday]!.text = formatHoursInput(
        daySchedule.targetMinutes,
      );
      _weekdayStartTimeControllers[weekday]!.text = daySchedule.startTime ?? '';
      _weekdayEndTimeControllers[weekday]!.text = daySchedule.endTime ?? '';
      _weekdayBreakControllers[weekday]!.text = _formatBreakInput(
        daySchedule.breakMinutes,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _uniformDailyTargetController.dispose();
    _uniformStartTimeController.dispose();
    _uniformEndTimeController.dispose();
    _uniformBreakController.dispose();
    for (final controller in _weekdayControllers.values) {
      controller.dispose();
    }
    for (final controller in _weekdayStartTimeControllers.values) {
      controller.dispose();
    }
    for (final controller in _weekdayEndTimeControllers.values) {
      controller.dispose();
    }
    for (final controller in _weekdayBreakControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    if (_stepIndex < 2) {
      if (_stepIndex == 1 && _nameController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Inserisci il tuo nome per continuare.';
        });
        return;
      }

      setState(() {
        _errorMessage = null;
        _stepIndex += 1;
      });
      return;
    }

    final configuration = _buildConfiguration();
    if (configuration == null) {
      setState(() {
        _errorMessage =
            'Controlla gli orari inseriti e riprova. Puoi usare qualsiasi formato comune.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSaveProfile(configuration);
      await widget.onCompleteInitialSetup();
      await widget.onThemeModeChanged(configuration.useDarkTheme);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage =
            'Non siamo riusciti a salvare la configurazione iniziale. Riprova.';
      });
    }
  }

  InitialSetupConfiguration? _buildConfiguration() {
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      return null;
    }

    final weekdaySchedule = _buildWeekdaySchedule();
    if (weekdaySchedule == null) {
      return null;
    }
    final weekdayTargetMinutes = WeekdayTargetMinutes(
      monday: weekdaySchedule.monday.targetMinutes,
      tuesday: weekdaySchedule.tuesday.targetMinutes,
      wednesday: weekdaySchedule.wednesday.targetMinutes,
      thursday: weekdaySchedule.thursday.targetMinutes,
      friday: weekdaySchedule.friday.targetMinutes,
      saturday: weekdaySchedule.saturday.targetMinutes,
      sunday: weekdaySchedule.sunday.targetMinutes,
    );

    final dailyTargetMinutes = _useUniformDailyTarget
        ? parseHoursInput(_uniformDailyTargetController.text)
        : _averageWorkingDayTargetMinutes(weekdayTargetMinutes);
    if (dailyTargetMinutes == null) {
      return null;
    }

    return InitialSetupConfiguration(
      useDarkTheme: _useDarkTheme,
      fullName: fullName,
      useUniformDailyTarget: _useUniformDailyTarget,
      dailyTargetMinutes: dailyTargetMinutes,
      weekdayTargetMinutes: weekdayTargetMinutes,
      weekdaySchedule: weekdaySchedule,
    );
  }

  WeekdaySchedule? _buildWeekdaySchedule() {
    if (_useUniformDailyTarget) {
      final uniformMinutes = parseHoursInput(
        _uniformDailyTargetController.text,
      );
      if (uniformMinutes == null) {
        return null;
      }

      _uniformDailyTargetController.text = formatHoursInput(uniformMinutes);
      final startMinutes = parseTimeInput(_uniformStartTimeController.text);
      final endMinutes = parseTimeInput(_uniformEndTimeController.text);
      final hasStartTime = _uniformStartTimeController.text.trim().isNotEmpty;
      final hasEndTime = _uniformEndTimeController.text.trim().isNotEmpty;
      final breakMinutes = parseBreakDurationInput(_uniformBreakController.text);
      if (breakMinutes == null) {
        return null;
      }
      if (hasStartTime != hasEndTime) {
        return null;
      }
      if ((hasStartTime && startMinutes == null) || (hasEndTime && endMinutes == null)) {
        return null;
      }
      if ((!hasStartTime || !hasEndTime) && breakMinutes > 0) {
        return null;
      }
      if (startMinutes != null && endMinutes != null) {
        final elapsedMinutes = endMinutes - startMinutes;
        if (elapsedMinutes < 0 || breakMinutes > elapsedMinutes) {
          return null;
        }
        if ((elapsedMinutes - breakMinutes) != uniformMinutes) {
          return null;
        }
        _uniformStartTimeController.text = formatTimeInput(startMinutes);
        _uniformEndTimeController.text = formatTimeInput(endMinutes);
      }
      _uniformBreakController.text = _formatBreakInput(breakMinutes);
      return WeekdaySchedule.uniform(
        uniformMinutes,
        startTime: startMinutes == null ? null : formatTimeInput(startMinutes),
        endTime: endMinutes == null ? null : formatTimeInput(endMinutes),
        breakMinutes: breakMinutes,
      );
    }

    final parsedValues = <WeekdayKey, DaySchedule>{};
    for (final weekday in WeekdayKey.values) {
      final value = _parseDaySchedule(
        targetText: _weekdayControllers[weekday]!.text,
        startTimeText: _weekdayStartTimeControllers[weekday]!.text,
        endTimeText: _weekdayEndTimeControllers[weekday]!.text,
        breakText: _weekdayBreakControllers[weekday]!.text,
      );
      if (value == null) {
        return null;
      }
      parsedValues[weekday] = value;
    }

    return WeekdaySchedule(
      monday: parsedValues[WeekdayKey.monday]!,
      tuesday: parsedValues[WeekdayKey.tuesday]!,
      wednesday: parsedValues[WeekdayKey.wednesday]!,
      thursday: parsedValues[WeekdayKey.thursday]!,
      friday: parsedValues[WeekdayKey.friday]!,
      saturday: parsedValues[WeekdayKey.saturday]!,
      sunday: parsedValues[WeekdayKey.sunday]!,
    );
  }

  DaySchedule? _parseDaySchedule({
    required String targetText,
    required String startTimeText,
    required String endTimeText,
    required String breakText,
  }) {
    final targetMinutes = parseHoursInput(targetText);
    if (targetMinutes == null) {
      return null;
    }

    final normalizedStartTimeText = startTimeText.trim();
    final normalizedEndTimeText = endTimeText.trim();
    final hasStartTime = normalizedStartTimeText.isNotEmpty;
    final hasEndTime = normalizedEndTimeText.isNotEmpty;
    if (hasStartTime != hasEndTime) {
      return null;
    }

    final startMinutes = hasStartTime ? parseTimeInput(normalizedStartTimeText) : null;
    final endMinutes = hasEndTime ? parseTimeInput(normalizedEndTimeText) : null;
    if ((hasStartTime && startMinutes == null) || (hasEndTime && endMinutes == null)) {
      return null;
    }

    final breakMinutes = parseBreakDurationInput(breakText);
    if (breakMinutes == null) {
      return null;
    }
    if ((!hasStartTime || !hasEndTime) && breakMinutes > 0) {
      return null;
    }

    if (startMinutes != null && endMinutes != null) {
      final elapsedMinutes = endMinutes - startMinutes;
      if (elapsedMinutes < 0 || breakMinutes > elapsedMinutes) {
        return null;
      }
      if ((elapsedMinutes - breakMinutes) != targetMinutes) {
        return null;
      }
    }

    return DaySchedule(
      targetMinutes: targetMinutes,
      startTime: startMinutes == null ? null : formatTimeInput(startMinutes),
      endTime: endMinutes == null ? null : formatTimeInput(endMinutes),
      breakMinutes: breakMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configurazione iniziale ${_stepIndex + 1}/3'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_stepTitle),
            const SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: _buildStepContent())),
            if (_stepIndex == 2) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  'Puoi usare l app anche senza registrarti. Se piu avanti vorrai ritrovare profilo e impostazioni dopo una disinstallazione o su un altro dispositivo, attiva il backup cloud dalle Impostazioni.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9D3D2F),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_stepIndex > 0)
          TextButton(
            onPressed: _isSaving
                ? null
                : () {
                    setState(() {
                      _errorMessage = null;
                      _stepIndex -= 1;
                    });
                  },
            child: const Text('Indietro'),
          ),
        FilledButton(
          onPressed: _isSaving ? null : _continue,
          child: Text(
            _isSaving
                ? 'Salvo...'
                : _stepIndex == 2
                ? 'Inizia'
                : 'Continua',
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_stepIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scegli subito il tema che preferisci. Potrai cambiarlo anche dopo nelle impostazioni.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ThemeChoiceCard(
                  label: 'Chiaro',
                  icon: Icons.light_mode_outlined,
                  isSelected: !_useDarkTheme,
                  onTap: () {
                    setState(() {
                      _useDarkTheme = false;
                    });
                  },
                ),
                _ThemeChoiceCard(
                  label: 'Scuro',
                  icon: Icons.dark_mode_outlined,
                  isSelected: _useDarkTheme,
                  onTap: () {
                    setState(() {
                      _useDarkTheme = true;
                    });
                  },
                ),
              ],
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inserisci i dati base per personalizzare l app fin da subito.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Come ti chiami?'),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imposta il tuo orario standard con ore, inizio, fine e pausa. Potrai sempre modificarlo piu avanti o gestire eccezioni dal calendario.',
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _useUniformDailyTarget,
              onChanged: (value) {
                setState(() {
                  _useUniformDailyTarget = value;
                });
              },
              title: const Text('Stesse ore ogni giorno lavorativo'),
              subtitle: const Text(
                'Disattiva se vuoi inserire un orario diverso per ogni giorno.',
              ),
            ),
            const SizedBox(height: 12),
            if (_useUniformDailyTarget)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _uniformDailyTargetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Ore lun-ven',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _uniformStartTimeController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Inizio',
                        hintText: '08:30',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _uniformEndTimeController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Fine',
                        hintText: '17:00',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _uniformBreakController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Pausa',
                        hintText: '0:30',
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: WeekdayKey.values
                    .map(
                      (weekday) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InitialSetupDayRow(
                          weekday: weekday,
                          targetController: _weekdayControllers[weekday]!,
                          startTimeController:
                              _weekdayStartTimeControllers[weekday]!,
                          endTimeController:
                              _weekdayEndTimeControllers[weekday]!,
                          breakController: _weekdayBreakControllers[weekday]!,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 12),
            Text(
              'Se imposti inizio, fine e pausa, il totale deve tornare con le ore lavorate.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String get _stepTitle {
    switch (_stepIndex) {
      case 0:
        return 'Prima scegli l aspetto dell app';
      case 1:
        return 'Poi inserisci i tuoi dati';
      case 2:
        return 'Infine configura il tuo orario';
      default:
        return 'Configurazione iniziale';
    }
  }

  int _averageWorkingDayTargetMinutes(WeekdayTargetMinutes value) {
    final total =
        value.monday +
        value.tuesday +
        value.wednesday +
        value.thursday +
        value.friday;
    return (total / 5).round();
  }
}

String _formatBreakInput(int minutes) {
  return minutes == 0 ? '' : formatHoursInput(minutes);
}

class _InitialSetupDayRow extends StatelessWidget {
  const _InitialSetupDayRow({
    required this.weekday,
    required this.targetController,
    required this.startTimeController,
    required this.endTimeController,
    required this.breakController,
  });

  final WeekdayKey weekday;
  final TextEditingController targetController;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final TextEditingController breakController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            weekday.label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Ore'),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: startTimeController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(labelText: 'Inizio'),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: endTimeController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(labelText: 'Fine'),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: breakController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Pausa'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 180,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.5),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
