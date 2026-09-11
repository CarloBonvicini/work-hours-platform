import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:work_hours_mobile/application/services/account_service.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/domain/models/account_session.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_snapshot_store.dart';
import 'package:work_hours_mobile/application/services/diagnostic_log_service.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/local_notification_service.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
import 'package:work_hours_mobile/application/services/support_ticket_store.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/application/services/update_launcher.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/application/services/workday_start_store.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';
import 'package:work_hours_mobile/presentation/home/consuntivo_section.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_day_labels.dart';
import 'package:work_hours_mobile/presentation/home/logic/day_balance.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';
import 'package:work_hours_mobile/presentation/home/logic/rule_value_labels.dart';
import 'package:work_hours_mobile/presentation/home/logic/schedule_draft.dart';
import 'package:work_hours_mobile/presentation/home/logic/ticket_labels.dart';
import 'package:work_hours_mobile/presentation/home/logic/workday_session_info.dart';
import 'package:work_hours_mobile/presentation/home/models/activity_item.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_day.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_view.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/models/home_section.dart';
import 'package:work_hours_mobile/presentation/home/models/support_ticket_limits.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/calendar_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/calendar/quick_entry_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/home_header.dart';
import 'package:work_hours_mobile/presentation/home/widgets/overview/overview_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/overview/recent_activity_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/cloud_backup_account_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/profile_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/work_settings_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/section_cards.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/wheel_picker_bottom_sheet.dart';
import 'package:work_hours_mobile/presentation/home/widgets/support/support_ticket_card.dart';
import 'package:work_hours_mobile/presentation/home/widgets/update/update_dialog.dart';
import 'package:work_hours_mobile/presentation/home/widgets/update/update_download_dialog.dart';

enum _TicketVoiceRecordingAction { cancel, save }

final ImagePicker _ticketImagePicker = ImagePicker();
const List<String> _recoveryQuestionSuggestions = [
  'Come si chiamava il tuo primo animale domestico?',
  'Qual e il nome della tua scuola elementare?',
  'Qual e la citta in cui sei nato?',
  'Qual e il nome di tua nonna materna?',
  'Qual e il tuo film preferito da bambino?',
];

enum _ScheduleOverrideAutosaveAction { none, save, remove }

class _ScheduleTimeWheelSelection {
  const _ScheduleTimeWheelSelection.confirmed(this.minutes) : cleared = false;
  const _ScheduleTimeWheelSelection.cleared() : minutes = null, cleared = true;

  final int? minutes;
  final bool cleared;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
    required this.updateReminderStore,
    this.dashboardSnapshotStore = const InMemoryDashboardSnapshotStore(),
    required this.onboardingPreferenceStore,
    required this.workdayStartStore,
    this.supportTicketStore = const SharedPreferencesSupportTicketStore(),
    this.accountService,
    this.initialAccountSession,
    required this.hasCompletedInitialSetup,
    required this.isDarkTheme,
    required this.appearanceSettings,
    required this.onAppearanceSettingsChanged,
    required this.onThemeModeChanged,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;
  final UpdateReminderStore updateReminderStore;
  final DashboardSnapshotStore dashboardSnapshotStore;
  final OnboardingPreferenceStore onboardingPreferenceStore;
  final WorkdayStartStore workdayStartStore;
  final SupportTicketStore supportTicketStore;
  final AccountService? accountService;
  final AccountSession? initialAccountSession;
  final bool hasCompletedInitialSetup;
  final bool isDarkTheme;
  final AppAppearanceSettings appearanceSettings;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;
  final Future<void> Function(bool useDarkTheme) onThemeModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _profileFormKey = GlobalKey<FormState>();
  final _quickEntryFormKey = GlobalKey<FormState>();
  final _scheduleOverrideFormKey = GlobalKey<FormState>();
  final _ticketFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _uniformDailyTargetController = TextEditingController();
  final _uniformStartTimeController = TextEditingController();
  final _uniformEndTimeController = TextEditingController();
  final _uniformBreakController = TextEditingController();
  final _rulesExpectedDailyController = TextEditingController();
  final _rulesMinimumBreakController = TextEditingController();
  final _rulesMaximumDailyCreditController = TextEditingController();
  final _rulesMaximumDailyDebitController = TextEditingController();
  final _rulesMaximumMonthlyCreditController = TextEditingController();
  final _rulesMaximumMonthlyDebitController = TextEditingController();
  final _rulesOvertimeDailyCapController = TextEditingController();
  final _rulesOvertimeWeeklyCapController = TextEditingController();
  final _rulesOvertimeMonthlyCapController = TextEditingController();
  final _rulesFlexibleStartWindowController = TextEditingController();
  final _rulesWalletDailyExitController = TextEditingController();
  final _rulesWalletWeeklyExitController = TextEditingController();
  final _rulesImplicitCreditDailyCapController = TextEditingController();
  final _entryDateController = TextEditingController();
  final _entryMinutesController = TextEditingController();
  final _entryNoteController = TextEditingController();
  final _scheduleOverrideTargetController = TextEditingController();
  final _scheduleOverrideStartTimeController = TextEditingController();
  final _scheduleOverrideEndTimeController = TextEditingController();
  final _scheduleOverrideBreakController = TextEditingController();
  final _ticketNameController = TextEditingController();
  final _ticketEmailController = TextEditingController();
  final _ticketSubjectController = TextEditingController();
  final _ticketMessageController = TextEditingController();
  final _ticketReplyController = TextEditingController();
  final _ticketRecoveryIdController = TextEditingController();
  final _ticketAppVersionController = TextEditingController(
    text: const String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0'),
  );
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

