// Composizione delle sezioni della home (build dei contenuti per sezione).

part of '../home_screen.dart';

mixin _HomeSectionsState on _HomeScreenStateBase {
  Widget _buildPlannerSectionCard({
    required DashboardSnapshot snapshot,
    required String title,
    required CalendarView calendarView,
    required String periodLabel,
    required bool showViewSelector,
    required Future<void> Function() onPreviousPeriod,
    required Future<void> Function() onNextPeriod,
  }) {
    final monthSnapshot = _snapshotForMonth(_selectedMonth) ?? snapshot;
    final weekMetrics = _buildWeekMetrics();
    final baseDayMetrics = _buildDayMetrics(_selectedDate);
    final baseDaySchedule = _resolveBaseDayScheduleForDate(
      monthSnapshot,
      _selectedDate,
    );
    final effectiveDaySchedule = _resolveEffectiveDayScheduleForDate(
      monthSnapshot,
      _selectedDate,
    );
    final draftEffectiveDaySchedule = _resolveCurrentScheduleDraft(
      effectiveDaySchedule,
    );
    final displayedDaySchedule = _resolveDisplayedDaySchedule(
      draftEffectiveDaySchedule,
      _selectedDate,
    );
    final previewDaySchedule = _resolveAgendaPreviewSchedule(
      displayedDaySchedule,
    );
    final selectedDayPauseWindow = _resolveSelectedDayPauseWindow(
      schedule: displayedDaySchedule,
      session: isSameDay(_selectedDate, _todayDate) ? _workdaySession : null,
    );
    final dayMetrics = _withDisplayedDaySchedule(
      baseDayMetrics,
      displayedDaySchedule,
    );
    final pendingExitConfirmationMinutes =
        _pendingExitConfirmationForSelectedDate;
    // Inserimento manuale precompilato con cio' che manca per coprire la
    // giornata: si usa quando ci si dimentica di timbrare.
    final remainingDayMinutes =
        dayMetrics.expectedMinutes -
        dayMetrics.workedMinutes -
        dayMetrics.leaveMinutes;
    final prefilledEntryMinutes = remainingDayMinutes > 0
        ? remainingDayMinutes
        : null;

    return CalendarCard(
      title: title,
      showViewSelector: showViewSelector,
      calendarView: calendarView,
      periodLabel: periodLabel,
      isLoadingCalendarData: _isLoadingCalendarData,
      month: monthSnapshot.summary.month,
      selectedDate: _selectedDate,
      workRules: monthSnapshot.profile.workRules,
      days: _buildCalendarDays(monthSnapshot),
      baseDaySchedule: baseDaySchedule,
      plannedDaySchedule: _resolvePlannedDayScheduleForDate(
        monthSnapshot,
        _selectedDate,
      ),
      effectiveDaySchedule: displayedDaySchedule,
      draftDaySchedule: displayedDaySchedule,
      quickEditorDaySchedule: previewDaySchedule,
      quickEditorPauseWindow:
          _agendaPreviewPauseWindow() ?? selectedDayPauseWindow,
      selectedDayPauseWindow: selectedDayPauseWindow,
      overrideFormKey: _scheduleOverrideFormKey,
      appearanceSettings: widget.appearanceSettings,
      overrideTargetController: _scheduleOverrideTargetController,
      overrideStartTimeController: _scheduleOverrideStartTimeController,
      overrideEndTimeController: _scheduleOverrideEndTimeController,
      overrideBreakController: _scheduleOverrideBreakController,
      pendingExitConfirmationMinutes: pendingExitConfirmationMinutes,
      dayMetrics: dayMetrics,
      weekMetrics: weekMetrics,
      monthMetrics: MonthMetrics(
        month: monthSnapshot.summary.month,
        expectedMinutes: monthSnapshot.summary.expectedMinutes,
        workedMinutes: monthSnapshot.summary.workedMinutes,
        leaveMinutes: monthSnapshot.summary.leaveMinutes,
        rawBalanceMinutes: monthSnapshot.summary.rawBalanceMinutes,
        balanceMinutes: monthSnapshot.summary.balanceMinutes,
        overrideCount: _overrideCountForMonth(monthSnapshot),
      ),
      yearMetrics: _buildYearMetrics(),
      onCalendarViewChanged: _changeCalendarView,
      onPreviousPeriod: onPreviousPeriod,
      onNextPeriod: onNextPeriod,
      onSelectDate: _selectDate,
      onOpenDay: _openDayForDate,
      isSelectedDateToday: isSameDay(_selectedDate, _todayDate),
      dayActivities: _buildActivitiesForDate(monthSnapshot, _selectedDate),
      onOpenWorkQuickEntry: () => _openWorkQuickEntryForDate(
        _selectedDate,
        prefilledMinutes: prefilledEntryMinutes,
      ),
      onOpenLeaveQuickEntry: () => _openLeaveQuickEntryForDate(
        _selectedDate,
        prefilledMinutes: prefilledEntryMinutes,
      ),
      onEditActivity: _startEditingActivity,
      onDeleteActivity: _confirmDeleteActivity,
      workdaySession: _workdaySession,
      isSavingWorkdaySession: _isSavingWorkdaySession,
      onRecordWorkdayStartNow: _recordWorkdayStartNow,
      onStartWorkdayBreakNow: _startWorkdayBreakNow,
      onResumeWorkdayNow: _resumeWorkdayNow,
      onFinishWorkdayNow: _finishWorkdayNow,
      onClearWorkdaySession: _clearWorkdaySession,
      onPickOverrideTargetMinutes: _pickScheduleOverrideTargetMinutes,
      onPickOverrideTime: _pickScheduleOverrideTime,
      onPickOverrideBreakMinutes: _pickScheduleOverrideBreakMinutes,
      onAgendaSchedulePreviewChanged: _previewScheduleOverrideFromAgenda,
      onAgendaSchedulePreviewCleared: _clearScheduleOverrideAgendaPreview,
      onAgendaScheduleChanged: _updateScheduleOverrideFromAgenda,
      onAgendaInteractionChanged: _setAgendaInteracting,
      onAppearanceSettingsChanged: _updateAppearanceSettings,
      canUndoOverrideChanges: _canUndoScheduleOverride,
      canRedoOverrideChanges: _canRedoScheduleOverride,
      onUndoOverrideChange: _undoScheduleOverrideDraftChange,
      onRedoOverrideChange: _redoScheduleOverrideDraftChange,
      onMarkDayAsOff: _markSelectedDayAsDayOff,
      onRegisterUnrecordedHours: _registerUnrecordedHours,
      onRestoreWorkingDay: _removeScheduleOverride,
      onConfirmSuggestedExitMinutes: _confirmSuggestedExitMinutes,
      onOpenWorkSettings: _openWorkSettingsSectionFromSummary,
      onOvertimeLimitExceeded: _handleOvertimeLimitExceededNotification,
    );
  }

  Widget _buildSelectedSection(DashboardSnapshot snapshot) {
    switch (_selectedSection) {
      case HomeSection.day:
        return GestureDetector(
          key: const ValueKey('today-swipe-day-navigation'),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if (_isLoading || _isLoadingCalendarData) {
              return;
            }

            final horizontalVelocity = details.primaryVelocity ?? 0;
            if (horizontalVelocity.abs() < 260) {
              return;
            }

            // Si scorre come si sfoglia: trascinare verso sinistra porta al
            // giorno dopo, verso destra a quello prima.
            unawaited(_shiftSelectedDay(horizontalVelocity > 0 ? -1 : 1));
          },
          child: _buildPlannerSectionCard(
            snapshot: snapshot,
            title: '',
            calendarView: CalendarView.day,
            periodLabel: formatLongDate(_selectedDate),
            showViewSelector: false,
            onPreviousPeriod: () => _shiftSelectedDay(-1),
            onNextPeriod: () => _shiftSelectedDay(1),
          ),
        );
      case HomeSection.consuntivo:
        final consuntivoData = _buildConsuntivoSectionData(snapshot);
        return ConsuntivoSection(
          data: consuntivoData,
          selectedRange: _consuntivoRange,
          isLoading: _isLoadingConsuntivoData,
          onRangeChanged: (range) {
            unawaited(_changeConsuntivoRange(range));
          },
          onPreviousMonth: () => _shiftConsuntivoAnchorMonth(-1),
          onNextMonth: () => _shiftConsuntivoAnchorMonth(1),
        );
      case HomeSection.quickEntry:
        return QuickEntryCard(
          formKey: _quickEntryFormKey,
          selectedEntryMode: _selectedEntryMode,
          onEntryModeChanged: (mode) {
            setState(() {
              _selectedEntryMode = mode;
            });
          },
          selectedLeaveType: _selectedLeaveType,
          onLeaveTypeChanged: (leaveType) {
            setState(() {
              _selectedLeaveType = leaveType;
            });
          },
          dateController: _entryDateController,
          minutesController: _entryMinutesController,
          noteController: _entryNoteController,
          minutePresets: _minutesPresets,
          onMinutePresetSelected: _applyPresetMinutes,
          isBusy: _isSubmittingEntry,
          onPickDate: _pickEntryDate,
          onSubmit: _submitQuickEntry,
          isEditing: _editingEntry != null,
          onCancelEdit: _cancelEntryEditing,
        );
      case HomeSection.calendar:
        return _buildPlannerSectionCard(
          snapshot: snapshot,
          title: 'Calendario',
          calendarView: _calendarView,
          periodLabel: _calendarPeriodLabel(),
          showViewSelector: true,
          onPreviousPeriod: () => _shiftCalendarPeriod(-1),
          onNextPeriod: () => _shiftCalendarPeriod(1),
        );
      case HomeSection.workSettings:
        return WorkSettingsCard(
          formKey: _profileFormKey,
          appearanceSettings: widget.appearanceSettings,
          useUniformDailyTarget: _useUniformDailyTarget,
          onUniformDailyTargetChanged: (value) {
            setState(() {
              _useUniformDailyTarget = value;
            });
          },
          uniformDailyTargetController: _uniformDailyTargetController,
          uniformStartTimeController: _uniformStartTimeController,
          uniformEndTimeController: _uniformEndTimeController,
          uniformBreakController: _uniformBreakController,
          rulesMinimumBreakController: _rulesMinimumBreakController,
          rulesMaximumDailyCreditController: _rulesMaximumDailyCreditController,
          rulesMaximumDailyDebitController: _rulesMaximumDailyDebitController,
          rulesMaximumMonthlyCreditController:
              _rulesMaximumMonthlyCreditController,
          rulesMaximumMonthlyDebitController:
              _rulesMaximumMonthlyDebitController,
          rulesOvertimeEnabled: _rulesOvertimeEnabled,
          rulesOvertimeCapEnabled: _rulesOvertimeCapEnabled,
          rulesFixedScheduleEnabled: _rulesFixedScheduleEnabled,
          rulesFlexibleStartEnabled: _rulesFlexibleStartEnabled,
          rulesWalletEnabled: _rulesWalletEnabled,
          rulesImplicitCreditEnabled: _rulesImplicitCreditEnabled,
          rulesPauseAdjustmentMode: _rulesPauseAdjustmentMode,
          rulesOvertimeDailyCapController: _rulesOvertimeDailyCapController,
          rulesOvertimeWeeklyCapController: _rulesOvertimeWeeklyCapController,
          rulesOvertimeMonthlyCapController: _rulesOvertimeMonthlyCapController,
          rulesFlexibleStartWindowController:
              _rulesFlexibleStartWindowController,
          rulesWalletDailyExitController: _rulesWalletDailyExitController,
          rulesWalletWeeklyExitController: _rulesWalletWeeklyExitController,
          rulesImplicitCreditDailyCapController:
              _rulesImplicitCreditDailyCapController,
          rulesAdditionalPermissions: _rulesAdditionalPermissions,
          rulesLeaveBanks: _rulesLeaveBanks,
          weekdayControllers: _weekdayControllers,
          weekdayStartTimeControllers: _weekdayStartTimeControllers,
          weekdayEndTimeControllers: _weekdayEndTimeControllers,
          weekdayBreakControllers: _weekdayBreakControllers,
          isBusy: _isSavingProfile,
          isReloading: _isReloadingProfile,
          onPickUniformTargetMinutes: _pickUniformTargetMinutes,
          onPickUniformScheduleTime: _pickUniformScheduleTime,
          onPickUniformBreakMinutes: _pickUniformBreakMinutes,
          onUniformLunchBreakChanged: _setUniformLunchBreakEnabled,
          onPickRulesMinimumBreakMinutes: _pickRulesMinimumBreakMinutes,
          onPickRulesMaximumDailyCreditMinutes:
              _pickRulesMaximumDailyCreditMinutes,
          onPickRulesMaximumDailyDebitMinutes:
              _pickRulesMaximumDailyDebitMinutes,
          onPickRulesMaximumMonthlyCreditMinutes:
              _pickRulesMaximumMonthlyCreditMinutes,
          onPickRulesMaximumMonthlyDebitMinutes:
              _pickRulesMaximumMonthlyDebitMinutes,
          onRulesOvertimeEnabledChanged: (value) {
            setState(() {
              _rulesOvertimeEnabled = value;
            });
          },
          onRulesOvertimeCapEnabledChanged: (value) {
            setState(() {
              _rulesOvertimeCapEnabled = value;
            });
          },
          onRulesFixedScheduleEnabledChanged: (value) {
            setState(() {
              _rulesFixedScheduleEnabled = value;
              if (!value && _rulesFlexibleStartEnabled) {
                _rulesFlexibleStartEnabled = false;
              }
            });
          },
          onRulesFlexibleStartEnabledChanged: (value) {
            setState(() {
              _rulesFlexibleStartEnabled = value;
              if (value) {
                _rulesFixedScheduleEnabled = true;
              }
            });
          },
          onRulesWalletEnabledChanged: (value) {
            setState(() {
              _rulesWalletEnabled = value;
            });
          },
          onRulesImplicitCreditEnabledChanged: (value) {
            setState(() {
              _rulesImplicitCreditEnabled = value;
            });
          },
          onRulesPauseAdjustmentModeChanged: (value) {
            setState(() {
              _rulesPauseAdjustmentMode = value;
            });
          },
          onPickRulesOvertimeDailyCapMinutes: _pickRulesOvertimeDailyCapMinutes,
          onPickRulesOvertimeWeeklyCapMinutes:
              _pickRulesOvertimeWeeklyCapMinutes,
          onPickRulesOvertimeMonthlyCapMinutes:
              _pickRulesOvertimeMonthlyCapMinutes,
          onPickRulesFlexibleStartWindowMinutes:
              _pickRulesFlexibleStartWindowMinutes,
          onPickRulesWalletDailyExitMinutes: _pickRulesWalletDailyExitMinutes,
          onPickRulesWalletWeeklyExitMinutes: _pickRulesWalletWeeklyExitMinutes,
          onPickRulesImplicitCreditDailyCapMinutes:
              _pickRulesImplicitCreditDailyCapMinutes,
          onAddAdditionalPermission: () => _addPermissionRule(leaveBank: false),
          onAddLeaveBank: () => _addPermissionRule(leaveBank: true),
          onEditAdditionalPermission: (ruleId) =>
              _editPermissionRule(leaveBank: false, ruleId: ruleId),
          onEditLeaveBank: (ruleId) =>
              _editPermissionRule(leaveBank: true, ruleId: ruleId),
          onRemoveAdditionalPermission: (ruleId) =>
              _removePermissionRule(leaveBank: false, ruleId: ruleId),
          onRemoveLeaveBank: (ruleId) =>
              _removePermissionRule(leaveBank: true, ruleId: ruleId),
          onPickWeekdayTargetMinutes: _pickWeekdayTargetMinutes,
          onPickWeekdayScheduleTime: _pickWeekdayScheduleTime,
          onPickWeekdayBreakMinutes: _pickWeekdayBreakMinutes,
          onWeekdayLunchBreakChanged: _setWeekdayLunchBreakEnabled,
          onWeekdayWorkingDayChanged: _setWeekdayWorkingEnabled,
          onAppearanceSettingsChanged: _updateAppearanceSettings,
          onReload: _reloadProfileDraft,
          onSubmit: _submitProfile,
        );
      case HomeSection.profile:
        return ProfileCard(
          formKey: _profileFormKey,
          fullNameController: _fullNameController,
          isBusy: _isSavingProfile,
          isReloading: _isReloadingProfile,
          isDarkTheme: widget.isDarkTheme,
          appearanceSettings: widget.appearanceSettings,
          availableUpdate: _availableUpdate,
          isCheckingForUpdate: _isCheckingForUpdate,
          isOpeningUpdate: _isOpeningUpdate,
          isBackgroundUpdateDownloadInProgress:
              _isBackgroundUpdateDownloadInProgress,
          backgroundUpdateProgress: _backgroundUpdateProgress,
          backgroundUpdate: _backgroundUpdate,
          isUpdatingThemeMode: _isUpdatingThemeMode,
          accountSession: _accountSession,
          selectedAuthMode: _accountAuthMode,
          accountEmailController: _accountEmailController,
          accountPasswordController: _accountPasswordController,
          isAuthenticatingAccount: _isAuthenticatingAccount,
          isRecoveringPassword: _isRecoveringAccountPassword,
          isConfiguringRecoveryQuestions: _isConfiguringRecoveryQuestions,
          isRestoringCloudBackup: _isRestoringCloudBackup,
          isSyncingCloudBackup: _isSyncingCloudBackup,
          hasCloudBackupAvailable: _hasCloudBackupAvailable,
          onDarkThemeChanged: _toggleThemeMode,
          onOpenUpdateFromSettings: _openUpdateFromSettings,
          onAppearanceSettingsChanged: _updateAppearanceSettings,
          onRegisterAccount: _registerAccount,
          onLoginAccount: _loginAccount,
          onAuthModeChanged: (mode) {
            setState(() {
              _accountAuthMode = mode;
            });
          },
          onOpenPasswordRecovery: _openPasswordRecoveryFlow,
          onOpenRecoveryQuestionsSetup: _openRecoveryQuestionsSetupFlow,
          onBackupNow: _triggerManualCloudBackup,
          onRestoreCloudBackup: _restoreCloudBackup,
          onLogoutAccount: _logoutAccount,
          isLoadingCloudBackupStatus: _isLoadingCloudBackupStatus,
          lastCloudBackupAt: _lastCloudBackupAt,
          lastCloudBackupAttemptAt: _lastCloudBackupAttemptAt,
          lastCloudBackupSucceeded: _lastCloudBackupSucceeded,
          lastCloudBackupFeedback: _lastCloudBackupFeedback,
          onReload: _reloadProfileDraft,
          onSubmit: _submitProfile,
        );
      case HomeSection.ticket:
        return SupportTicketCard(
          ticketApiBaseUrl: snapshot.apiBaseUrl,
          formKey: _ticketFormKey,
          selectedCategory: _selectedTicketCategory,
          onCategoryChanged: (category) {
            setState(() {
              _selectedTicketCategory = category;
            });
          },
          nameController: _ticketNameController,
          emailController: _ticketEmailController,
          subjectController: _ticketSubjectController,
          messageController: _ticketMessageController,
          replyController: _ticketReplyController,
          recoveryTicketIdController: _ticketRecoveryIdController,
          appVersionController: _ticketAppVersionController,
          attachments: _ticketAttachments,
          includeDiagnosticLogs: _includeDiagnosticLogsInTicket,
          onIncludeDiagnosticLogsChanged: (value) {
            setState(() {
              _includeDiagnosticLogsInTicket = value;
            });
          },
          trackedTickets: _trackedTickets,
          ticketThreadsById: _ticketThreadsById,
          selectedTicketId: _selectedTrackedTicketId,
          isSubmitting: _isSubmittingTicket,
          isRecordingVoiceAttachment: _isRecordingTicketVoice,
          isLoadingThreads: _isLoadingTicketThreads,
          isSubmittingReply: _isSubmittingTicketReply,
          isRecoveringTicket: _isRecoveringTrackedTicket,
          unreadReplyCount: _unreadTicketReplyCount,
          onSelectTicket: _selectTrackedSupportTicket,
          onRefreshThreads: _refreshTrackedSupportTickets,
          onRecoverTicketById: _recoverTrackedSupportTicketById,
          onPickAttachments: _pickTicketAttachments,
          onRecordVoiceAttachment: _recordTicketVoiceAttachment,
          onPickVoiceAttachments: _pickTicketVoiceAttachments,
          onRemoveAttachment: _removeTicketAttachmentAt,
          onSubmit: _submitSupportTicket,
          onSubmitReply: _submitSupportTicketReply,
        );
    }
  }
}
