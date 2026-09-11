// Profilo, bozza impostazioni, setup iniziale e aspetto.

part of '../home_screen.dart';

mixin _ProfileState on _HomeScreenStateBase {
  @override
  Future<void> _maybeShowInitialSetup(DashboardSnapshot _) async {
    if (_hasCompletedInitialSetup) {
      return;
    }

    _hasCompletedInitialSetup = true;
    await widget.onboardingPreferenceStore.markInitialSetupCompleted();
  }

  @override
  void _hydrateControllers(
    DashboardSnapshot snapshot,
    DateTime selectedDate, {
    bool resetScheduleHistory = true,
  }) {
    _fullNameController.text = snapshot.profile.fullName;
    _useUniformDailyTarget = snapshot.profile.useUniformDailyTarget;
    _uniformDailyTargetController.text = formatHoursInput(
      snapshot.profile.dailyTargetMinutes,
    );
    _uniformStartTimeController.text =
        snapshot.profile.weekdaySchedule.monday.startTime ?? '';
    _uniformEndTimeController.text =
        snapshot.profile.weekdaySchedule.monday.endTime ?? '';
    _uniformBreakController.text = formatBreakInput(
      snapshot.profile.weekdaySchedule.monday.breakMinutes,
    );
    _rulesExpectedDailyController.text = formatHoursInput(
      snapshot.profile.workRules.expectedDailyMinutes,
    );
    _rulesMinimumBreakController.text = formatBreakInput(
      snapshot.profile.workRules.minimumBreakMinutes,
    );
    _rulesMaximumDailyCreditController.text = formatHoursInput(
      snapshot.profile.workRules.maximumDailyCreditMinutes,
    );
    _rulesMaximumDailyDebitController.text = formatHoursInput(
      snapshot.profile.workRules.maximumDailyDebitMinutes,
    );
    _rulesMaximumMonthlyCreditController.text = formatHoursInput(
      snapshot.profile.workRules.maximumMonthlyCreditMinutes,
    );
    _rulesMaximumMonthlyDebitController.text = formatHoursInput(
      snapshot.profile.workRules.maximumMonthlyDebitMinutes,
    );
    _rulesOvertimeEnabled = snapshot.profile.workRules.overtimeEnabled;
    _rulesOvertimeCapEnabled = snapshot.profile.workRules.overtimeCapEnabled;
    _rulesOvertimeDailyCapController.text = formatHoursInput(
      snapshot.profile.workRules.overtimeDailyCapMinutes,
    );
    _rulesOvertimeWeeklyCapController.text = formatHoursInput(
      snapshot.profile.workRules.overtimeWeeklyCapMinutes,
    );
    _rulesOvertimeMonthlyCapController.text = formatHoursInput(
      snapshot.profile.workRules.overtimeMonthlyCapMinutes,
    );
    _rulesFixedScheduleEnabled =
        snapshot.profile.workRules.fixedScheduleEnabled ||
        snapshot.profile.workRules.flexibleStartEnabled;
    _rulesFlexibleStartEnabled =
        snapshot.profile.workRules.flexibleStartEnabled;
    _rulesFlexibleStartWindowController.text = formatHoursInput(
      snapshot.profile.workRules.flexibleStartWindowMinutes,
    );
    _rulesWalletEnabled = snapshot.profile.workRules.walletEnabled;
    _rulesWalletDailyExitController.text = formatHoursInput(
      snapshot.profile.workRules.walletDailyExitEarlyMinutes,
    );
    _rulesWalletWeeklyExitController.text = formatHoursInput(
      snapshot.profile.workRules.walletWeeklyExitEarlyMinutes,
    );
    _rulesImplicitCreditEnabled =
        snapshot.profile.workRules.implicitCreditEnabled;
    _rulesImplicitCreditDailyCapController.text = formatHoursInput(
      snapshot.profile.workRules.implicitCreditDailyCapMinutes,
    );
    _rulesPauseAdjustmentMode = snapshot.profile.workRules.pauseAdjustmentMode;
    _rulesAdditionalPermissions = List<WorkPermissionRule>.from(
      snapshot.profile.workRules.additionalPermissions,
    );
    _rulesLeaveBanks = List<WorkPermissionRule>.from(
      snapshot.profile.workRules.leaveBanks,
    );
    for (final weekday in WeekdayKey.values) {
      final daySchedule = snapshot.profile.weekdaySchedule.forWeekday(weekday);
      _weekdayControllers[weekday]!.text = formatHoursInput(
        daySchedule.targetMinutes,
      );
      _weekdayStartTimeControllers[weekday]!.text = daySchedule.startTime ?? '';
      _weekdayEndTimeControllers[weekday]!.text = daySchedule.endTime ?? '';
      _weekdayBreakControllers[weekday]!.text = formatBreakInput(
        daySchedule.breakMinutes,
      );
    }

    _hydrateSelectedDateControllers(
      snapshot,
      selectedDate,
      resetScheduleHistory: resetScheduleHistory,
    );
    if (_ticketNameController.text.trim().isEmpty) {
      _ticketNameController.text = snapshot.profile.fullName;
    }
  }

  @override
  Future<void> _submitProfile() async {
    final isValid = _profileFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final weekdaySchedule = _buildWeekdayScheduleFromControllers();
    if (weekdaySchedule == null) {
      setState(() {
        _errorMessage =
            'Controlla ore, inizio, fine e pausa. Se imposti gli orari, il totale deve tornare.';
      });
      return;
    }

    final weekdayTargetMinutes = _deriveWeekdayTargetMinutesFromSchedule(
      weekdaySchedule,
    );
    final workRules = _buildWorkRulesFromControllers(
      weekdaySchedule: weekdaySchedule,
    );
    if (workRules == null) {
      setState(() {
        _errorMessage =
            'Controlla le regole contratto: ore attese, pausa minima e limiti di credito o debito devono essere validi.';
      });
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await widget.dashboardService.saveProfile(
        fullName: _fullNameController.text.trim(),
        useUniformDailyTarget: _useUniformDailyTarget,
        dailyTargetMinutes: workRules.expectedDailyMinutes,
        weekdayTargetMinutes: weekdayTargetMinutes,
        weekdaySchedule: weekdaySchedule,
        workRules: workRules,
        month: _snapshot?.summary.month,
      );

      if (!mounted) {
        return;
      }

      _hydrateControllers(snapshot, _selectedDate);
      await _cacheSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      setState(() {
        _snapshot = snapshot;
        _isSavingProfile = false;
      });
      await _queueCloudBackup();
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(const SnackBar(content: Text('Dati aggiornati.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
        _isSavingProfile = false;
      });
    }
  }

  @override
  Future<void> _reloadProfileDraft() async {
    setState(() {
      _isReloadingProfile = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await widget.dashboardService.loadSnapshot(
        month: _selectedMonth,
      );

      if (!mounted) {
        return;
      }

      _snapshotCache[snapshot.summary.month] = snapshot;
      await _cacheSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      _hydrateControllers(snapshot, _selectedDate);
      setState(() {
        _snapshot = snapshot;
        _isReloadingProfile = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profilo ricaricato.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
        _isReloadingProfile = false;
      });
    }
  }

  @override
  Future<void> _toggleThemeMode(bool useDarkTheme) async {
    final nextThemeMode = useDarkTheme ? ThemeMode.dark : ThemeMode.light;
    if (widget.appearanceSettings.themeMode == nextThemeMode) {
      return;
    }

    await _updateAppearanceSettings(
      widget.appearanceSettings.copyWith(themeMode: nextThemeMode),
    );
  }

  @override
  Future<void> _updateAppearanceSettings(
    AppAppearanceSettings appearanceSettings,
  ) async {
    if (_isUpdatingThemeMode) {
      return;
    }

    setState(() {
      _isUpdatingThemeMode = true;
    });

    try {
      await widget.onAppearanceSettingsChanged(appearanceSettings);
      await _queueCloudBackup();
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingThemeMode = false;
        });
      }
    }
  }
}
