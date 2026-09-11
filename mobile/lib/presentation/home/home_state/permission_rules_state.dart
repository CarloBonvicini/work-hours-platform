// Aggiunta, modifica e rimozione delle regole permessi/banche ore.

part of '../home_screen.dart';

mixin _PermissionRulesState on _HomeScreenStateBase {
  @override
  Future<void> _addPermissionRule({required bool leaveBank}) async {
    final rule = await _showPermissionRuleDialog(
      title: leaveBank ? 'Nuova causale permesso' : 'Nuovo permesso extra',
    );
    if (rule == null || !mounted) {
      return;
    }

    setState(() {
      if (leaveBank) {
        _rulesLeaveBanks = [..._rulesLeaveBanks, rule];
      } else {
        _rulesAdditionalPermissions = [..._rulesAdditionalPermissions, rule];
      }
    });
  }

  @override
  Future<void> _editPermissionRule({
    required bool leaveBank,
    required String ruleId,
  }) async {
    final sourceRules = leaveBank
        ? _rulesLeaveBanks
        : _rulesAdditionalPermissions;
    WorkPermissionRule? existingRule;
    for (final rule in sourceRules) {
      if (rule.id == ruleId) {
        existingRule = rule;
        break;
      }
    }
    if (existingRule == null) {
      return;
    }

    final updatedRule = await _showPermissionRuleDialog(
      title: leaveBank
          ? 'Modifica causale permesso'
          : 'Modifica permesso extra',
      initialRule: existingRule,
    );
    if (updatedRule == null || !mounted) {
      return;
    }

    setState(() {
      final nextRules = sourceRules
          .map((rule) => rule.id == ruleId ? updatedRule : rule)
          .toList(growable: false);
      if (leaveBank) {
        _rulesLeaveBanks = nextRules;
      } else {
        _rulesAdditionalPermissions = nextRules;
      }
    });
  }

  @override
  void _removePermissionRule({
    required bool leaveBank,
    required String ruleId,
  }) {
    setState(() {
      if (leaveBank) {
        _rulesLeaveBanks = _rulesLeaveBanks
            .where((rule) => rule.id != ruleId)
            .toList(growable: false);
      } else {
        _rulesAdditionalPermissions = _rulesAdditionalPermissions
            .where((rule) => rule.id != ruleId)
            .toList(growable: false);
      }
    });
  }

  Future<WorkPermissionRule?> _showPermissionRuleDialog({
    required String title,
    WorkPermissionRule? initialRule,
  }) async {
    final nameController = TextEditingController(text: initialRule?.name ?? '');
    final allowanceController = TextEditingController(
      text: formatHoursInput(initialRule?.allowanceMinutes ?? 0),
    );
    final usedController = TextEditingController(
      text: formatHoursInput(initialRule?.usedMinutes ?? 0),
    );
    final allowanceDaysController = TextEditingController(
      text: (initialRule?.allowanceDays ?? 0).toString(),
    );
    final usedDaysController = TextEditingController(
      text: (initialRule?.usedDays ?? 0).toString(),
    );
    var selectedPeriod = initialRule?.period ?? WorkAllowancePeriod.monthly;
    var selectedAllowanceType =
        initialRule?.allowanceType ?? WorkPermissionAllowanceType.hours;
    final selectedMovements = <WorkPermissionMovement>{
      ...(initialRule?.movements ??
          const [
            WorkPermissionMovement.entryLate,
            WorkPermissionMovement.exitEarly,
          ]),
    };
    var enabled = initialRule?.enabled ?? true;

    final createdRule = await showDialog<WorkPermissionRule>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome permesso',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WorkAllowancePeriod>(
                      initialValue: selectedPeriod,
                      decoration: const InputDecoration(labelText: 'Periodo'),
                      items: WorkAllowancePeriod.values
                          .map(
                            (period) => DropdownMenuItem(
                              value: period,
                              child: Text(period.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedPeriod = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tipologia causale',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: WorkPermissionAllowanceType.values
                          .map(
                            (allowanceType) => ChoiceChip(
                              label: Text(allowanceType.label),
                              selected: selectedAllowanceType == allowanceType,
                              onSelected: (selected) {
                                if (!selected) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedAllowanceType = allowanceType;
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    if (selectedAllowanceType.includesHours) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: allowanceController,
                        decoration: const InputDecoration(
                          labelText: 'Monte ore previsto (hh:mm)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usedController,
                        decoration: const InputDecoration(
                          labelText: 'Ore gia usate (hh:mm)',
                        ),
                      ),
                    ],
                    if (selectedAllowanceType.includesDays) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: allowanceDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monte giorni previsto',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usedDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Giorni gia usati',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (value) {
                        setDialogState(() {
                          enabled = value;
                        });
                      },
                      title: const Text('Permesso attivo'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Movimenti consentiti',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: WorkPermissionMovement.values
                          .map((movement) {
                            return FilterChip(
                              label: Text(movement.label),
                              selected: selectedMovements.contains(movement),
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedMovements.add(movement);
                                  } else {
                                    selectedMovements.remove(movement);
                                  }
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    int? parseDays(String value) {
                      final normalizedValue = value.trim();
                      if (normalizedValue.isEmpty) {
                        return 0;
                      }
                      final parsedValue = int.tryParse(normalizedValue);
                      if (parsedValue == null || parsedValue < 0) {
                        return null;
                      }
                      return parsedValue;
                    }

                    final allowanceMinutes = selectedAllowanceType.includesHours
                        ? parseHoursInput(allowanceController.text)
                        : 0;
                    final usedMinutes = selectedAllowanceType.includesHours
                        ? parseHoursInput(usedController.text)
                        : 0;
                    final allowanceDays = selectedAllowanceType.includesDays
                        ? parseDays(allowanceDaysController.text)
                        : 0;
                    final usedDays = selectedAllowanceType.includesDays
                        ? parseDays(usedDaysController.text)
                        : 0;
                    if (name.isEmpty ||
                        allowanceMinutes == null ||
                        usedMinutes == null ||
                        allowanceDays == null ||
                        usedDays == null ||
                        selectedMovements.isEmpty) {
                      return;
                    }

                    Navigator.of(context).pop(
                      WorkPermissionRule(
                        id:
                            initialRule?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        name: name,
                        enabled: enabled,
                        period: selectedPeriod,
                        allowanceType: selectedAllowanceType,
                        allowanceMinutes: allowanceMinutes,
                        usedMinutes: usedMinutes,
                        allowanceDays: allowanceDays,
                        usedDays: usedDays,
                        movements: selectedMovements.toList(growable: false),
                      ),
                    );
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );

    return createdRule;
  }
}
