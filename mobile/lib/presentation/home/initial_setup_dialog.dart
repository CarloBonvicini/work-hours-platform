import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';

class InitialSetupConfiguration {
  const InitialSetupConfiguration({
    required this.useDarkTheme,
    required this.fullName,
    required this.useUniformDailyTarget,
    required this.dailyTargetMinutes,
    required this.weekdayTargetMinutes,
  });

  final bool useDarkTheme;
  final String fullName;
  final bool useUniformDailyTarget;
  final int dailyTargetMinutes;
  final WeekdayTargetMinutes weekdayTargetMinutes;
}

class InitialSetupDialog extends StatefulWidget {
  const InitialSetupDialog({
    super.key,
    required this.initialProfile,
    required this.initialIsDarkTheme,
    required this.onThemeModeChanged,
    required this.onSaveProfile,
  });

  final UserProfile initialProfile;
  final bool initialIsDarkTheme;
  final Future<void> Function(bool useDarkTheme) onThemeModeChanged;
  final Future<void> Function(InitialSetupConfiguration configuration)
  onSaveProfile;

  @override
  State<InitialSetupDialog> createState() => _InitialSetupDialogState();
}

class _InitialSetupDialogState extends State<InitialSetupDialog> {
  final _nameController = TextEditingController();
  final _uniformDailyTargetController = TextEditingController();
  final Map<WeekdayKey, TextEditingController> _weekdayControllers = {
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
    for (final weekday in WeekdayKey.values) {
      _weekdayControllers[weekday]!.text = formatHoursInput(
        profile.weekdayTargetMinutes.forWeekday(weekday),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _uniformDailyTargetController.dispose();
    for (final controller in _weekdayControllers.values) {
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
      await widget.onThemeModeChanged(configuration.useDarkTheme);
      await widget.onSaveProfile(configuration);
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

    final weekdayTargetMinutes = _buildWeekdayTargetMinutes();
    if (weekdayTargetMinutes == null) {
      return null;
    }

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
    );
  }

  WeekdayTargetMinutes? _buildWeekdayTargetMinutes() {
    if (_useUniformDailyTarget) {
      final uniformMinutes = parseHoursInput(
        _uniformDailyTargetController.text,
      );
      if (uniformMinutes == null) {
        return null;
      }

      _uniformDailyTargetController.text = formatHoursInput(uniformMinutes);
      return WeekdayTargetMinutes(
        monday: uniformMinutes,
        tuesday: uniformMinutes,
        wednesday: uniformMinutes,
        thursday: uniformMinutes,
        friday: uniformMinutes,
        saturday: 0,
        sunday: 0,
      );
    }

    final parsedValues = <WeekdayKey, int>{};
    for (final weekday in WeekdayKey.values) {
      final value = parseHoursInput(_weekdayControllers[weekday]!.text);
      if (value == null) {
        return null;
      }
      _weekdayControllers[weekday]!.text = formatHoursInput(value);
      parsedValues[weekday] = value;
    }

    return WeekdayTargetMinutes(
      monday: parsedValues[WeekdayKey.monday]!,
      tuesday: parsedValues[WeekdayKey.tuesday]!,
      wednesday: parsedValues[WeekdayKey.wednesday]!,
      thursday: parsedValues[WeekdayKey.thursday]!,
      friday: parsedValues[WeekdayKey.friday]!,
      saturday: parsedValues[WeekdayKey.saturday]!,
      sunday: parsedValues[WeekdayKey.sunday]!,
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
              'Imposta l orario che fai di solito. Potrai sempre modificarlo piu avanti o gestire eccezioni dal calendario.',
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
              TextField(
                controller: _uniformDailyTargetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Ore standard lun-ven',
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: WeekdayKey.values
                    .map(
                      (weekday) => SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _weekdayControllers[weekday],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(labelText: weekday.label),
                        ),
                      ),
                    )
                    .toList(growable: false),
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
