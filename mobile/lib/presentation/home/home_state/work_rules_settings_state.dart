// Regole del contratto: limiti, straordinari, flessibilita' e permessi.

part of '../home_screen.dart';

mixin _WorkRulesSettingsState on _HomeScreenStateBase {
  @override
  UserWorkRules? _buildWorkRulesFromControllers({
    required WeekdaySchedule weekdaySchedule,
  }) {
    // Vale anche per l'orario unico: con il weekend lavorativo il lunedi' puo'
    // essere un giorno libero e non rappresenta piu' la giornata tipo.
    final expectedDailyMinutes = averageWorkingDayTargetMinutes(
      weekdaySchedule,
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
}
