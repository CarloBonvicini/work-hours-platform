// Impostazioni orario settimanale e regole: controller, pick e costruzione delle regole.

part of '../home_screen.dart';

mixin _WorkScheduleSettingsState on _HomeScreenStateBase {
  @override
  WeekdayKey _weekdayKeyForDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return WeekdayKey.monday;
      case DateTime.tuesday:
        return WeekdayKey.tuesday;
      case DateTime.wednesday:
        return WeekdayKey.wednesday;
      case DateTime.thursday:
        return WeekdayKey.thursday;
      case DateTime.friday:
        return WeekdayKey.friday;
      case DateTime.saturday:
        return WeekdayKey.saturday;
      default:
        return WeekdayKey.sunday;
    }
  }

  @override
  Future<void> _openSelectedWeekdayStandardWorkSettings() async {
    final weekday = _weekdayKeyForDate(_selectedDate);
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSection = HomeSection.workSettings;
    });
    final appearanceSettings = widget.appearanceSettings;
    if (!appearanceSettings.expandWorkSettingsSchedule) {
      await _updateAppearanceSettings(
        appearanceSettings.copyWith(expandWorkSettingsSchedule: true),
      );
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Apri Orario di lavoro e modifica il giorno ${weekday.label}.',
        ),
      ),
    );
  }

  @override
  void _openWorkSettingsSectionFromSummary() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedSection = HomeSection.workSettings;
    });
  }

  @override
  Future<void> _pickUniformTargetMinutes() async {
    final currentTargetMinutes =
        parseHoursInput(_uniformDailyTargetController.text) ?? 8 * 60;
    final pickedMinutes = await _showScheduleTargetWheelPicker(
      title: 'Ore giornaliere',
      initialMinutes: currentTargetMinutes,
    );
    if (pickedMinutes == null) {
      return;
    }

    _uniformDailyTargetController.text = formatHoursInput(pickedMinutes);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Future<void> _pickUniformScheduleTime(CalendarTimeField field) async {
    final controller = switch (field) {
      CalendarTimeField.start => _uniformStartTimeController,
      CalendarTimeField.end => _uniformEndTimeController,
    };
    final initialMinutes =
        parseTimeInput(controller.text) ??
        (field == CalendarTimeField.start ? 9 * 60 : 18 * 60);
    final pickedSelection = await _showScheduleTimeWheelPicker(
      title: field == CalendarTimeField.start ? 'Entrata' : 'Uscita',
      initialMinutes: initialMinutes,
      allowClear: controller.text.trim().isNotEmpty,
    );
    if (pickedSelection == null) {
      return;
    }

    if (pickedSelection.cleared) {
      controller.clear();
    } else {
      controller.text = formatTimeInput(pickedSelection.minutes!);
    }
    _syncProfileTargetFromTimes();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Future<void> _pickUniformBreakMinutes() async {
    final currentBreakMinutes =
        parseBreakDurationInput(_uniformBreakController.text) ?? 0;
    final pickedMinutes = await _showScheduleBreakWheelPicker(
      initialMinutes: currentBreakMinutes,
    );
    if (pickedMinutes == null) {
      return;
    }

    _uniformBreakController.text = formatBreakInput(pickedMinutes);
    _syncProfileTargetFromTimes();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Future<void> _pickWeekdayTargetMinutes(WeekdayKey weekday) async {
    final controller = _weekdayControllers[weekday]!;
    final currentTargetMinutes = parseHoursInput(controller.text) ?? 8 * 60;
    final pickedMinutes = await _showScheduleTargetWheelPicker(
      title: 'Ore ${weekday.label.toLowerCase()}',
      initialMinutes: currentTargetMinutes,
    );
    if (pickedMinutes == null) {
      return;
    }

    controller.text = formatHoursInput(pickedMinutes);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Future<void> _pickWeekdayScheduleTime(
    WeekdayKey weekday,
    CalendarTimeField field,
  ) async {
    final controller = switch (field) {
      CalendarTimeField.start => _weekdayStartTimeControllers[weekday]!,
      CalendarTimeField.end => _weekdayEndTimeControllers[weekday]!,
    };
    final initialMinutes =
        parseTimeInput(controller.text) ??
        (field == CalendarTimeField.start ? 9 * 60 : 18 * 60);
    final pickedSelection = await _showScheduleTimeWheelPicker(
      title:
          '${field == CalendarTimeField.start ? 'Entrata' : 'Uscita'} ${weekday.label.toLowerCase()}',
      initialMinutes: initialMinutes,
      allowClear: controller.text.trim().isNotEmpty,
    );
    if (pickedSelection == null) {
      return;
    }

    if (pickedSelection.cleared) {
      controller.clear();
    } else {
      controller.text = formatTimeInput(pickedSelection.minutes!);
    }
    _syncProfileTargetFromTimes(weekday: weekday);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Future<void> _pickWeekdayBreakMinutes(WeekdayKey weekday) async {
    final controller = _weekdayBreakControllers[weekday]!;
    final currentBreakMinutes = parseBreakDurationInput(controller.text) ?? 0;
    final pickedMinutes = await _showScheduleBreakWheelPicker(
      initialMinutes: currentBreakMinutes,
    );
    if (pickedMinutes == null) {
      return;
    }

    controller.text = formatBreakInput(pickedMinutes);
    _syncProfileTargetFromTimes(weekday: weekday);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void _setUniformLunchBreakEnabled(bool enabled) {
    _setLunchBreakEnabled(
      breakController: _uniformBreakController,
      enabled: enabled,
    );
  }

  @override
  void _setWeekdayLunchBreakEnabled(WeekdayKey weekday, bool enabled) {
    _setLunchBreakEnabled(
      breakController: _weekdayBreakControllers[weekday]!,
      enabled: enabled,
      weekday: weekday,
    );
  }

  @override
  void _setWeekdayWorkingEnabled(WeekdayKey weekday, bool enabled) {
    final targetController = _weekdayControllers[weekday]!;
    final startController = _weekdayStartTimeControllers[weekday]!;
    final endController = _weekdayEndTimeControllers[weekday]!;
    final breakController = _weekdayBreakControllers[weekday]!;

    if (!enabled) {
      targetController.text = formatHoursInput(0);
      startController.clear();
      endController.clear();
      breakController.clear();
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final currentTargetMinutes =
        resolveDraftTargetMinutes(
          targetText: targetController.text,
          startTimeText: startController.text,
          endTimeText: endController.text,
          breakText: breakController.text,
        ) ??
        0;
    if (currentTargetMinutes <= 0) {
      final fallbackTargetMinutes =
          parseHoursInput(_uniformDailyTargetController.text) ??
          parseHoursInput(_rulesExpectedDailyController.text) ??
          8 * 60;
      targetController.text = formatHoursInput(fallbackTargetMinutes);
    }

    final uniformStart = _uniformStartTimeController.text.trim();
    final uniformEnd = _uniformEndTimeController.text.trim();
    final uniformBreak = _uniformBreakController.text.trim();
    if (startController.text.trim().isEmpty && uniformStart.isNotEmpty) {
      startController.text = uniformStart;
    }
    if (endController.text.trim().isEmpty && uniformEnd.isNotEmpty) {
      endController.text = uniformEnd;
    }
    if (breakController.text.trim().isEmpty && uniformBreak.isNotEmpty) {
      breakController.text = uniformBreak;
    }

    _syncProfileTargetFromTimes(weekday: weekday);
    if (mounted) {
      setState(() {});
    }
  }

  void _setLunchBreakEnabled({
    required TextEditingController breakController,
    required bool enabled,
    WeekdayKey? weekday,
  }) {
    final currentBreakMinutes =
        parseBreakDurationInput(breakController.text) ?? 0;
    if (enabled && currentBreakMinutes <= 0) {
      breakController.text = formatBreakInput(_defaultLunchBreakMinutes());
    } else if (!enabled) {
      breakController.text = formatBreakInput(0);
    }

    _syncProfileTargetFromTimes(weekday: weekday);
    if (mounted) {
      setState(() {});
    }
  }

  int _defaultLunchBreakMinutes() {
    final configuredMinimumBreakMinutes = parseBreakDurationInput(
      _rulesMinimumBreakController.text,
    );
    if (configuredMinimumBreakMinutes != null &&
        configuredMinimumBreakMinutes > 0) {
      return configuredMinimumBreakMinutes;
    }

    final uniformBreakMinutes = parseBreakDurationInput(
      _uniformBreakController.text,
    );
    if (uniformBreakMinutes != null && uniformBreakMinutes > 0) {
      return uniformBreakMinutes;
    }

    return 30;
  }

  @override
  UserWorkRules? _buildWorkRulesFromControllers({
    required WeekdaySchedule weekdaySchedule,
  }) {
    final expectedDailyMinutes = _useUniformDailyTarget
        ? weekdaySchedule.monday.targetMinutes
        : _averageWorkingDayTargetMinutes(
            _deriveWeekdayTargetMinutesFromSchedule(weekdaySchedule),
          );
    final minimumBreakMinutes = parseBreakDurationInput(
      _rulesMinimumBreakController.text,
    );
    final maximumDailyCreditMinutes = parseHoursInput(
      _rulesMaximumDailyCreditController.text,
    );
    final maximumDailyDebitMinutes = parseHoursInput(
      _rulesMaximumDailyDebitController.text,
    );
    final maximumMonthlyCreditMinutes = parseHoursInput(
      _rulesMaximumMonthlyCreditController.text,
    );
    final maximumMonthlyDebitMinutes = parseHoursInput(
      _rulesMaximumMonthlyDebitController.text,
    );
    final overtimeDailyCapMinutes = parseHoursInput(
      _rulesOvertimeDailyCapController.text,
    );
    final overtimeWeeklyCapMinutes = parseHoursInput(
      _rulesOvertimeWeeklyCapController.text,
    );
    final overtimeMonthlyCapMinutes = parseHoursInput(
      _rulesOvertimeMonthlyCapController.text,
    );
    final flexibleStartWindowMinutes = parseHoursInput(
      _rulesFlexibleStartWindowController.text,
    );
    final walletDailyExitEarlyMinutes = parseHoursInput(
      _rulesWalletDailyExitController.text,
    );
    final walletWeeklyExitEarlyMinutes = parseHoursInput(
      _rulesWalletWeeklyExitController.text,
    );
    final implicitCreditDailyCapMinutes = parseHoursInput(
      _rulesImplicitCreditDailyCapController.text,
    );

    if (minimumBreakMinutes == null ||
        maximumDailyCreditMinutes == null ||
        maximumDailyDebitMinutes == null ||
        maximumMonthlyCreditMinutes == null ||
        maximumMonthlyDebitMinutes == null ||
        overtimeDailyCapMinutes == null ||
        overtimeWeeklyCapMinutes == null ||
        overtimeMonthlyCapMinutes == null ||
        flexibleStartWindowMinutes == null ||
        walletDailyExitEarlyMinutes == null ||
        walletWeeklyExitEarlyMinutes == null ||
        implicitCreditDailyCapMinutes == null) {
      return null;
    }

    final effectiveFixedScheduleEnabled = _rulesFixedScheduleEnabled;
    final effectiveFlexibleStartEnabled =
        _rulesFlexibleStartEnabled && effectiveFixedScheduleEnabled;

    return UserWorkRules(
      expectedDailyMinutes: expectedDailyMinutes,
      minimumBreakMinutes: minimumBreakMinutes,
      maximumDailyCreditMinutes: maximumDailyCreditMinutes,
      maximumDailyDebitMinutes: maximumDailyDebitMinutes,
      maximumMonthlyCreditMinutes: maximumMonthlyCreditMinutes,
      maximumMonthlyDebitMinutes: maximumMonthlyDebitMinutes,
      overtimeEnabled: _rulesOvertimeEnabled,
      overtimeCapEnabled: _rulesOvertimeCapEnabled,
      overtimeDailyCapMinutes: overtimeDailyCapMinutes,
      overtimeWeeklyCapMinutes: overtimeWeeklyCapMinutes,
      overtimeMonthlyCapMinutes: overtimeMonthlyCapMinutes,
      fixedScheduleEnabled: effectiveFixedScheduleEnabled,
      flexibleStartEnabled: effectiveFlexibleStartEnabled,
      flexibleStartWindowMinutes: flexibleStartWindowMinutes,
      walletEnabled: _rulesWalletEnabled,
      walletDailyExitEarlyMinutes: walletDailyExitEarlyMinutes,
      walletWeeklyExitEarlyMinutes: walletWeeklyExitEarlyMinutes,
      implicitCreditEnabled: _rulesImplicitCreditEnabled,
      implicitCreditDailyCapMinutes: implicitCreditDailyCapMinutes,
      pauseAdjustmentMode: _rulesPauseAdjustmentMode,
      additionalPermissions: List<WorkPermissionRule>.from(
        _rulesAdditionalPermissions,
      ),
      leaveBanks: List<WorkPermissionRule>.from(_rulesLeaveBanks),
    );
  }

  @override
  Future<void> _pickRulesMinimumBreakMinutes() async {
    final currentMinutes =
        parseBreakDurationInput(_rulesMinimumBreakController.text) ?? 0;
    final pickedMinutes = await _showDurationWheelPicker(
      title: 'Pausa minima',
      initialMinutes: currentMinutes,
      maxMinutes: 4 * 60,
      stepMinutes: 5,
      zeroLabel: 'Nessuna pausa minima',
    );
    if (pickedMinutes == null) {
      return;
    }

    _rulesMinimumBreakController.text = formatBreakInput(pickedMinutes);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Future<void> _pickRulesMaximumDailyCreditMinutes() async {
    await _pickRulesLimitDuration(
      title: 'Massimo credito giornaliero',
      controller: _rulesMaximumDailyCreditController,
      maxMinutes: 16 * 60,
      unboundedMinutes: 24 * 60,
    );
  }

  @override
  Future<void> _pickRulesMaximumDailyDebitMinutes() async {
    await _pickRulesLimitDuration(
      title: 'Massimo debito giornaliero',
      controller: _rulesMaximumDailyDebitController,
      maxMinutes: 16 * 60,
      unboundedMinutes: 24 * 60,
    );
  }

  @override
  Future<void> _pickRulesMaximumMonthlyCreditMinutes() async {
    await _pickRulesLimitDuration(
      title: 'Massimo credito mensile',
      controller: _rulesMaximumMonthlyCreditController,
      maxMinutes: 240 * 60,
      unboundedMinutes: 31 * 24 * 60,
    );
  }

  @override
  Future<void> _pickRulesMaximumMonthlyDebitMinutes() async {
    await _pickRulesLimitDuration(
      title: 'Massimo debito mensile',
      controller: _rulesMaximumMonthlyDebitController,
      maxMinutes: 240 * 60,
      unboundedMinutes: 31 * 24 * 60,
    );
  }

  @override
  Future<void> _pickRulesOvertimeDailyCapMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Massimale straordinario giornaliero',
      controller: _rulesOvertimeDailyCapController,
      maxMinutes: 16 * 60,
      zeroLabel: 'Nessun massimale',
    );
  }

  @override
  Future<void> _pickRulesOvertimeWeeklyCapMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Massimale straordinario settimanale',
      controller: _rulesOvertimeWeeklyCapController,
      maxMinutes: 60 * 60,
      zeroLabel: 'Nessun massimale',
    );
  }

  @override
  Future<void> _pickRulesOvertimeMonthlyCapMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Massimale straordinario mensile',
      controller: _rulesOvertimeMonthlyCapController,
      maxMinutes: 240 * 60,
      zeroLabel: 'Nessun massimale',
    );
  }

  @override
  Future<void> _pickRulesFlexibleStartWindowMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Finestra flessibilita entrata',
      controller: _rulesFlexibleStartWindowController,
      maxMinutes: 4 * 60,
      zeroLabel: 'Nessuna flessibilita',
    );
  }

  @override
  Future<void> _pickRulesWalletDailyExitMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Permesso uscita anticipata: max al giorno',
      controller: _rulesWalletDailyExitController,
      maxMinutes: 8 * 60,
      zeroLabel: 'Nessun limite giornaliero',
    );
  }

  @override
  Future<void> _pickRulesWalletWeeklyExitMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Permesso uscita anticipata: max a settimana',
      controller: _rulesWalletWeeklyExitController,
      maxMinutes: 30 * 60,
      zeroLabel: 'Nessun limite settimanale',
    );
  }

  @override
  Future<void> _pickRulesImplicitCreditDailyCapMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Credito senza straordinario: max al giorno',
      controller: _rulesImplicitCreditDailyCapController,
      maxMinutes: 8 * 60,
      zeroLabel: 'Nessun credito',
    );
  }

  Future<void> _pickRulesOptionalDuration({
    required String title,
    required TextEditingController controller,
    required int maxMinutes,
    String? zeroLabel,
  }) async {
    final currentMinutes = parseHoursInput(controller.text) ?? 0;
    final pickedMinutes = await _showDurationWheelPicker(
      title: title,
      initialMinutes: currentMinutes,
      maxMinutes: maxMinutes,
      stepMinutes: 5,
      zeroLabel: zeroLabel,
    );
    if (pickedMinutes == null) {
      return;
    }

    controller.text = formatHoursInput(pickedMinutes);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickRulesLimitDuration({
    required String title,
    required TextEditingController controller,
    required int maxMinutes,
    required int unboundedMinutes,
  }) async {
    final currentMinutes = parseHoursInput(controller.text) ?? 0;
    final pickedMinutes = await _showDurationWheelPicker(
      title: title,
      initialMinutes: currentMinutes,
      maxMinutes: maxMinutes,
      stepMinutes: 5,
      specialValue: unboundedMinutes,
      specialLabel: 'Nessun limite',
    );
    if (pickedMinutes == null) {
      return;
    }

    controller.text = formatHoursInput(pickedMinutes);
    if (mounted) {
      setState(() {});
    }
  }

  void _syncProfileTargetFromTimes({WeekdayKey? weekday}) {
    final targetController = weekday == null
        ? _uniformDailyTargetController
        : _weekdayControllers[weekday]!;
    final startController = weekday == null
        ? _uniformStartTimeController
        : _weekdayStartTimeControllers[weekday]!;
    final endController = weekday == null
        ? _uniformEndTimeController
        : _weekdayEndTimeControllers[weekday]!;
    final breakController = weekday == null
        ? _uniformBreakController
        : _weekdayBreakControllers[weekday]!;

    final resolvedTargetMinutes = resolveDraftTargetMinutes(
      targetText: targetController.text,
      startTimeText: startController.text,
      endTimeText: endController.text,
      breakText: breakController.text,
    );
    if (resolvedTargetMinutes == null) {
      return;
    }

    final startMinutes = parseTimeInput(startController.text.trim());
    final endMinutes = parseTimeInput(endController.text.trim());
    final breakMinutes = parseBreakDurationInput(breakController.text) ?? 0;
    if (startMinutes == null || endMinutes == null) {
      return;
    }

    _normalizeScheduleInputs(
      targetText: targetController.text,
      startTimeText: startController.text,
      endTimeText: endController.text,
      breakText: breakController.text,
      targetMinutes: resolvedTargetMinutes,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      breakMinutes: breakMinutes,
    );
  }

  @override
  WeekdaySchedule? _buildWeekdayScheduleFromControllers() {
    final fallbackWeekdaySchedule =
        _snapshot?.profile.weekdaySchedule ?? WeekdaySchedule.uniform(8 * 60);
    if (_useUniformDailyTarget) {
      final uniformSchedule = _buildFlexibleDayScheduleInput(
        targetText: _uniformDailyTargetController.text,
        startTimeText: _uniformStartTimeController.text,
        endTimeText: _uniformEndTimeController.text,
        breakText: _uniformBreakController.text,
        fallbackSchedule: fallbackWeekdaySchedule.monday,
      );
      if (uniformSchedule == null) {
        return null;
      }

      return WeekdaySchedule.uniform(
        uniformSchedule.targetMinutes,
        startTime: uniformSchedule.startTime,
        endTime: uniformSchedule.endTime,
        breakMinutes: uniformSchedule.breakMinutes,
      );
    }

    final parsedValues = <WeekdayKey, DaySchedule>{};
    for (final weekday in WeekdayKey.values) {
      final parsedValue = _buildFlexibleDayScheduleInput(
        targetText: _weekdayControllers[weekday]!.text,
        startTimeText: _weekdayStartTimeControllers[weekday]!.text,
        endTimeText: _weekdayEndTimeControllers[weekday]!.text,
        breakText: _weekdayBreakControllers[weekday]!.text,
        fallbackSchedule: fallbackWeekdaySchedule.forWeekday(weekday),
      );
      if (parsedValue == null) {
        return null;
      }
      parsedValues[weekday] = parsedValue;
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

  @override
  DaySchedule? _buildFlexibleDayScheduleInput({
    required String targetText,
    required String startTimeText,
    required String endTimeText,
    required String breakText,
    required DaySchedule fallbackSchedule,
  }) {
    final explicitTargetMinutes = parseHoursInput(targetText);
    final parsedStartMinutes = parseTimeInput(startTimeText.trim());
    final parsedEndMinutes = parseTimeInput(endTimeText.trim());
    final parsedBreakMinutes = breakText.trim().isEmpty
        ? 0
        : parseBreakDurationInput(breakText);
    if (parsedBreakMinutes == null) {
      return null;
    }

    var startMinutes = parsedStartMinutes;
    var endMinutes = parsedEndMinutes;
    var breakMinutes = parsedBreakMinutes;
    var targetMinutes = explicitTargetMinutes ?? fallbackSchedule.targetMinutes;

    if (startMinutes != null && endMinutes != null) {
      if (endMinutes < startMinutes) {
        final tmp = startMinutes;
        startMinutes = endMinutes;
        endMinutes = tmp;
      }
      final elapsedMinutes = endMinutes - startMinutes;
      if (breakMinutes > elapsedMinutes) {
        breakMinutes = elapsedMinutes;
      }
      targetMinutes = math.max(0, elapsedMinutes - breakMinutes);
    } else if (startMinutes != null) {
      endMinutes = (startMinutes + targetMinutes + breakMinutes).clamp(
        0,
        (23 * 60) + 59,
      );
      final elapsedMinutes = endMinutes - startMinutes;
      if (breakMinutes > elapsedMinutes) {
        breakMinutes = elapsedMinutes;
      }
      targetMinutes = math.max(0, elapsedMinutes - breakMinutes);
    } else if (endMinutes != null) {
      startMinutes = (endMinutes - targetMinutes - breakMinutes).clamp(
        0,
        (23 * 60) + 59,
      );
      final elapsedMinutes = endMinutes - startMinutes;
      if (breakMinutes > elapsedMinutes) {
        breakMinutes = elapsedMinutes;
      }
      targetMinutes = math.max(0, elapsedMinutes - breakMinutes);
    }

    return DaySchedule(
      targetMinutes: targetMinutes,
      startTime: startMinutes == null ? null : formatTimeInput(startMinutes),
      endTime: endMinutes == null ? null : formatTimeInput(endMinutes),
      breakMinutes: breakMinutes,
    );
  }

  @override
  DaySchedule? _parseDayScheduleInput({
    required String targetText,
    required String startTimeText,
    required String endTimeText,
    required String breakText,
  }) {
    final normalizedStartTimeText = startTimeText.trim();
    final normalizedEndTimeText = endTimeText.trim();
    final hasStartTime = normalizedStartTimeText.isNotEmpty;
    final hasEndTime = normalizedEndTimeText.isNotEmpty;
    if (hasStartTime != hasEndTime) {
      return null;
    }

    final startMinutes = hasStartTime
        ? parseTimeInput(normalizedStartTimeText)
        : null;
    final endMinutes = hasEndTime
        ? parseTimeInput(normalizedEndTimeText)
        : null;
    if ((hasStartTime && startMinutes == null) ||
        (hasEndTime && endMinutes == null)) {
      return null;
    }

    final breakMinutes = parseBreakDurationInput(breakText);
    if (breakMinutes == null) {
      return null;
    }
    if ((!hasStartTime || !hasEndTime) && breakMinutes > 0) {
      return null;
    }

    final targetMinutes = resolveDraftTargetMinutes(
      targetText: targetText,
      startTimeText: startTimeText,
      endTimeText: endTimeText,
      breakText: breakText,
    );
    if (targetMinutes == null) {
      return null;
    }

    if (startMinutes != null && endMinutes != null) {
      final elapsedMinutes = endMinutes - startMinutes;
      if (elapsedMinutes < 0 || breakMinutes > elapsedMinutes) {
        return null;
      }
    }

    _normalizeScheduleInputs(
      targetText: targetText,
      startTimeText: startTimeText,
      endTimeText: endTimeText,
      breakText: breakText,
      targetMinutes: targetMinutes,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      breakMinutes: breakMinutes,
    );

    return DaySchedule(
      targetMinutes: targetMinutes,
      startTime: startMinutes == null ? null : formatTimeInput(startMinutes),
      endTime: endMinutes == null ? null : formatTimeInput(endMinutes),
      breakMinutes: breakMinutes,
    );
  }

  void _normalizeScheduleInputs({
    required String targetText,
    required String startTimeText,
    required String endTimeText,
    required String breakText,
    required int targetMinutes,
    required int? startMinutes,
    required int? endMinutes,
    required int breakMinutes,
  }) {
    void assignIfMatches(
      String source,
      TextEditingController controller,
      String value,
    ) {
      if (controller.text == source) {
        controller.text = value;
      }
    }

    assignIfMatches(
      targetText,
      _uniformDailyTargetController,
      formatHoursInput(targetMinutes),
    );
    assignIfMatches(
      targetText,
      _scheduleOverrideTargetController,
      formatHoursInput(targetMinutes),
    );
    for (final controller in _weekdayControllers.values) {
      assignIfMatches(targetText, controller, formatHoursInput(targetMinutes));
    }

    final normalizedStart = startMinutes == null
        ? ''
        : formatTimeInput(startMinutes);
    final normalizedEnd = endMinutes == null ? '' : formatTimeInput(endMinutes);
    assignIfMatches(
      startTimeText,
      _uniformStartTimeController,
      normalizedStart,
    );
    assignIfMatches(endTimeText, _uniformEndTimeController, normalizedEnd);
    assignIfMatches(
      breakText,
      _uniformBreakController,
      formatBreakInput(breakMinutes),
    );
    assignIfMatches(
      startTimeText,
      _scheduleOverrideStartTimeController,
      normalizedStart,
    );
    assignIfMatches(
      endTimeText,
      _scheduleOverrideEndTimeController,
      normalizedEnd,
    );
    assignIfMatches(
      breakText,
      _scheduleOverrideBreakController,
      formatBreakInput(breakMinutes),
    );
    for (final controller in _weekdayStartTimeControllers.values) {
      assignIfMatches(startTimeText, controller, normalizedStart);
    }
    for (final controller in _weekdayEndTimeControllers.values) {
      assignIfMatches(endTimeText, controller, normalizedEnd);
    }
    for (final controller in _weekdayBreakControllers.values) {
      assignIfMatches(breakText, controller, formatBreakInput(breakMinutes));
    }
  }

  @override
  WeekdayTargetMinutes _deriveWeekdayTargetMinutesFromSchedule(
    WeekdaySchedule schedule,
  ) {
    return WeekdayTargetMinutes(
      monday: schedule.monday.targetMinutes,
      tuesday: schedule.tuesday.targetMinutes,
      wednesday: schedule.wednesday.targetMinutes,
      thursday: schedule.thursday.targetMinutes,
      friday: schedule.friday.targetMinutes,
      saturday: schedule.saturday.targetMinutes,
      sunday: schedule.sunday.targetMinutes,
    );
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