  DashboardSnapshot? _snapshot;
  final Map<String, DashboardSnapshot> _snapshotCache = {};
  AppUpdate? _availableUpdate;
  late String _selectedMonth;
  late DateTime _selectedDate;
  CalendarView _calendarView = CalendarView.month;
  bool _useUniformDailyTarget = true;
  bool _rulesOvertimeEnabled = false;
  bool _rulesOvertimeCapEnabled = false;
  bool _rulesFixedScheduleEnabled = false;
  bool _rulesFlexibleStartEnabled = false;
  bool _rulesWalletEnabled = false;
  bool _rulesImplicitCreditEnabled = false;
  WorkRulesPauseAdjustmentMode _rulesPauseAdjustmentMode =
      WorkRulesPauseAdjustmentMode.keepWorkedMinutes;
  List<WorkPermissionRule> _rulesAdditionalPermissions = const [];
  List<WorkPermissionRule> _rulesLeaveBanks = const [];
  LeaveType _selectedLeaveType = LeaveType.vacation;
  QuickEntryMode _selectedEntryMode = QuickEntryMode.work;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isCheckingForUpdate = true;
  bool _isSavingProfile = false;
  bool _isReloadingProfile = false;
  bool _isSavingScheduleOverride = false;
  bool _isSubmittingEntry = false;
  bool _isSubmittingTicket = false;
  bool _isOpeningUpdate = false;
  bool _isShowingUpdateDialog = false;
  bool _isLoadingCalendarData = false;
  bool _isUpdatingThemeMode = false;
  bool _isSavingWorkdaySession = false;
  bool _isAgendaInteracting = false;
  bool _isLoadingTicketThreads = false;
  bool _isLoadingConsuntivoData = false;
  bool _isSubmittingTicketReply = false;
  bool _isRecordingTicketVoice = false;
  bool _isRecoveringTrackedTicket = false;
  bool _isAuthenticatingAccount = false;
  bool _isRecoveringAccountPassword = false;
  bool _isConfiguringRecoveryQuestions = false;
  bool _isRestoringCloudBackup = false;
  bool _isSyncingCloudBackup = false;
  bool _isLoadingCloudBackupStatus = false;
  bool _isBackgroundUpdateDownloadInProgress = false;
  bool _isPromptingBackgroundUpdateInstall = false;
  bool _cloudBackupQueued = false;
  AppUpdate? _backgroundUpdate;
  DownloadedAppUpdate? _backgroundDownloadedUpdate;
  UpdateDownloadProgress _backgroundUpdateProgress =
      const UpdateDownloadProgress(receivedBytes: 0, totalBytes: null);
  late bool _hasCompletedInitialSetup;
  HomeSection _selectedSection = HomeSection.calendar;
  ConsuntivoRangeOption _consuntivoRange = ConsuntivoRangeOption.oneMonth;
  SupportTicketCategory _selectedTicketCategory = SupportTicketCategory.bug;
  List<TrackedSupportTicket> _trackedTickets = const [];
  Map<String, SupportTicketThread> _ticketThreadsById = const {};
  List<SupportTicketUploadAttachment> _ticketAttachments = const [];
  bool _includeDiagnosticLogsInTicket = true;
  String? _selectedTrackedTicketId;
  int _unreadTicketReplyCount = 0;
  WorkdaySession? _workdaySession;
  bool _scheduleOverrideAutosaveQueued = false;
  List<ScheduleOverrideDraftState> _scheduleOverrideHistory = const [];
  int _scheduleOverrideHistoryIndex = -1;
  String? _scheduleOverrideHistoryDateKey;
  int? _selectedDayPauseStartMinutes;
  int? _selectedDayPauseEndMinutes;
  int? _agendaPreviewStartMinutes;
  int? _agendaPreviewEndMinutes;
  int? _agendaPreviewBreakMinutes;
  int? _agendaPreviewPauseStartMinutes;
  int? _agendaPreviewPauseEndMinutes;
  int? _pendingExitConfirmationMinutes;
  String? _pendingExitConfirmationDateKey;
  String? _lastOvertimeExceededNotificationKey;
  AccountSession? _accountSession;
  DateTime? _lastCloudBackupAt;
  DateTime? _lastCloudBackupAttemptAt;
  bool? _lastCloudBackupSucceeded;
  String? _lastCloudBackupFeedback;
  bool _hasCloudBackupAvailable = false;
  AccountAuthMode _accountAuthMode = AccountAuthMode.login;
  Timer? _ticketNotificationTimer;
  Timer? _liveWorkedMinutesTimer;
  StreamSubscription<RemoteMessage>? _foregroundPushSubscription;
  final AudioRecorder _ticketAudioRecorder = AudioRecorder();
  final LocalNotificationService _localNotificationService =
      LocalNotificationService();
  final DiagnosticLogService _diagnosticLogService = DiagnosticLogService();
  final _accountEmailController = TextEditingController();
  final _accountPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedMonth = widget.dashboardService.currentMonth;
    _selectedDate = _resolveSelectedDateForMonth(_selectedMonth);
    _hasCompletedInitialSetup = widget.hasCompletedInitialSetup;
    _accountSession = widget.initialAccountSession;
    _logDiagnostic(
      'home.init',
      details: <String, Object?>{
        'hasInitialSession': _accountSession != null,
        'selectedMonth': _selectedMonth,
      },
    );
    _entryDateController.text = DashboardService.defaultEntryDateOf(
      _selectedDate,
    );
    if (_accountSession != null) {
      unawaited(_refreshCloudBackupStatus(silent: true));
    }
    unawaited(_primeSnapshotFromLocalCache());
    _loadSnapshot();
    unawaited(_loadWorkdaySessionForDate(_selectedDate));
    unawaited(_refreshTrackedSupportTickets());
    _startTicketNotificationPolling();
    _startLiveWorkedMinutesTicker();
    unawaited(_initializeUpdateExperience());
    unawaited(_initializeRemotePushForegroundHandling());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isCheckingForUpdate) {
      unawaited(_checkForUpdate());
    }
    if (state == AppLifecycleState.resumed) {
      _startTicketNotificationPolling();
      _startLiveWorkedMinutesTicker();
      unawaited(_refreshTrackedSupportTickets(notifyAboutNewReplies: true));
    } else {
      _ticketNotificationTimer?.cancel();
      _ticketNotificationTimer = null;
      _liveWorkedMinutesTimer?.cancel();
      _liveWorkedMinutesTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticketNotificationTimer?.cancel();
    _ticketNotificationTimer = null;
    _liveWorkedMinutesTimer?.cancel();
    _liveWorkedMinutesTimer = null;
    unawaited(_foregroundPushSubscription?.cancel());
    _foregroundPushSubscription = null;
    _fullNameController.dispose();
    _uniformDailyTargetController.dispose();
    _uniformStartTimeController.dispose();
    _uniformEndTimeController.dispose();
    _uniformBreakController.dispose();
    _rulesExpectedDailyController.dispose();
    _rulesMinimumBreakController.dispose();
    _rulesMaximumDailyCreditController.dispose();
    _rulesMaximumDailyDebitController.dispose();
    _rulesMaximumMonthlyCreditController.dispose();
    _rulesMaximumMonthlyDebitController.dispose();
    _rulesOvertimeDailyCapController.dispose();
    _rulesOvertimeWeeklyCapController.dispose();
    _rulesOvertimeMonthlyCapController.dispose();
    _rulesFlexibleStartWindowController.dispose();
    _rulesWalletDailyExitController.dispose();
    _rulesWalletWeeklyExitController.dispose();
    _rulesImplicitCreditDailyCapController.dispose();
    _entryDateController.dispose();
    _entryMinutesController.dispose();
    _entryNoteController.dispose();
    _scheduleOverrideTargetController.dispose();
    _scheduleOverrideStartTimeController.dispose();
    _scheduleOverrideEndTimeController.dispose();
    _scheduleOverrideBreakController.dispose();
    _ticketNameController.dispose();
    _ticketEmailController.dispose();
    _ticketSubjectController.dispose();
    _ticketMessageController.dispose();
    _ticketAppVersionController.dispose();
    _ticketReplyController.dispose();
    _ticketRecoveryIdController.dispose();
    _accountEmailController.dispose();
    _accountPasswordController.dispose();
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
    unawaited(_ticketAudioRecorder.dispose());
    super.dispose();
  }

  Future<void> _loadSnapshot({String? month, DateTime? selectedDate}) async {
    final requestedMonth = month ?? _selectedMonth;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _fetchSnapshotForMonth(requestedMonth);
      if (!mounted) {
        return;
      }

      final resolvedSelectedDate = _resolveSelectedDateForMonth(
        snapshot.summary.month,
        preferredDate: selectedDate,
      );

      _hydrateControllers(snapshot, resolvedSelectedDate);
      await _cacheSnapshot(snapshot);
      _entryDateController.text = DashboardService.defaultEntryDateOf(
        resolvedSelectedDate,
      );
      setState(() {
        _snapshot = snapshot;
        _snapshotCache[snapshot.summary.month] = snapshot;
        _selectedMonth = snapshot.summary.month;
        _selectedDate = resolvedSelectedDate;
        _isLoading = false;
      });
      unawaited(_loadWorkdaySessionForDate(resolvedSelectedDate));
      unawaited(_ensureCalendarDataForCurrentView());
      unawaited(_ensureUpcomingWeekData());
      if (_selectedSection == HomeSection.consuntivo) {
        unawaited(_ensureConsuntivoDataLoaded());
      }
      await _maybeShowInitialSetup(snapshot);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final cachedSnapshot = await widget.dashboardSnapshotStore.loadSnapshot(
        requestedMonth,
      );
      if (cachedSnapshot != null) {
        final resolvedSelectedDate = _resolveSelectedDateForMonth(
          cachedSnapshot.summary.month,
          preferredDate: selectedDate,
        );

        _hydrateControllers(cachedSnapshot, resolvedSelectedDate);
        _entryDateController.text = DashboardService.defaultEntryDateOf(
          resolvedSelectedDate,
        );
        setState(() {
          _snapshot = cachedSnapshot;
          _snapshotCache[cachedSnapshot.summary.month] = cachedSnapshot;
          _selectedMonth = cachedSnapshot.summary.month;
          _selectedDate = resolvedSelectedDate;
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _maybeShowInitialSetup(DashboardSnapshot _) async {
    if (_hasCompletedInitialSetup) {
      return;
    }

    _hasCompletedInitialSetup = true;
    await widget.onboardingPreferenceStore.markInitialSetupCompleted();
  }

  Future<void> _initializeUpdateExperience() async {
    await _initializeLocalNotifications();
    if (!mounted) {
      return;
    }

    await _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingForUpdate = true;
    });

    try {
      final availableUpdate = await widget.appUpdateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _availableUpdate = availableUpdate;
        _isCheckingForUpdate = false;
      });
      if (availableUpdate != null) {
        unawaited(
          _localNotificationService.notifyUpdateAvailable(availableUpdate),
        );
        await _maybePromptForUpdate(availableUpdate);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _availableUpdate = null;
        _isCheckingForUpdate = false;
      });
    }
  }

  Future<void> _maybePromptForUpdate(AppUpdate update) async {
    if (_isShowingUpdateDialog) {
      return;
    }

    final shouldPrompt = await widget.updateReminderStore.shouldPromptFor(
      update,
    );
    if (!mounted || !shouldPrompt) {
      return;
    }

    _isShowingUpdateDialog = true;
    final action = await showDialog<UpdateDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(update: update),
    );
    _isShowingUpdateDialog = false;

    if (!mounted) {
      return;
    }

    switch (action) {
      case UpdateDialogAction.updateNow:
        await widget.updateReminderStore.deferAfterOpening(update);
        await _startInAppUpdateFlow(update);
        break;
      case UpdateDialogAction.remindLater:
      case null:
        await widget.updateReminderStore.remindLater(update);
        break;
    }
  }

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

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      _loadSnapshot(month: _selectedMonth, selectedDate: _selectedDate),
      _checkForUpdate(),
      _refreshTrackedSupportTickets(),
    ]);
  }

  void _logDiagnostic(
    String event, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _diagnosticLogService.add(event, details: details);
  }

  String _buildTicketDiagnosticLogs() {
    final accountEmail = _accountSession?.user.email;
    final lines = <String>[
      'Contesto ticket app',
      'timestamp=${DateTime.now().toIso8601String()}',
      'sezioneAttiva=${_selectedSection.name}',
      'apiBase=${_snapshot?.apiBaseUrl ?? "n/d"}',
      'accountCloud=${accountEmail == null ? "non loggato" : _maskEmailForDiagnostic(accountEmail)}',
      'backupCloudDisponibile=$_hasCloudBackupAvailable',
      'ultimoBackupAt=${_lastCloudBackupAt?.toIso8601String() ?? "n/d"}',
      'ultimoTentativoBackupAt=${_lastCloudBackupAttemptAt?.toIso8601String() ?? "n/d"}',
      'ultimoBackupOk=${_lastCloudBackupSucceeded?.toString() ?? "n/d"}',
      '',
      _diagnosticLogService.exportText(header: 'Log eventi'),
    ];

    final payload = lines.join('\n');
    if (payload.length <= maxTicketDiagnosticLogChars) {
      return payload;
    }

    final cutIndex = payload.length - maxTicketDiagnosticLogChars;
    return '...log troncati ($cutIndex caratteri rimossi)\n${payload.substring(cutIndex)}';
  }

  String _maskEmailForDiagnostic(String email) {
    final normalized = email.trim();
    final atIndex = normalized.indexOf('@');
    if (atIndex <= 1 || atIndex >= normalized.length - 1) {
      return normalized;
    }

    final localPart = normalized.substring(0, atIndex);
    final domainPart = normalized.substring(atIndex + 1);
    final hiddenCharacters = List.filled(
      math.max(0, localPart.length - 2),
      '*',
    ).join();
    final maskedLocal = localPart.length <= 2
        ? '${localPart[0]}*'
        : '${localPart[0]}$hiddenCharacters${localPart[localPart.length - 1]}';
    return '$maskedLocal@$domainPart';
  }

  bool get _isCloudBackupEnabled =>
      widget.accountService != null && _accountSession != null;

  Future<void> _triggerManualCloudBackup() {
    return _queueCloudBackup(showFeedback: true);
  }

  bool _isUnauthorizedApiError(Object error) {
    return error is ApiException &&
        (error.statusCode == 401 || error.statusCode == 403);
  }

  Future<void> _handleInvalidCloudSession({required bool showFeedback}) async {
    _logDiagnostic(
      'cloud.session.invalid',
      details: <String, Object?>{'showFeedback': showFeedback},
    );
    if (widget.accountService != null) {
      try {
        await widget.accountService!.logout();
      } catch (_) {
        // Best effort: local reset below is still enough to recover.
      }
    }

    if (!mounted) {
      return;
    }

    const message =
        'Accesso cloud non piu valido sul server. Ti ho disconnesso dal cloud: apri Profilo, accedi di nuovo e riprova.';
    setState(() {
      _accountSession = null;
      _accountAuthMode = AccountAuthMode.login;
      _hasCloudBackupAvailable = false;
      _lastCloudBackupAt = null;
      _lastCloudBackupAttemptAt = null;
      _isLoadingCloudBackupStatus = false;
      _isRestoringCloudBackup = false;
      _isSyncingCloudBackup = false;
      _lastCloudBackupSucceeded = false;
      _lastCloudBackupFeedback = message;
    });

    if (!showFeedback) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(message),
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: 'Apri profilo',
          onPressed: () {
            if (!mounted) {
              return;
            }

            setState(() {
              _selectedSection = HomeSection.profile;
            });
          },
        ),
      ),
    );
  }

  Future<void> _refreshCloudBackupStatus({bool silent = false}) async {
    if (!_isCloudBackupEnabled ||
        widget.accountService == null ||
        _accountSession == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingCloudBackupStatus = true;
      });
    }

    try {
      _logDiagnostic(
        'cloud.backup.status.start',
        details: <String, Object?>{'silent': silent},
      );
      final status = await widget.accountService!.loadCloudBackupStatus(
        session: _accountSession,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCloudBackupStatus = false;
        _hasCloudBackupAvailable = status.hasBackup;
        _lastCloudBackupAt = status.hasBackup ? status.updatedAt : null;
      });
      _logDiagnostic(
        'cloud.backup.status.ok',
        details: <String, Object?>{
          'hasBackup': status.hasBackup,
          'updatedAt': status.updatedAt?.toIso8601String(),
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorizedApiError(error)) {
        _logDiagnostic(
          'cloud.backup.status.unauthorized',
          details: <String, Object?>{'error': error.toString()},
        );
        await _handleInvalidCloudSession(showFeedback: !silent);
        return;
      }

      setState(() {
        _isLoadingCloudBackupStatus = false;
      });
      _logDiagnostic(
        'cloud.backup.status.error',
        details: <String, Object?>{'error': error.toString()},
      );
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
      }
    }
  }

  Future<void> _queueCloudBackup({bool showFeedback = false}) async {
    if (!_isCloudBackupEnabled) {
      return;
    }

    if (_isSyncingCloudBackup) {
      _cloudBackupQueued = true;
      _logDiagnostic(
        'cloud.backup.queued',
        details: <String, Object?>{'reason': 'already_running'},
      );
      return;
    }

    final attemptedAt = DateTime.now();
    setState(() {
      _isSyncingCloudBackup = true;
      _lastCloudBackupAttemptAt = attemptedAt;
    });

    var rerunQueuedBackup = false;
    try {
      _logDiagnostic(
        'cloud.backup.start',
        details: <String, Object?>{
          'showFeedback': showFeedback,
          'attemptedAt': attemptedAt.toIso8601String(),
        },
      );
      final backupStatus = await widget.accountService!.backupToCloud();
      if (!mounted) {
        return;
      }

      final savedAt = backupStatus.updatedAt ?? attemptedAt;
      final droppedItemsCount = backupStatus.droppedItemsCount;
      final baseSuccessMessage =
          'Backup cloud completato alle ${formatTicketDateTime(savedAt)}.';
      final successMessage = droppedItemsCount > 0
          ? '$baseSuccessMessage Ho ignorato $droppedItemsCount voce${droppedItemsCount == 1 ? '' : 'i'} non valida${droppedItemsCount == 1 ? '' : 'e'} per evitare il blocco del backup.'
          : baseSuccessMessage;
      setState(() {
        _hasCloudBackupAvailable = true;
        _lastCloudBackupAt = savedAt;
        _lastCloudBackupSucceeded = true;
        _lastCloudBackupFeedback = successMessage;
      });
      _logDiagnostic(
        'cloud.backup.ok',
        details: <String, Object?>{
          'savedAt': savedAt.toIso8601String(),
          'droppedItems': droppedItemsCount,
        },
      );

      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorizedApiError(error)) {
        _logDiagnostic(
          'cloud.backup.unauthorized',
          details: <String, Object?>{'error': error.toString()},
        );
        await _handleInvalidCloudSession(showFeedback: showFeedback);
      } else {
        final message = _humanizeError(error);
        setState(() {
          _lastCloudBackupSucceeded = false;
          _lastCloudBackupFeedback = message;
        });
        if (showFeedback) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        _logDiagnostic(
          'cloud.backup.error',
          details: <String, Object?>{
            'message': message,
            'error': error.toString(),
          },
        );
      }
    } finally {
      if (mounted) {
        rerunQueuedBackup = _cloudBackupQueued;
        if (_cloudBackupQueued) {
          _cloudBackupQueued = false;
        }
        setState(() {
          _isSyncingCloudBackup = false;
        });
      }
    }

    if (rerunQueuedBackup) {
      unawaited(_queueCloudBackup());
    }
  }

  void _openAccountRegistrationFlow() {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSection = HomeSection.profile;
      _accountAuthMode = AccountAuthMode.register;
    });
  }

  bool _isLikelyValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  }

  Future<String?> _promptRecoveryEmail() async {
    final emailController = TextEditingController(
      text: _accountEmailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Recupera password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inserisci la tua email: carico le 2 domande di sicurezza.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final emailValue = value?.trim() ?? '';
                    return _isLikelyValidEmail(emailValue)
                        ? null
                        : 'Inserisci un email valida.';
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final isValid = formKey.currentState?.validate() ?? false;
                if (!isValid) {
                  return;
                }

                Navigator.of(dialogContext).pop(emailController.text.trim());
              },
              child: const Text('Continua'),
            ),
          ],
        );
      },
    );

    emailController.dispose();
    return email;
  }

  Future<({String answerOne, String answerTwo, String newPassword})?>
  _promptRecoveryAnswers({
    required String questionOne,
    required String questionTwo,
  }) async {
    final formKey = GlobalKey<FormState>();
    final answerOneController = TextEditingController();
    final answerTwoController = TextEditingController();
    final newPasswordController = TextEditingController();
    var obscurePassword = true;

    final payload =
        await showDialog<
          ({String answerOne, String answerTwo, String newPassword})
        >(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                return AlertDialog(
                  title: const Text('Rispondi alle domande'),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            questionOne,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: answerOneController,
                            decoration: const InputDecoration(
                              labelText: 'Risposta 1',
                            ),
                            validator: (value) {
                              final answer = value?.trim() ?? '';
                              return answer.isNotEmpty
                                  ? null
                                  : 'Inserisci una risposta.';
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            questionTwo,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: answerTwoController,
                            decoration: const InputDecoration(
                              labelText: 'Risposta 2',
                            ),
                            validator: (value) {
                              final answer = value?.trim() ?? '';
                              return answer.isNotEmpty
                                  ? null
                                  : 'Inserisci una risposta.';
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: newPasswordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Nuova password',
                              helperText: 'Scegli la password che preferisci',
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? 'Mostra password'
                                    : 'Nascondi password',
                                onPressed: () => setDialogState(() {
                                  obscurePassword = !obscurePassword;
                                }),
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              return password.trim().isNotEmpty
                                  ? null
                                  : 'Inserisci la nuova password.';
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Annulla'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final isValid =
                            formKey.currentState?.validate() ?? false;
                        if (!isValid) {
                          return;
                        }

                        Navigator.of(dialogContext).pop((
                          answerOne: answerOneController.text.trim(),
                          answerTwo: answerTwoController.text.trim(),
                          newPassword: newPasswordController.text,
                        ));
                      },
                      child: const Text('Aggiorna password'),
                    ),
                  ],
                );
              },
            );
          },
        );

    answerOneController.dispose();
    answerTwoController.dispose();
    newPasswordController.dispose();
    return payload;
  }

  Future<void> _openPasswordRecoveryFlow() async {
    if (widget.accountService == null || _isRecoveringAccountPassword) {
      return;
    }

    final email = await _promptRecoveryEmail();
    if (email == null || email.trim().isEmpty) {
      return;
    }

    late final String questionOne;
    late final String questionTwo;
    setState(() {
      _isRecoveringAccountPassword = true;
    });

    try {
      final recoveryQuestions = await widget.accountService!
          .loadRecoveryQuestions(email: email);
      questionOne = recoveryQuestions.questionOne;
      questionTwo = recoveryQuestions.questionTwo;
      if (recoveryQuestions.locked) {
        final waitMinutes = recoveryQuestions.retryAfterMinutes;
        throw ApiException(
          waitMinutes == null
              ? 'Troppi tentativi. Riprova tra poco.'
              : 'Troppi tentativi. Riprova tra circa $waitMinutes minuti.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecoveringAccountPassword = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
      return;
    }

    setState(() {
      _isRecoveringAccountPassword = false;
    });

    final recoveryPayload = await _promptRecoveryAnswers(
      questionOne: questionOne,
      questionTwo: questionTwo,
    );
    if (recoveryPayload == null) {
      return;
    }

    setState(() {
      _isRecoveringAccountPassword = true;
    });
    try {
      await widget.accountService!.recoverPassword(
        email: email,
        answerOne: recoveryPayload.answerOne,
        answerTwo: recoveryPayload.answerTwo,
        newPassword: recoveryPayload.newPassword,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecoveringAccountPassword = false;
      });
      _accountEmailController.text = email;
      _accountPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password aggiornata. Ora puoi accedere con la nuova password.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecoveringAccountPassword = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _openRecoveryQuestionsSetupFlow() async {
    if (widget.accountService == null ||
        _accountSession == null ||
        _isConfiguringRecoveryQuestions) {
      return;
    }

    final formKey = GlobalKey<FormState>();
    final questionOneController = TextEditingController();
    final answerOneController = TextEditingController();
    final questionTwoController = TextEditingController();
    final answerTwoController = TextEditingController();

    final payload =
        await showDialog<
          ({
            String questionOne,
            String answerOne,
            String questionTwo,
            String answerTwo,
          })?
        >(
          context: context,
          builder: (dialogContext) {
            Widget suggestionWrap({required TextEditingController controller}) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recoveryQuestionSuggestions
                    .map(
                      (question) => ActionChip(
                        label: Text(question),
                        onPressed: () {
                          controller.text = question;
                        },
                      ),
                    )
                    .toList(growable: false),
              );
            }

            return AlertDialog(
              title: const Text('Metodi di recupero'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Imposta 2 domande di sicurezza: puoi scegliere dai suggerimenti o scriverne di personalizzate.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: questionOneController,
                        decoration: const InputDecoration(
                          labelText: 'Domanda 1',
                        ),
                        validator: (value) {
                          final question = value?.trim() ?? '';
                          return question.isNotEmpty
                              ? null
                              : 'Inserisci una domanda.';
                        },
                      ),
                      const SizedBox(height: 8),
                      suggestionWrap(controller: questionOneController),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: answerOneController,
                        decoration: const InputDecoration(
                          labelText: 'Risposta 1',
                        ),
                        validator: (value) {
                          final answer = value?.trim() ?? '';
                          return answer.isNotEmpty
                              ? null
                              : 'Inserisci una risposta.';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: questionTwoController,
                        decoration: const InputDecoration(
                          labelText: 'Domanda 2',
                        ),
                        validator: (value) {
                          final question = value?.trim() ?? '';
                          return question.isNotEmpty
                              ? null
                              : 'Inserisci una domanda.';
                        },
                      ),
                      const SizedBox(height: 8),
                      suggestionWrap(controller: questionTwoController),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: answerTwoController,
                        decoration: const InputDecoration(
                          labelText: 'Risposta 2',
                        ),
                        validator: (value) {
                          final answer = value?.trim() ?? '';
                          return answer.isNotEmpty
                              ? null
                              : 'Inserisci una risposta.';
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    final isValid = formKey.currentState?.validate() ?? false;
                    if (!isValid) {
                      return;
                    }

                    Navigator.of(dialogContext).pop((
                      questionOne: questionOneController.text.trim(),
                      answerOne: answerOneController.text.trim(),
                      questionTwo: questionTwoController.text.trim(),
                      answerTwo: answerTwoController.text.trim(),
                    ));
                  },
                  child: const Text('Salva domande'),
                ),
              ],
            );
          },
        );

    questionOneController.dispose();
    answerOneController.dispose();
    questionTwoController.dispose();
    answerTwoController.dispose();

    if (payload == null) {
      return;
    }

    setState(() {
      _isConfiguringRecoveryQuestions = true;
    });
    try {
      await widget.accountService!.configureRecoveryQuestions(
        session: _accountSession,
        questionOne: payload.questionOne,
        answerOne: payload.answerOne,
        questionTwo: payload.questionTwo,
        answerTwo: payload.answerTwo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isConfiguringRecoveryQuestions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Domande di recupero salvate. Ora puoi recuperare la password senza codice.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isConfiguringRecoveryQuestions = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _registerAccount() async {
    if (widget.accountService == null) {
      return;
    }

    final email = _accountEmailController.text.trim();
    final password = _accountPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci email e password per registrarti.'),
        ),
      );
      return;
    }

    setState(() {
      _isAuthenticatingAccount = true;
    });

    try {
      _logDiagnostic(
        'account.register.start',
        details: <String, Object?>{'email': email},
      );
      final session = await widget.accountService!.register(
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _accountSession = session;
        _isAuthenticatingAccount = false;
        _accountAuthMode = AccountAuthMode.login;
        _lastCloudBackupSucceeded = null;
        _lastCloudBackupFeedback = null;
      });
      _accountPasswordController.clear();
      unawaited(_refreshCloudBackupStatus(silent: true));
      _logDiagnostic(
        'account.register.ok',
        details: <String, Object?>{'email': session.user.email},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account creato. Da ora i dati vengono salvati anche nel cloud.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthenticatingAccount = false;
      });
      _logDiagnostic(
        'account.register.error',
        details: <String, Object?>{'email': email, 'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _loginAccount() async {
    if (widget.accountService == null) {
      return;
    }

    final email = _accountEmailController.text.trim();
    final password = _accountPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci email e password per accedere.'),
        ),
      );
      return;
    }

    setState(() {
      _isAuthenticatingAccount = true;
    });

    try {
      _logDiagnostic(
        'account.login.start',
        details: <String, Object?>{'email': email},
      );
      final session = await widget.accountService!.login(
        email: email,
        password: password,
      );
      final backupStatus = await widget.accountService!.loadCloudBackupStatus(
        session: session,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _accountSession = session;
        _isAuthenticatingAccount = false;
        _accountAuthMode = AccountAuthMode.login;
        _hasCloudBackupAvailable = backupStatus.hasBackup;
        _lastCloudBackupAt = backupStatus.hasBackup
            ? backupStatus.updatedAt
            : null;
        _lastCloudBackupAttemptAt = null;
        _lastCloudBackupSucceeded = null;
        _lastCloudBackupFeedback = backupStatus.hasBackup
            ? 'Account attivo. Backup cloud trovato: puoi ripristinarlo quando vuoi.'
            : 'Account attivo. Nessun backup cloud trovato: usa "Backup ora" per salvarne uno.';
      });
      _accountPasswordController.clear();

      if (!mounted) {
        return;
      }

      _logDiagnostic(
        'account.login.ok',
        details: <String, Object?>{
          'email': session.user.email,
          'hasBackup': backupStatus.hasBackup,
          'updatedAt': backupStatus.updatedAt?.toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backupStatus.hasBackup
                ? 'Accesso completato. Backup cloud disponibile: tocca "Ripristina dal cloud" se vuoi recuperarlo.'
                : 'Accesso completato. Nessun backup cloud trovato: puoi iniziare e fare "Backup ora".',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthenticatingAccount = false;
      });
      _logDiagnostic(
        'account.login.error',
        details: <String, Object?>{'email': email, 'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _restoreCloudBackup() async {
    if (widget.accountService == null || _accountSession == null) {
      return;
    }
    if (!_hasCloudBackupAvailable) {
      _logDiagnostic(
        'cloud.restore.skipped',
        details: const <String, Object?>{'reason': 'no_backup_available'},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessun backup cloud disponibile per questo account. Usa "Backup ora".',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isRestoringCloudBackup = true;
    });

    try {
      _logDiagnostic('cloud.restore.start');
      final restoreResult = await widget.accountService!.restoreFromCloud(
        session: _accountSession,
      );
      if (!mounted) {
        return;
      }

      if (restoreResult.bundle != null) {
        await widget.onAppearanceSettingsChanged(
          restoreResult.bundle!.appearanceSettings,
        );
        await _loadSnapshot(month: _selectedMonth, selectedDate: _selectedDate);
        await _loadWorkdaySessionForDate(_selectedDate);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringCloudBackup = false;
        _hasCloudBackupAvailable = restoreResult.hasBackup;
        _lastCloudBackupAt = restoreResult.hasBackup
            ? (restoreResult.bundle?.updatedAt ?? _lastCloudBackupAt)
            : null;
        _lastCloudBackupSucceeded = restoreResult.hasBackup;
        _lastCloudBackupFeedback = restoreResult.hasBackup
            ? 'Ripristino completato dal backup cloud.'
            : 'Nessun backup cloud disponibile per questo account.';
      });
      unawaited(_refreshCloudBackupStatus(silent: true));
      _logDiagnostic(
        'cloud.restore.ok',
        details: <String, Object?>{
          'hasBackup': restoreResult.hasBackup,
          'updatedAt': restoreResult.bundle?.updatedAt?.toIso8601String(),
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restoreResult.hasBackup
                ? 'Backup cloud ripristinato.'
                : 'Nessun backup cloud disponibile per questo account.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorizedApiError(error)) {
        _logDiagnostic(
          'cloud.restore.unauthorized',
          details: <String, Object?>{'error': error.toString()},
        );
        await _handleInvalidCloudSession(showFeedback: true);
        return;
      }

      setState(() {
        _isRestoringCloudBackup = false;
      });
      _logDiagnostic(
        'cloud.restore.error',
        details: <String, Object?>{'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _logoutAccount() async {
    if (widget.accountService == null) {
      return;
    }

    setState(() {
      _isAuthenticatingAccount = true;
    });

    try {
      await widget.accountService!.logout();
      if (!mounted) {
        return;
      }

      setState(() {
        _accountSession = null;
        _isAuthenticatingAccount = false;
        _accountAuthMode = AccountAuthMode.login;
        _hasCloudBackupAvailable = false;
        _lastCloudBackupAt = null;
        _lastCloudBackupAttemptAt = null;
        _lastCloudBackupSucceeded = null;
        _lastCloudBackupFeedback = null;
        _isLoadingCloudBackupStatus = false;
      });
      _logDiagnostic('account.logout.ok');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup cloud disattivato. I dati restano su questo dispositivo.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthenticatingAccount = false;
      });
      _logDiagnostic(
        'account.logout.error',
        details: <String, Object?>{'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _loadWorkdaySessionForDate(DateTime date) async {
    final isoDate = DashboardService.defaultEntryDateOf(date);
    final session = await widget.workdayStartStore.loadSession(isoDate);
    if (!mounted || !isSameDay(_selectedDate, date)) {
      return;
    }

    setState(() {
      _workdaySession = session;
      _syncSelectedDayPauseWindowDraftForCurrentDisplay(session: session);
    });
  }

  TrackedSupportTicket? _trackedTicketById(String? ticketId) {
    if (ticketId == null) {
      return null;
    }

    for (final ticket in _trackedTickets) {
      if (ticket.id == ticketId) {
        return ticket;
      }
    }

    return null;
  }

  int _countUnreadAdminReplies(
    List<TrackedSupportTicket> trackedTickets,
    Map<String, SupportTicketThread> ticketThreadsById,
  ) {
    var unreadReplies = 0;
    for (final trackedTicket in trackedTickets) {
      final thread = ticketThreadsById[trackedTicket.id];
      if (thread == null) {
        continue;
      }

      unreadReplies += math.max(
        0,
        thread.adminReplyCount - trackedTicket.lastSeenAdminReplyCount,
      );
    }

    return unreadReplies;
  }

  void _startTicketNotificationPolling() {
    _ticketNotificationTimer?.cancel();
    _ticketNotificationTimer = Timer.periodic(
      ticketNotificationPollingInterval,
      (_) {
        if (!mounted) {
          return;
        }
        unawaited(_refreshTrackedSupportTickets(notifyAboutNewReplies: true));
      },
    );
  }

  void _startLiveWorkedMinutesTicker() {
    _liveWorkedMinutesTimer?.cancel();
    _liveWorkedMinutesTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _selectedSection != HomeSection.day) {
        return;
      }
      setState(() {});
    });
  }

  Future<void> _initializeRemotePushForegroundHandling() async {
    try {
      await _foregroundPushSubscription?.cancel();
      _foregroundPushSubscription = FirebaseMessaging.onMessage.listen((
        message,
      ) {
        unawaited(_handleForegroundRemotePush(message));
      });
    } catch (_) {
      // Foreground push handling is best-effort.
    }
  }

  Future<void> _handleForegroundRemotePush(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final type = _normalizePushDataValue(data['type']);

    if (type == 'ticket_reply') {
      final fallbackTicketMessage = data['message'];
      final ticketMessage = notification?.body?.trim().isNotEmpty == true
          ? notification!.body!.trim()
          : _normalizePushDataValue(fallbackTicketMessage) ??
                'Nuova risposta dal supporto.';
      await _localNotificationService.notifyTicketReplies(
        message: ticketMessage,
      );
      return;
    }

    if (type == 'app_update') {
      final fallbackUpdateMessage = data['message'];
      final updateMessage = notification?.body?.trim().isNotEmpty == true
          ? notification!.body!.trim()
          : _normalizePushDataValue(fallbackUpdateMessage) ??
                'Nuova versione disponibile. Apri l app per vedere le novita.';
      final updateTitle = notification?.title?.trim().isNotEmpty == true
          ? notification!.title!.trim()
          : 'Nuovo aggiornamento disponibile';
      await _localNotificationService.notifyUpdateMessage(
        title: updateTitle,
        message: updateMessage,
        version: _normalizePushDataValue(data['version']),
      );
      return;
    }
  }

  String? _normalizePushDataValue(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      await _localNotificationService.initialize();
      await _localNotificationService.requestPermissions();
    } catch (_) {
      // Local notifications are best-effort and should not block app startup.
    }
  }

  String _buildTicketReplyNotificationMessage(
    List<({String subject, int newReplies})> updates,
  ) {
    if (updates.isEmpty) {
      return 'Nuove risposte ticket disponibili.';
    }

    if (updates.length == 1) {
      final update = updates.first;
      if (update.newReplies == 1) {
        return 'Nuova risposta su "${update.subject}".';
      }
      return 'Hai ${update.newReplies} nuove risposte su "${update.subject}".';
    }

    final totalNewReplies = updates.fold<int>(
      0,
      (total, update) => total + update.newReplies,
    );
    if (totalNewReplies == updates.length) {
      return 'Hai nuove risposte su ${updates.length} ticket.';
    }

    return 'Hai $totalNewReplies nuove risposte su ${updates.length} ticket.';
  }

  Future<void> _markTrackedTicketRepliesNotified(
    List<({String ticketId, int adminReplyCount})> updates,
  ) async {
    if (updates.isEmpty) {
      return;
    }

    final latestAdminReplyCountByTicket = <String, int>{};
    for (final update in updates) {
      final previousValue = latestAdminReplyCountByTicket[update.ticketId];
      if (previousValue == null || update.adminReplyCount > previousValue) {
        latestAdminReplyCountByTicket[update.ticketId] = update.adminReplyCount;
      }
    }

    await widget.supportTicketStore.markAdminRepliesNotifiedBatch(
      adminReplyCountByTicketId: latestAdminReplyCountByTicket,
    );
    if (!mounted) {
      return;
    }

    var hasChanges = false;
    final nextTrackedTickets = _trackedTickets
        .map((ticket) {
          final latestAdminReplyCount =
              latestAdminReplyCountByTicket[ticket.id];
          if (latestAdminReplyCount == null ||
              latestAdminReplyCount <= ticket.lastNotifiedAdminReplyCount) {
            return ticket;
          }
          hasChanges = true;
          return ticket.copyWith(
            lastNotifiedAdminReplyCount: latestAdminReplyCount,
          );
        })
        .toList(growable: false);
    if (!hasChanges) {
      return;
    }

    setState(() {
      _trackedTickets = nextTrackedTickets;
    });
  }

  Future<void> _refreshTrackedSupportTickets({
    bool notifyAboutNewReplies = false,
  }) async {
    if (_isLoadingTicketThreads) {
      return;
    }

    setState(() {
      _isLoadingTicketThreads = true;
    });

    try {
      final trackedTickets = await widget.supportTicketStore
          .loadTrackedTickets();
      if (trackedTickets.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _trackedTickets = const [];
          _ticketThreadsById = const {};
          _selectedTrackedTicketId = null;
          _unreadTicketReplyCount = 0;
          _isLoadingTicketThreads = false;
        });
        return;
      }

      final fetchedEntries = await Future.wait(
        trackedTickets.map((trackedTicket) async {
          try {
            final thread = await widget.dashboardService.fetchSupportTicket(
              ticketId: trackedTicket.id,
            );
            return (tracked: trackedTicket, thread: thread);
          } catch (_) {
            return null;
          }
        }),
      );

      final nextThreadsById = <String, SupportTicketThread>{};
      final nextTrackedTickets = <TrackedSupportTicket>[];
      final newRepliesToNotify =
          <
            ({
              String ticketId,
              String subject,
              int newReplies,
              int adminReplyCount,
            })
          >[];
      for (var index = 0; index < trackedTickets.length; index++) {
        final trackedTicket = trackedTickets[index];
        final entry = fetchedEntries[index];
        if (entry == null) {
          nextTrackedTickets.add(trackedTicket);
          final cachedThread = _ticketThreadsById[trackedTicket.id];
          if (cachedThread != null) {
            nextThreadsById[trackedTicket.id] = cachedThread;
          }
          continue;
        }

        nextThreadsById[entry.thread.id] = entry.thread;
        nextTrackedTickets.add(
          entry.tracked.copyWith(
            subject: entry.thread.subject,
            createdAt: entry.thread.createdAt,
          ),
        );

        final unreadReplies = math.max(
          0,
          entry.thread.adminReplyCount - entry.tracked.lastSeenAdminReplyCount,
        );
        if (notifyAboutNewReplies && unreadReplies > 0) {
          final newReplies = math.max(
            0,
            entry.thread.adminReplyCount -
                entry.tracked.lastNotifiedAdminReplyCount,
          );
          if (newReplies > 0) {
            newRepliesToNotify.add((
              ticketId: entry.thread.id,
              subject: entry.thread.subject,
              newReplies: newReplies,
              adminReplyCount: entry.thread.adminReplyCount,
            ));
          }
        }
      }

      final selectedTicketId =
          nextThreadsById.containsKey(_selectedTrackedTicketId)
          ? _selectedTrackedTicketId
          : (nextTrackedTickets.isEmpty ? null : nextTrackedTickets.first.id);
      final unreadTicketReplyCount = _countUnreadAdminReplies(
        nextTrackedTickets,
        nextThreadsById,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _trackedTickets = nextTrackedTickets;
        _ticketThreadsById = nextThreadsById;
        _selectedTrackedTicketId = selectedTicketId;
        _unreadTicketReplyCount = unreadTicketReplyCount;
        _isLoadingTicketThreads = false;
      });

      if (notifyAboutNewReplies && newRepliesToNotify.isNotEmpty) {
        await _markTrackedTicketRepliesNotified(
          newRepliesToNotify
              .map(
                (update) => (
                  ticketId: update.ticketId,
                  adminReplyCount: update.adminReplyCount,
                ),
              )
              .toList(growable: false),
        );
      }

      if (notifyAboutNewReplies && newRepliesToNotify.isNotEmpty && mounted) {
        final message = _buildTicketReplyNotificationMessage(
          newRepliesToNotify
              .map(
                (update) =>
                    (subject: update.subject, newReplies: update.newReplies),
              )
              .toList(growable: false),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        unawaited(
          _localNotificationService.notifyTicketReplies(message: message),
        );
      }

      final currentSelectedTicketId = selectedTicketId;
      if (_selectedSection == HomeSection.ticket &&
          currentSelectedTicketId != null) {
        unawaited(_markTrackedTicketRepliesSeen(currentSelectedTicketId));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingTicketThreads = false;
      });
    }
  }

  Future<void> _upsertTrackedSupportTicket(SupportTicketThread thread) async {
    final trackedTicket = _trackedTicketById(thread.id);
    final nextTrackedTicket = TrackedSupportTicket(
      id: thread.id,
      subject: thread.subject,
      createdAt: thread.createdAt,
      lastSeenAdminReplyCount:
          trackedTicket?.lastSeenAdminReplyCount ?? thread.adminReplyCount,
      lastNotifiedAdminReplyCount:
          trackedTicket?.lastNotifiedAdminReplyCount ?? thread.adminReplyCount,
    );
    await widget.supportTicketStore.upsertTrackedTicket(nextTrackedTicket);
  }

  Future<void> _markTrackedTicketRepliesSeen(String ticketId) async {
    final thread = _ticketThreadsById[ticketId];
    if (thread == null) {
      return;
    }

    final trackedTicket = _trackedTicketById(ticketId);
    if (trackedTicket == null) {
      return;
    }
    if (trackedTicket.lastSeenAdminReplyCount >= thread.adminReplyCount &&
        trackedTicket.lastNotifiedAdminReplyCount >= thread.adminReplyCount) {
      return;
    }

    await widget.supportTicketStore.markAdminRepliesSeenAndNotified(
      ticketId: ticketId,
      adminReplyCount: thread.adminReplyCount,
    );
    if (!mounted) {
      return;
    }

    final latestReplyCount = thread.adminReplyCount;
    final nextTrackedTickets = _trackedTickets
        .map(
          (ticket) => ticket.id == ticketId
              ? ticket.copyWith(
                  lastSeenAdminReplyCount: latestReplyCount,
                  lastNotifiedAdminReplyCount: latestReplyCount,
                )
              : ticket,
        )
        .toList(growable: false);
    setState(() {
      _trackedTickets = nextTrackedTickets;
      _unreadTicketReplyCount = _countUnreadAdminReplies(
        nextTrackedTickets,
        _ticketThreadsById,
      );
    });
  }

  Future<void> _selectTrackedSupportTicket(String ticketId) async {
    setState(() {
      _selectedTrackedTicketId = ticketId;
    });
    await _markTrackedTicketRepliesSeen(ticketId);
  }

  Future<void> _recoverTrackedSupportTicketById() async {
    final ticketId = _ticketRecoveryIdController.text.trim();
    if (ticketId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il codice ticket.')),
      );
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(ticketId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codice ticket non valido.')),
      );
      return;
    }
    if (_isRecoveringTrackedTicket) {
      return;
    }

    setState(() {
      _isRecoveringTrackedTicket = true;
    });

    try {
      final thread = await widget.dashboardService.fetchSupportTicket(
        ticketId: ticketId,
      );
      await _upsertTrackedSupportTicket(thread);
      if (!mounted) {
        return;
      }

      _ticketRecoveryIdController.clear();
      await _refreshTrackedSupportTickets(notifyAboutNewReplies: false);
      if (!mounted) {
        return;
      }

      await _selectTrackedSupportTicket(thread.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ticket ${thread.id} recuperato. Le prossime risposte arriveranno qui.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _humanizeError(
              error,
              apiBaseUrl: _snapshot?.apiBaseUrl,
              isTicketRequest: true,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRecoveringTrackedTicket = false;
        });
      }
    }
  }

  Future<void> _submitSupportTicketReply() async {
    final selectedTicketId = _selectedTrackedTicketId;
    if (selectedTicketId == null) {
      return;
    }

    final selectedThread = _ticketThreadsById[selectedTicketId];
    if (selectedThread != null &&
        selectedThread.status == SupportTicketStatus.closed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Questo ticket e chiuso e non puo ricevere altre risposte.',
          ),
        ),
      );
      return;
    }

    final message = _ticketReplyController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrivi una risposta prima di inviarla.')),
      );
      return;
    }

    setState(() {
      _isSubmittingTicketReply = true;
    });

    try {
      final updatedThread = await widget.dashboardService.replyToSupportTicket(
        ticketId: selectedTicketId,
        message: message,
      );
      await _upsertTrackedSupportTicket(updatedThread);
      if (!mounted) {
        return;
      }

      _ticketReplyController.clear();
      final nextThreadsById = Map<String, SupportTicketThread>.from(
        _ticketThreadsById,
      )..[updatedThread.id] = updatedThread;
      setState(() {
        _ticketThreadsById = nextThreadsById;
        _isSubmittingTicketReply = false;
      });
      await _markTrackedTicketRepliesSeen(updatedThread.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risposta inviata correttamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmittingTicketReply = false;
        _errorMessage = _humanizeError(
          error,
          apiBaseUrl: _snapshot?.apiBaseUrl,
          isTicketRequest: true,
        );
      });
    }
  }

  void _rescheduleMissingExitReminderForSession(WorkdaySession session) {
    final todayMonth = DashboardService.formatMonth(_todayDate);
    final snapshot = _snapshotForMonth(todayMonth) ?? _snapshot;
    if (snapshot == null) {
      return;
    }

    final schedule = _resolveEffectiveDayScheduleForDate(snapshot, _todayDate);
    if (schedule.targetMinutes <= 0) {
      return;
    }

    final nowMinutes = _currentMinutesOfDay();
    final actualBreakMinutes = currentSessionBreakMinutes(session, nowMinutes);
    final effectiveBreakMinutes = math.max(
      schedule.breakMinutes,
      actualBreakMinutes,
    );
    final expectedEndMinutes =
        session.startMinutes + schedule.targetMinutes + effectiveBreakMinutes;
    unawaited(
      _localNotificationService.scheduleMissingExitReminder(
        // Un'ora di margine oltre l'uscita prevista prima del promemoria.
        delay: Duration(minutes: (expectedEndMinutes + 60) - nowMinutes),
        expectedEndLabel: formatTimeInput(expectedEndMinutes % (24 * 60)),
      ),
    );
  }

  void _scheduleBreakEndReminderForSession(WorkdaySession session) {
    final todayMonth = DashboardService.formatMonth(_todayDate);
    final snapshot = _snapshotForMonth(todayMonth) ?? _snapshot;
    if (snapshot == null) {
      return;
    }

    final schedule = _resolveEffectiveDayScheduleForDate(snapshot, _todayDate);
    final remainingBreakMinutes =
        schedule.breakMinutes - session.accumulatedBreakMinutes;
    if (remainingBreakMinutes <= 0) {
      return;
    }

    unawaited(
      _localNotificationService.scheduleBreakEndReminder(
        delay: Duration(minutes: remainingBreakMinutes),
      ),
    );
  }

  void _cancelWorkdayReminders() {
    unawaited(_localNotificationService.cancelBreakEndReminder());
    unawaited(_localNotificationService.cancelMissingExitReminder());
  }

  Future<void> _recordWorkdayStartNow() async {
    if (!isSameDay(_selectedDate, _todayDate)) {
      return;
    }

    final now = DateTime.now();
    final startMinutes = (now.hour * 60) + now.minute;
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);

    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      final session = WorkdaySession(startMinutes: startMinutes);
      await widget.workdayStartStore.saveSession(isoDate, session);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = session;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(session: session);
        _isSavingWorkdaySession = false;
      });
      _rescheduleMissingExitReminderForSession(session);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Entrata registrata alle ${formatTimeInput(startMinutes)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile registrare l entrata in questo momento.';
      });
    }
  }

  Future<void> _startWorkdayBreakNow() async {
    final session = _workdaySession;
    if (!isSameDay(_selectedDate, _todayDate) ||
        session == null ||
        session.isOnBreak ||
        session.isCompleted) {
      return;
    }

    final now = DateTime.now();
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      final updatedSession = session.copyWith(
        breakStartedMinutes: (now.hour * 60) + now.minute,
      );
      await widget.workdayStartStore.saveSession(isoDate, updatedSession);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = updatedSession;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(
          session: updatedSession,
        );
        _isSavingWorkdaySession = false;
      });
      _scheduleBreakEndReminderForSession(updatedSession);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile avviare la pausa in questo momento.';
      });
    }
  }

  Future<void> _resumeWorkdayNow() async {
    final session = _workdaySession;
    final breakStartedMinutes = session?.breakStartedMinutes;
    if (!isSameDay(_selectedDate, _todayDate) ||
        session == null ||
        breakStartedMinutes == null ||
        session.isCompleted) {
      return;
    }

    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      final addedBreakMinutes = math.max(0, nowMinutes - breakStartedMinutes);
      final updatedSession = session.copyWith(
        breakStartedMinutes: null,
        accumulatedBreakMinutes:
            session.accumulatedBreakMinutes + addedBreakMinutes,
        breakSegments: [
          ...session.breakSegments,
          WorkdayBreakSegment(
            startMinutes: breakStartedMinutes,
            endMinutes: nowMinutes,
          ),
        ],
      );
      await widget.workdayStartStore.saveSession(isoDate, updatedSession);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = updatedSession;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(
          session: updatedSession,
        );
        _isSavingWorkdaySession = false;
      });
      unawaited(_localNotificationService.cancelBreakEndReminder());
      _rescheduleMissingExitReminderForSession(updatedSession);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile riprendere la giornata in questo momento.';
      });
    }
  }

  Future<void> _finishWorkdayNow() async {
    final session = _workdaySession;
    if (!isSameDay(_selectedDate, _todayDate) ||
        session == null ||
        session.isCompleted) {
      return;
    }

    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      final totalBreakMinutes = session.breakStartedMinutes == null
          ? session.accumulatedBreakMinutes
          : session.accumulatedBreakMinutes +
                    math.max(0, nowMinutes - session.breakStartedMinutes!)
                as int;
      final completedBreakSegments = session.breakStartedMinutes == null
          ? session.breakSegments
          : [
              ...session.breakSegments,
              WorkdayBreakSegment(
                startMinutes: session.breakStartedMinutes!,
                endMinutes: nowMinutes,
              ),
            ];
      final updatedSession = session.copyWith(
        breakStartedMinutes: null,
        accumulatedBreakMinutes: totalBreakMinutes,
        breakSegments: completedBreakSegments,
        endMinutes: nowMinutes,
      );
      await widget.workdayStartStore.saveSession(isoDate, updatedSession);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = updatedSession;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(
          session: updatedSession,
        );
        _isSavingWorkdaySession = false;
      });
      _cancelWorkdayReminders();
      unawaited(_queueCloudBackup());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile registrare l uscita in questo momento.';
      });
    }
  }

  Future<void> _clearWorkdaySession() async {
    final isoDate = DashboardService.defaultEntryDateOf(_selectedDate);
    setState(() {
      _isSavingWorkdaySession = true;
    });

    try {
      await widget.workdayStartStore.clearSession(isoDate);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = null;
        _syncSelectedDayPauseWindowDraftForCurrentDisplay(session: null);
        _isSavingWorkdaySession = false;
      });
      _cancelWorkdayReminders();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingWorkdaySession = false;
        _errorMessage = 'Impossibile rimuovere la giornata registrata.';
      });
    }
  }

  Future<void> _primeSnapshotFromLocalCache() async {
    final cachedSnapshot = await widget.dashboardSnapshotStore.loadSnapshot(
      _selectedMonth,
    );
    if (!mounted || cachedSnapshot == null) {
      return;
    }

    final resolvedSelectedDate = _resolveSelectedDateForMonth(
      cachedSnapshot.summary.month,
      preferredDate: _selectedDate,
    );
    _hydrateControllers(cachedSnapshot, resolvedSelectedDate);
    _entryDateController.text = DashboardService.defaultEntryDateOf(
      resolvedSelectedDate,
    );

    setState(() {
      _snapshot = cachedSnapshot;
      _snapshotCache[cachedSnapshot.summary.month] = cachedSnapshot;
      _selectedMonth = cachedSnapshot.summary.month;
      _selectedDate = resolvedSelectedDate;
      _isLoading = false;
    });
  }

  Future<void> _cacheSnapshot(DashboardSnapshot snapshot) async {
    _snapshotCache[snapshot.summary.month] = snapshot;
    await widget.dashboardSnapshotStore.saveSnapshot(snapshot);
  }

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

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

  void _openWorkSettingsSectionFromSummary() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedSection = HomeSection.workSettings;
    });
  }

  void _handleOvertimeLimitExceededNotification(int exceededMinutes) {
    if (exceededMinutes <= 0 || !isSameDay(_selectedDate, _todayDate)) {
      _lastOvertimeExceededNotificationKey = null;
      return;
    }

    final notificationKey = DashboardService.defaultEntryDateOf(_selectedDate);
    if (_lastOvertimeExceededNotificationKey == notificationKey) {
      return;
    }
    _lastOvertimeExceededNotificationKey = notificationKey;

    unawaited(
      _localNotificationService.notifyOvertimeLimitExceeded(
        message:
            'Sei oltre il limite di straordinario di ${formatHoursInput(exceededMinutes)}.',
      ),
    );
  }

  void _openWorkQuickEntryForDate(
    DateTime date, {
    int? prefilledMinutes,
    String? note,
  }) {
    setState(() {
      _selectedSection = HomeSection.quickEntry;
      _selectedEntryMode = QuickEntryMode.work;
      _entryDateController.text = DashboardService.defaultEntryDateOf(date);
      _entryMinutesController.text = prefilledMinutes == null
          ? ''
          : formatHoursInput(prefilledMinutes);
      _entryNoteController.text = note ?? '';
    });
  }

  void _openLeaveQuickEntryForDate(
    DateTime date, {
    int? prefilledMinutes,
    LeaveType leaveType = LeaveType.permit,
    String? note,
  }) {
    setState(() {
      _selectedSection = HomeSection.quickEntry;
      _selectedEntryMode = QuickEntryMode.leave;
      _selectedLeaveType = leaveType;
      _entryDateController.text = DashboardService.defaultEntryDateOf(date);
      _entryMinutesController.text = prefilledMinutes == null
          ? ''
          : formatHoursInput(prefilledMinutes);
      _entryNoteController.text = note ?? '';
    });
  }

  Future<void> _openDayForDate(DateTime date) async {
    setState(() {
      _selectedSection = HomeSection.day;
    });
    await _setSelectedDate(date, alignToPeriod: false);
  }

  Future<void> _shiftSelectedDay(int step) async {
    await _setSelectedDate(
      _selectedDate.add(Duration(days: step)),
      alignToPeriod: false,
    );
  }

  Future<void> _prepareTodayOverridePreset(TodayOverridePreset preset) async {
    final today = _todayDate;
    final todayMonth = DashboardService.formatMonth(today);
    if (todayMonth != _selectedMonth) {
      await _loadSnapshot(month: todayMonth, selectedDate: today);
    }

    final snapshot = _snapshotForMonth(todayMonth) ?? _snapshot;
    if (snapshot == null) {
      return;
    }

    final baseSchedule = _resolveBaseDayScheduleForDate(snapshot, today);
    final preparedSchedule = _buildPresetSchedule(preset, baseSchedule);

    await _setSelectedDate(today);
    _scheduleOverrideTargetController.text = formatHoursInput(
      preparedSchedule.targetMinutes,
    );
    _scheduleOverrideStartTimeController.text =
        preparedSchedule.startTime ?? '';
    _scheduleOverrideEndTimeController.text = preparedSchedule.endTime ?? '';
    _scheduleOverrideBreakController.text = formatBreakInput(
      preparedSchedule.breakMinutes,
    );
    setState(() {
      _selectedSection = HomeSection.day;
    });
  }

  Future<void> _removeTodayOverride() async {
    await _setSelectedDate(_todayDate);
    await _removeScheduleOverride();
  }

  DaySchedule _buildPresetSchedule(
    TodayOverridePreset preset,
    DaySchedule baseSchedule,
  ) {
    final startMinutes = parseTimeInput(baseSchedule.startTime);
    final endMinutes = parseTimeInput(baseSchedule.endTime);

    switch (preset) {
      case TodayOverridePreset.startLater:
        if (startMinutes != null && endMinutes != null) {
          return DaySchedule(
            targetMinutes: baseSchedule.targetMinutes,
            startTime: formatTimeInput(startMinutes + 60),
            endTime: formatTimeInput(endMinutes + 60),
            breakMinutes: baseSchedule.breakMinutes,
          );
        }
        return DaySchedule(
          targetMinutes: baseSchedule.targetMinutes,
          breakMinutes: baseSchedule.breakMinutes,
        );
      case TodayOverridePreset.finishEarlier:
        final nextTarget = (baseSchedule.targetMinutes - 60).clamp(0, 24 * 60);
        if (startMinutes != null && endMinutes != null) {
          return DaySchedule(
            targetMinutes: nextTarget,
            startTime: baseSchedule.startTime,
            endTime: formatTimeInput((endMinutes - 60).clamp(0, 24 * 60)),
            breakMinutes: baseSchedule.breakMinutes,
          );
        }
        return DaySchedule(
          targetMinutes: nextTarget,
          breakMinutes: baseSchedule.breakMinutes,
        );
      case TodayOverridePreset.longerBreak:
        if (startMinutes != null && endMinutes != null) {
          return DaySchedule(
            targetMinutes: baseSchedule.targetMinutes,
            startTime: baseSchedule.startTime,
            endTime: formatTimeInput((endMinutes + 30).clamp(0, 24 * 60)),
            breakMinutes: baseSchedule.breakMinutes + 30,
          );
        }
        return DaySchedule(
          targetMinutes: baseSchedule.targetMinutes,
          breakMinutes: baseSchedule.breakMinutes + 30,
        );
      case TodayOverridePreset.dayOff:
        return const DaySchedule(targetMinutes: 0);
    }
  }

  Future<DashboardSnapshot> _fetchSnapshotForMonth(String month) async {
    final currentSnapshot = _snapshot;
    if (currentSnapshot != null && currentSnapshot.summary.month == month) {
      _snapshotCache[month] = currentSnapshot;
      return currentSnapshot;
    }

    final cachedSnapshot = _snapshotCache[month];
    if (cachedSnapshot != null) {
      return cachedSnapshot;
    }

    final persistedSnapshot = await widget.dashboardSnapshotStore.loadSnapshot(
      month,
    );
    if (persistedSnapshot != null) {
      _snapshotCache[month] = persistedSnapshot;
      return persistedSnapshot;
    }

    final snapshot = await widget.dashboardService.loadSnapshot(month: month);
    await _cacheSnapshot(snapshot);
    return snapshot;
  }

  Future<void> _ensureCalendarDataForCurrentView() async {
    final months = _requiredMonthsForCalendarView();
    final missingMonths = months
        .where((month) => !_snapshotCache.containsKey(month))
        .toList(growable: false);
    if (missingMonths.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _isLoadingCalendarData = true;
    });

    try {
      for (final month in missingMonths) {
        final snapshot = await widget.dashboardService.loadSnapshot(
          month: month,
        );
        await _cacheSnapshot(snapshot);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _humanizeError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCalendarData = false;
        });
      }
    }
  }

  Future<void> _pickEntryDate() async {
    final initialDate =
        DateTime.tryParse(_entryDateController.text) ?? _selectedDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    final pickedMonth = DashboardService.formatMonth(pickedDate);
    if (pickedMonth != _selectedMonth) {
      await _loadSnapshot(month: pickedMonth, selectedDate: pickedDate);
      return;
    }

    _selectDate(pickedDate);
  }

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

  Future<void> _submitQuickEntry() async {
    final isValid = _quickEntryFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isSubmittingEntry = true;
      _errorMessage = null;
    });

    try {
      final note = _entryNoteController.text.trim();
      final snapshot = _selectedEntryMode == QuickEntryMode.work
          ? await widget.dashboardService.addWorkEntry(
              date: _entryDateController.text.trim(),
              minutes: int.parse(_entryMinutesController.text.trim()),
              note: note.isEmpty ? null : note,
            )
          : await widget.dashboardService.addLeaveEntry(
              date: _entryDateController.text.trim(),
              minutes: int.parse(_entryMinutesController.text.trim()),
              type: _selectedLeaveType,
              note: note.isEmpty ? null : note,
            );

      if (!mounted) {
        return;
      }

      _hydrateControllers(snapshot, _selectedDate);
      _entryMinutesController.clear();
      _entryNoteController.clear();
      setState(() {
        _snapshot = snapshot;
        _isSubmittingEntry = false;
      });
      final messenger = ScaffoldMessenger.of(context);
      await _queueCloudBackup();
      if (!mounted) {
        return;
      }

      final successMessage = _selectedEntryMode == QuickEntryMode.work
          ? 'Ore registrate con successo.'
          : '${_selectedLeaveType.label} registrato con successo.';
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
        _isSubmittingEntry = false;
      });
    }
  }

  Future<void> _removeScheduleOverride() async {
    setState(() {
      _isSavingScheduleOverride = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await widget.dashboardService.removeScheduleOverride(
        date: DashboardService.defaultEntryDateOf(_selectedDate),
      );

      if (!mounted) {
        return;
      }

      await _cacheSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      _hydrateControllers(snapshot, _selectedDate);
      setState(() {
        _snapshot = snapshot;
        _isSavingScheduleOverride = false;
      });
      await _queueCloudBackup();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
        _isSavingScheduleOverride = false;
      });
    }
  }

  Future<void> _autosaveScheduleOverride() async {
    _scheduleOverrideAutosaveQueued = true;
    if (_isSavingScheduleOverride) {
      return;
    }

    while (_scheduleOverrideAutosaveQueued) {
      _scheduleOverrideAutosaveQueued = false;

      final snapshot = _snapshotForMonth(_selectedMonth) ?? _snapshot;
      if (snapshot == null) {
        return;
      }

      final draftValidation = validateScheduleDraft(
        targetText: _scheduleOverrideTargetController.text,
        startTimeText: _scheduleOverrideStartTimeController.text,
        endTimeText: _scheduleOverrideEndTimeController.text,
        breakText: _scheduleOverrideBreakController.text,
      );
      final draftSchedule = _parseDayScheduleInput(
        targetText: _scheduleOverrideTargetController.text,
        startTimeText: _scheduleOverrideStartTimeController.text,
        endTimeText: _scheduleOverrideEndTimeController.text,
        breakText: _scheduleOverrideBreakController.text,
      );
      if (draftValidation != null || draftSchedule == null) {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
        continue;
      }

      final baseSchedule = _resolveBaseDayScheduleForDate(
        snapshot,
        _selectedDate,
      );
      final selectedOverride = _findScheduleOverrideForDate(
        snapshot,
        _selectedDate,
      );
      final autosaveAction = _sameDaySchedule(draftSchedule, baseSchedule)
          ? (selectedOverride == null
                ? _ScheduleOverrideAutosaveAction.none
                : _ScheduleOverrideAutosaveAction.remove)
          : _ScheduleOverrideAutosaveAction.save;
      assert(() {
        debugPrint(
          '[agenda-autosave] action=$autosaveAction date=${DashboardService.defaultEntryDateOf(_selectedDate)} '
          'start=${draftSchedule.startTime ?? '-'} end=${draftSchedule.endTime ?? '-'} '
          'target=${draftSchedule.targetMinutes} break=${draftSchedule.breakMinutes}',
        );
        return true;
      }());
      if (autosaveAction == _ScheduleOverrideAutosaveAction.none) {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
        continue;
      }

      if (mounted) {
        setState(() {
          _isSavingScheduleOverride = true;
          _errorMessage = null;
        });
      }

      try {
        final currentPauseWindow = _selectedDayPauseWindowDraft();
        final nextSnapshot =
            autosaveAction == _ScheduleOverrideAutosaveAction.remove
            ? await widget.dashboardService.removeScheduleOverride(
                date: DashboardService.defaultEntryDateOf(_selectedDate),
              )
            : await widget.dashboardService.saveScheduleOverride(
                date: DashboardService.defaultEntryDateOf(_selectedDate),
                targetMinutes: draftSchedule.targetMinutes,
                startTime: draftSchedule.startTime,
                endTime: draftSchedule.endTime,
                breakMinutes: draftSchedule.breakMinutes,
                note: null,
              );

        if (!mounted) {
          return;
        }

        await _cacheSnapshot(nextSnapshot);
        if (!mounted) {
          return;
        }

        _hydrateControllers(
          nextSnapshot,
          _selectedDate,
          resetScheduleHistory: false,
        );
        _setSelectedDayPauseWindowDraft(currentPauseWindow);
        setState(() {
          _snapshot = nextSnapshot;
          _isSavingScheduleOverride = false;
        });
        await _queueCloudBackup();
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage = _humanizeError(error);
          _isSavingScheduleOverride = false;
        });
        return;
      }
    }
  }

  Future<void> _pickScheduleOverrideTime(CalendarTimeField field) async {
    final initialMinutes = _currentScheduleOverrideTimeMinutes(field);
    final controller = _scheduleTimeController(field);
    final pickedSelection = await _showScheduleTimeWheelPicker(
      title: switch (field) {
        CalendarTimeField.start => 'Entrata',
        CalendarTimeField.end => 'Uscita',
      },
      initialMinutes: initialMinutes,
      allowClear: controller.text.trim().isNotEmpty,
      helperTextBuilder: (pickedMinutes) =>
          _buildScheduleOverrideWorkedMinutesPreviewLabel(
            field: field,
            pickedMinutes: pickedMinutes,
          ),
    );
    if (pickedSelection == null) {
      return;
    }

    _seedScheduleOverrideDraftFromCurrentDisplay();
    if (pickedSelection.cleared) {
      controller.clear();
    } else {
      controller.text = formatTimeInput(pickedSelection.minutes!);
    }
    if (field == CalendarTimeField.start) {
      _syncScheduleOverrideEndFromTarget(
        markPendingConfirmation: widget.appearanceSettings.showDayEndTime,
      );
    } else {
      _clearPendingExitConfirmationForSelectedDate();
    }
    _normalizeSelectedDayPauseWindowForCurrentDraft();
    _clearAgendaPreviewState();
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
    _pushCurrentScheduleOverrideDraftToHistory();
    if (_hasPendingExitConfirmationForSelectedDate) {
      return;
    }
    await _autosaveScheduleOverride();
  }

  String _buildScheduleOverrideWorkedMinutesPreviewLabel({
    required CalendarTimeField field,
    required int pickedMinutes,
  }) {
    final currentSchedule = _displayedScheduleStateForSelectedDate().schedule;
    final minimumBreakMinutes =
        _snapshot?.profile.workRules.minimumBreakMinutes;
    final previewSchedule = _buildFlexibleDayScheduleInput(
      targetText: _scheduleOverrideTargetController.text,
      startTimeText: field == CalendarTimeField.start
          ? formatTimeInput(pickedMinutes)
          : _scheduleOverrideStartTimeController.text,
      endTimeText: field == CalendarTimeField.end
          ? formatTimeInput(pickedMinutes)
          : _scheduleOverrideEndTimeController.text,
      breakText: _scheduleOverrideBreakController.text,
      fallbackSchedule: currentSchedule,
    );
    final workedMinutes = previewSchedule == null
        ? null
        : resolveComputedWorkedMinutes(
            schedule: previewSchedule,
            minimumBreakMinutes: minimumBreakMinutes ?? 0,
          );
    return workedMinutes == null
        ? 'Ore di lavoro: --'
        : 'Ore di lavoro: ${formatHoursInput(workedMinutes)}';
  }

  Future<void> _pickScheduleOverrideBreakMinutes() async {
    final currentBreakMinutes =
        _displayedScheduleStateForSelectedDate().schedule.breakMinutes;
    final weekday = _weekdayKeyForDate(_selectedDate);
    final pickedMinutes = await _showScheduleBreakWheelPicker(
      initialMinutes: currentBreakMinutes,
      standardScheduleLinkLabel: 'Vai a Orario di lavoro (${weekday.label})',
      onOpenStandardScheduleLink: _openSelectedWeekdayStandardWorkSettings,
    );
    if (pickedMinutes == null) {
      return;
    }
    _seedScheduleOverrideDraftFromCurrentDisplay();
    await _setScheduleOverrideBreakMinutes(pickedMinutes);
  }

  Future<void> _pickScheduleOverrideTargetMinutes() async {
    final currentTargetMinutes =
        _displayedScheduleStateForSelectedDate().schedule.targetMinutes;
    final weekday = _weekdayKeyForDate(_selectedDate);
    final pickedMinutes = await _showScheduleTargetWheelPicker(
      title: 'Durata del giorno',
      initialMinutes: currentTargetMinutes,
      standardScheduleLinkLabel: 'Vai a Orario di lavoro (${weekday.label})',
      onOpenStandardScheduleLink: _openSelectedWeekdayStandardWorkSettings,
    );
    if (pickedMinutes == null) {
      return;
    }

    _seedScheduleOverrideDraftFromCurrentDisplay();
    _scheduleOverrideTargetController.text = formatHoursInput(pickedMinutes);
    _clearPendingExitConfirmationForSelectedDate();
    final startMinutes = parseTimeInput(
      _scheduleOverrideStartTimeController.text,
    );
    if (startMinutes != null) {
      final breakMinutes =
          parseBreakDurationInput(_scheduleOverrideBreakController.text) ?? 0;
      final targetEndMinutes = startMinutes + pickedMinutes + breakMinutes;
      final normalizedEndMinutes = targetEndMinutes.clamp(0, (23 * 60) + 59);
      _scheduleOverrideEndTimeController.text = formatTimeInput(
        normalizedEndMinutes,
      );
    }
    _normalizeSelectedDayPauseWindowForCurrentDraft();
    _clearAgendaPreviewState();
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
    _pushCurrentScheduleOverrideDraftToHistory();
    await _autosaveScheduleOverride();
  }

  Future<void> _confirmSuggestedExitMinutes(int exitMinutes) async {
    final clampedExitMinutes = exitMinutes.clamp(0, (23 * 60) + 59).toInt();
    _scheduleOverrideEndTimeController.text = formatTimeInput(
      clampedExitMinutes,
    );
    _clearPendingExitConfirmationForSelectedDate();
    _normalizeSelectedDayPauseWindowForCurrentDraft();
    _clearAgendaPreviewState();
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
    _pushCurrentScheduleOverrideDraftToHistory();
    await _autosaveScheduleOverride();
  }

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

  void _setUniformLunchBreakEnabled(bool enabled) {
    _setLunchBreakEnabled(
      breakController: _uniformBreakController,
      enabled: enabled,
    );
  }

  void _setWeekdayLunchBreakEnabled(WeekdayKey weekday, bool enabled) {
    _setLunchBreakEnabled(
      breakController: _weekdayBreakControllers[weekday]!,
      enabled: enabled,
      weekday: weekday,
    );
  }

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

  Future<void> _pickRulesMaximumDailyCreditMinutes() async {
    await _pickRulesLimitDuration(
      title: 'Massimo credito giornaliero',
      controller: _rulesMaximumDailyCreditController,
      maxMinutes: 16 * 60,
      unboundedMinutes: 24 * 60,
    );
  }

  Future<void> _pickRulesMaximumDailyDebitMinutes() async {
    await _pickRulesLimitDuration(
      title: 'Massimo debito giornaliero',
      controller: _rulesMaximumDailyDebitController,
      maxMinutes: 16 * 60,
      unboundedMinutes: 24 * 60,
    );
  }

  Future<void> _pickRulesMaximumMonthlyCreditMinutes() async {
    await _pickRulesLimitDuration(
      title: 'Massimo credito mensile',
      controller: _rulesMaximumMonthlyCreditController,
      maxMinutes: 240 * 60,
      unboundedMinutes: 31 * 24 * 60,
    );
  }

  Future<void> _pickRulesMaximumMonthlyDebitMinutes() async {
    await _pickRulesLimitDuration(
      title: 'Massimo debito mensile',
      controller: _rulesMaximumMonthlyDebitController,
      maxMinutes: 240 * 60,
      unboundedMinutes: 31 * 24 * 60,
    );
  }

  Future<void> _pickRulesOvertimeDailyCapMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Massimale straordinario giornaliero',
      controller: _rulesOvertimeDailyCapController,
      maxMinutes: 16 * 60,
      zeroLabel: 'Nessun massimale',
    );
  }

  Future<void> _pickRulesOvertimeWeeklyCapMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Massimale straordinario settimanale',
      controller: _rulesOvertimeWeeklyCapController,
      maxMinutes: 60 * 60,
      zeroLabel: 'Nessun massimale',
    );
  }

  Future<void> _pickRulesOvertimeMonthlyCapMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Massimale straordinario mensile',
      controller: _rulesOvertimeMonthlyCapController,
      maxMinutes: 240 * 60,
      zeroLabel: 'Nessun massimale',
    );
  }

  Future<void> _pickRulesFlexibleStartWindowMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Finestra flessibilita entrata',
      controller: _rulesFlexibleStartWindowController,
      maxMinutes: 4 * 60,
      zeroLabel: 'Nessuna flessibilita',
    );
  }

  Future<void> _pickRulesWalletDailyExitMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Permesso uscita anticipata: max al giorno',
      controller: _rulesWalletDailyExitController,
      maxMinutes: 8 * 60,
      zeroLabel: 'Nessun limite giornaliero',
    );
  }

  Future<void> _pickRulesWalletWeeklyExitMinutes() async {
    await _pickRulesOptionalDuration(
      title: 'Permesso uscita anticipata: max a settimana',
      controller: _rulesWalletWeeklyExitController,
      maxMinutes: 30 * 60,
      zeroLabel: 'Nessun limite settimanale',
    );
  }

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

  Future<void> _setScheduleOverrideBreakMinutes(int minutes) async {
    final normalizedMinutes = minutes.clamp(0, 24 * 60);
    _scheduleOverrideBreakController.text = formatBreakInput(normalizedMinutes);
    if (_rulesPauseAdjustmentMode ==
        WorkRulesPauseAdjustmentMode.keepWorkedMinutes) {
      _syncScheduleOverrideEndFromTarget(
        markPendingConfirmation: widget.appearanceSettings.showDayEndTime,
      );
    } else {
      final didKeepEndTime = _syncScheduleOverrideTargetFromStartEndAndBreak();
      if (!didKeepEndTime) {
        _syncScheduleOverrideEndFromTarget(
          markPendingConfirmation: widget.appearanceSettings.showDayEndTime,
        );
      }
    }
    _normalizeSelectedDayPauseWindowForCurrentDraft();
    _clearAgendaPreviewState();
    setState(() {
      _errorMessage = null;
    });
    _pushCurrentScheduleOverrideDraftToHistory();
    if (_hasPendingExitConfirmationForSelectedDate) {
      return;
    }
    await _autosaveScheduleOverride();
  }

  bool _syncScheduleOverrideTargetFromStartEndAndBreak() {
    final startMinutes = parseTimeInput(
      _scheduleOverrideStartTimeController.text.trim(),
    );
    final endMinutes = parseTimeInput(
      _scheduleOverrideEndTimeController.text.trim(),
    );
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return false;
    }

    final breakMinutes =
        parseBreakDurationInput(_scheduleOverrideBreakController.text) ?? 0;
    final targetMinutes = math.max(0, endMinutes - startMinutes - breakMinutes);
    _scheduleOverrideTargetController.text = formatHoursInput(targetMinutes);
    _clearPendingExitConfirmationForSelectedDate();
    return true;
  }

  Future<_ScheduleTimeWheelSelection?> _showScheduleTimeWheelPicker({
    required String title,
    required int initialMinutes,
    bool allowClear = false,
    String? Function(int pickedMinutes)? helperTextBuilder,
  }) async {
    final clearSentinel = DateTime(1900, 1, 1);
    final initialDateTime = DateTime(
      2026,
      1,
      1,
      (initialMinutes ~/ 60).clamp(0, 23),
      initialMinutes % 60,
    );
    final pickedDateTime = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => WheelPickerBottomSheet<DateTime>(
        title: title,
        initialValue: initialDateTime,
        clearLabel: allowClear ? 'Rimuovi' : null,
        clearValue: allowClear ? clearSentinel : null,
        valueBuilder: (controller) => ValueListenableBuilder<DateTime>(
          valueListenable: controller,
          builder: (context, value, _) {
            final pickedMinutes = (value.hour * 60) + value.minute;
            final helperText = helperTextBuilder?.call(pickedMinutes);
            final theme = Theme.of(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTimeInput(pickedMinutes),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (helperText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    helperText,
                    key: const ValueKey('schedule-time-wheel-helper-text'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        pickerBuilder: (controller) => SizedBox(
          height: 220,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: initialDateTime,
            onDateTimeChanged: (value) => controller.value = value,
          ),
        ),
      ),
    );
    if (pickedDateTime == null) {
      return null;
    }
    if (allowClear &&
        pickedDateTime.year == clearSentinel.year &&
        pickedDateTime.month == clearSentinel.month &&
        pickedDateTime.day == clearSentinel.day) {
      return const _ScheduleTimeWheelSelection.cleared();
    }
    return _ScheduleTimeWheelSelection.confirmed(
      (pickedDateTime.hour * 60) + pickedDateTime.minute,
    );
  }

  Future<int?> _showScheduleBreakWheelPicker({
    required int initialMinutes,
    String? standardScheduleLinkLabel,
    Future<void> Function()? onOpenStandardScheduleLink,
  }) async {
    final allowedValues = List<int>.generate(241, (index) => index);
    final initialIndex = initialMinutes.clamp(0, allowedValues.length - 1);
    var openStandardScheduleRequested = false;
    final pickedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => WheelPickerBottomSheet<int>(
        title: 'Pausa',
        initialValue: allowedValues[initialIndex],
        valueBuilder: (controller) => ValueListenableBuilder<int>(
          valueListenable: controller,
          builder: (context, value, _) {
            final linkLabel = standardScheduleLinkLabel;
            if (linkLabel != null && onOpenStandardScheduleLink != null) {
              return Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () {
                    openStandardScheduleRequested = true;
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      linkLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Text(
              value == 0 ? 'Nessuna pausa' : '$value min',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            );
          },
        ),
        pickerBuilder: (controller) => SizedBox(
          height: 220,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex,
            ),
            itemExtent: 38,
            onSelectedItemChanged: (index) {
              controller.value = allowedValues[index];
            },
            children: [
              for (final value in allowedValues)
                Center(
                  child: Text(value == 0 ? 'Nessuna pausa' : '$value min'),
                ),
            ],
          ),
        ),
      ),
    );
    if (openStandardScheduleRequested && onOpenStandardScheduleLink != null) {
      await onOpenStandardScheduleLink();
      return null;
    }
    return pickedMinutes;
  }

  Future<int?> _showScheduleTargetWheelPicker({
    required String title,
    required int initialMinutes,
    String? standardScheduleLinkLabel,
    Future<void> Function()? onOpenStandardScheduleLink,
  }) async {
    const maxHours = 16;
    final normalizedInitialMinutes = initialMinutes
        .clamp(0, maxHours * 60)
        .toInt();
    final initialHours = normalizedInitialMinutes ~/ 60;
    final initialMinute = normalizedInitialMinutes % 60;
    final hourValues = List<int>.generate(maxHours + 1, (index) => index);
    final minuteValues = List<int>.generate(60, (index) => index);
    var openStandardScheduleRequested = false;

    final pickedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var selectedHour = initialHours;
        var selectedMinute = initialMinute;
        return WheelPickerBottomSheet<int>(
          title: title,
          initialValue: normalizedInitialMinutes,
          valueBuilder: (controller) => ValueListenableBuilder<int>(
            valueListenable: controller,
            builder: (context, value, _) {
              final linkLabel = standardScheduleLinkLabel;
              if (linkLabel != null && onOpenStandardScheduleLink != null) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      openStandardScheduleRequested = true;
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        linkLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Text(
                formatHoursInput(value),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              );
            },
          ),
          pickerBuilder: (controller) => SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: initialHours,
                    ),
                    itemExtent: 38,
                    onSelectedItemChanged: (index) {
                      selectedHour = hourValues[index];
                      controller.value = (selectedHour * 60) + selectedMinute;
                    },
                    children: [
                      for (final hour in hourValues)
                        Center(child: Text(hour.toString().padLeft(2, '0'))),
                    ],
                  ),
                ),
                Text(
                  ':',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: initialMinute,
                    ),
                    itemExtent: 38,
                    onSelectedItemChanged: (index) {
                      selectedMinute = minuteValues[index];
                      controller.value = (selectedHour * 60) + selectedMinute;
                    },
                    children: [
                      for (final minute in minuteValues)
                        Center(child: Text(minute.toString().padLeft(2, '0'))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (openStandardScheduleRequested && onOpenStandardScheduleLink != null) {
      await onOpenStandardScheduleLink();
      return null;
    }
    return pickedMinutes;
  }

  Future<int?> _showDurationWheelPicker({
    required String title,
    required int initialMinutes,
    required int maxMinutes,
    int stepMinutes = 5,
    String? zeroLabel,
    int? specialValue,
    String? specialLabel,
  }) async {
    final allowedValues = [
      ...?specialValue == null ? null : [specialValue],
      ...List<int>.generate(
        (maxMinutes ~/ stepMinutes) + 1,
        (index) => index * stepMinutes,
      ),
    ];
    final normalizedInitial =
        initialMinutes == specialValue && specialValue != null
        ? specialValue
        : ((initialMinutes / stepMinutes).round() * stepMinutes).clamp(
            0,
            maxMinutes,
          );
    final initialIndex = allowedValues.indexOf(normalizedInitial);
    final resolvedInitialIndex = initialIndex < 0 ? 0 : initialIndex;
    String labelFor(int value) {
      if (specialValue != null &&
          value == specialValue &&
          specialLabel != null) {
        return specialLabel;
      }
      if (value == 0 && zeroLabel != null) {
        return zeroLabel;
      }
      return formatHoursInput(value);
    }

    final pickedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => WheelPickerBottomSheet<int>(
        title: title,
        initialValue: allowedValues[resolvedInitialIndex],
        valueBuilder: (controller) => ValueListenableBuilder<int>(
          valueListenable: controller,
          builder: (context, value, _) => Text(
            labelFor(value),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        pickerBuilder: (controller) => SizedBox(
          height: 220,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: resolvedInitialIndex,
            ),
            itemExtent: 38,
            onSelectedItemChanged: (index) {
              controller.value = allowedValues[index];
            },
            children: [
              for (final value in allowedValues)
                Center(child: Text(labelFor(value))),
            ],
          ),
        ),
      ),
    );
    return pickedMinutes;
  }

  void _markSelectedDayAsDayOff() {
    _seedScheduleOverrideDraftFromCurrentDisplay();
    _scheduleOverrideTargetController.text = formatHoursInput(0);
    _scheduleOverrideStartTimeController.clear();
    _scheduleOverrideEndTimeController.clear();
    _scheduleOverrideBreakController.clear();
    _setSelectedDayPauseWindowDraft(null);
    _clearPendingExitConfirmationForSelectedDate();
    _clearAgendaPreviewState();
    setState(() {
      _errorMessage = null;
    });
    _pushCurrentScheduleOverrideDraftToHistory();
    unawaited(_autosaveScheduleOverride());
  }

  TextEditingController _scheduleTimeController(CalendarTimeField field) {
    return switch (field) {
      CalendarTimeField.start => _scheduleOverrideStartTimeController,
      CalendarTimeField.end => _scheduleOverrideEndTimeController,
    };
  }

  int _currentScheduleOverrideTimeMinutes(CalendarTimeField field) {
    final fallbackSchedule = _displayedScheduleStateForSelectedDate().schedule;
    final fallbackMinutes = switch (field) {
      CalendarTimeField.start => parseTimeInput(fallbackSchedule.startTime),
      CalendarTimeField.end => parseTimeInput(fallbackSchedule.endTime),
    };
    if (fallbackMinutes != null) {
      return fallbackMinutes;
    }

    if (field == CalendarTimeField.start) {
      return 9 * 60;
    }

    return ((9 * 60) +
            fallbackSchedule.targetMinutes +
            fallbackSchedule.breakMinutes)
        .clamp(0, (23 * 60) + 59);
  }

  DaySchedule _fallbackScheduleForSelectedDate() {
    final snapshot = _snapshotForMonth(_selectedMonth) ?? _snapshot;
    return snapshot == null
        ? const DaySchedule(targetMinutes: 8 * 60)
        : _resolveEffectiveDayScheduleForDate(snapshot, _selectedDate);
  }

  int _currentMinutesOfDay() {
    final now = DateTime.now();
    return (now.hour * 60) + now.minute;
  }

  void _setSelectedDayPauseWindowDraft(CalendarPauseWindow? pauseWindow) {
    if (pauseWindow == null ||
        pauseWindow.resumeMinutes <= pauseWindow.pauseStartMinutes) {
      _selectedDayPauseStartMinutes = null;
      _selectedDayPauseEndMinutes = null;
      return;
    }

    _selectedDayPauseStartMinutes = pauseWindow.pauseStartMinutes;
    _selectedDayPauseEndMinutes = pauseWindow.resumeMinutes;
  }

  void _setAgendaPreviewState({
    int? startMinutes,
    int? endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  }) {
    _agendaPreviewStartMinutes = startMinutes;
    _agendaPreviewEndMinutes = endMinutes;
    _agendaPreviewBreakMinutes = breakMinutes;
    _agendaPreviewPauseStartMinutes = pauseStartMinutes;
    _agendaPreviewPauseEndMinutes = pauseEndMinutes;
  }

  void _clearAgendaPreviewState() {
    _setAgendaPreviewState();
  }

  bool get _hasPendingExitConfirmationForSelectedDate =>
      _pendingExitConfirmationDateKey ==
          DashboardService.defaultEntryDateOf(_selectedDate) &&
      _pendingExitConfirmationMinutes != null;

  int? get _pendingExitConfirmationForSelectedDate =>
      _hasPendingExitConfirmationForSelectedDate
      ? _pendingExitConfirmationMinutes
      : null;

  void _setPendingExitConfirmationForSelectedDate(int minutes) {
    _pendingExitConfirmationDateKey = DashboardService.defaultEntryDateOf(
      _selectedDate,
    );
    _pendingExitConfirmationMinutes = minutes.clamp(0, (23 * 60) + 59);
  }

  void _clearPendingExitConfirmationForSelectedDate() {
    final selectedDateKey = DashboardService.defaultEntryDateOf(_selectedDate);
    if (_pendingExitConfirmationDateKey != selectedDateKey &&
        _pendingExitConfirmationMinutes != null) {
      return;
    }
    _pendingExitConfirmationDateKey = null;
    _pendingExitConfirmationMinutes = null;
  }

  String _scheduleOverrideHistoryDateKeyFor(DateTime date) {
    return DashboardService.defaultEntryDateOf(date);
  }

  bool _samePauseWindow(CalendarPauseWindow? left, CalendarPauseWindow? right) {
    return left?.pauseStartMinutes == right?.pauseStartMinutes &&
        left?.resumeMinutes == right?.resumeMinutes;
  }

  bool _sameScheduleOverrideDraftState(
    ScheduleOverrideDraftState left,
    ScheduleOverrideDraftState right,
  ) {
    return _sameDaySchedule(left.schedule, right.schedule) &&
        _samePauseWindow(left.pauseWindow, right.pauseWindow);
  }

  ScheduleOverrideDraftState _currentScheduleOverrideDraftState({
    DaySchedule? fallbackSchedule,
  }) {
    final effectiveFallback =
        fallbackSchedule ?? _fallbackScheduleForSelectedDate();
    return ScheduleOverrideDraftState(
      schedule: _resolveCurrentScheduleDraft(effectiveFallback),
      pauseWindow: _selectedDayPauseWindowDraft(),
    );
  }

  void _resetScheduleOverrideHistoryForDate(
    DateTime date, {
    required DaySchedule schedule,
    CalendarPauseWindow? pauseWindow,
  }) {
    _scheduleOverrideHistoryDateKey = _scheduleOverrideHistoryDateKeyFor(date);
    _scheduleOverrideHistory = [
      ScheduleOverrideDraftState(schedule: schedule, pauseWindow: pauseWindow),
    ];
    _scheduleOverrideHistoryIndex = 0;
  }

  void _primeScheduleOverrideHistoryFromCurrentDisplay() {
    final displayedState = _displayedScheduleStateForSelectedDate();
    final historyEntry = ScheduleOverrideDraftState(
      schedule: displayedState.schedule,
      pauseWindow: displayedState.pauseWindow,
    );
    final dateKey = _scheduleOverrideHistoryDateKeyFor(_selectedDate);
    if (_scheduleOverrideHistoryDateKey != dateKey ||
        _scheduleOverrideHistory.isEmpty ||
        _scheduleOverrideHistoryIndex < 0) {
      _resetScheduleOverrideHistoryForDate(
        _selectedDate,
        schedule: historyEntry.schedule,
        pauseWindow: historyEntry.pauseWindow,
      );
      return;
    }

    if (_scheduleOverrideHistory.length == 1 &&
        _scheduleOverrideHistoryIndex == 0 &&
        !_sameScheduleOverrideDraftState(
          _scheduleOverrideHistory.first,
          historyEntry,
        )) {
      _resetScheduleOverrideHistoryForDate(
        _selectedDate,
        schedule: historyEntry.schedule,
        pauseWindow: historyEntry.pauseWindow,
      );
    }
  }

  void _pushCurrentScheduleOverrideDraftToHistory() {
    final dateKey = _scheduleOverrideHistoryDateKeyFor(_selectedDate);
    final nextEntry = _currentScheduleOverrideDraftState();
    if (_scheduleOverrideHistoryDateKey != dateKey ||
        _scheduleOverrideHistory.isEmpty ||
        _scheduleOverrideHistoryIndex < 0) {
      _resetScheduleOverrideHistoryForDate(
        _selectedDate,
        schedule: nextEntry.schedule,
        pauseWindow: nextEntry.pauseWindow,
      );
      return;
    }

    final currentEntry =
        _scheduleOverrideHistory[_scheduleOverrideHistoryIndex];
    if (_sameScheduleOverrideDraftState(currentEntry, nextEntry)) {
      return;
    }

    final nextHistory =
        _scheduleOverrideHistory
            .take(_scheduleOverrideHistoryIndex + 1)
            .toList(growable: true)
          ..add(nextEntry);
    _scheduleOverrideHistory = nextHistory;
    _scheduleOverrideHistoryIndex = nextHistory.length - 1;
  }

  bool get _canUndoScheduleOverride =>
      _scheduleOverrideHistoryDateKey ==
          _scheduleOverrideHistoryDateKeyFor(_selectedDate) &&
      _scheduleOverrideHistoryIndex > 0;

  bool get _canRedoScheduleOverride =>
      _scheduleOverrideHistoryDateKey ==
          _scheduleOverrideHistoryDateKeyFor(_selectedDate) &&
      _scheduleOverrideHistoryIndex >= 0 &&
      _scheduleOverrideHistoryIndex < (_scheduleOverrideHistory.length - 1);

  Future<void> _restoreScheduleOverrideHistoryEntry(int index) async {
    if (index < 0 || index >= _scheduleOverrideHistory.length) {
      return;
    }

    final historyEntry = _scheduleOverrideHistory[index];
    _applyDayScheduleDraft(
      historyEntry.schedule,
      pauseWindow: historyEntry.pauseWindow,
    );
    _clearPendingExitConfirmationForSelectedDate();
    _clearAgendaPreviewState();
    if (mounted) {
      setState(() {
        _scheduleOverrideHistoryIndex = index;
        _errorMessage = null;
      });
    } else {
      _scheduleOverrideHistoryIndex = index;
    }
    await _autosaveScheduleOverride();
  }

  Future<void> _undoScheduleOverrideDraftChange() async {
    if (!_canUndoScheduleOverride) {
      return;
    }

    await _restoreScheduleOverrideHistoryEntry(
      _scheduleOverrideHistoryIndex - 1,
    );
  }

  Future<void> _redoScheduleOverrideDraftChange() async {
    if (!_canRedoScheduleOverride) {
      return;
    }

    await _restoreScheduleOverrideHistoryEntry(
      _scheduleOverrideHistoryIndex + 1,
    );
  }

  ({DaySchedule schedule, CalendarPauseWindow? pauseWindow})
  _displayedScheduleStateForSelectedDate({
    DashboardSnapshot? snapshot,
    WorkdaySession? session,
  }) {
    final resolvedSnapshot =
        snapshot ?? (_snapshotForMonth(_selectedMonth) ?? _snapshot);
    final effectiveSchedule = resolvedSnapshot == null
        ? const DaySchedule(targetMinutes: 8 * 60)
        : _resolveEffectiveDayScheduleForDate(resolvedSnapshot, _selectedDate);
    final baseSchedule = resolvedSnapshot == null
        ? effectiveSchedule
        : _resolveBaseDayScheduleForDate(resolvedSnapshot, _selectedDate);
    final draftSchedule = _resolveCurrentScheduleDraft(effectiveSchedule);
    final effectiveSession = isSameDay(_selectedDate, _todayDate)
        ? (session ?? _workdaySession)
        : null;
    final displayedSchedule = _resolveDisplayedDayScheduleForSession(
      draftSchedule,
      baseSchedule,
      effectiveSession,
      _selectedDate,
    );
    final pauseWindow = resolveCalendarPauseWindow(
      schedule: displayedSchedule,
      startMinutes: parseTimeInput(displayedSchedule.startTime),
      endMinutes: parseTimeInput(displayedSchedule.endTime),
      session: effectiveSession,
      nowMinutes: _currentMinutesOfDay(),
    );

    return (schedule: displayedSchedule, pauseWindow: pauseWindow);
  }

  void _seedScheduleOverrideDraftFromCurrentDisplay() {
    final displayedState = _displayedScheduleStateForSelectedDate();
    _primeScheduleOverrideHistoryFromCurrentDisplay();
    _applyDayScheduleDraft(
      displayedState.schedule,
      pauseWindow: displayedState.pauseWindow,
    );
  }

  void _syncSelectedDayPauseWindowDraftForCurrentDisplay({
    WorkdaySession? session,
  }) {
    final displayedState = _displayedScheduleStateForSelectedDate(
      session: session,
    );
    _setSelectedDayPauseWindowDraft(displayedState.pauseWindow);
  }

  CalendarPauseWindow? _agendaPreviewPauseWindow() {
    final pauseStartMinutes = _agendaPreviewPauseStartMinutes;
    final pauseEndMinutes = _agendaPreviewPauseEndMinutes;
    if (pauseStartMinutes == null ||
        pauseEndMinutes == null ||
        pauseEndMinutes <= pauseStartMinutes) {
      return null;
    }

    return CalendarPauseWindow(
      pauseStartMinutes: pauseStartMinutes,
      resumeMinutes: pauseEndMinutes,
    );
  }

  CalendarPauseWindow? _selectedDayPauseWindowDraft() {
    final pauseStartMinutes = _selectedDayPauseStartMinutes;
    final pauseEndMinutes = _selectedDayPauseEndMinutes;
    if (pauseStartMinutes == null ||
        pauseEndMinutes == null ||
        pauseEndMinutes <= pauseStartMinutes) {
      return null;
    }

    return CalendarPauseWindow(
      pauseStartMinutes: pauseStartMinutes,
      resumeMinutes: pauseEndMinutes,
    );
  }

  void _applyDayScheduleDraft(
    DaySchedule schedule, {
    CalendarPauseWindow? pauseWindow,
  }) {
    _clearPendingExitConfirmationForSelectedDate();
    _scheduleOverrideTargetController.text = formatHoursInput(
      schedule.targetMinutes,
    );
    _scheduleOverrideStartTimeController.text = schedule.startTime ?? '';
    _scheduleOverrideEndTimeController.text = schedule.endTime ?? '';
    _scheduleOverrideBreakController.text = formatBreakInput(
      schedule.breakMinutes,
    );
    _setSelectedDayPauseWindowDraft(pauseWindow);
  }

  void _normalizeSelectedDayPauseWindowForCurrentDraft() {
    final currentSchedule = _resolveCurrentScheduleDraft(
      _fallbackScheduleForSelectedDate(),
    );
    final startMinutes = parseTimeInput(currentSchedule.startTime);
    final endMinutes = parseTimeInput(currentSchedule.endTime);
    final breakMinutes = currentSchedule.breakMinutes;
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes ||
        breakMinutes <= 0) {
      _setSelectedDayPauseWindowDraft(null);
      return;
    }

    final currentPauseWindow = _selectedDayPauseWindowDraft();
    final pauseStartMinutes = currentPauseWindow == null
        ? startMinutes + ((endMinutes - startMinutes - breakMinutes) ~/ 2)
        : (() {
            final currentDuration =
                currentPauseWindow.resumeMinutes -
                currentPauseWindow.pauseStartMinutes;
            final currentCenter =
                currentPauseWindow.pauseStartMinutes + (currentDuration ~/ 2);
            return currentCenter - (breakMinutes ~/ 2);
          })();
    final clampedPauseStartMinutes = pauseStartMinutes.clamp(
      startMinutes,
      endMinutes - breakMinutes,
    );
    _setSelectedDayPauseWindowDraft(
      CalendarPauseWindow(
        pauseStartMinutes: clampedPauseStartMinutes,
        resumeMinutes: clampedPauseStartMinutes + breakMinutes,
      ),
    );
  }

  CalendarPauseWindow? _resolveSelectedDayPauseWindow({
    required DaySchedule schedule,
    WorkdaySession? session,
  }) {
    final draftPauseWindow = _selectedDayPauseWindowDraft();
    if (draftPauseWindow != null) {
      return draftPauseWindow;
    }

    return resolveCalendarPauseWindow(
      schedule: schedule,
      startMinutes: parseTimeInput(schedule.startTime),
      endMinutes: parseTimeInput(schedule.endTime),
      session: session,
      nowMinutes: _currentMinutesOfDay(),
    );
  }

  DaySchedule _resolveAgendaPreviewSchedule(DaySchedule fallbackSchedule) {
    final previewStartMinutes = _agendaPreviewStartMinutes;
    final previewEndMinutes = _agendaPreviewEndMinutes;
    if (previewStartMinutes == null ||
        previewEndMinutes == null ||
        previewEndMinutes <= previewStartMinutes) {
      return fallbackSchedule;
    }

    final previewBreakMinutes =
        _agendaPreviewBreakMinutes ??
        math.max(0, fallbackSchedule.breakMinutes);
    return DaySchedule(
      targetMinutes: math.max(
        0,
        (previewEndMinutes - previewStartMinutes) - previewBreakMinutes,
      ),
      startTime: formatTimeInput(previewStartMinutes),
      endTime: formatTimeInput(previewEndMinutes),
      breakMinutes: previewBreakMinutes,
    );
  }

  DaySchedule _resolveDisplayedDayScheduleForSession(
    DaySchedule schedule,
    DaySchedule baseSchedule,
    WorkdaySession? session,
    DateTime selectedDate,
  ) {
    if (!isSameDay(selectedDate, _todayDate) || session == null) {
      return schedule;
    }

    final explicitStartMinutes = parseTimeInput(schedule.startTime);
    final explicitEndMinutes = parseTimeInput(schedule.endTime);
    final baseStartMinutes = parseTimeInput(baseSchedule.startTime);
    final baseEndMinutes = parseTimeInput(baseSchedule.endTime);
    final currentBreakMinutes = currentSessionBreakMinutes(
      session,
      _currentMinutesOfDay(),
    );
    final usesDefaultStart =
        explicitStartMinutes == null ||
        (baseStartMinutes != null && explicitStartMinutes == baseStartMinutes);
    final usesDefaultEnd =
        explicitEndMinutes == null ||
        (baseEndMinutes != null && explicitEndMinutes == baseEndMinutes);
    final displayedStartMinutes = usesDefaultStart
        ? session.startMinutes
        : explicitStartMinutes;
    final effectiveBreakMinutes = math.max(
      schedule.breakMinutes,
      currentBreakMinutes,
    );
    final computedEndMinutes = session.endMinutes != null && usesDefaultEnd
        ? session.endMinutes
        : explicitEndMinutes ??
              (schedule.targetMinutes > 0
                  ? displayedStartMinutes +
                        schedule.targetMinutes +
                        effectiveBreakMinutes
                  : null);
    return DaySchedule(
      // Keep daily target stable: editing start/end must not rewrite "Ore di lavoro".
      targetMinutes: schedule.targetMinutes,
      startTime: formatTimeInput(displayedStartMinutes),
      endTime: computedEndMinutes == null
          ? schedule.endTime
          : formatTimeInput(
              (computedEndMinutes % (24 * 60)).clamp(0, (23 * 60) + 59).toInt(),
            ),
      breakMinutes: effectiveBreakMinutes,
    );
  }

  bool _syncScheduleOverrideEndFromTarget({
    bool markPendingConfirmation = false,
  }) {
    final previousEndMinutes = parseTimeInput(
      _scheduleOverrideEndTimeController.text.trim(),
    );
    final startMinutes = parseTimeInput(
      _scheduleOverrideStartTimeController.text,
    );
    final targetMinutes = parseHoursInput(
      _scheduleOverrideTargetController.text,
    );
    final breakMinutes =
        parseBreakDurationInput(_scheduleOverrideBreakController.text) ?? 0;
    if (startMinutes == null || targetMinutes == null) {
      if (markPendingConfirmation) {
        _clearPendingExitConfirmationForSelectedDate();
      }
      return false;
    }

    final endMinutes = (startMinutes + targetMinutes + breakMinutes).clamp(
      0,
      (23 * 60) + 59,
    );
    _scheduleOverrideEndTimeController.text = formatTimeInput(endMinutes);
    if (markPendingConfirmation) {
      if (previousEndMinutes == null || previousEndMinutes != endMinutes) {
        _setPendingExitConfirmationForSelectedDate(endMinutes);
      } else {
        _clearPendingExitConfirmationForSelectedDate();
      }
    } else {
      _clearPendingExitConfirmationForSelectedDate();
    }
    return true;
  }

  DaySchedule _resolveCurrentScheduleDraft(DaySchedule fallbackSchedule) {
    final draft = _parseDayScheduleInput(
      targetText: _scheduleOverrideTargetController.text,
      startTimeText: _scheduleOverrideStartTimeController.text,
      endTimeText: _scheduleOverrideEndTimeController.text,
      breakText: _scheduleOverrideBreakController.text,
    );
    return draft ?? fallbackSchedule;
  }

  void _updateScheduleOverrideFromAgenda({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  }) {
    final normalizedStart = startMinutes.clamp(0, 24 * 60).toInt();
    final normalizedEnd = endMinutes.clamp(0, 24 * 60).toInt();
    if (normalizedEnd <= normalizedStart) {
      return;
    }

    _seedScheduleOverrideDraftFromCurrentDisplay();
    _scheduleOverrideStartTimeController.text = formatTimeInput(
      normalizedStart,
    );
    _scheduleOverrideEndTimeController.text = formatTimeInput(normalizedEnd);
    if (breakMinutes != null) {
      _scheduleOverrideBreakController.text = formatBreakInput(
        breakMinutes.clamp(0, normalizedEnd - normalizedStart),
      );
    }
    _setSelectedDayPauseWindowDraft(
      pauseStartMinutes != null &&
              pauseEndMinutes != null &&
              pauseEndMinutes > pauseStartMinutes
          ? CalendarPauseWindow(
              pauseStartMinutes: pauseStartMinutes,
              resumeMinutes: pauseEndMinutes,
            )
          : null,
    );
    assert(() {
      debugPrint(
        '[agenda-commit] date=${DashboardService.defaultEntryDateOf(_selectedDate)} '
        'start=${formatTimeInput(normalizedStart)} end=${formatTimeInput(normalizedEnd)} '
        'break=${breakMinutes ?? '-'} '
        'pauseStart=${pauseStartMinutes == null ? '-' : formatTimeInput(pauseStartMinutes)} '
        'pauseEnd=${pauseEndMinutes == null ? '-' : formatTimeInput(pauseEndMinutes)}',
      );
      return true;
    }());
    _clearAgendaPreviewState();
    _clearPendingExitConfirmationForSelectedDate();
    setState(() {
      _errorMessage = null;
    });
    _pushCurrentScheduleOverrideDraftToHistory();
    unawaited(_autosaveScheduleOverride());
  }

  void _previewScheduleOverrideFromAgenda({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  }) {
    final normalizedStart = startMinutes.clamp(0, 24 * 60).toInt();
    final normalizedEnd = endMinutes.clamp(0, 24 * 60).toInt();
    if (normalizedEnd <= normalizedStart) {
      return;
    }

    final normalizedBreakMinutes = breakMinutes?.clamp(
      0,
      normalizedEnd - normalizedStart,
    );
    setState(() {
      _setAgendaPreviewState(
        startMinutes: normalizedStart,
        endMinutes: normalizedEnd,
        breakMinutes: normalizedBreakMinutes,
        pauseStartMinutes: pauseStartMinutes,
        pauseEndMinutes: pauseEndMinutes,
      );
      _errorMessage = null;
    });
  }

  void _clearScheduleOverrideAgendaPreview() {
    if (_agendaPreviewStartMinutes == null &&
        _agendaPreviewEndMinutes == null &&
        _agendaPreviewBreakMinutes == null &&
        _agendaPreviewPauseStartMinutes == null &&
        _agendaPreviewPauseEndMinutes == null) {
      return;
    }

    setState(_clearAgendaPreviewState);
  }

  bool _sameDaySchedule(DaySchedule left, DaySchedule right) {
    return left.targetMinutes == right.targetMinutes &&
        left.startTime == right.startTime &&
        left.endTime == right.endTime &&
        left.breakMinutes == right.breakMinutes;
  }

  DaySchedule _resolveDisplayedDaySchedule(
    DaySchedule schedule,
    DateTime selectedDate,
  ) {
    final snapshot =
        _snapshotForMonth(DashboardService.formatMonth(selectedDate)) ??
        _snapshot;
    final baseSchedule = snapshot == null
        ? schedule
        : _resolveBaseDayScheduleForDate(snapshot, selectedDate);
    return _resolveDisplayedDayScheduleForSession(
      schedule,
      baseSchedule,
      _workdaySession,
      selectedDate,
    );
  }

  DayMetrics _withDisplayedDaySchedule(
    DayMetrics metrics,
    DaySchedule displayedSchedule,
  ) {
    return DayMetrics(
      date: metrics.date,
      expectedMinutes: metrics.expectedMinutes,
      workedMinutes: metrics.workedMinutes,
      leaveMinutes: metrics.leaveMinutes,
      rawBalanceMinutes: metrics.rawBalanceMinutes,
      balanceMinutes: metrics.balanceMinutes,
      hasOverride: metrics.hasOverride,
      schedule: displayedSchedule,
      overrideNote: metrics.overrideNote,
    );
  }

  Future<void> _openUpdate() async {
    final availableUpdate = _availableUpdate;
    if (availableUpdate == null || _isOpeningUpdate) {
      return;
    }

    setState(() {
      _isOpeningUpdate = true;
    });

    final didOpen = await widget.appUpdateService.openUpdate(availableUpdate);
    if (!mounted) {
      return;
    }

    setState(() {
      _isOpeningUpdate = false;
    });

    if (didOpen) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Impossibile aprire l aggiornamento. Apri manualmente ${availableUpdate.releasePageUrl}',
        ),
      ),
    );
  }

  Future<void> _openUpdateFromSettings() async {
    if (_isOpeningUpdate || _isCheckingForUpdate) {
      return;
    }

    final downloadedUpdate = _backgroundDownloadedUpdate;
    if (downloadedUpdate != null) {
      await _promptInstallDownloadedUpdate(downloadedUpdate);
      return;
    }

    if (_isBackgroundUpdateDownloadInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download aggiornamento in background gia in corso.'),
        ),
      );
      return;
    }

    final cachedUpdate = _availableUpdate;
    if (cachedUpdate != null) {
      await _startInAppUpdateFlow(cachedUpdate);
      return;
    }

    setState(() {
      _isCheckingForUpdate = true;
    });

    try {
      final availableUpdate = await widget.appUpdateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _availableUpdate = availableUpdate;
        _isCheckingForUpdate = false;
      });

      if (availableUpdate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hai gia l ultima versione.')),
        );
        return;
      }

      await _startInAppUpdateFlow(availableUpdate);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingForUpdate = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Controllo aggiornamenti non riuscito.')),
      );
    }
  }

  Future<void> _startInAppUpdateFlow(AppUpdate update) async {
    final result = await showDialog<UpdateDownloadDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDownloadDialog(
        update: update,
        appUpdateService: widget.appUpdateService,
        onOpenReleasePage: _openUpdate,
        onBackgroundDownloadEnabled: () =>
            _handleBackgroundUpdateDownloadEnabled(update),
        onBackgroundProgress: _handleBackgroundUpdateDownloadProgress,
        onBackgroundDownloadCompleted: _handleBackgroundUpdateDownloadCompleted,
        onBackgroundDownloadFailed: _handleBackgroundUpdateDownloadFailed,
      ),
    );
    if (!mounted) {
      return;
    }

    if (result == UpdateDownloadDialogAction.downloadInBackground) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Download in background attivo. Puoi continuare a usare l app.',
          ),
        ),
      );
    }
  }

  void _handleBackgroundUpdateDownloadEnabled(AppUpdate update) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBackgroundUpdateDownloadInProgress = true;
      _backgroundUpdate = update;
      _backgroundDownloadedUpdate = null;
      _backgroundUpdateProgress = const UpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      );
    });
  }

  void _handleBackgroundUpdateDownloadProgress(
    UpdateDownloadProgress progress,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBackgroundUpdateDownloadInProgress = true;
      _backgroundUpdateProgress = progress;
    });
  }

  Future<void> _handleBackgroundUpdateDownloadCompleted(
    DownloadedAppUpdate downloadedUpdate,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBackgroundUpdateDownloadInProgress = false;
      _backgroundDownloadedUpdate = downloadedUpdate;
      _backgroundUpdate = downloadedUpdate.update;
      _backgroundUpdateProgress = UpdateDownloadProgress(
        receivedBytes: downloadedUpdate.bytesDownloaded,
        totalBytes: downloadedUpdate.bytesDownloaded,
      );
    });

    await _localNotificationService.notifyUpdateReadyToInstall(
      latestVersion: downloadedUpdate.update.latestVersion,
    );
    if (!mounted) {
      return;
    }

    await _promptInstallDownloadedUpdate(downloadedUpdate);
  }

  void _handleBackgroundUpdateDownloadFailed() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isBackgroundUpdateDownloadInProgress = false;
      _backgroundDownloadedUpdate = null;
      _backgroundUpdate = null;
      _backgroundUpdateProgress = const UpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Download in background non riuscito. Riprova dagli aggiornamenti.',
        ),
      ),
    );
  }

  Future<void> _promptInstallDownloadedUpdate(
    DownloadedAppUpdate downloadedUpdate,
  ) async {
    if (!mounted || _isPromptingBackgroundUpdateInstall) {
      return;
    }

    _isPromptingBackgroundUpdateInstall = true;
    final shouldInstall = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Aggiornamento pronto'),
        content: Text(
          'Download completato per la versione ${downloadedUpdate.update.latestVersion}. Vuoi installarla ora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Piu tardi'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.install_mobile_outlined),
            label: const Text('Installa ora'),
          ),
        ],
      ),
    );
    _isPromptingBackgroundUpdateInstall = false;

    if (!mounted || shouldInstall != true) {
      return;
    }

    final result = await widget.appUpdateService.installUpdate(
      downloadedUpdate,
    );
    if (!mounted) {
      return;
    }

    switch (result) {
      case UpdateInstallResult.started:
        setState(() {
          _backgroundDownloadedUpdate = null;
          _backgroundUpdate = null;
          _backgroundUpdateProgress = const UpdateDownloadProgress(
            receivedBytes: 0,
            totalBytes: null,
          );
        });
        break;
      case UpdateInstallResult.permissionRequired:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Per installare l APK devi autorizzare questa app nelle impostazioni Android.',
            ),
          ),
        );
        break;
      case UpdateInstallResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile avviare l installazione.')),
        );
        break;
    }
  }

  Future<void> _toggleThemeMode(bool useDarkTheme) async {
    final nextThemeMode = useDarkTheme ? ThemeMode.dark : ThemeMode.light;
    if (widget.appearanceSettings.themeMode == nextThemeMode) {
      return;
    }

    await _updateAppearanceSettings(
      widget.appearanceSettings.copyWith(themeMode: nextThemeMode),
    );
  }

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

  Future<void> _submitSupportTicket() async {
    if (_isRecordingTicketVoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa o annulla la registrazione vocale prima di inviare il ticket.',
          ),
        ),
      );
      return;
    }

    final isValid = _ticketFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isSubmittingTicket = true;
      _errorMessage = null;
    });

    try {
      _logDiagnostic(
        'ticket.submit.start',
        details: <String, Object?>{
          'category': _selectedTicketCategory.apiValue,
          'attachments': _ticketAttachments.length,
          'includeDiagnosticLogs': _includeDiagnosticLogsInTicket,
        },
      );
      final clientLogs = _includeDiagnosticLogsInTicket
          ? _buildTicketDiagnosticLogs()
          : null;
      final createdThread = await widget.dashboardService.submitSupportTicket(
        category: _selectedTicketCategory,
        name: _ticketNameController.text.trim().isEmpty
            ? null
            : _ticketNameController.text.trim(),
        email: _ticketEmailController.text.trim().isEmpty
            ? null
            : _ticketEmailController.text.trim(),
        subject: _ticketSubjectController.text.trim(),
        message: _ticketMessageController.text.trim(),
        appVersion: _ticketAppVersionController.text.trim().isEmpty
            ? null
            : _ticketAppVersionController.text.trim(),
        clientLogs: clientLogs,
        attachments: List<SupportTicketUploadAttachment>.from(
          _ticketAttachments,
        ),
      );

      if (!mounted) {
        return;
      }

      await _upsertTrackedSupportTicket(createdThread);
      if (!mounted) {
        return;
      }
      final nextThreadsById = Map<String, SupportTicketThread>.from(
        _ticketThreadsById,
      )..[createdThread.id] = createdThread;
      _ticketSubjectController.clear();
      _ticketMessageController.clear();
      _ticketRecoveryIdController.text = createdThread.id;
      setState(() {
        _ticketAttachments = const [];
        _trackedTickets = [
          TrackedSupportTicket(
            id: createdThread.id,
            subject: createdThread.subject,
            createdAt: createdThread.createdAt,
            lastSeenAdminReplyCount: createdThread.adminReplyCount,
            lastNotifiedAdminReplyCount: createdThread.adminReplyCount,
          ),
          ..._trackedTickets.where((ticket) => ticket.id != createdThread.id),
        ];
        _ticketThreadsById = nextThreadsById;
        _selectedTrackedTicketId = createdThread.id;
        _selectedSection = HomeSection.ticket;
        _unreadTicketReplyCount = _countUnreadAdminReplies([
          TrackedSupportTicket(
            id: createdThread.id,
            subject: createdThread.subject,
            createdAt: createdThread.createdAt,
            lastSeenAdminReplyCount: createdThread.adminReplyCount,
            lastNotifiedAdminReplyCount: createdThread.adminReplyCount,
          ),
          ..._trackedTickets.where((ticket) => ticket.id != createdThread.id),
        ], nextThreadsById);
        _isSubmittingTicket = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket inviato. Codice ticket: ${createdThread.id}'),
        ),
      );
      _logDiagnostic(
        'ticket.submit.ok',
        details: <String, Object?>{'ticketId': createdThread.id},
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(
          error,
          apiBaseUrl: _snapshot?.apiBaseUrl,
          isTicketRequest: true,
        );
        _isSubmittingTicket = false;
      });
      _logDiagnostic(
        'ticket.submit.error',
        details: <String, Object?>{'error': error.toString()},
      );
    }
  }

  Future<void> _pickTicketAttachments() async {
    if (_isSubmittingTicket) {
      return;
    }

    final remainingSlots = maxTicketAttachments - _ticketAttachments.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puoi allegare al massimo 3 file per ticket.'),
        ),
      );
      return;
    }

    try {
      final selectedImages = await _ticketImagePicker.pickMultiImage(
        requestFullMetadata: false,
      );
      if (selectedImages.isEmpty || !mounted) {
        return;
      }

      final nextAttachments = List<SupportTicketUploadAttachment>.from(
        _ticketAttachments,
      );
      var addedCount = 0;
      var skippedCount = 0;
      for (final selectedImage in selectedImages) {
        if (nextAttachments.length >= maxTicketAttachments) {
          skippedCount += 1;
          continue;
        }

        final fileName = selectedImage.name;
        final contentType = _ticketAttachmentContentTypeForFileName(fileName);
        final bytes = await selectedImage.readAsBytes();
        if (contentType == null ||
            !contentType.startsWith('image/') ||
            bytes.isEmpty ||
            bytes.lengthInBytes > maxTicketAttachmentBytes) {
          skippedCount += 1;
          continue;
        }

        nextAttachments.add(
          SupportTicketUploadAttachment(
            fileName: fileName,
            contentType: contentType,
            bytes: bytes,
          ),
        );
        addedCount += 1;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _ticketAttachments = nextAttachments;
      });

      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessuno screenshot valido selezionato. Usa PNG, JPG o WEBP fino a 4 MB.',
            ),
          ),
        );
      } else if (skippedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aggiunti $addedCount screenshot. Alcuni file sono stati ignorati per formato, peso o limite massimo.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire la galleria screenshot.'),
        ),
      );
    }
  }

  Future<void> _pickTicketVoiceAttachments() async {
    if (_isSubmittingTicket) {
      return;
    }

    final remainingSlots = maxTicketAttachments - _ticketAttachments.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puoi allegare al massimo 3 file per ticket.'),
        ),
      );
      return;
    }

    try {
      final selectedAudio = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ticketAudioAttachmentExtensions,
      );
      if (selectedAudio == null || selectedAudio.files.isEmpty || !mounted) {
        return;
      }

      final nextAttachments = List<SupportTicketUploadAttachment>.from(
        _ticketAttachments,
      );
      var addedCount = 0;
      var skippedCount = 0;
      for (final selectedFile in selectedAudio.files) {
        if (nextAttachments.length >= maxTicketAttachments) {
          skippedCount += 1;
          continue;
        }

        final fileName = selectedFile.name;
        final contentType = _ticketAttachmentContentTypeForFileName(fileName);
        final bytes = selectedFile.bytes;
        if (contentType == null ||
            !_isAudioTicketAttachmentContentType(contentType) ||
            bytes == null ||
            bytes.isEmpty ||
            bytes.lengthInBytes > maxTicketAttachmentBytes) {
          skippedCount += 1;
          continue;
        }

        nextAttachments.add(
          SupportTicketUploadAttachment(
            fileName: fileName,
            contentType: contentType,
            bytes: bytes,
          ),
        );
        addedCount += 1;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _ticketAttachments = nextAttachments;
      });

      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessun vocale valido selezionato. Usa M4A, MP3, WAV, OGG, AAC o WEBM fino a 4 MB.',
            ),
          ),
        );
      } else if (skippedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aggiunti $addedCount vocali. Alcuni file sono stati ignorati per formato, peso o limite massimo.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire il selettore file vocali.'),
        ),
      );
    }
  }

  Future<void> _recordTicketVoiceAttachment() async {
    if (_isSubmittingTicket || _isRecordingTicketVoice) {
      return;
    }

    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La registrazione vocale diretta e disponibile solo su Android.',
          ),
        ),
      );
      return;
    }

    final remainingSlots = maxTicketAttachments - _ticketAttachments.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puoi allegare al massimo 3 file per ticket.'),
        ),
      );
      return;
    }

    String? outputPath;
    try {
      final hasPermission = await _ticketAudioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permesso microfono non concesso. Abilitalo per registrare un vocale.',
            ),
          ),
        );
        return;
      }

      final tempDirectory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      outputPath = '${tempDirectory.path}/ticket-voice-$timestamp.m4a';

      await _ticketAudioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: outputPath,
      );

      if (!mounted) {
        await _ticketAudioRecorder.cancel();
        return;
      }

      setState(() {
        _isRecordingTicketVoice = true;
      });

      final action = await showDialog<_TicketVoiceRecordingAction>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Registra vocale'),
            content: const Text(
              'Registrazione in corso. Quando hai finito premi "Termina e allega".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_TicketVoiceRecordingAction.cancel),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_TicketVoiceRecordingAction.save),
                child: const Text('Termina e allega'),
              ),
            ],
          );
        },
      );

      if (action == _TicketVoiceRecordingAction.save) {
        final recordedPath = await _ticketAudioRecorder.stop();
        final normalizedPath = (recordedPath ?? '').trim();
        if (normalizedPath.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Registrazione non completata. Riprova a registrare il vocale.',
                ),
              ),
            );
          }
          return;
        }

        final voiceBytes = await File(normalizedPath).readAsBytes();
        if (!mounted) {
          return;
        }

        if (voiceBytes.isEmpty ||
            voiceBytes.lengthInBytes > maxTicketAttachmentBytes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vocale non valido o troppo grande. Limite 4 MB per allegato.',
              ),
            ),
          );
          return;
        }

        if (_ticketAttachments.length >= maxTicketAttachments) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Puoi allegare al massimo 3 file per ticket.'),
            ),
          );
          return;
        }

        final attachment = SupportTicketUploadAttachment(
          fileName: 'vocale-$timestamp.m4a',
          contentType: 'audio/mp4',
          bytes: voiceBytes,
        );
        setState(() {
          _ticketAttachments = [..._ticketAttachments, attachment];
        });
      } else {
        await _ticketAudioRecorder.cancel();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossibile registrare il vocale in questo momento.',
            ),
          ),
        );
      }
      await _ticketAudioRecorder.cancel().catchError((_) {});
    } finally {
      if (outputPath != null) {
        unawaited(
          File(outputPath).delete().then<void>((_) {}).catchError((_) {}),
        );
      }
      if (mounted) {
        setState(() {
          _isRecordingTicketVoice = false;
        });
      }
    }
  }

  void _removeTicketAttachmentAt(int index) {
    if (index < 0 || index >= _ticketAttachments.length) {
      return;
    }

    setState(() {
      _ticketAttachments = [
        for (var i = 0; i < _ticketAttachments.length; i += 1)
          if (i != index) _ticketAttachments[i],
      ];
    });
  }

  String? _ticketAttachmentContentTypeForFileName(String fileName) {
    final lowerFileName = fileName.toLowerCase();
    if (lowerFileName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerFileName.endsWith('.jpg') || lowerFileName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerFileName.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerFileName.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    if (lowerFileName.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (lowerFileName.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (lowerFileName.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    if (lowerFileName.endsWith('.aac')) {
      return 'audio/aac';
    }
    if (lowerFileName.endsWith('.webm')) {
      return 'audio/webm';
    }
    return null;
  }

  bool _isAudioTicketAttachmentContentType(String contentType) {
    return contentType.startsWith('audio/');
  }

  void _applyPresetMinutes(int minutes) {
    _entryMinutesController.text = minutes.toString();
  }

  Future<void> _changeCalendarView(CalendarView view) async {
    if (_calendarView == view) {
      return;
    }

    setState(() {
      _calendarView = view;
    });
    await _ensureCalendarDataForCurrentView();
  }

  Future<void> _shiftCalendarPeriod(int step) async {
    final nextDate = switch (_calendarView) {
      CalendarView.day => _selectedDate.add(Duration(days: step)),
      CalendarView.week => _selectedDate.add(Duration(days: step * 7)),
      CalendarView.month => DateTime(
        _selectedDate.year,
        _selectedDate.month + step,
        1,
      ),
      CalendarView.year => DateTime(
        _selectedDate.year + step,
        _selectedDate.month,
        1,
      ),
    };

    await _setSelectedDate(nextDate, alignToPeriod: true);
  }

  Future<void> _setSelectedDate(
    DateTime date, {
    bool alignToPeriod = false,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextSelectedDate = switch (_calendarView) {
      CalendarView.month when alignToPeriod => DateTime(
        normalizedDate.year,
        normalizedDate.month,
        1,
      ),
      CalendarView.year when alignToPeriod => DateTime(
        normalizedDate.year,
        normalizedDate.month,
        1,
      ),
      _ => normalizedDate,
    };

    _entryDateController.text = DashboardService.defaultEntryDateOf(
      nextSelectedDate,
    );
    final nextMonth = DashboardService.formatMonth(nextSelectedDate);
    if (nextMonth != _selectedMonth) {
      await _loadSnapshot(month: nextMonth, selectedDate: nextSelectedDate);
      return;
    }

    setState(() {
      _selectedDate = nextSelectedDate;
      _workdaySession = null;
      _clearAgendaPreviewState();
    });
    unawaited(_loadWorkdaySessionForDate(nextSelectedDate));
    final currentSnapshot = _snapshot;
    if (currentSnapshot != null) {
      _hydrateSelectedDateControllers(currentSnapshot, nextSelectedDate);
    }
    await _ensureCalendarDataForCurrentView();
  }

  void _selectDate(DateTime date) {
    unawaited(_setSelectedDate(date));
  }

  void _hydrateSelectedDateControllers(
    DashboardSnapshot snapshot,
    DateTime selectedDate, {
    bool resetScheduleHistory = true,
  }) {
    final daySchedule = _resolveEffectiveDayScheduleForDate(
      snapshot,
      selectedDate,
    );
    final baseSchedule = _resolveBaseDayScheduleForDate(snapshot, selectedDate);
    final displayedSchedule = _resolveDisplayedDayScheduleForSession(
      daySchedule,
      baseSchedule,
      isSameDay(selectedDate, _todayDate) ? _workdaySession : null,
      selectedDate,
    );
    final displayedPauseWindow = resolveCalendarPauseWindow(
      schedule: displayedSchedule,
      startMinutes: parseTimeInput(displayedSchedule.startTime),
      endMinutes: parseTimeInput(displayedSchedule.endTime),
      session: isSameDay(selectedDate, _todayDate) ? _workdaySession : null,
      nowMinutes: _currentMinutesOfDay(),
    );
    _applyDayScheduleDraft(daySchedule, pauseWindow: displayedPauseWindow);
    if (resetScheduleHistory) {
      _resetScheduleOverrideHistoryForDate(
        selectedDate,
        schedule: displayedSchedule,
        pauseWindow: displayedPauseWindow,
      );
    }
  }

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

  ScheduleOverride? _findScheduleOverrideForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    final isoDate = DashboardService.defaultEntryDateOf(date);
    for (final scheduleOverride in snapshot.scheduleOverrides) {
      if (scheduleOverride.date == isoDate) {
        return scheduleOverride;
      }
    }

    return null;
  }

  DaySchedule _resolveBaseDayScheduleForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    return snapshot.profile.weekdaySchedule.forDate(date);
  }

  DaySchedule _resolveEffectiveDayScheduleForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    final scheduleOverride = _findScheduleOverrideForDate(snapshot, date);
    if (scheduleOverride == null) {
      return _resolveBaseDayScheduleForDate(snapshot, date);
    }

    return DaySchedule(
      targetMinutes: scheduleOverride.targetMinutes,
      startTime: scheduleOverride.startTime,
      endTime: scheduleOverride.endTime,
      breakMinutes: scheduleOverride.breakMinutes,
    );
  }

  DashboardSnapshot? _snapshotForMonth(String month) {
    final currentSnapshot = _snapshot;
    if (currentSnapshot != null && currentSnapshot.summary.month == month) {
      return currentSnapshot;
    }

    return _snapshotCache[month];
  }

  List<String> _requiredMonthsForCalendarView() {
    switch (_calendarView) {
      case CalendarView.day:
      case CalendarView.month:
        return [DashboardService.formatMonth(_selectedDate)];
      case CalendarView.week:
        return _monthsBetweenDates(
          _firstDayOfWeek(_selectedDate),
          _lastDayOfWeek(_selectedDate),
        );
      case CalendarView.year:
        return List.generate(
          12,
          (index) =>
              '${_selectedDate.year}-${(index + 1).toString().padLeft(2, '0')}',
        );
    }
  }

  List<String> _requiredMonthsForConsuntivoRange() {
    final monthCount = _consuntivoRange.monthCount;
    final anchorMonthDate = monthToDate(_selectedMonth);

    return List.generate(monthCount, (index) {
      final offset = (monthCount - 1) - index;
      final monthDate = DateTime(
        anchorMonthDate.year,
        anchorMonthDate.month - offset,
        1,
      );
      return DashboardService.formatMonth(monthDate);
    }, growable: false);
  }

  Future<void> _ensureConsuntivoDataLoaded() async {
    if (!mounted || _isLoadingConsuntivoData) {
      return;
    }

    final requiredMonths = _requiredMonthsForConsuntivoRange();
    final missingMonths = requiredMonths
        .where((month) => _snapshotForMonth(month) == null)
        .toList(growable: false);
    if (missingMonths.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingConsuntivoData = true;
    });

    try {
      for (final month in missingMonths) {
        final snapshot = await _fetchSnapshotForMonth(month);
        await _cacheSnapshot(snapshot);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _humanizeError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConsuntivoData = false;
        });
      }
    }
  }

  Future<void> _changeConsuntivoRange(ConsuntivoRangeOption nextRange) async {
    if (nextRange == _consuntivoRange) {
      return;
    }

    setState(() {
      _consuntivoRange = nextRange;
    });
    await _ensureConsuntivoDataLoaded();
  }

  Future<void> _shiftConsuntivoAnchorMonth(int step) async {
    if (step == 0 || _isLoading) {
      return;
    }

    final currentMonthDate = monthToDate(_selectedMonth);
    final nextMonthDate = DateTime(
      currentMonthDate.year,
      currentMonthDate.month + step,
      1,
    );
    final nextMonth = DashboardService.formatMonth(nextMonthDate);
    if (nextMonth == _selectedMonth) {
      return;
    }

    final daysInNextMonth = DateTime(
      nextMonthDate.year,
      nextMonthDate.month + 1,
      0,
    ).day;
    final nextSelectedDate = DateTime(
      nextMonthDate.year,
      nextMonthDate.month,
      math.min(_selectedDate.day, daysInNextMonth),
    );

    await _loadSnapshot(month: nextMonth, selectedDate: nextSelectedDate);
    if (!mounted) {
      return;
    }
    await _ensureConsuntivoDataLoaded();
  }

  ConsuntivoSectionData _buildConsuntivoSectionData(
    DashboardSnapshot fallbackSnapshot,
  ) {
    final requiredMonths = _requiredMonthsForConsuntivoRange();
    final snapshotsByMonth = <String, DashboardSnapshot>{
      for (final month in requiredMonths)
        if (_snapshotForMonth(month) != null) month: _snapshotForMonth(month)!,
    };
    final anchorSnapshot =
        snapshotsByMonth[_selectedMonth] ??
        _snapshotForMonth(_selectedMonth) ??
        fallbackSnapshot;

    final monthSummaries = requiredMonths
        .map((month) {
          final snapshot = snapshotsByMonth[month];
          if (snapshot == null) {
            return ConsuntivoMonthSummary(
              monthLabel: formatMonthLabel(month),
              expectedMinutes: 0,
              workedMinutes: 0,
              leaveMinutes: 0,
              balanceMinutes: 0,
            );
          }

          return ConsuntivoMonthSummary(
            monthLabel: formatMonthLabel(snapshot.summary.month),
            expectedMinutes: snapshot.summary.expectedMinutes,
            workedMinutes: snapshot.summary.workedMinutes,
            leaveMinutes: snapshot.summary.leaveMinutes,
            balanceMinutes: snapshot.summary.balanceMinutes,
          );
        })
        .toList(growable: false);

    var totalExpectedMinutes = 0;
    var totalWorkedMinutes = 0;
    var totalLeaveMinutes = 0;
    var totalRawBalanceMinutes = 0;
    var totalClampedBalanceMinutes = 0;

    for (final month in requiredMonths) {
      final snapshot = snapshotsByMonth[month];
      if (snapshot == null) {
        continue;
      }

      totalExpectedMinutes += snapshot.summary.expectedMinutes;
      totalWorkedMinutes += snapshot.summary.workedMinutes;
      totalLeaveMinutes += snapshot.summary.leaveMinutes;
      totalRawBalanceMinutes += snapshot.summary.rawBalanceMinutes;
      totalClampedBalanceMinutes += snapshot.summary.balanceMinutes;
    }

    final allPermissionRules = [
      ...anchorSnapshot.profile.workRules.additionalPermissions,
      ...anchorSnapshot.profile.workRules.leaveBanks,
    ];
    final permissions =
        allPermissionRules
            .map(
              (rule) => ConsuntivoPermissionSummary(
                name: rule.name,
                periodLabel: rule.period.label,
                enabled: rule.enabled,
                allowanceLabel: formatRuleAllowanceValue(rule),
                usedLabel: formatRuleUsedValue(rule),
                remainingLabel: formatRuleRemainingValue(rule),
                movementsLabel: rule.movements
                    .map((item) => item.label)
                    .join(', '),
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.name.compareTo(right.name));

    final daySummariesData = _buildConsuntivoDaySummaries(
      requiredMonths: requiredMonths,
      snapshotsByMonth: snapshotsByMonth,
    );

    final firstMonthLabel = formatMonthLabel(requiredMonths.first);
    final lastMonthLabel = formatMonthLabel(requiredMonths.last);
    final periodLabel = firstMonthLabel == lastMonthLabel
        ? firstMonthLabel
        : '$firstMonthLabel - $lastMonthLabel';

    return ConsuntivoSectionData(
      anchorMonthLabel: formatMonthLabel(_selectedMonth),
      periodLabel: periodLabel,
      totals: ConsuntivoTotals(
        expectedMinutes: totalExpectedMinutes,
        workedMinutes: totalWorkedMinutes,
        leaveMinutes: totalLeaveMinutes,
        rawBalanceMinutes: totalRawBalanceMinutes,
        clampedBalanceMinutes: totalClampedBalanceMinutes,
        overtimeMaturedMinutes: math.max(totalRawBalanceMinutes, 0),
        debitMaturedMinutes: math.max(-totalRawBalanceMinutes, 0),
      ),
      months: monthSummaries,
      permissions: permissions,
      days: daySummariesData.days,
      hiddenDaysCount: daySummariesData.hiddenCount,
    );
  }

  ({List<ConsuntivoDaySummary> days, int hiddenCount})
  _buildConsuntivoDaySummaries({
    required List<String> requiredMonths,
    required Map<String, DashboardSnapshot> snapshotsByMonth,
  }) {
    if (requiredMonths.isEmpty) {
      return (days: const <ConsuntivoDaySummary>[], hiddenCount: 0);
    }

    final workByMonthAndDate = <String, Map<String, List<WorkEntry>>>{};
    final leaveByMonthAndDate = <String, Map<String, List<LeaveEntry>>>{};
    final overridesByMonthAndDate = <String, Map<String, ScheduleOverride>>{};

    for (final month in requiredMonths) {
      final snapshot = snapshotsByMonth[month];
      if (snapshot == null) {
        continue;
      }

      final workByDate = <String, List<WorkEntry>>{};
      for (final entry in snapshot.workEntries) {
        workByDate.putIfAbsent(entry.date, () => <WorkEntry>[]).add(entry);
      }

      final leaveByDate = <String, List<LeaveEntry>>{};
      for (final entry in snapshot.leaveEntries) {
        leaveByDate.putIfAbsent(entry.date, () => <LeaveEntry>[]).add(entry);
      }

      final overrideByDate = <String, ScheduleOverride>{
        for (final item in snapshot.scheduleOverrides) item.date: item,
      };

      workByMonthAndDate[month] = workByDate;
      leaveByMonthAndDate[month] = leaveByDate;
      overridesByMonthAndDate[month] = overrideByDate;
    }

    final startDate = monthToDate(requiredMonths.first);
    final selectedMonthDate = monthToDate(_selectedMonth);
    final selectedMonthLastDate = DateTime(
      selectedMonthDate.year,
      selectedMonthDate.month + 1,
      0,
    );
    final today = DateUtils.dateOnly(DateTime.now());
    final endDate = selectedMonthLastDate.isAfter(today)
        ? today
        : selectedMonthLastDate;
    if (endDate.isBefore(startDate)) {
      return (days: const <ConsuntivoDaySummary>[], hiddenCount: 0);
    }

    final allDays = <ConsuntivoDaySummary>[];
    var cursor = endDate;
    while (!cursor.isBefore(startDate)) {
      final month = DashboardService.formatMonth(cursor);
      final snapshot = snapshotsByMonth[month];
      if (snapshot != null) {
        final isoDate = DashboardService.defaultEntryDateOf(cursor);
        final workEntries =
            workByMonthAndDate[month]?[isoDate] ?? const <WorkEntry>[];
        final leaveEntries =
            leaveByMonthAndDate[month]?[isoDate] ?? const <LeaveEntry>[];
        final override = overridesByMonthAndDate[month]?[isoDate];
        final effectiveSchedule = _resolveEffectiveDayScheduleForDate(
          snapshot,
          cursor,
        );

        final workedMinutes = workEntries.fold<int>(
          0,
          (total, entry) => total + entry.minutes,
        );
        final leaveMinutes = leaveEntries.fold<int>(
          0,
          (total, entry) => total + entry.minutes,
        );
        final registeredMinutes = workedMinutes + leaveMinutes;
        final balanceMinutes =
            registeredMinutes - effectiveSchedule.targetMinutes;

        final includeRow =
            workedMinutes > 0 ||
            leaveMinutes > 0 ||
            override != null ||
            balanceMinutes != 0;
        if (includeRow) {
          final startTime = effectiveSchedule.startTime?.trim() ?? '';
          final endTime = effectiveSchedule.endTime?.trim() ?? '';
          final hasTimeline = startTime.isNotEmpty && endTime.isNotEmpty;
          final scheduleDetail = hasTimeline
              ? 'Dettaglio: $startTime-$endTime, pausa ${formatHoursInput(effectiveSchedule.breakMinutes)}'
              : null;

          final details = <String>[];
          if (leaveEntries.isNotEmpty) {
            final leaveLabel = leaveEntries
                .map(
                  (entry) =>
                      '${entry.type.label} ${formatHoursInput(entry.minutes)}',
                )
                .join(', ');
            details.add('Causali: $leaveLabel');
          }
          if (override != null) {
            details.add('Programma personalizzato');
          }
          final notedWorkEntries = workEntries
              .map((entry) => entry.note?.trim() ?? '')
              .where((note) => note.isNotEmpty)
              .toList(growable: false);
          if (notedWorkEntries.isNotEmpty) {
            details.add('Note: ${notedWorkEntries.join(' | ')}');
          }

          allDays.add(
            ConsuntivoDaySummary(
              dateLabel:
                  '${formatWeekdayShortLabel(cursor)} ${formatCompactDate(cursor)}',
              plannedLabel: formatHoursInput(effectiveSchedule.targetMinutes),
              registeredLabel: formatHoursInput(registeredMinutes),
              balanceMinutes: balanceMinutes,
              scheduleDetail: scheduleDetail,
              causalDetail: details.isEmpty ? null : details.join(' | '),
            ),
          );
        }
      }

      cursor = cursor.subtract(const Duration(days: 1));
    }

    const maxVisibleRows = 90;
    if (allDays.length <= maxVisibleRows) {
      return (days: allDays, hiddenCount: 0);
    }

    return (
      days: allDays.take(maxVisibleRows).toList(growable: false),
      hiddenCount: allDays.length - maxVisibleRows,
    );
  }

  List<String> _monthsBetweenDates(DateTime start, DateTime end) {
    final months = <String>[];
    var cursor = DateTime(start.year, start.month, 1);
    final lastMonth = DateTime(end.year, end.month, 1);

    while (!cursor.isAfter(lastMonth)) {
      months.add(DashboardService.formatMonth(cursor));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return months;
  }

  DateTime _firstDayOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  DateTime _lastDayOfWeek(DateTime date) {
    final firstDay = _firstDayOfWeek(date);
    return firstDay.add(const Duration(days: 6));
  }

  int _sumWorkedMinutesForDate(DashboardSnapshot snapshot, String isoDate) {
    var total = 0;
    for (final entry in snapshot.workEntries) {
      if (entry.date == isoDate) {
        total += entry.minutes;
      }
    }
    return total;
  }

  int _sumLeaveMinutesForDate(DashboardSnapshot snapshot, String isoDate) {
    var total = 0;
    for (final entry in snapshot.leaveEntries) {
      if (entry.date == isoDate) {
        total += entry.minutes;
      }
    }
    return total;
  }

  int _overrideCountForMonth(DashboardSnapshot snapshot) {
    return snapshot.scheduleOverrides.length;
  }

  DayMetrics _buildDayMetrics(DateTime date) {
    final month = DashboardService.formatMonth(date);
    final snapshot = _snapshotForMonth(month);
    if (snapshot == null) {
      return DayMetrics.empty(date);
    }

    final isoDate = DashboardService.defaultEntryDateOf(date);
    final effectiveSchedule = _resolveEffectiveDayScheduleForDate(
      snapshot,
      date,
    );
    final override = _findScheduleOverrideForDate(snapshot, date);
    final workedMinutes = _sumWorkedMinutesForDate(snapshot, isoDate);
    final leaveMinutes = _sumLeaveMinutesForDate(snapshot, isoDate);
    final rawBalanceMinutes =
        workedMinutes + leaveMinutes - effectiveSchedule.targetMinutes;

    return DayMetrics(
      date: date,
      expectedMinutes: effectiveSchedule.targetMinutes,
      workedMinutes: workedMinutes,
      leaveMinutes: leaveMinutes,
      rawBalanceMinutes: rawBalanceMinutes,
      balanceMinutes: snapshot.profile.workRules.clampDailyBalance(
        rawBalanceMinutes,
      ),
      hasOverride: override != null,
      schedule: effectiveSchedule,
      overrideNote: override?.note,
    );
  }

  List<DayMetrics> _buildWeekMetrics() {
    final firstDay = _firstDayOfWeek(_selectedDate);
    return List.generate(
      7,
      (index) => _buildDayMetrics(firstDay.add(Duration(days: index))),
      growable: false,
    );
  }

  List<MonthMetrics> _buildYearMetrics() {
    return List.generate(12, (index) {
      final month =
          '${_selectedDate.year}-${(index + 1).toString().padLeft(2, '0')}';
      final snapshot = _snapshotForMonth(month);
      if (snapshot == null) {
        return MonthMetrics.empty(month);
      }

      return MonthMetrics(
        month: snapshot.summary.month,
        expectedMinutes: snapshot.summary.expectedMinutes,
        workedMinutes: snapshot.summary.workedMinutes,
        leaveMinutes: snapshot.summary.leaveMinutes,
        rawBalanceMinutes: snapshot.summary.rawBalanceMinutes,
        balanceMinutes: snapshot.summary.balanceMinutes,
        overrideCount: _overrideCountForMonth(snapshot),
      );
    }, growable: false);
  }

  String _calendarPeriodLabelFor(CalendarView view) {
    switch (view) {
      case CalendarView.day:
        return formatLongDate(_selectedDate);
      case CalendarView.week:
        final firstDay = _firstDayOfWeek(_selectedDate);
        final lastDay = _lastDayOfWeek(_selectedDate);
        return '${formatCompactDate(firstDay)} - ${formatCompactDate(lastDay)}';
      case CalendarView.month:
        return formatMonthLabel(_selectedMonth);
      case CalendarView.year:
        return '${_selectedDate.year}';
    }
  }

  String _calendarPeriodLabel() => _calendarPeriodLabelFor(_calendarView);

  DateTime _resolveSelectedDateForMonth(
    String month, {
    DateTime? preferredDate,
  }) {
    final monthDate = monthToDate(month);
    final candidateDate = preferredDate;
    if (candidateDate != null && isSameMonth(candidateDate, monthDate)) {
      return DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
      );
    }

    if (_snapshot != null && isSameMonth(_selectedDate, monthDate)) {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
    }

    final today = DateTime.now();
    if (isSameMonth(today, monthDate)) {
      return DateTime(today.year, today.month, today.day);
    }

    return DateTime(monthDate.year, monthDate.month, 1);
  }

  List<CalendarDay> _buildCalendarDays(DashboardSnapshot snapshot) {
    final monthDate = monthToDate(snapshot.summary.month);
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final workMinutesByDate = <String, int>{};
    final leaveMinutesByDate = <String, int>{};

    for (final entry in snapshot.workEntries) {
      workMinutesByDate.update(
        entry.date,
        (value) => value + entry.minutes,
        ifAbsent: () => entry.minutes,
      );
    }

    for (final entry in snapshot.leaveEntries) {
      leaveMinutesByDate.update(
        entry.date,
        (value) => value + entry.minutes,
        ifAbsent: () => entry.minutes,
      );
    }

    final days = <CalendarDay>[];
    for (var index = 1; index < firstDayOfMonth.weekday; index += 1) {
      days.add(const CalendarDay.empty());
    }

    final today = DateTime.now();
    for (var day = 1; day <= daysInMonth; day += 1) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      final isoDate = DashboardService.defaultEntryDateOf(date);
      final effectiveSchedule = _resolveEffectiveDayScheduleForDate(
        snapshot,
        date,
      );
      final displayedSchedule = _resolveDisplayedDaySchedule(
        effectiveSchedule,
        date,
      );
      final hasOverride = _findScheduleOverrideForDate(snapshot, date) != null;
      final relation = switch (compareDateToToday(date)) {
        0 => CalendarDayRelation.today,
        < 0 => CalendarDayRelation.past,
        _ => CalendarDayRelation.future,
      };
      final workedMinutes = workMinutesByDate[isoDate] ?? 0;
      final leaveMinutes = leaveMinutesByDate[isoDate] ?? 0;
      final todayStatusLabel = relation == CalendarDayRelation.today
          ? workdaySessionStatusLabel(
              resolveWorkdaySessionStatus(_workdaySession),
            )
          : null;
      days.add(
        CalendarDay(
          date: date,
          isoDate: isoDate,
          expectedMinutes: effectiveSchedule.targetMinutes,
          workedMinutes: workedMinutes,
          leaveMinutes: leaveMinutes,
          hasOverride: hasOverride,
          isToday: isSameDay(date, today),
          isSelected: isSameDay(date, _selectedDate),
          relation: relation,
          primaryLabel: buildCalendarDayPrimaryLabel(
            relation: relation,
            schedule: displayedSchedule,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            hasOverride: hasOverride,
          ),
          secondaryLabel: buildCalendarDaySecondaryLabel(
            relation: relation,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            hasOverride: hasOverride,
            todayStatusLabel: todayStatusLabel,
          ),
          details: buildCalendarDayDetails(
            relation: relation,
            schedule: displayedSchedule,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            session: relation == CalendarDayRelation.today
                ? _workdaySession
                : null,
          ),
        ),
      );
    }

    while (days.length % 7 != 0) {
      days.add(const CalendarDay.empty());
    }

    return days;
  }

  List<ActivityItem> _buildActivitiesForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    final selectedIsoDate = DashboardService.defaultEntryDateOf(date);
    return _buildActivities(
      snapshot,
    ).where((item) => item.date == selectedIsoDate).toList(growable: false);
  }

  TodayStatus _resolveDayStatus(DateTime date, DayMetrics metrics) {
    final registeredMinutes = metrics.workedMinutes + metrics.leaveMinutes;
    if (metrics.expectedMinutes == 0 && registeredMinutes == 0) {
      return TodayStatus.dayOff;
    }
    if (metrics.leaveMinutes >= metrics.expectedMinutes &&
        metrics.expectedMinutes > 0) {
      return TodayStatus.absent;
    }
    if (registeredMinutes >= metrics.expectedMinutes &&
        metrics.expectedMinutes > 0) {
      return TodayStatus.completed;
    }

    final now = DateTime.now();
    final currentMinutesOfDay = (now.hour * 60) + now.minute;
    final scheduledStart = parseTimeInput(metrics.schedule.startTime);
    final scheduledEnd = parseTimeInput(metrics.schedule.endTime);

    if (date.isAfter(_todayDate)) {
      return TodayStatus.planned;
    }

    if (date.isBefore(_todayDate)) {
      return registeredMinutes == 0
          ? TodayStatus.needsAttention
          : TodayStatus.inProgress;
    }

    if (registeredMinutes == 0) {
      if (scheduledStart != null && currentMinutesOfDay < scheduledStart) {
        return TodayStatus.planned;
      }
      return TodayStatus.needsAttention;
    }

    if (scheduledEnd != null && currentMinutesOfDay >= scheduledEnd + 15) {
      return TodayStatus.needsAttention;
    }

    return TodayStatus.inProgress;
  }

  TodayStatus _resolveTodayStatus(DayMetrics metrics) {
    return _resolveDayStatus(_todayDate, metrics);
  }

  List<({IconData icon, String title, String description})>
  _buildTodayReminders(DashboardSnapshot snapshot, DayMetrics metrics) {
    final reminders = <({IconData icon, String title, String description})>[];
    final todayStatus = _resolveTodayStatus(metrics);
    final now = DateTime.now();
    final currentMinutesOfDay = (now.hour * 60) + now.minute;
    final scheduledStart = parseTimeInput(metrics.schedule.startTime);
    final scheduledEnd = parseTimeInput(metrics.schedule.endTime);

    if (todayStatus == TodayStatus.needsAttention &&
        scheduledStart != null &&
        currentMinutesOfDay >= scheduledStart) {
      reminders.add((
        icon: Icons.play_circle_outline,
        title: 'Giornata da avviare o chiudere',
        description:
            'Oggi risulti ancora incompleto. Registra le ore mancanti oppure chiudi la giornata.',
      ));
    }

    if (todayStatus == TodayStatus.inProgress &&
        scheduledEnd != null &&
        currentMinutesOfDay >= scheduledEnd - 30) {
      reminders.add((
        icon: Icons.alarm_on_outlined,
        title: 'Controlla la chiusura di oggi',
        description:
            'La fascia prevista sta per finire. Ti conviene verificare l ultima registrazione della giornata.',
      ));
    }

    final tomorrow = _todayDate.add(const Duration(days: 1));
    final tomorrowSnapshot =
        _snapshotForMonth(DashboardService.formatMonth(tomorrow)) ??
        (isSameMonth(tomorrow, monthToDate(snapshot.summary.month))
            ? snapshot
            : null);
    final tomorrowOverride = tomorrowSnapshot == null
        ? null
        : _findScheduleOverrideForDate(tomorrowSnapshot, tomorrow);
    if (tomorrowOverride != null) {
      reminders.add((
        icon: Icons.event_repeat_outlined,
        title: 'Domani hai orari diversi',
        description:
            'Il programma di domani e diverso dal solito. Controlla gli orari prima di iniziare.',
      ));
    }

    if (metrics.hasOverride) {
      reminders.add((
        icon: Icons.rule_folder_outlined,
        title: 'Oggi hai orari diversi',
        description:
            'La giornata di oggi usa orari diversi rispetto al solito.',
      ));
    }

    return reminders;
  }

  Future<void> _ensureUpcomingWeekData() async {
    final days = List.generate(
      7,
      (index) => _todayDate.add(Duration(days: index)),
      growable: false,
    );
    final missingMonths = days
        .map(DashboardService.formatMonth)
        .where((month) => !_snapshotCache.containsKey(month))
        .toSet()
        .toList(growable: false);
    if (missingMonths.isEmpty) {
      return;
    }

    try {
      for (final month in missingMonths) {
        final loadedSnapshot = await widget.dashboardService.loadSnapshot(
          month: month,
        );
        await _cacheSnapshot(loadedSnapshot);
      }
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _humanizeError(error);
        });
      }
    }
  }

  List<WeekPlanDay> _buildUpcomingWeekPlan() {
    return List.generate(7, (index) {
      final date = _todayDate.add(Duration(days: index));
      final month = DashboardService.formatMonth(date);
      final monthSnapshot = _snapshotForMonth(month);
      if (monthSnapshot == null) {
        return WeekPlanDay.empty(date);
      }

      final metrics = _buildDayMetrics(date);
      final override = _findScheduleOverrideForDate(monthSnapshot, date);
      return WeekPlanDay(
        date: date,
        status: _resolveDayStatus(date, metrics),
        metrics: metrics,
        overrideNote: override?.note,
      );
    }, growable: false);
  }

  String _humanizeError(
    Object error, {
    String? apiBaseUrl,
    bool isTicketRequest = false,
  }) {
    if (error is ApiException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Accesso cloud non valido. Apri Profilo e accedi di nuovo.';
      }
      if (error.message == 'account not found') {
        return 'Nessun account trovato con questa email.';
      }
      if (error.message == 'recovery questions not configured') {
        return 'Per questo account non sono ancora state configurate le domande di recupero.';
      }
      if (error.message == 'too many recovery attempts') {
        return 'Troppi tentativi di recupero. Riprova tra qualche minuto.';
      }
      if (error.message == 'questionOne is required') {
        return 'La prima domanda di recupero non è valida.';
      }
      if (error.message == 'questionTwo is required') {
        return 'La seconda domanda di recupero non è valida.';
      }
      if (error.message == 'answerOne is required') {
        return 'La prima risposta di recupero non è valida.';
      }
      if (error.message == 'answerTwo is required') {
        return 'La seconda risposta di recupero non è valida.';
      }
      if (error.message == 'answerOne must be between 1 and 120 characters') {
        return 'La prima risposta di recupero non è valida.';
      }
      if (error.message == 'answerTwo must be between 1 and 120 characters') {
        return 'La seconda risposta di recupero non è valida.';
      }
      if (error.message ==
          'workEntries, leaveEntries and scheduleOverrides must contain valid items') {
        return 'Backup cloud non riuscito: alcuni dati locali risultano incompleti o danneggiati. Modifica gli ultimi inserimenti e riprova.';
      }
      if (error.message.contains('weekdaySchedule must include') ||
          error.message.contains('weekdayTargetMinutes must include') ||
          error.message.contains(
            'targetMinutes must match startTime/endTime minus breakMinutes',
          )) {
        return 'Controlla le impostazioni orarie: ogni giorno deve avere ore valide e, se imposti inizio e fine, la pausa deve far tornare il totale.';
      }
      return error.message;
    }

    final normalizedApiBaseUrl = apiBaseUrl?.trim();
    if (normalizedApiBaseUrl != null && normalizedApiBaseUrl.isNotEmpty) {
      return isTicketRequest
          ? 'Impossibile contattare il backend ticket su $normalizedApiBaseUrl. Verifica che l API sia attiva e raggiungibile.'
          : 'Impossibile contattare il backend su $normalizedApiBaseUrl. Verifica che l API sia attiva e raggiungibile.';
    }

    return isTicketRequest
        ? 'Impossibile contattare il backend ticket. Verifica che l API sia attiva e raggiungibile.'
        : 'Impossibile contattare il backend. Verifica che l API sia attiva e raggiungibile.';
  }

  List<int> get _minutesPresets {
    if (_selectedEntryMode == QuickEntryMode.work) {
      return const [240, 360, 420, 480];
    }

    return const [60, 120, 240, 480];
  }

  List<ActivityItem> _buildActivities(DashboardSnapshot snapshot) {
    final workItems = snapshot.workEntries.map(
      (entry) => ActivityItem(
        key: 'work-${entry.id}',
        date: entry.date,
        title: 'Ore lavorate',
        subtitle: entry.note?.isNotEmpty == true
            ? entry.note!
            : 'Registrazione lavoro',
        minutes: entry.minutes,
        accentColor: const Color(0xFF0B6E69),
        icon: Icons.work_outline,
      ),
    );

    final leaveItems = snapshot.leaveEntries.map(
      (entry) => ActivityItem(
        key: 'leave-${entry.id}',
        date: entry.date,
        title: entry.type.label,
        subtitle: entry.note?.isNotEmpty == true
            ? entry.note!
            : 'Assenza registrata',
        minutes: entry.minutes,
        accentColor: const Color(0xFFBF7A24),
        icon: entry.type == LeaveType.vacation
            ? Icons.beach_access_outlined
            : Icons.event_available_outlined,
      ),
    );

    final items = [...workItems, ...leaveItems];
    items.sort((left, right) => right.date.compareTo(left.date));
    return items.take(8).toList(growable: false);
  }

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
      dayLeaveEntries: monthSnapshot.leaveEntries
          .where(
            (entry) =>
                entry.date ==
                DashboardService.defaultEntryDateOf(_selectedDate),
          )
          .toList(growable: false),
      onOpenLeaveQuickEntry: () => _openLeaveQuickEntryForDate(_selectedDate),
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

            if (horizontalVelocity > 0) {
              unawaited(_shiftSelectedDay(1));
              return;
            }

            unawaited(_shiftSelectedDay(-1));
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
      case HomeSection.overview:
        final today = _todayDate;
        final todaySnapshot =
            _snapshotForMonth(DashboardService.formatMonth(today)) ?? snapshot;
        final todayMetrics = _buildDayMetrics(today);
        final todayStatus = _resolveTodayStatus(todayMetrics);
        return OverviewCard(
          selectedDate: today,
          todayMetrics: todayMetrics,
          todayStatus: todayStatus,
          effectiveSchedule: _resolveEffectiveDayScheduleForDate(
            todaySnapshot,
            today,
          ),
          todayOverride: _findScheduleOverrideForDate(todaySnapshot, today),
          todayActivities: _buildActivitiesForDate(todaySnapshot, today),
          reminders: _buildTodayReminders(todaySnapshot, todayMetrics),
          onOpenWorkEntry: () => _openWorkQuickEntryForDate(
            today,
            prefilledMinutes:
                (todayMetrics.expectedMinutes -
                        todayMetrics.workedMinutes -
                        todayMetrics.leaveMinutes)
                    .clamp(0, 24 * 60),
          ),
          onOpenLeaveEntry: () => _openLeaveQuickEntryForDate(
            today,
            prefilledMinutes: todayMetrics.expectedMinutes == 0
                ? null
                : (todayMetrics.expectedMinutes -
                          todayMetrics.workedMinutes -
                          todayMetrics.leaveMinutes)
                      .clamp(60, 24 * 60),
            leaveType: LeaveType.permit,
          ),
          onOpenTodayCalendar: () => _openDayForDate(today),
          onApplyPreset: _prepareTodayOverridePreset,
          onRemoveTodayOverride: todayMetrics.hasOverride
              ? _removeTodayOverride
              : null,
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
      case HomeSection.recentActivity:
        return RecentActivityCard(
          weekPlan: _buildUpcomingWeekPlan(),
          onOpenDay: _openDayForDate,
          onOpenWorkEntry: _openWorkQuickEntryForDate,
          onOpenLeaveEntry: _openLeaveQuickEntryForDate,
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

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    if (_isLoading && snapshot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              physics: _isAgendaInteracting
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                HomeHeader(
                  selectedSection: _selectedSection,
                  hasCloudAccount: _accountSession != null,
                  unreadTicketReplyCount: _unreadTicketReplyCount,
                  onSelectSection: (section) {
                    setState(() {
                      _selectedSection = section;
                      if (section == HomeSection.calendar &&
                          _calendarView == CalendarView.day) {
                        _calendarView = CalendarView.month;
                      }
                    });
                    if (section == HomeSection.ticket) {
                      unawaited(_refreshTrackedSupportTickets());
                      final selectedTicketId = _selectedTrackedTicketId;
                      if (selectedTicketId != null) {
                        unawaited(
                          _markTrackedTicketRepliesSeen(selectedTicketId),
                        );
                      }
                    }
                    if (section == HomeSection.consuntivo) {
                      unawaited(_ensureConsuntivoDataLoaded());
                    }
                  },
                  onOpenRegistration: _openAccountRegistrationFlow,
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  ErrorCard(message: _errorMessage!, onRetry: _refreshAll),
                  const SizedBox(height: 16),
                ],
                if (snapshot != null) ...[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey(_selectedSection),
                      child: _buildSelectedSection(snapshot),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setAgendaInteracting(bool isInteracting) {
    if (!mounted || _isAgendaInteracting == isInteracting) {
      return;
    }
    setState(() {
      _isAgendaInteracting = isInteracting;
    });
  }
}
