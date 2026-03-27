import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:work_hours_mobile/application/services/account_service.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/domain/models/account_session.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_snapshot_store.dart';
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

enum _QuickEntryMode { work, leave }

enum _CalendarView { day, week, month, year }

enum _AppearanceTab { theme, colors, typography }

enum _AccountAuthMode { login, register }

const int _maxTicketAttachments = 3;
const int _maxTicketAttachmentBytes = 4 * 1024 * 1024;
const Duration _ticketNotificationPollingInterval = Duration(minutes: 1);
final ImagePicker _ticketImagePicker = ImagePicker();

enum _HomeSection {
  day,
  overview,
  quickEntry,
  calendar,
  recentActivity,
  workSettings,
  profile,
  ticket,
}

enum _ScheduleOverrideAutosaveAction { none, save, remove }

enum _TodayStatus {
  dayOff,
  planned,
  needsAttention,
  inProgress,
  completed,
  absent,
}

enum _TodayOverridePreset { startLater, finishEarlier, longerBreak, dayOff }

enum _CalendarTimeField { start, end }

class _ScheduleTimeWheelSelection {
  const _ScheduleTimeWheelSelection.confirmed(this.minutes) : cleared = false;
  const _ScheduleTimeWheelSelection.cleared()
    : minutes = null,
      cleared = true;

  final int? minutes;
  final bool cleared;
}

enum _WorkdaySessionStatus { notStarted, active, onBreak, completed }

const _mainNavigationSections = [
  _HomeSection.day,
  _HomeSection.calendar,
  _HomeSection.workSettings,
  _HomeSection.profile,
  _HomeSection.ticket,
];

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
  _CalendarView _calendarView = _CalendarView.month;
  bool _useUniformDailyTarget = true;
  bool _rulesOvertimeEnabled = false;
  bool _rulesOvertimeCapEnabled = false;
  bool _rulesFixedScheduleEnabled = false;
  bool _rulesFlexibleStartEnabled = false;
  bool _rulesWalletEnabled = false;
  bool _rulesImplicitCreditEnabled = false;
  List<WorkPermissionRule> _rulesAdditionalPermissions = const [];
  List<WorkPermissionRule> _rulesLeaveBanks = const [];
  LeaveType _selectedLeaveType = LeaveType.vacation;
  _QuickEntryMode _selectedEntryMode = _QuickEntryMode.work;
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
  bool _isSubmittingTicketReply = false;
  bool _isRecoveringTrackedTicket = false;
  bool _isAuthenticatingAccount = false;
  bool _isRecoveringAccountPassword = false;
  bool _isRestoringCloudBackup = false;
  bool _isSyncingCloudBackup = false;
  bool _isBackgroundUpdateDownloadInProgress = false;
  bool _isPromptingBackgroundUpdateInstall = false;
  bool _cloudBackupQueued = false;
  AppUpdate? _backgroundUpdate;
  DownloadedAppUpdate? _backgroundDownloadedUpdate;
  UpdateDownloadProgress _backgroundUpdateProgress =
      const UpdateDownloadProgress(receivedBytes: 0, totalBytes: null);
  late bool _hasCompletedInitialSetup;
  _HomeSection _selectedSection = _HomeSection.calendar;
  SupportTicketCategory _selectedTicketCategory = SupportTicketCategory.bug;
  List<TrackedSupportTicket> _trackedTickets = const [];
  Map<String, SupportTicketThread> _ticketThreadsById = const {};
  List<SupportTicketUploadAttachment> _ticketAttachments = const [];
  String? _selectedTrackedTicketId;
  int _unreadTicketReplyCount = 0;
  WorkdaySession? _workdaySession;
  bool _scheduleOverrideAutosaveQueued = false;
  List<_ScheduleOverrideDraftState> _scheduleOverrideHistory = const [];
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
  _AccountAuthMode _accountAuthMode = _AccountAuthMode.login;
  Timer? _ticketNotificationTimer;
  Timer? _liveWorkedMinutesTimer;
  final LocalNotificationService _localNotificationService =
      LocalNotificationService();
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
    _entryDateController.text = DashboardService.defaultEntryDateOf(
      _selectedDate,
    );
    unawaited(_primeSnapshotFromLocalCache());
    _loadSnapshot();
    unawaited(_loadWorkdaySessionForDate(_selectedDate));
    unawaited(_refreshTrackedSupportTickets());
    _startTicketNotificationPolling();
    _startLiveWorkedMinutesTicker();
    unawaited(_initializeUpdateExperience());
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
        unawaited(_localNotificationService.notifyUpdateAvailable(availableUpdate));
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
    final action = await showDialog<_UpdateDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(update: update),
    );
    _isShowingUpdateDialog = false;

    if (!mounted) {
      return;
    }

    switch (action) {
      case _UpdateDialogAction.updateNow:
        await widget.updateReminderStore.deferAfterOpening(update);
        await _startInAppUpdateFlow(update);
        break;
      case _UpdateDialogAction.remindLater:
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
    _uniformDailyTargetController.text = _formatHoursInput(
      snapshot.profile.dailyTargetMinutes,
    );
    _uniformStartTimeController.text =
        snapshot.profile.weekdaySchedule.monday.startTime ?? '';
    _uniformEndTimeController.text =
        snapshot.profile.weekdaySchedule.monday.endTime ?? '';
    _uniformBreakController.text = _formatBreakInput(
      snapshot.profile.weekdaySchedule.monday.breakMinutes,
    );
    _rulesExpectedDailyController.text = _formatHoursInput(
      snapshot.profile.workRules.expectedDailyMinutes,
    );
    _rulesMinimumBreakController.text = _formatBreakInput(
      snapshot.profile.workRules.minimumBreakMinutes,
    );
    _rulesMaximumDailyCreditController.text = _formatHoursInput(
      snapshot.profile.workRules.maximumDailyCreditMinutes,
    );
    _rulesMaximumDailyDebitController.text = _formatHoursInput(
      snapshot.profile.workRules.maximumDailyDebitMinutes,
    );
    _rulesMaximumMonthlyCreditController.text = _formatHoursInput(
      snapshot.profile.workRules.maximumMonthlyCreditMinutes,
    );
    _rulesMaximumMonthlyDebitController.text = _formatHoursInput(
      snapshot.profile.workRules.maximumMonthlyDebitMinutes,
    );
    _rulesOvertimeEnabled = snapshot.profile.workRules.overtimeEnabled;
    _rulesOvertimeCapEnabled = snapshot.profile.workRules.overtimeCapEnabled;
    _rulesOvertimeDailyCapController.text = _formatHoursInput(
      snapshot.profile.workRules.overtimeDailyCapMinutes,
    );
    _rulesOvertimeWeeklyCapController.text = _formatHoursInput(
      snapshot.profile.workRules.overtimeWeeklyCapMinutes,
    );
    _rulesOvertimeMonthlyCapController.text = _formatHoursInput(
      snapshot.profile.workRules.overtimeMonthlyCapMinutes,
    );
    _rulesFixedScheduleEnabled =
        snapshot.profile.workRules.fixedScheduleEnabled ||
        snapshot.profile.workRules.flexibleStartEnabled;
    _rulesFlexibleStartEnabled = snapshot.profile.workRules.flexibleStartEnabled;
    _rulesFlexibleStartWindowController.text = _formatHoursInput(
      snapshot.profile.workRules.flexibleStartWindowMinutes,
    );
    _rulesWalletEnabled = snapshot.profile.workRules.walletEnabled;
    _rulesWalletDailyExitController.text = _formatHoursInput(
      snapshot.profile.workRules.walletDailyExitEarlyMinutes,
    );
    _rulesWalletWeeklyExitController.text = _formatHoursInput(
      snapshot.profile.workRules.walletWeeklyExitEarlyMinutes,
    );
    _rulesImplicitCreditEnabled = snapshot.profile.workRules.implicitCreditEnabled;
    _rulesImplicitCreditDailyCapController.text = _formatHoursInput(
      snapshot.profile.workRules.implicitCreditDailyCapMinutes,
    );
    _rulesAdditionalPermissions = List<WorkPermissionRule>.from(
      snapshot.profile.workRules.additionalPermissions,
    );
    _rulesLeaveBanks = List<WorkPermissionRule>.from(
      snapshot.profile.workRules.leaveBanks,
    );
    for (final weekday in WeekdayKey.values) {
      final daySchedule = snapshot.profile.weekdaySchedule.forWeekday(weekday);
      _weekdayControllers[weekday]!.text = _formatHoursInput(
        daySchedule.targetMinutes,
      );
      _weekdayStartTimeControllers[weekday]!.text = daySchedule.startTime ?? '';
      _weekdayEndTimeControllers[weekday]!.text = daySchedule.endTime ?? '';
      _weekdayBreakControllers[weekday]!.text = _formatBreakInput(
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

  bool get _isCloudBackupEnabled =>
      widget.accountService != null && _accountSession != null;

  Future<void> _queueCloudBackup() async {
    if (!_isCloudBackupEnabled) {
      return;
    }

    if (_isSyncingCloudBackup) {
      _cloudBackupQueued = true;
      return;
    }

    setState(() {
      _isSyncingCloudBackup = true;
    });

    var rerunQueuedBackup = false;
    try {
      await widget.accountService!.backupToCloud();
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        await widget.accountService!.logout();
        if (mounted) {
          setState(() {
            _accountSession = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sessione cloud scaduta. Accedi di nuovo e riprova il backup.',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _humanizeError(error),
            ),
          ),
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
      _selectedSection = _HomeSection.profile;
      _accountAuthMode = _AccountAuthMode.register;
    });
  }

  Future<void> _showRecoveryCodeDialog({
    required String recoveryCode,
    required String title,
    required String description,
  }) async {
    if (!mounted || recoveryCode.trim().isEmpty) {
      return;
    }

    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 14),
              SelectableText(
                recoveryCode,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Conservalo: serve per recuperare la password.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Ho salvato il codice'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPasswordRecoveryFlow() async {
    if (widget.accountService == null || _isRecoveringAccountPassword) {
      return;
    }

    final emailController = TextEditingController(
      text: _accountEmailController.text.trim(),
    );
    final recoveryCodeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscurePassword = true;

    final payload =
        await showDialog<
          ({String email, String recoveryCode, String newPassword})
        >(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                return AlertDialog(
                  title: const Text('Recupera password'),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inserisci email, codice recupero e nuova password.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            final isValidEmail = RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(email);
                            return isValidEmail
                                ? null
                                : 'Inserisci un email valida.';
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: recoveryCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Codice recupero',
                            hintText: 'Es. ABCDE-FGHIJ',
                          ),
                          validator: (value) {
                            final code = value?.trim() ?? '';
                            return code.isEmpty
                                ? 'Inserisci il codice recupero.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Nuova password',
                            helperText: 'Almeno 8 caratteri',
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
                            return password.trim().length >= 8
                                ? null
                                : 'Minimo 8 caratteri.';
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

                        Navigator.of(dialogContext).pop((
                          email: emailController.text.trim(),
                          recoveryCode: recoveryCodeController.text.trim(),
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

    emailController.dispose();
    recoveryCodeController.dispose();
    newPasswordController.dispose();

    if (payload == null) {
      return;
    }

    setState(() {
      _isRecoveringAccountPassword = true;
    });

    try {
      final nextRecoveryCode = await widget.accountService!.recoverPassword(
        email: payload.email,
        recoveryCode: payload.recoveryCode,
        newPassword: payload.newPassword,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecoveringAccountPassword = false;
      });
      _accountEmailController.text = payload.email;
      _accountPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password aggiornata. Ora puoi accedere con la nuova password.',
          ),
        ),
      );
      await _showRecoveryCodeDialog(
        recoveryCode: nextRecoveryCode,
        title: 'Nuovo codice recupero',
        description:
            'Per sicurezza il codice recupero e stato rigenerato dopo il reset password.',
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
        _accountAuthMode = _AccountAuthMode.login;
      });
      _accountPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account creato. Da ora i dati vengono salvati anche nel cloud.',
          ),
        ),
      );
      if (session.recoveryCode != null && session.recoveryCode!.isNotEmpty) {
        await _showRecoveryCodeDialog(
          recoveryCode: session.recoveryCode!,
          title: 'Codice recupero account',
          description:
              'Tieni questo codice al sicuro. Ti serve per recuperare la password in futuro.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthenticatingAccount = false;
      });
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
      final restoreResult = await widget.accountService!.login(
        email: email,
        password: password,
      );
      final session = await widget.accountService!.loadSession();
      if (!mounted) {
        return;
      }

      setState(() {
        _accountSession = session;
        _isAuthenticatingAccount = false;
        _accountAuthMode = _AccountAuthMode.login;
      });
      _accountPasswordController.clear();

      if (restoreResult.bundle != null) {
        await widget.onAppearanceSettingsChanged(
          restoreResult.bundle!.appearanceSettings,
        );
        await _loadSnapshot(month: _selectedMonth, selectedDate: _selectedDate);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restoreResult.hasBackup
                ? 'Accesso completato. Backup cloud ripristinato su questo dispositivo.'
                : 'Accesso completato. Nessun backup cloud trovato per questo account.',
          ),
        ),
      );
      final sessionRecoveryCode = session?.recoveryCode?.trim();
      if (sessionRecoveryCode != null && sessionRecoveryCode.isNotEmpty) {
        await _showRecoveryCodeDialog(
          recoveryCode: sessionRecoveryCode,
          title: 'Codice recupero generato',
          description:
              'Il tuo account non aveva ancora un codice recupero: ora e stato creato.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthenticatingAccount = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _restoreCloudBackup() async {
    if (widget.accountService == null || _accountSession == null) {
      return;
    }

    setState(() {
      _isRestoringCloudBackup = true;
    });

    try {
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
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringCloudBackup = false;
      });
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

      setState(() {
        _isRestoringCloudBackup = false;
      });
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
        _accountAuthMode = _AccountAuthMode.login;
      });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _loadWorkdaySessionForDate(DateTime date) async {
    final isoDate = DashboardService.defaultEntryDateOf(date);
    final session = await widget.workdayStartStore.loadSession(isoDate);
    if (!mounted || !_isSameDay(_selectedDate, date)) {
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
      _ticketNotificationPollingInterval,
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
    _liveWorkedMinutesTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!mounted || _selectedSection != _HomeSection.day) {
          return;
        }
        setState(() {});
      },
    );
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
        latestAdminReplyCountByTicket[update.ticketId] =
            update.adminReplyCount;
      }
    }

    await widget.supportTicketStore.markAdminRepliesNotifiedBatch(
      adminReplyCountByTicketId: latestAdminReplyCountByTicket,
    );
    if (!mounted) {
      return;
    }

    var hasChanges = false;
    final nextTrackedTickets = _trackedTickets.map((ticket) {
      final latestAdminReplyCount = latestAdminReplyCountByTicket[ticket.id];
      if (latestAdminReplyCount == null ||
          latestAdminReplyCount <= ticket.lastNotifiedAdminReplyCount) {
        return ticket;
      }
      hasChanges = true;
      return ticket.copyWith(
        lastNotifiedAdminReplyCount: latestAdminReplyCount,
      );
    }).toList(growable: false);
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
      final newRepliesToNotify = <({
        String ticketId,
        String subject,
        int newReplies,
        int adminReplyCount,
      })>[];
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

      if (notifyAboutNewReplies &&
          newRepliesToNotify.isNotEmpty) {
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

      if (notifyAboutNewReplies &&
          newRepliesToNotify.isNotEmpty &&
          mounted) {
        final message = _buildTicketReplyNotificationMessage(
          newRepliesToNotify
              .map(
                (update) => (
                  subject: update.subject,
                  newReplies: update.newReplies,
                ),
              )
              .toList(growable: false),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        unawaited(_localNotificationService.notifyTicketReplies(message: message));
      }

      final currentSelectedTicketId = selectedTicketId;
      if (_selectedSection == _HomeSection.ticket &&
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

  Future<void> _recordWorkdayStartNow() async {
    if (!_isSameDay(_selectedDate, _todayDate)) {
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
    if (!_isSameDay(_selectedDate, _todayDate) ||
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
    if (!_isSameDay(_selectedDate, _todayDate) ||
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
    if (!_isSameDay(_selectedDate, _todayDate) ||
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
      _selectedSection = _HomeSection.workSettings;
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
      _selectedSection = _HomeSection.workSettings;
    });
  }

  void _handleOvertimeLimitExceededNotification(int exceededMinutes) {
    if (exceededMinutes <= 0 || !_isSameDay(_selectedDate, _todayDate)) {
      _lastOvertimeExceededNotificationKey = null;
      return;
    }

    final notificationKey =
        DashboardService.defaultEntryDateOf(_selectedDate);
    if (_lastOvertimeExceededNotificationKey == notificationKey) {
      return;
    }
    _lastOvertimeExceededNotificationKey = notificationKey;

    unawaited(
      _localNotificationService.notifyOvertimeLimitExceeded(
        message:
            'Sei oltre il limite di straordinario di ${_formatHoursInput(exceededMinutes)}.',
      ),
    );
  }

  void _openWorkQuickEntryForDate(
    DateTime date, {
    int? prefilledMinutes,
    String? note,
  }) {
    setState(() {
      _selectedSection = _HomeSection.quickEntry;
      _selectedEntryMode = _QuickEntryMode.work;
      _entryDateController.text = DashboardService.defaultEntryDateOf(date);
      _entryMinutesController.text = prefilledMinutes == null
          ? ''
          : _formatHoursInput(prefilledMinutes);
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
      _selectedSection = _HomeSection.quickEntry;
      _selectedEntryMode = _QuickEntryMode.leave;
      _selectedLeaveType = leaveType;
      _entryDateController.text = DashboardService.defaultEntryDateOf(date);
      _entryMinutesController.text = prefilledMinutes == null
          ? ''
          : _formatHoursInput(prefilledMinutes);
      _entryNoteController.text = note ?? '';
    });
  }

  Future<void> _openDayForDate(DateTime date) async {
    setState(() {
      _selectedSection = _HomeSection.day;
    });
    await _setSelectedDate(date, alignToPeriod: false);
  }

  Future<void> _shiftSelectedDay(int step) async {
    await _setSelectedDate(
      _selectedDate.add(Duration(days: step)),
      alignToPeriod: false,
    );
  }

  Future<void> _prepareTodayOverridePreset(_TodayOverridePreset preset) async {
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
    _scheduleOverrideTargetController.text = _formatHoursInput(
      preparedSchedule.targetMinutes,
    );
    _scheduleOverrideStartTimeController.text =
        preparedSchedule.startTime ?? '';
    _scheduleOverrideEndTimeController.text = preparedSchedule.endTime ?? '';
    _scheduleOverrideBreakController.text = _formatBreakInput(
      preparedSchedule.breakMinutes,
    );
    setState(() {
      _selectedSection = _HomeSection.day;
    });
  }

  Future<void> _removeTodayOverride() async {
    await _setSelectedDate(_todayDate);
    await _removeScheduleOverride();
  }

  DaySchedule _buildPresetSchedule(
    _TodayOverridePreset preset,
    DaySchedule baseSchedule,
  ) {
    final startMinutes = parseTimeInput(baseSchedule.startTime);
    final endMinutes = parseTimeInput(baseSchedule.endTime);

    switch (preset) {
      case _TodayOverridePreset.startLater:
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
      case _TodayOverridePreset.finishEarlier:
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
      case _TodayOverridePreset.longerBreak:
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
      case _TodayOverridePreset.dayOff:
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
      final snapshot = _selectedEntryMode == _QuickEntryMode.work
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

      final successMessage = _selectedEntryMode == _QuickEntryMode.work
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

      final draftValidation = _validateScheduleDraft(
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

  Future<void> _pickScheduleOverrideTime(_CalendarTimeField field) async {
    final initialMinutes = _currentScheduleOverrideTimeMinutes(field);
    final controller = _scheduleTimeController(field);
    final pickedSelection = await _showScheduleTimeWheelPicker(
      title: switch (field) {
        _CalendarTimeField.start => 'Entrata',
        _CalendarTimeField.end => 'Uscita',
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
    if (field == _CalendarTimeField.start) {
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
    required _CalendarTimeField field,
    required int pickedMinutes,
  }) {
    final currentSchedule = _displayedScheduleStateForSelectedDate().schedule;
    final minimumBreakMinutes =
        _snapshot?.profile.workRules.minimumBreakMinutes;
    final previewSchedule = _buildFlexibleDayScheduleInput(
      targetText: _scheduleOverrideTargetController.text,
      startTimeText: field == _CalendarTimeField.start
          ? formatTimeInput(pickedMinutes)
          : _scheduleOverrideStartTimeController.text,
      endTimeText: field == _CalendarTimeField.end
          ? formatTimeInput(pickedMinutes)
          : _scheduleOverrideEndTimeController.text,
      breakText: _scheduleOverrideBreakController.text,
      fallbackSchedule: currentSchedule,
    );
    final workedMinutes = previewSchedule == null
        ? null
        : _resolveComputedWorkedMinutes(
            schedule: previewSchedule,
            minimumBreakMinutes: minimumBreakMinutes ?? 0,
          );
    return workedMinutes == null
        ? 'Ore di lavoro: --'
        : 'Ore di lavoro: ${_formatHoursInput(workedMinutes)}';
  }

  Future<void> _pickScheduleOverrideBreakMinutes() async {
    final currentBreakMinutes =
        _displayedScheduleStateForSelectedDate().schedule.breakMinutes;
    final weekday = _weekdayKeyForDate(_selectedDate);
    final pickedMinutes = await _showScheduleBreakWheelPicker(
      initialMinutes: currentBreakMinutes,
      standardScheduleLinkLabel:
          'Vai a Orario di lavoro (${weekday.label})',
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
      standardScheduleLinkLabel:
          'Vai a Orario di lavoro (${weekday.label})',
      onOpenStandardScheduleLink: _openSelectedWeekdayStandardWorkSettings,
    );
    if (pickedMinutes == null) {
      return;
    }

    _seedScheduleOverrideDraftFromCurrentDisplay();
    _scheduleOverrideTargetController.text = _formatHoursInput(pickedMinutes);
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
    _scheduleOverrideEndTimeController.text = formatTimeInput(clampedExitMinutes);
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

    _uniformDailyTargetController.text = _formatHoursInput(pickedMinutes);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickUniformScheduleTime(_CalendarTimeField field) async {
    final controller = switch (field) {
      _CalendarTimeField.start => _uniformStartTimeController,
      _CalendarTimeField.end => _uniformEndTimeController,
    };
    final initialMinutes =
        parseTimeInput(controller.text) ??
        (field == _CalendarTimeField.start ? 9 * 60 : 18 * 60);
    final pickedSelection = await _showScheduleTimeWheelPicker(
      title: field == _CalendarTimeField.start ? 'Entrata' : 'Uscita',
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

    _uniformBreakController.text = _formatBreakInput(pickedMinutes);
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

    controller.text = _formatHoursInput(pickedMinutes);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickWeekdayScheduleTime(
    WeekdayKey weekday,
    _CalendarTimeField field,
  ) async {
    final controller = switch (field) {
      _CalendarTimeField.start => _weekdayStartTimeControllers[weekday]!,
      _CalendarTimeField.end => _weekdayEndTimeControllers[weekday]!,
    };
    final initialMinutes =
        parseTimeInput(controller.text) ??
        (field == _CalendarTimeField.start ? 9 * 60 : 18 * 60);
    final pickedSelection = await _showScheduleTimeWheelPicker(
      title:
          '${field == _CalendarTimeField.start ? 'Entrata' : 'Uscita'} ${weekday.label.toLowerCase()}',
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

    controller.text = _formatBreakInput(pickedMinutes);
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
      targetController.text = _formatHoursInput(0);
      startController.clear();
      endController.clear();
      breakController.clear();
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final currentTargetMinutes =
        _resolveDraftTargetMinutes(
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
      targetController.text = _formatHoursInput(fallbackTargetMinutes);
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
      breakController.text = _formatBreakInput(_defaultLunchBreakMinutes());
    } else if (!enabled) {
      breakController.text = _formatBreakInput(0);
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

    _rulesMinimumBreakController.text = _formatBreakInput(pickedMinutes);
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

    controller.text = _formatHoursInput(pickedMinutes);
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
  }) async {
    final nameController = TextEditingController();
    final allowanceController = TextEditingController(text: _formatHoursInput(0));
    final usedController = TextEditingController(text: _formatHoursInput(0));
    var selectedPeriod = WorkAllowancePeriod.monthly;
    final selectedMovements = <WorkPermissionMovement>{
      WorkPermissionMovement.entryLate,
      WorkPermissionMovement.exitEarly,
    };
    var enabled = true;

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
                      children: WorkPermissionMovement.values.map((movement) {
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
                      }).toList(growable: false),
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
                    final allowanceMinutes = parseHoursInput(
                      allowanceController.text,
                    );
                    final usedMinutes = parseHoursInput(usedController.text);
                    if (name.isEmpty ||
                        allowanceMinutes == null ||
                        usedMinutes == null ||
                        selectedMovements.isEmpty) {
                      return;
                    }

                    Navigator.of(context).pop(
                      WorkPermissionRule(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        name: name,
                        enabled: enabled,
                        period: selectedPeriod,
                        allowanceMinutes: allowanceMinutes,
                        usedMinutes: usedMinutes,
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

    nameController.dispose();
    allowanceController.dispose();
    usedController.dispose();
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

    controller.text = _formatHoursInput(pickedMinutes);
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

    final resolvedTargetMinutes = _resolveDraftTargetMinutes(
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
    _scheduleOverrideBreakController.text = _formatBreakInput(
      normalizedMinutes,
    );
    _syncScheduleOverrideEndFromTarget(
      markPendingConfirmation: widget.appearanceSettings.showDayEndTime,
    );
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
      builder: (context) => _WheelPickerBottomSheet<DateTime>(
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
      builder: (context) => _WheelPickerBottomSheet<int>(
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
        return _WheelPickerBottomSheet<int>(
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
                _formatHoursInput(value),
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
      return _formatHoursInput(value);
    }

    final pickedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _WheelPickerBottomSheet<int>(
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
    _scheduleOverrideTargetController.text = _formatHoursInput(0);
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

  TextEditingController _scheduleTimeController(_CalendarTimeField field) {
    return switch (field) {
      _CalendarTimeField.start => _scheduleOverrideStartTimeController,
      _CalendarTimeField.end => _scheduleOverrideEndTimeController,
    };
  }

  int _currentScheduleOverrideTimeMinutes(_CalendarTimeField field) {
    final fallbackSchedule = _displayedScheduleStateForSelectedDate().schedule;
    final fallbackMinutes = switch (field) {
      _CalendarTimeField.start => parseTimeInput(fallbackSchedule.startTime),
      _CalendarTimeField.end => parseTimeInput(fallbackSchedule.endTime),
    };
    if (fallbackMinutes != null) {
      return fallbackMinutes;
    }

    if (field == _CalendarTimeField.start) {
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

  void _setSelectedDayPauseWindowDraft(_CalendarPauseWindow? pauseWindow) {
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

  bool _samePauseWindow(
    _CalendarPauseWindow? left,
    _CalendarPauseWindow? right,
  ) {
    return left?.pauseStartMinutes == right?.pauseStartMinutes &&
        left?.resumeMinutes == right?.resumeMinutes;
  }

  bool _sameScheduleOverrideDraftState(
    _ScheduleOverrideDraftState left,
    _ScheduleOverrideDraftState right,
  ) {
    return _sameDaySchedule(left.schedule, right.schedule) &&
        _samePauseWindow(left.pauseWindow, right.pauseWindow);
  }

  _ScheduleOverrideDraftState _currentScheduleOverrideDraftState({
    DaySchedule? fallbackSchedule,
  }) {
    final effectiveFallback =
        fallbackSchedule ?? _fallbackScheduleForSelectedDate();
    return _ScheduleOverrideDraftState(
      schedule: _resolveCurrentScheduleDraft(effectiveFallback),
      pauseWindow: _selectedDayPauseWindowDraft(),
    );
  }

  void _resetScheduleOverrideHistoryForDate(
    DateTime date, {
    required DaySchedule schedule,
    _CalendarPauseWindow? pauseWindow,
  }) {
    _scheduleOverrideHistoryDateKey = _scheduleOverrideHistoryDateKeyFor(date);
    _scheduleOverrideHistory = [
      _ScheduleOverrideDraftState(schedule: schedule, pauseWindow: pauseWindow),
    ];
    _scheduleOverrideHistoryIndex = 0;
  }

  void _primeScheduleOverrideHistoryFromCurrentDisplay() {
    final displayedState = _displayedScheduleStateForSelectedDate();
    final historyEntry = _ScheduleOverrideDraftState(
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

  ({DaySchedule schedule, _CalendarPauseWindow? pauseWindow})
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
    final effectiveSession = _isSameDay(_selectedDate, _todayDate)
        ? (session ?? _workdaySession)
        : null;
    final displayedSchedule = _resolveDisplayedDayScheduleForSession(
      draftSchedule,
      baseSchedule,
      effectiveSession,
      _selectedDate,
    );
    final pauseWindow = _resolveCalendarPauseWindow(
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

  _CalendarPauseWindow? _agendaPreviewPauseWindow() {
    final pauseStartMinutes = _agendaPreviewPauseStartMinutes;
    final pauseEndMinutes = _agendaPreviewPauseEndMinutes;
    if (pauseStartMinutes == null ||
        pauseEndMinutes == null ||
        pauseEndMinutes <= pauseStartMinutes) {
      return null;
    }

    return _CalendarPauseWindow(
      pauseStartMinutes: pauseStartMinutes,
      resumeMinutes: pauseEndMinutes,
    );
  }

  _CalendarPauseWindow? _selectedDayPauseWindowDraft() {
    final pauseStartMinutes = _selectedDayPauseStartMinutes;
    final pauseEndMinutes = _selectedDayPauseEndMinutes;
    if (pauseStartMinutes == null ||
        pauseEndMinutes == null ||
        pauseEndMinutes <= pauseStartMinutes) {
      return null;
    }

    return _CalendarPauseWindow(
      pauseStartMinutes: pauseStartMinutes,
      resumeMinutes: pauseEndMinutes,
    );
  }

  void _applyDayScheduleDraft(
    DaySchedule schedule, {
    _CalendarPauseWindow? pauseWindow,
  }) {
    _clearPendingExitConfirmationForSelectedDate();
    _scheduleOverrideTargetController.text = _formatHoursInput(
      schedule.targetMinutes,
    );
    _scheduleOverrideStartTimeController.text = schedule.startTime ?? '';
    _scheduleOverrideEndTimeController.text = schedule.endTime ?? '';
    _scheduleOverrideBreakController.text = _formatBreakInput(
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
      _CalendarPauseWindow(
        pauseStartMinutes: clampedPauseStartMinutes,
        resumeMinutes: clampedPauseStartMinutes + breakMinutes,
      ),
    );
  }

  _CalendarPauseWindow? _resolveSelectedDayPauseWindow({
    required DaySchedule schedule,
    WorkdaySession? session,
  }) {
    final draftPauseWindow = _selectedDayPauseWindowDraft();
    if (draftPauseWindow != null) {
      return draftPauseWindow;
    }

    return _resolveCalendarPauseWindow(
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
    if (!_isSameDay(selectedDate, _todayDate) || session == null) {
      return schedule;
    }

    final explicitStartMinutes = parseTimeInput(schedule.startTime);
    final explicitEndMinutes = parseTimeInput(schedule.endTime);
    final baseStartMinutes = parseTimeInput(baseSchedule.startTime);
    final baseEndMinutes = parseTimeInput(baseSchedule.endTime);
    final currentBreakMinutes = _currentSessionBreakMinutes(
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
      _scheduleOverrideBreakController.text = _formatBreakInput(
        breakMinutes.clamp(0, normalizedEnd - normalizedStart),
      );
    }
    _setSelectedDayPauseWindowDraft(
      pauseStartMinutes != null &&
              pauseEndMinutes != null &&
              pauseEndMinutes > pauseStartMinutes
          ? _CalendarPauseWindow(
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

  _DayMetrics _withDisplayedDaySchedule(
    _DayMetrics metrics,
    DaySchedule displayedSchedule,
  ) {
    return _DayMetrics(
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
          content: Text(
            'Download aggiornamento in background gia in corso.',
          ),
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
    final result = await showDialog<_UpdateDownloadDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDownloadDialog(
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

    if (result == _UpdateDownloadDialogAction.downloadInBackground) {
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

  void _handleBackgroundUpdateDownloadProgress(UpdateDownloadProgress progress) {
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

    final result = await widget.appUpdateService.installUpdate(downloadedUpdate);
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
          const SnackBar(
            content: Text('Impossibile avviare l installazione.'),
          ),
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
    final isValid = _ticketFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isSubmittingTicket = true;
      _errorMessage = null;
    });

    try {
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
        _selectedSection = _HomeSection.ticket;
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
    }
  }

  Future<void> _pickTicketAttachments() async {
    if (_isSubmittingTicket) {
      return;
    }

    final remainingSlots = _maxTicketAttachments - _ticketAttachments.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puoi allegare al massimo 3 screenshot per ticket.'),
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
        if (nextAttachments.length >= _maxTicketAttachments) {
          skippedCount += 1;
          continue;
        }

        final fileName = selectedImage.name;
        final contentType = _ticketAttachmentContentTypeForFileName(fileName);
        final bytes = await selectedImage.readAsBytes();
        if (contentType == null ||
            bytes.isEmpty ||
            bytes.lengthInBytes > _maxTicketAttachmentBytes) {
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
    return null;
  }

  void _applyPresetMinutes(int minutes) {
    _entryMinutesController.text = minutes.toString();
  }

  Future<void> _changeCalendarView(_CalendarView view) async {
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
      _CalendarView.day => _selectedDate.add(Duration(days: step)),
      _CalendarView.week => _selectedDate.add(Duration(days: step * 7)),
      _CalendarView.month => DateTime(
        _selectedDate.year,
        _selectedDate.month + step,
        1,
      ),
      _CalendarView.year => DateTime(
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
      _CalendarView.month when alignToPeriod => DateTime(
        normalizedDate.year,
        normalizedDate.month,
        1,
      ),
      _CalendarView.year when alignToPeriod => DateTime(
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
      _isSameDay(selectedDate, _todayDate) ? _workdaySession : null,
      selectedDate,
    );
    final displayedPauseWindow = _resolveCalendarPauseWindow(
      schedule: displayedSchedule,
      startMinutes: parseTimeInput(displayedSchedule.startTime),
      endMinutes: parseTimeInput(displayedSchedule.endTime),
      session: _isSameDay(selectedDate, _todayDate) ? _workdaySession : null,
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

    final targetMinutes = _resolveDraftTargetMinutes(
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
      _formatHoursInput(targetMinutes),
    );
    assignIfMatches(
      targetText,
      _scheduleOverrideTargetController,
      _formatHoursInput(targetMinutes),
    );
    for (final controller in _weekdayControllers.values) {
      assignIfMatches(targetText, controller, _formatHoursInput(targetMinutes));
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
      _formatBreakInput(breakMinutes),
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
      _formatBreakInput(breakMinutes),
    );
    for (final controller in _weekdayStartTimeControllers.values) {
      assignIfMatches(startTimeText, controller, normalizedStart);
    }
    for (final controller in _weekdayEndTimeControllers.values) {
      assignIfMatches(endTimeText, controller, normalizedEnd);
    }
    for (final controller in _weekdayBreakControllers.values) {
      assignIfMatches(breakText, controller, _formatBreakInput(breakMinutes));
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
      case _CalendarView.day:
      case _CalendarView.month:
        return [DashboardService.formatMonth(_selectedDate)];
      case _CalendarView.week:
        return _monthsBetweenDates(
          _firstDayOfWeek(_selectedDate),
          _lastDayOfWeek(_selectedDate),
        );
      case _CalendarView.year:
        return List.generate(
          12,
          (index) =>
              '${_selectedDate.year}-${(index + 1).toString().padLeft(2, '0')}',
        );
    }
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

  _DayMetrics _buildDayMetrics(DateTime date) {
    final month = DashboardService.formatMonth(date);
    final snapshot = _snapshotForMonth(month);
    if (snapshot == null) {
      return _DayMetrics.empty(date);
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

    return _DayMetrics(
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

  List<_DayMetrics> _buildWeekMetrics() {
    final firstDay = _firstDayOfWeek(_selectedDate);
    return List.generate(
      7,
      (index) => _buildDayMetrics(firstDay.add(Duration(days: index))),
      growable: false,
    );
  }

  List<_MonthMetrics> _buildYearMetrics() {
    return List.generate(12, (index) {
      final month =
          '${_selectedDate.year}-${(index + 1).toString().padLeft(2, '0')}';
      final snapshot = _snapshotForMonth(month);
      if (snapshot == null) {
        return _MonthMetrics.empty(month);
      }

      return _MonthMetrics(
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

  String _calendarPeriodLabelFor(_CalendarView view) {
    switch (view) {
      case _CalendarView.day:
        return _formatLongDate(_selectedDate);
      case _CalendarView.week:
        final firstDay = _firstDayOfWeek(_selectedDate);
        final lastDay = _lastDayOfWeek(_selectedDate);
        return '${_formatCompactDate(firstDay)} - ${_formatCompactDate(lastDay)}';
      case _CalendarView.month:
        return _formatMonthLabel(_selectedMonth);
      case _CalendarView.year:
        return '${_selectedDate.year}';
    }
  }

  String _calendarPeriodLabel() => _calendarPeriodLabelFor(_calendarView);

  DateTime _resolveSelectedDateForMonth(
    String month, {
    DateTime? preferredDate,
  }) {
    final monthDate = _monthToDate(month);
    final candidateDate = preferredDate;
    if (candidateDate != null && _isSameMonth(candidateDate, monthDate)) {
      return DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
      );
    }

    if (_snapshot != null && _isSameMonth(_selectedDate, monthDate)) {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
    }

    final today = DateTime.now();
    if (_isSameMonth(today, monthDate)) {
      return DateTime(today.year, today.month, today.day);
    }

    return DateTime(monthDate.year, monthDate.month, 1);
  }

  List<_CalendarDay> _buildCalendarDays(DashboardSnapshot snapshot) {
    final monthDate = _monthToDate(snapshot.summary.month);
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

    final days = <_CalendarDay>[];
    for (var index = 1; index < firstDayOfMonth.weekday; index += 1) {
      days.add(const _CalendarDay.empty());
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
      final relation = switch (_compareDateToToday(date)) {
        0 => _CalendarDayRelation.today,
        < 0 => _CalendarDayRelation.past,
        _ => _CalendarDayRelation.future,
      };
      final workedMinutes = workMinutesByDate[isoDate] ?? 0;
      final leaveMinutes = leaveMinutesByDate[isoDate] ?? 0;
      final todayStatusLabel = relation == _CalendarDayRelation.today
          ? _workdaySessionStatusLabel(
              _resolveWorkdaySessionStatus(_workdaySession),
            )
          : null;
      days.add(
        _CalendarDay(
          date: date,
          isoDate: isoDate,
          expectedMinutes: effectiveSchedule.targetMinutes,
          workedMinutes: workedMinutes,
          leaveMinutes: leaveMinutes,
          hasOverride: hasOverride,
          isToday: _isSameDay(date, today),
          isSelected: _isSameDay(date, _selectedDate),
          relation: relation,
          primaryLabel: _buildCalendarDayPrimaryLabel(
            relation: relation,
            schedule: displayedSchedule,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            hasOverride: hasOverride,
          ),
          secondaryLabel: _buildCalendarDaySecondaryLabel(
            relation: relation,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            hasOverride: hasOverride,
            todayStatusLabel: todayStatusLabel,
          ),
          details: _buildCalendarDayDetails(
            relation: relation,
            schedule: displayedSchedule,
            workedMinutes: workedMinutes,
            leaveMinutes: leaveMinutes,
            session: relation == _CalendarDayRelation.today
                ? _workdaySession
                : null,
          ),
        ),
      );
    }

    while (days.length % 7 != 0) {
      days.add(const _CalendarDay.empty());
    }

    return days;
  }

  List<_ActivityItem> _buildActivitiesForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  ) {
    final selectedIsoDate = DashboardService.defaultEntryDateOf(date);
    return _buildActivities(
      snapshot,
    ).where((item) => item.date == selectedIsoDate).toList(growable: false);
  }

  _TodayStatus _resolveDayStatus(DateTime date, _DayMetrics metrics) {
    final registeredMinutes = metrics.workedMinutes + metrics.leaveMinutes;
    if (metrics.expectedMinutes == 0 && registeredMinutes == 0) {
      return _TodayStatus.dayOff;
    }
    if (metrics.leaveMinutes >= metrics.expectedMinutes &&
        metrics.expectedMinutes > 0) {
      return _TodayStatus.absent;
    }
    if (registeredMinutes >= metrics.expectedMinutes &&
        metrics.expectedMinutes > 0) {
      return _TodayStatus.completed;
    }

    final now = DateTime.now();
    final currentMinutesOfDay = (now.hour * 60) + now.minute;
    final scheduledStart = parseTimeInput(metrics.schedule.startTime);
    final scheduledEnd = parseTimeInput(metrics.schedule.endTime);

    if (date.isAfter(_todayDate)) {
      return _TodayStatus.planned;
    }

    if (date.isBefore(_todayDate)) {
      return registeredMinutes == 0
          ? _TodayStatus.needsAttention
          : _TodayStatus.inProgress;
    }

    if (registeredMinutes == 0) {
      if (scheduledStart != null && currentMinutesOfDay < scheduledStart) {
        return _TodayStatus.planned;
      }
      return _TodayStatus.needsAttention;
    }

    if (scheduledEnd != null && currentMinutesOfDay >= scheduledEnd + 15) {
      return _TodayStatus.needsAttention;
    }

    return _TodayStatus.inProgress;
  }

  _TodayStatus _resolveTodayStatus(_DayMetrics metrics) {
    return _resolveDayStatus(_todayDate, metrics);
  }

  List<({IconData icon, String title, String description})>
  _buildTodayReminders(DashboardSnapshot snapshot, _DayMetrics metrics) {
    final reminders = <({IconData icon, String title, String description})>[];
    final todayStatus = _resolveTodayStatus(metrics);
    final now = DateTime.now();
    final currentMinutesOfDay = (now.hour * 60) + now.minute;
    final scheduledStart = parseTimeInput(metrics.schedule.startTime);
    final scheduledEnd = parseTimeInput(metrics.schedule.endTime);

    if (todayStatus == _TodayStatus.needsAttention &&
        scheduledStart != null &&
        currentMinutesOfDay >= scheduledStart) {
      reminders.add((
        icon: Icons.play_circle_outline,
        title: 'Giornata da avviare o chiudere',
        description:
            'Oggi risulti ancora incompleto. Registra le ore mancanti oppure chiudi la giornata.',
      ));
    }

    if (todayStatus == _TodayStatus.inProgress &&
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
        (_isSameMonth(tomorrow, _monthToDate(snapshot.summary.month))
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

  List<_WeekPlanDay> _buildUpcomingWeekPlan() {
    return List.generate(7, (index) {
      final date = _todayDate.add(Duration(days: index));
      final month = DashboardService.formatMonth(date);
      final monthSnapshot = _snapshotForMonth(month);
      if (monthSnapshot == null) {
        return _WeekPlanDay.empty(date);
      }

      final metrics = _buildDayMetrics(date);
      final override = _findScheduleOverrideForDate(monthSnapshot, date);
      return _WeekPlanDay(
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
    if (_selectedEntryMode == _QuickEntryMode.work) {
      return const [240, 360, 420, 480];
    }

    return const [60, 120, 240, 480];
  }

  List<_ActivityItem> _buildActivities(DashboardSnapshot snapshot) {
    final workItems = snapshot.workEntries.map(
      (entry) => _ActivityItem(
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
      (entry) => _ActivityItem(
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
    required _CalendarView calendarView,
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
      session: _isSameDay(_selectedDate, _todayDate) ? _workdaySession : null,
    );
    final dayMetrics = _withDisplayedDaySchedule(
      baseDayMetrics,
      displayedDaySchedule,
    );
    final pendingExitConfirmationMinutes = _pendingExitConfirmationForSelectedDate;

    return _CalendarCard(
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
      monthMetrics: _MonthMetrics(
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
      isSelectedDateToday: _isSameDay(_selectedDate, _todayDate),
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
      case _HomeSection.day:
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
            calendarView: _CalendarView.day,
            periodLabel: _formatLongDate(_selectedDate),
            showViewSelector: false,
            onPreviousPeriod: () => _shiftSelectedDay(-1),
            onNextPeriod: () => _shiftSelectedDay(1),
          ),
        );
      case _HomeSection.overview:
        final today = _todayDate;
        final todaySnapshot =
            _snapshotForMonth(DashboardService.formatMonth(today)) ?? snapshot;
        final todayMetrics = _buildDayMetrics(today);
        final todayStatus = _resolveTodayStatus(todayMetrics);
        return _OverviewCard(
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
      case _HomeSection.quickEntry:
        return _QuickEntryCard(
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
      case _HomeSection.calendar:
        return _buildPlannerSectionCard(
          snapshot: snapshot,
          title: 'Calendario',
          calendarView: _calendarView,
          periodLabel: _calendarPeriodLabel(),
          showViewSelector: true,
          onPreviousPeriod: () => _shiftCalendarPeriod(-1),
          onNextPeriod: () => _shiftCalendarPeriod(1),
        );
      case _HomeSection.recentActivity:
        return _RecentActivityCard(
          weekPlan: _buildUpcomingWeekPlan(),
          onOpenDay: _openDayForDate,
          onOpenWorkEntry: _openWorkQuickEntryForDate,
          onOpenLeaveEntry: _openLeaveQuickEntryForDate,
        );
      case _HomeSection.workSettings:
        return _WorkSettingsCard(
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
          rulesOvertimeDailyCapController: _rulesOvertimeDailyCapController,
          rulesOvertimeWeeklyCapController: _rulesOvertimeWeeklyCapController,
          rulesOvertimeMonthlyCapController: _rulesOvertimeMonthlyCapController,
          rulesFlexibleStartWindowController: _rulesFlexibleStartWindowController,
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
      case _HomeSection.profile:
        return _ProfileCard(
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
          isRestoringCloudBackup: _isRestoringCloudBackup,
          isSyncingCloudBackup: _isSyncingCloudBackup,
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
          onBackupNow: _queueCloudBackup,
          onRestoreCloudBackup: _restoreCloudBackup,
          onLogoutAccount: _logoutAccount,
          onReload: _reloadProfileDraft,
          onSubmit: _submitProfile,
        );
      case _HomeSection.ticket:
        return _SupportTicketCard(
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
          trackedTickets: _trackedTickets,
          ticketThreadsById: _ticketThreadsById,
          selectedTicketId: _selectedTrackedTicketId,
          isSubmitting: _isSubmittingTicket,
          isLoadingThreads: _isLoadingTicketThreads,
          isSubmittingReply: _isSubmittingTicketReply,
          isRecoveringTicket: _isRecoveringTrackedTicket,
          unreadReplyCount: _unreadTicketReplyCount,
          onSelectTicket: _selectTrackedSupportTicket,
          onRefreshThreads: _refreshTrackedSupportTickets,
          onRecoverTicketById: _recoverTrackedSupportTicketById,
          onPickAttachments: _pickTicketAttachments,
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
                _Header(
                  selectedSection: _selectedSection,
                  hasCloudAccount: _accountSession != null,
                  unreadTicketReplyCount: _unreadTicketReplyCount,
                  onSelectSection: (section) {
                    setState(() {
                      _selectedSection = section;
                      if (section == _HomeSection.calendar &&
                          _calendarView == _CalendarView.day) {
                        _calendarView = _CalendarView.month;
                      }
                    });
                    if (section == _HomeSection.ticket) {
                      unawaited(_refreshTrackedSupportTickets());
                      final selectedTicketId = _selectedTrackedTicketId;
                      if (selectedTicketId != null) {
                        unawaited(
                          _markTrackedTicketRepliesSeen(selectedTicketId),
                        );
                      }
                    }
                  },
                  onOpenRegistration: _openAccountRegistrationFlow,
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  _ErrorCard(message: _errorMessage!, onRetry: _refreshAll),
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

class _QuickEntryCard extends StatelessWidget {
  const _QuickEntryCard({
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
  final _QuickEntryMode selectedEntryMode;
  final ValueChanged<_QuickEntryMode> onEntryModeChanged;
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
    final isWorkMode = selectedEntryMode == _QuickEntryMode.work;

    return _SectionCard(
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
                      : (_) => onEntryModeChanged(_QuickEntryMode.work),
                ),
                ChoiceChip(
                  label: const Text('Ferie o permesso'),
                  selected: !isWorkMode,
                  onSelected: isBusy
                      ? null
                      : (_) => onEntryModeChanged(_QuickEntryMode.leave),
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
            _DateField(controller: dateController, onPickDate: onPickDate),
            const SizedBox(height: 14),
            _MinutesField(
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
                      label: Text(_formatHours(minutes)),
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

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.title,
    required this.showViewSelector,
    required this.calendarView,
    required this.periodLabel,
    required this.isLoadingCalendarData,
    required this.month,
    required this.selectedDate,
    required this.workRules,
    required this.days,
    required this.baseDaySchedule,
    required this.effectiveDaySchedule,
    required this.draftDaySchedule,
    required this.quickEditorDaySchedule,
    required this.quickEditorPauseWindow,
    required this.selectedDayPauseWindow,
    required this.overrideFormKey,
    required this.appearanceSettings,
    required this.overrideTargetController,
    required this.overrideStartTimeController,
    required this.overrideEndTimeController,
    required this.overrideBreakController,
    required this.pendingExitConfirmationMinutes,
    required this.dayMetrics,
    required this.weekMetrics,
    required this.monthMetrics,
    required this.yearMetrics,
    required this.onCalendarViewChanged,
    required this.onPreviousPeriod,
    required this.onNextPeriod,
    required this.onSelectDate,
    required this.onOpenDay,
    required this.isSelectedDateToday,
    required this.workdaySession,
    required this.isSavingWorkdaySession,
    required this.onRecordWorkdayStartNow,
    required this.onStartWorkdayBreakNow,
    required this.onResumeWorkdayNow,
    required this.onFinishWorkdayNow,
    required this.onClearWorkdaySession,
    required this.onPickOverrideTargetMinutes,
    required this.onPickOverrideTime,
    required this.onPickOverrideBreakMinutes,
    required this.onAgendaSchedulePreviewChanged,
    required this.onAgendaSchedulePreviewCleared,
    required this.onAgendaScheduleChanged,
    required this.onAgendaInteractionChanged,
    required this.onAppearanceSettingsChanged,
    required this.canUndoOverrideChanges,
    required this.canRedoOverrideChanges,
    required this.onUndoOverrideChange,
    required this.onRedoOverrideChange,
    required this.onMarkDayAsOff,
    required this.onRestoreWorkingDay,
    required this.onConfirmSuggestedExitMinutes,
    required this.onOpenWorkSettings,
    required this.onOvertimeLimitExceeded,
  });

  final String title;
  final bool showViewSelector;
  final _CalendarView calendarView;
  final String periodLabel;
  final bool isLoadingCalendarData;
  final String month;
  final DateTime selectedDate;
  final UserWorkRules workRules;
  final List<_CalendarDay> days;
  final DaySchedule baseDaySchedule;
  final DaySchedule effectiveDaySchedule;
  final DaySchedule draftDaySchedule;
  final DaySchedule quickEditorDaySchedule;
  final _CalendarPauseWindow? quickEditorPauseWindow;
  final _CalendarPauseWindow? selectedDayPauseWindow;
  final GlobalKey<FormState> overrideFormKey;
  final AppAppearanceSettings appearanceSettings;
  final TextEditingController overrideTargetController;
  final TextEditingController overrideStartTimeController;
  final TextEditingController overrideEndTimeController;
  final TextEditingController overrideBreakController;
  final int? pendingExitConfirmationMinutes;
  final _DayMetrics dayMetrics;
  final List<_DayMetrics> weekMetrics;
  final _MonthMetrics monthMetrics;
  final List<_MonthMetrics> yearMetrics;
  final Future<void> Function(_CalendarView view) onCalendarViewChanged;
  final Future<void> Function() onPreviousPeriod;
  final Future<void> Function() onNextPeriod;
  final ValueChanged<DateTime> onSelectDate;
  final Future<void> Function(DateTime date) onOpenDay;
  final bool isSelectedDateToday;
  final WorkdaySession? workdaySession;
  final bool isSavingWorkdaySession;
  final Future<void> Function() onRecordWorkdayStartNow;
  final Future<void> Function() onStartWorkdayBreakNow;
  final Future<void> Function() onResumeWorkdayNow;
  final Future<void> Function() onFinishWorkdayNow;
  final Future<void> Function() onClearWorkdaySession;
  final Future<void> Function() onPickOverrideTargetMinutes;
  final Future<void> Function(_CalendarTimeField field) onPickOverrideTime;
  final Future<void> Function() onPickOverrideBreakMinutes;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onAgendaSchedulePreviewChanged;
  final VoidCallback onAgendaSchedulePreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onAgendaScheduleChanged;
  final ValueChanged<bool> onAgendaInteractionChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;
  final bool canUndoOverrideChanges;
  final bool canRedoOverrideChanges;
  final Future<void> Function() onUndoOverrideChange;
  final Future<void> Function() onRedoOverrideChange;
  final VoidCallback onMarkDayAsOff;
  final Future<void> Function() onRestoreWorkingDay;
  final Future<void> Function(int exitMinutes) onConfirmSuggestedExitMinutes;
  final VoidCallback onOpenWorkSettings;
  final ValueChanged<int> onOvertimeLimitExceeded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveQuickEditorStartTime =
        quickEditorDaySchedule.startTime ?? overrideStartTimeController.text;
    final effectiveQuickEditorTargetText = _formatHoursInput(
      quickEditorDaySchedule.targetMinutes,
    );
    final effectiveQuickEditorEndTime =
        quickEditorDaySchedule.endTime ?? overrideEndTimeController.text;
    final effectiveQuickEditorBreakMinutes = (() {
      final quickPauseWindow = quickEditorPauseWindow;
      if (quickPauseWindow == null) {
        return quickEditorDaySchedule.breakMinutes;
      }
      return quickPauseWindow.resumeMinutes -
          quickPauseWindow.pauseStartMinutes;
    })();
    final liveExpectedMinutes = _resolveDisplayedExpectedMinutes(
      effectiveSchedule: effectiveDaySchedule,
      quickEditorSchedule: quickEditorDaySchedule,
    );
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final hasRecordedWorkContext =
        (isSelectedDateToday && workdaySession != null) ||
        dayMetrics.workedMinutes > 0 ||
        dayMetrics.leaveMinutes > 0;
    final hasQuickTimeWindow =
        (quickEditorDaySchedule.startTime?.trim().isNotEmpty ?? false) ||
        (quickEditorDaySchedule.endTime?.trim().isNotEmpty ?? false);
    final hasQuickWorkedOverride =
        hasQuickTimeWindow &&
        (quickEditorDaySchedule.startTime != baseDaySchedule.startTime ||
            quickEditorDaySchedule.endTime != baseDaySchedule.endTime);
    final isQuickEditorDayOff = _isExplicitDayOffSchedule(
      quickEditorDaySchedule,
    );
    final resolvedEndMinutesForToday =
        parseTimeInput(overrideEndTimeController.text.trim()) ??
        parseTimeInput(effectiveQuickEditorEndTime);
    final hasElapsedManualExit =
        !isQuickEditorDayOff &&
        isSelectedDateToday &&
        hasQuickWorkedOverride &&
        resolvedEndMinutesForToday != null &&
        resolvedEndMinutesForToday <= nowMinutes;
    final liveWorkedMinutes = isSelectedDateToday
        ? _resolveLiveWorkedMinutes(
            quickEditorSchedule: quickEditorDaySchedule,
            workRules: workRules,
            session: workdaySession,
            pauseWindow: quickEditorPauseWindow,
            nowMinutes: nowMinutes,
            rawStartTimeText: overrideStartTimeController.text,
            rawEndTimeText: overrideEndTimeController.text,
            treatEndAsActual: hasElapsedManualExit,
          )
        : _resolveDisplayedWorkedMinutes(
            quickEditorSchedule: quickEditorDaySchedule,
            workRules: workRules,
          );
    final resolvedStartMinutesForSuggestion =
        parseTimeInput(overrideStartTimeController.text.trim()) ??
        parseTimeInput(effectiveQuickEditorStartTime);
    final hasStartForSuggestion =
        !isQuickEditorDayOff && resolvedStartMinutesForSuggestion != null;
    final hasQuickResultContext =
        hasRecordedWorkContext || hasQuickWorkedOverride;
    final hasExitSuggestionContext =
        hasQuickResultContext || hasStartForSuggestion;
    final displayedWorkedMinutes = hasQuickResultContext
        ? liveWorkedMinutes
        : 0;
    final controlInsights = _buildQuickDayControlInsights(
      selectedDate: selectedDate,
      workRules: workRules,
      days: days,
      weekMetrics: weekMetrics,
      liveExpectedMinutes: liveExpectedMinutes,
      liveWorkedMinutes: displayedWorkedMinutes,
      liveLeaveMinutes: dayMetrics.leaveMinutes,
      hasLiveResultContext: hasQuickResultContext,
    );
    final liveDayBalanceMinutes = controlInsights.controlledBalanceMinutes;
    final monthBalanceInfo = _buildDisplayedMonthBalanceInfo(
      selectedDate: selectedDate,
      days: days,
      liveExpectedMinutes: liveExpectedMinutes,
      liveWorkedMinutes: displayedWorkedMinutes,
      liveLeaveMinutes: dayMetrics.leaveMinutes,
    );
    final periodBalanceInfo = _buildDisplayedPeriodBalanceInfo(
      selectedDate: selectedDate,
      days: days,
      weekMetrics: weekMetrics,
      aggregation: appearanceSettings.dayBalanceAggregation,
      liveExpectedMinutes: liveExpectedMinutes,
      liveWorkedMinutes: displayedWorkedMinutes,
      liveLeaveMinutes: dayMetrics.leaveMinutes,
    );
    if (isSelectedDateToday && controlInsights.exceededOvertimeMinutes > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onOvertimeLimitExceeded(controlInsights.exceededOvertimeMinutes);
      });
    } else if (isSelectedDateToday) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onOvertimeLimitExceeded(0);
      });
    }
    final suggestedExitLabel = _resolveSuggestedExitLabel(
      effectiveSchedule: effectiveDaySchedule,
      quickEditorSchedule: quickEditorDaySchedule,
      workRules: workRules,
      rawStartTimeText: overrideStartTimeController.text,
      rawEndTimeText: overrideEndTimeController.text,
    );
    final suggestedExitTotalMinutes = _resolveSuggestedExitTotalMinutes(
      effectiveSchedule: effectiveDaySchedule,
      quickEditorSchedule: quickEditorDaySchedule,
      workRules: workRules,
      rawStartTimeText: overrideStartTimeController.text,
    );
    final hasScheduledExit = effectiveQuickEditorEndTime.trim().isNotEmpty;
    final programmedExitMinutes = parseTimeInput(
      effectiveQuickEditorEndTime.trim(),
    );
    final remainingToProgrammedExitLabel =
        !isQuickEditorDayOff &&
            isSelectedDateToday &&
            hasQuickResultContext &&
            programmedExitMinutes != null
        ? (() {
            final remainingMinutes = programmedExitMinutes - nowMinutes;
            if (remainingMinutes > 0) {
              return 'Mancano ${_formatHoursInput(remainingMinutes)} all\'uscita programmata';
            }
            return 'Uscita programmata raggiunta';
          })()
        : null;
    final hasPendingExitConfirmation = pendingExitConfirmationMinutes != null;
    final hasSuggestedTheoreticalExit =
        !isQuickEditorDayOff &&
        !hasScheduledExit &&
        hasExitSuggestionContext &&
        suggestedExitLabel != '--:--' &&
        suggestedExitLabel != 'Libero';
    final hasTheoreticalExit =
        hasPendingExitConfirmation || hasSuggestedTheoreticalExit;
    final isUsingStandardSchedule = _matchesDaySchedule(
      baseDaySchedule,
      quickEditorDaySchedule,
    );
    final isUsingStandardWorkTarget =
        quickEditorDaySchedule.targetMinutes == baseDaySchedule.targetMinutes;
    final candidateConfirmableExitMinutes = hasPendingExitConfirmation
        ? pendingExitConfirmationMinutes
        : suggestedExitTotalMinutes;
    final confirmableTheoreticalExitMinutes =
        candidateConfirmableExitMinutes == null ||
            candidateConfirmableExitMinutes > ((23 * 60) + 59)
        ? null
        : candidateConfirmableExitMinutes;
    final canRestoreWorkingDay =
        isQuickEditorDayOff && !isUsingStandardSchedule;
    final selectedDayInfo = switch (_compareDateToToday(selectedDate)) {
      0 => (
        label: 'Oggi',
        icon: Icons.today_outlined,
        color: theme.colorScheme.primary,
      ),
      < 0 => (
        label: 'Passato',
        icon: Icons.history,
        color: theme.colorScheme.secondary,
      ),
      _ => (
        label: 'Futuro',
        icon: Icons.upcoming_outlined,
        color: theme.colorScheme.tertiary,
      ),
    };
    final showWorkdaySessionCard =
        appearanceSettings.showDayWorkdayCard && isSelectedDateToday;
    final workdaySessionSpacing = appearanceSettings.expandDayWorkdayCard
        ? 18.0
        : 8.0;
    final quickEditorSpacing = appearanceSettings.expandDayQuickEditor
        ? 18.0
        : 8.0;
    final quickEditor = Form(
      key: overrideFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarQuickScheduleEditor(
            isExpanded: appearanceSettings.expandDayQuickEditor,
            targetText: effectiveQuickEditorTargetText,
            startTimeText: effectiveQuickEditorStartTime,
            endTimeText: effectiveQuickEditorEndTime,
            suggestedExitLabel: suggestedExitLabel,
            hasExitSuggestionContext: hasExitSuggestionContext,
            breakMinutes: effectiveQuickEditorBreakMinutes,
            showEndTime: appearanceSettings.showDayEndTime,
            showBreakMinutes: appearanceSettings.showDayBreakMinutes,
            onPickTargetMinutes: onPickOverrideTargetMinutes,
            onPickStartTime: () => onPickOverrideTime(_CalendarTimeField.start),
            onPickEndTime: () => onPickOverrideTime(_CalendarTimeField.end),
            onPickBreakMinutes: onPickOverrideBreakMinutes,
            canUndoChanges: canUndoOverrideChanges,
            canRedoChanges: canRedoOverrideChanges,
            onUndoChange: onUndoOverrideChange,
            onRedoChange: onRedoOverrideChange,
            onToggleExpanded: (expanded) => unawaited(
              onAppearanceSettingsChanged(
                appearanceSettings.copyWith(expandDayQuickEditor: expanded),
              ),
            ),
            onMarkDayAsOff: onMarkDayAsOff,
            onRestoreWorkingDay: onRestoreWorkingDay,
            isDayOff: isQuickEditorDayOff,
            canRestoreWorkingDay: canRestoreWorkingDay,
            workedMinutes: displayedWorkedMinutes,
            todayBalanceMinutes: liveDayBalanceMinutes,
            overtimeMinutes: controlInsights.todayOvertimeMinutes,
            exceededOvertimeMinutes: controlInsights.exceededOvertimeMinutes,
            showOvertimeConfigurationHint:
                controlInsights.showConfigurationHint,
            overtimeConfigurationHint: controlInsights.configurationHint,
            limitWarningText: controlInsights.limitWarningText,
            monthBalanceInfo: monthBalanceInfo,
            periodBalanceInfo: periodBalanceInfo,
            dayBalanceAggregation: appearanceSettings.dayBalanceAggregation,
            onDayBalanceAggregationChanged: (aggregation) => unawaited(
              onAppearanceSettingsChanged(
                appearanceSettings.copyWith(dayBalanceAggregation: aggregation),
              ),
            ),
            remainingToProgrammedExitLabel: remainingToProgrammedExitLabel,
            hasResultContext: hasQuickResultContext,
            hasTheoreticalExit: hasTheoreticalExit,
            hasPendingExitConfirmation: hasPendingExitConfirmation,
            isUsingStandardWorkTarget: isUsingStandardWorkTarget,
            onOpenWorkSettings: onOpenWorkSettings,
            isEndTimeFinalized:
                effectiveQuickEditorEndTime.trim().isNotEmpty &&
                (!isSelectedDateToday ||
                    hasElapsedManualExit ||
                    (workdaySession?.isCompleted ?? false)),
            onConfirmTheoreticalExit: confirmableTheoreticalExitMinutes == null
                ? null
                : () => onConfirmSuggestedExitMinutes(
                    confirmableTheoreticalExitMinutes,
                  ),
          ),
        ],
      ),
    );
    final dayTimeline = _CalendarPeriodSummary(
      calendarView: calendarView,
      days: days,
      dayMetrics: dayMetrics,
      daySchedule: draftDaySchedule,
      dayPauseWindow: selectedDayPauseWindow,
      isDayScheduleProvisional:
          isSelectedDateToday &&
          workdaySession != null &&
          !workdaySession!.isCompleted,
      workdaySession: isSelectedDateToday ? workdaySession : null,
      weekMetrics: isSelectedDateToday
          ? weekMetrics
                .map((metric) {
                  if (!_isSameDay(metric.date, selectedDate)) {
                    return metric;
                  }

                  final rawLiveBalanceMinutes =
                      (displayedWorkedMinutes + metric.leaveMinutes) -
                      liveExpectedMinutes;
                  return _DayMetrics(
                    date: metric.date,
                    expectedMinutes: liveExpectedMinutes,
                    workedMinutes: displayedWorkedMinutes,
                    leaveMinutes: metric.leaveMinutes,
                    rawBalanceMinutes: rawLiveBalanceMinutes,
                    balanceMinutes: rawLiveBalanceMinutes,
                    hasOverride:
                        metric.hasOverride ||
                        hasQuickWorkedOverride ||
                        hasPendingExitConfirmation,
                    schedule: quickEditorDaySchedule,
                    overrideNote: metric.overrideNote,
                  );
                })
                .toList(growable: false)
          : weekMetrics,
      monthMetrics: monthMetrics,
      yearMetrics: yearMetrics,
      selectedDate: selectedDate,
      onSelectDate: onSelectDate,
      onOpenDay: onOpenDay,
      onCalendarViewChanged: onCalendarViewChanged,
      onDaySchedulePreviewChanged: onAgendaSchedulePreviewChanged,
      onDaySchedulePreviewCleared: onAgendaSchedulePreviewCleared,
      onDayScheduleChanged: onAgendaScheduleChanged,
      onAgendaInteractionChanged: onAgendaInteractionChanged,
      isDayAgendaExpanded: appearanceSettings.expandDayAgenda,
      onToggleDayAgendaExpanded: (expanded) => unawaited(
        onAppearanceSettingsChanged(
          appearanceSettings.copyWith(expandDayAgenda: expanded),
        ),
      ),
    );

    final trailing = calendarView == _CalendarView.day
        ? Row(
            children: [
              Expanded(
                child: _CalendarPeriodSwitcher(
                  periodLabel: periodLabel,
                  onPreviousPeriod: onPreviousPeriod,
                  onNextPeriod: onNextPeriod,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CalendarDateRelationBadge(
                    label: selectedDayInfo.label,
                    icon: selectedDayInfo.icon,
                    color: selectedDayInfo.color,
                  ),
                  if (isLoadingCalendarData) ...[
                    const SizedBox(height: 6),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ],
          )
        : Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CalendarPeriodSwitcher(
                periodLabel: periodLabel,
                onPreviousPeriod: onPreviousPeriod,
                onNextPeriod: onNextPeriod,
              ),
              if (isLoadingCalendarData)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          );
    final compactCalendarTabs = MediaQuery.of(context).size.width <= 430;

    return _SectionCard(
      title: title,
      trailing: trailing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showViewSelector)
            LayoutBuilder(
              builder: (context, constraints) {
                final selector = SegmentedButton<_CalendarView>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<_CalendarView>(
                      value: _CalendarView.week,
                      label: Text('Settimana'),
                      icon: compactCalendarTabs
                          ? null
                          : const Icon(Icons.view_week_outlined),
                    ),
                    ButtonSegment<_CalendarView>(
                      value: _CalendarView.month,
                      label: Text('Mese'),
                      icon: compactCalendarTabs
                          ? null
                          : const Icon(Icons.calendar_month_outlined),
                    ),
                    ButtonSegment<_CalendarView>(
                      value: _CalendarView.year,
                      label: Text('Anno'),
                      icon: compactCalendarTabs
                          ? null
                          : const Icon(Icons.calendar_view_month_outlined),
                    ),
                  ],
                  selected: {_calendarViewOrDefault(calendarView)},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    unawaited(onCalendarViewChanged(selection.first));
                  },
                );

                if (compactCalendarTabs) {
                  return SizedBox(width: constraints.maxWidth, child: selector);
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: selector,
                );
              },
            ),
          if (calendarView == _CalendarView.day && showWorkdaySessionCard) ...[
            SizedBox(height: workdaySessionSpacing),
            _WorkdaySessionCard(
              isExpanded: appearanceSettings.expandDayWorkdayCard,
              session: workdaySession,
              schedule: effectiveDaySchedule,
              pauseWindow: selectedDayPauseWindow,
              isBusy: isSavingWorkdaySession,
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(expandDayWorkdayCard: expanded),
                ),
              ),
              onRecordNow: onRecordWorkdayStartNow,
              onStartBreak: onStartWorkdayBreakNow,
              onResume: onResumeWorkdayNow,
              onFinish: onFinishWorkdayNow,
              onClear: workdaySession == null ? null : onClearWorkdaySession,
            ),
          ],
          if (calendarView == _CalendarView.day) ...[
            SizedBox(height: quickEditorSpacing),
            if (appearanceSettings.dayCalendarLayoutMode ==
                DayCalendarLayoutMode.quickEditorFirst)
              quickEditor
            else
              dayTimeline,
            SizedBox(height: quickEditorSpacing),
            if (appearanceSettings.dayCalendarLayoutMode ==
                DayCalendarLayoutMode.quickEditorFirst)
              dayTimeline
            else
              quickEditor,
          ],
          if (calendarView != _CalendarView.day) ...[
            const SizedBox(height: 18),
            dayTimeline,
          ],
        ],
      ),
    );
  }
}

class _CalendarPeriodSwitcher extends StatelessWidget {
  const _CalendarPeriodSwitcher({
    required this.periodLabel,
    required this.onPreviousPeriod,
    required this.onNextPeriod,
  });

  final String periodLabel;
  final VoidCallback onPreviousPeriod;
  final VoidCallback onNextPeriod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              key: const ValueKey('calendar-prev-month'),
              onPressed: onPreviousPeriod,
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  periodLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('calendar-next-month'),
              onPressed: onNextPeriod,
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDateRelationBadge extends StatelessWidget {
  const _CalendarDateRelationBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarQuickScheduleEditor extends StatelessWidget {
  const _CalendarQuickScheduleEditor({
    required this.isExpanded,
    required this.targetText,
    required this.startTimeText,
    required this.endTimeText,
    required this.suggestedExitLabel,
    required this.hasExitSuggestionContext,
    required this.breakMinutes,
    required this.showEndTime,
    required this.showBreakMinutes,
    required this.onPickTargetMinutes,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickBreakMinutes,
    required this.canUndoChanges,
    required this.canRedoChanges,
    required this.onUndoChange,
    required this.onRedoChange,
    required this.onToggleExpanded,
    required this.onMarkDayAsOff,
    required this.onRestoreWorkingDay,
    required this.isDayOff,
    required this.canRestoreWorkingDay,
    required this.workedMinutes,
    required this.todayBalanceMinutes,
    required this.overtimeMinutes,
    required this.exceededOvertimeMinutes,
    required this.showOvertimeConfigurationHint,
    required this.overtimeConfigurationHint,
    required this.limitWarningText,
    required this.monthBalanceInfo,
    required this.periodBalanceInfo,
    required this.dayBalanceAggregation,
    required this.onDayBalanceAggregationChanged,
    required this.onOpenWorkSettings,
    required this.remainingToProgrammedExitLabel,
    required this.hasResultContext,
    required this.hasTheoreticalExit,
    required this.hasPendingExitConfirmation,
    required this.isUsingStandardWorkTarget,
    required this.isEndTimeFinalized,
    this.onConfirmTheoreticalExit,
  });

  final bool isExpanded;
  final String targetText;
  final String startTimeText;
  final String endTimeText;
  final String suggestedExitLabel;
  final bool hasExitSuggestionContext;
  final int breakMinutes;
  final bool showEndTime;
  final bool showBreakMinutes;
  final Future<void> Function() onPickTargetMinutes;
  final Future<void> Function() onPickStartTime;
  final Future<void> Function() onPickEndTime;
  final Future<void> Function() onPickBreakMinutes;
  final bool canUndoChanges;
  final bool canRedoChanges;
  final Future<void> Function() onUndoChange;
  final Future<void> Function() onRedoChange;
  final ValueChanged<bool> onToggleExpanded;
  final VoidCallback onMarkDayAsOff;
  final Future<void> Function() onRestoreWorkingDay;
  final bool isDayOff;
  final bool canRestoreWorkingDay;
  final int workedMinutes;
  final int todayBalanceMinutes;
  final int overtimeMinutes;
  final int exceededOvertimeMinutes;
  final bool showOvertimeConfigurationHint;
  final String? overtimeConfigurationHint;
  final String? limitWarningText;
  final _DisplayedMonthBalanceInfo monthBalanceInfo;
  final _DisplayedPeriodBalanceInfo periodBalanceInfo;
  final DayBalanceAggregation dayBalanceAggregation;
  final ValueChanged<DayBalanceAggregation> onDayBalanceAggregationChanged;
  final VoidCallback onOpenWorkSettings;
  final String? remainingToProgrammedExitLabel;
  final bool hasResultContext;
  final bool hasTheoreticalExit;
  final bool hasPendingExitConfirmation;
  final bool isUsingStandardWorkTarget;
  final bool isEndTimeFinalized;
  final Future<void> Function()? onConfirmTheoreticalExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggleButtonSize = isExpanded ? 36.0 : 30.0;
    final toggleIconSize = isExpanded ? 20.0 : 18.0;
    final expandedIcon = isExpanded
        ? Icons.keyboard_arrow_up_rounded
        : Icons.keyboard_arrow_down_rounded;
    final isProgrammedExit =
        endTimeText.trim().isNotEmpty &&
        hasExitSuggestionContext &&
        !isEndTimeFinalized;
    final standardScheduleColor = theme.colorScheme.onSurfaceVariant;
    const pendingExitColor = Color(0xFFBF7A24);
    final toggleButton = IconButton(
      key: const ValueKey('calendar-quick-editor-toggle-button'),
      onPressed: () => onToggleExpanded(!isExpanded),
      tooltip: isExpanded
          ? 'Riduci modifica rapida'
          : 'Espandi modifica rapida',
      visualDensity: VisualDensity.compact,
      iconSize: toggleIconSize,
      splashRadius: isExpanded ? 18 : 16,
      constraints: BoxConstraints.tightFor(
        width: toggleButtonSize,
        height: toggleButtonSize,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(expandedIcon),
    );
    final values = <Widget>[
      _QuickScheduleValue(
        label: 'Entrata',
        value: startTimeText.isEmpty ? '--:--' : startTimeText,
        valueKey: const ValueKey('calendar-override-start-time-button'),
        supportingText: !hasResultContext && !isDayOff ? 'Inizia da qui' : null,
        isPrimaryAction: !hasResultContext && !isDayOff,
        onTap: onPickStartTime,
      ),
      if (showEndTime)
        _QuickScheduleValue(
          label: hasPendingExitConfirmation
              ? 'Uscita programmata'
              : hasTheoreticalExit
              ? 'Uscita teorica'
              : (isProgrammedExit ? 'Uscita programmata' : 'Uscita'),
          value: hasPendingExitConfirmation
              ? (endTimeText.isEmpty ? suggestedExitLabel : endTimeText)
              : hasTheoreticalExit
              ? suggestedExitLabel
              : (endTimeText.isEmpty ? '--:--' : endTimeText),
          valueKey: const ValueKey('calendar-override-end-time-button'),
          supportingText: hasPendingExitConfirmation
              ? null
              : hasTheoreticalExit
              ? 'Calcolata su entrata + ore attese'
              : (endTimeText.isEmpty && !isDayOff ? 'Dopo l\'entrata' : null),
          labelColorOverride: hasPendingExitConfirmation || hasTheoreticalExit
              ? pendingExitColor
              : null,
          valueColorOverride: hasPendingExitConfirmation || hasTheoreticalExit
              ? pendingExitColor
              : null,
          secondaryActionLabel: hasPendingExitConfirmation || hasTheoreticalExit
              ? 'Conferma'
              : null,
          secondaryActionKey: const ValueKey(
            'calendar-override-confirm-theoretical-end-button',
          ),
          onSecondaryAction:
              (hasPendingExitConfirmation || hasTheoreticalExit) &&
                  onConfirmTheoreticalExit != null
              ? () => onConfirmTheoreticalExit!()
              : null,
          onTap: onPickEndTime,
        ),
      _QuickScheduleValue(
        label: isUsingStandardWorkTarget
            ? 'Ore di lavoro standard'
            : 'Ore di lavoro',
        value: targetText.isEmpty ? '--' : targetText,
        valueKey: const ValueKey('calendar-override-target-value'),
        labelColorOverride: isUsingStandardWorkTarget
            ? standardScheduleColor
            : null,
        valueColorOverride: isUsingStandardWorkTarget
            ? standardScheduleColor
            : null,
        onTap: onPickTargetMinutes,
      ),
      if (showBreakMinutes)
        _QuickScheduleValue(
          label: 'Pausa',
          value: breakMinutes == 0 ? '0 min' : '$breakMinutes min',
          valueKey: const ValueKey('calendar-override-break-value'),
          onTap: onPickBreakMinutes,
        ),
    ];

    final header = Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onToggleExpanded(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Modifica rapida',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          IconButton(
            key: const ValueKey('calendar-override-undo-button'),
            onPressed: canUndoChanges ? () => onUndoChange() : null,
            tooltip: 'Annulla modifica',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            key: const ValueKey('calendar-override-redo-button'),
            onPressed: canRedoChanges ? () => onRedoChange() : null,
            tooltip: 'Ripristina modifica',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.redo_rounded),
          ),
        ],
        toggleButton,
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isExpanded)
          header
        else
          SizedBox(
            height: 30,
            child: Align(alignment: Alignment.centerLeft, child: header),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilterChip(
                          key: const ValueKey(
                            'calendar-override-day-off-button',
                          ),
                          selected: isDayOff,
                          showCheckmark: false,
                          avatar: Icon(
                            isDayOff
                                ? Icons.event_busy_outlined
                                : Icons.event_available_outlined,
                            size: 18,
                          ),
                          label: Text(
                            isDayOff ? 'Giornata libera' : 'Segna libera',
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              onMarkDayAsOff();
                              return;
                            }
                            if (canRestoreWorkingDay) {
                              unawaited(onRestoreWorkingDay());
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columnCount = math.min(
                          values.length,
                          constraints.maxWidth >= 720
                              ? 4
                              : (constraints.maxWidth >= 540 ? 3 : 2),
                        );
                        const spacing = 12.0;
                        final itemWidth = columnCount <= 1
                            ? constraints.maxWidth
                            : (constraints.maxWidth -
                                      (spacing * (columnCount - 1))) /
                                  columnCount;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: 12,
                          children: [
                            for (final value in values)
                              SizedBox(width: itemWidth, child: value),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _QuickDayComputedSummary(
                      workedMinutes: workedMinutes,
                      todayBalanceMinutes: todayBalanceMinutes,
                      overtimeMinutes: overtimeMinutes,
                      exceededOvertimeMinutes: exceededOvertimeMinutes,
                      showOvertimeConfigurationHint:
                          showOvertimeConfigurationHint,
                      overtimeConfigurationHint: overtimeConfigurationHint,
                      limitWarningText: limitWarningText,
                      monthBalanceInfo: monthBalanceInfo,
                      periodBalanceInfo: periodBalanceInfo,
                      dayBalanceAggregation: dayBalanceAggregation,
                      onDayBalanceAggregationChanged:
                          onDayBalanceAggregationChanged,
                      remainingToProgrammedExitLabel:
                          remainingToProgrammedExitLabel,
                      onOpenWorkSettings: onOpenWorkSettings,
                      isDayOff: isDayOff,
                      hasResultContext: hasResultContext,
                    ),
                    if (!hasExitSuggestionContext && !isDayOff) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Inserisci l\'entrata per iniziare.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _WorkdaySessionCard extends StatelessWidget {
  const _WorkdaySessionCard({
    required this.isExpanded,
    required this.session,
    required this.schedule,
    required this.pauseWindow,
    required this.isBusy,
    required this.onToggleExpanded,
    required this.onRecordNow,
    required this.onStartBreak,
    required this.onResume,
    required this.onFinish,
    this.onClear,
  });

  final bool isExpanded;
  final WorkdaySession? session;
  final DaySchedule schedule;
  final _CalendarPauseWindow? pauseWindow;
  final bool isBusy;
  final ValueChanged<bool> onToggleExpanded;
  final Future<void> Function() onRecordNow;
  final Future<void> Function() onStartBreak;
  final Future<void> Function() onResume;
  final Future<void> Function() onFinish;
  final Future<void> Function()? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final status = _resolveWorkdaySessionStatus(session);
    final statusMeta = _workdaySessionStatusMeta(context, status);
    final currentBreakMinutes = _currentSessionBreakMinutes(
      session,
      nowMinutes,
    );
    final expectedEndInfo = _resolveExpectedEndInfo(
      session: session,
      schedule: schedule,
      nowMinutes: nowMinutes,
    );
    final workedSessionInfo = _resolveWorkedSessionInfo(
      session: session,
      schedule: schedule,
      pauseWindow: pauseWindow,
      nowMinutes: nowMinutes,
    );
    final displayedEndMinutes =
        parseTimeInput(schedule.endTime) ?? session?.endMinutes;
    final toggleButtonSize = isExpanded ? 36.0 : 30.0;
    final toggleIconSize = isExpanded ? 20.0 : 18.0;
    final expandedIcon = isExpanded
        ? Icons.keyboard_arrow_up_rounded
        : Icons.keyboard_arrow_down_rounded;
    final toggleButton = IconButton(
      key: const ValueKey('calendar-workday-card-toggle-button'),
      onPressed: () => onToggleExpanded(!isExpanded),
      tooltip: isExpanded ? 'Riduci riquadro' : 'Espandi riquadro',
      visualDensity: VisualDensity.compact,
      iconSize: toggleIconSize,
      splashRadius: isExpanded ? 18 : 16,
      constraints: BoxConstraints.tightFor(
        width: toggleButtonSize,
        height: toggleButtonSize,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(expandedIcon),
    );

    if (!isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onToggleExpanded(true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Entrata, pausa, uscita.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            toggleButton,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onToggleExpanded(false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Giornata di oggi',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _TodayStatusBadge(
                label: statusMeta.label,
                color: statusMeta.color,
                icon: statusMeta.icon,
              ),
              const SizedBox(width: 8),
              toggleButton,
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        _workdaySessionDescription(
                          session: session,
                          schedule: schedule,
                          pauseWindow: pauseWindow,
                          status: status,
                          currentBreakMinutes: currentBreakMinutes,
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (expectedEndInfo != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          expectedEndInfo,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                      if (workedSessionInfo != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          workedSessionInfo,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (displayedEndMinutes != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Uscita registrata alle ${formatTimeInput(displayedEndMinutes)}.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (session == null || session!.isCompleted)
                            FilledButton.icon(
                              key: const ValueKey(
                                'calendar-record-start-button',
                              ),
                              onPressed: isBusy ? null : onRecordNow,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(isBusy ? 'Salvo...' : 'Entrata'),
                            ),
                          if (session != null &&
                              !session!.isCompleted &&
                              !session!.isOnBreak)
                            FilledButton.tonalIcon(
                              key: const ValueKey(
                                'calendar-start-break-button',
                              ),
                              onPressed: isBusy ? null : onStartBreak,
                              icon: const Icon(Icons.coffee_outlined),
                              label: const Text('Inizio pausa'),
                            ),
                          if (session?.isOnBreak == true)
                            FilledButton.tonalIcon(
                              key: const ValueKey(
                                'calendar-resume-workday-button',
                              ),
                              onPressed: isBusy ? null : onResume,
                              icon: const Icon(
                                Icons.play_circle_outline_rounded,
                              ),
                              label: const Text('Fine pausa'),
                            ),
                          if (session != null && !session!.isCompleted)
                            FilledButton.icon(
                              key: const ValueKey(
                                'calendar-end-workday-button',
                              ),
                              onPressed: isBusy ? null : onFinish,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Uscita'),
                            ),
                          if (onClear != null)
                            OutlinedButton.icon(
                              key: const ValueKey(
                                'calendar-clear-workday-session-button',
                              ),
                              onPressed: isBusy ? null : onClear,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Rimuovi'),
                            ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _QuickScheduleValue extends StatelessWidget {
  const _QuickScheduleValue({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.onTap,
    this.supportingText,
    this.isPrimaryAction = false,
    this.labelColorOverride,
    this.valueColorOverride,
    this.secondaryActionLabel,
    this.secondaryActionKey,
    this.onSecondaryAction,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Future<void> Function() onTap;
  final String? supportingText;
  final bool isPrimaryAction;
  final Color? labelColorOverride;
  final Color? valueColorOverride;
  final String? secondaryActionLabel;
  final Key? secondaryActionKey;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelColor =
        labelColorOverride ??
        (isPrimaryAction ? colorScheme.primary : colorScheme.onSurface);
    final supportingColor = isPrimaryAction
        ? colorScheme.primary.withValues(alpha: 0.88)
        : colorScheme.onSurfaceVariant;
    final valueColor = valueColorOverride ?? colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: valueKey,
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_up_chevron_down,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ],
              ),
              if (supportingText != null) ...[
                const SizedBox(height: 4),
                Text(
                  supportingText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: supportingColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  key: secondaryActionKey,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: valueColor,
                    textStyle: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => onSecondaryAction!(),
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickDayComputedSummary extends StatelessWidget {
  const _QuickDayComputedSummary({
    required this.workedMinutes,
    required this.todayBalanceMinutes,
    required this.overtimeMinutes,
    required this.exceededOvertimeMinutes,
    required this.showOvertimeConfigurationHint,
    required this.overtimeConfigurationHint,
    required this.limitWarningText,
    required this.monthBalanceInfo,
    required this.periodBalanceInfo,
    required this.dayBalanceAggregation,
    required this.onDayBalanceAggregationChanged,
    required this.remainingToProgrammedExitLabel,
    required this.onOpenWorkSettings,
    required this.isDayOff,
    required this.hasResultContext,
  });

  final int workedMinutes;
  final int todayBalanceMinutes;
  final int overtimeMinutes;
  final int exceededOvertimeMinutes;
  final bool showOvertimeConfigurationHint;
  final String? overtimeConfigurationHint;
  final String? limitWarningText;
  final _DisplayedMonthBalanceInfo monthBalanceInfo;
  final _DisplayedPeriodBalanceInfo periodBalanceInfo;
  final DayBalanceAggregation dayBalanceAggregation;
  final ValueChanged<DayBalanceAggregation> onDayBalanceAggregationChanged;
  final String? remainingToProgrammedExitLabel;
  final VoidCallback onOpenWorkSettings;
  final bool isDayOff;
  final bool hasResultContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasStartedDay = hasResultContext && !isDayOff;
    final dayBalanceLabel = switch ((
      isDayOff,
      hasStartedDay,
      todayBalanceMinutes,
    )) {
      (true, _, _) => 'Saldo oggi',
      (false, false, _) => 'Saldo oggi',
      (false, true, > 0) => 'Credito',
      (false, true, < 0) => 'Debito',
      _ => 'In pari oggi',
    };
    final dayBalanceValue = switch ((isDayOff, hasStartedDay)) {
      (true, _) => '0:00',
      (false, false) => 'Da iniziare',
      _ => _formatSignedHoursInput(todayBalanceMinutes),
    };
    final dayBalanceColor = switch ((isDayOff, hasStartedDay)) {
      (true, _) => colorScheme.primary,
      (false, false) => colorScheme.onSurfaceVariant,
      _ => _balanceColor(context, todayBalanceMinutes),
    };
    final overtimeLabel = exceededOvertimeMinutes > 0
        ? 'Oltre straordinario'
        : 'Straordinario';
    final overtimeValue = switch ((isDayOff, hasStartedDay)) {
      (true, _) => '0:00',
      (false, false) => 'Da calcolare',
      _ => _formatHoursInput(overtimeMinutes),
    };
    final overtimeColor = switch ((isDayOff, hasStartedDay)) {
      (true, _) => colorScheme.onSurfaceVariant,
      (false, false) => colorScheme.onSurfaceVariant,
      _ => exceededOvertimeMinutes > 0
          ? const Color(0xFF9D3D2F)
          : overtimeMinutes > 0
          ? colorScheme.secondary
          : colorScheme.onSurfaceVariant,
    };
    final overtimeHelperText = exceededOvertimeMinutes > 0
        ? 'Fuori limite di ${_formatHoursInput(exceededOvertimeMinutes)}'
        : null;

    return _QuickDayHero(
      workedMinutes: workedMinutes,
      isDayOff: isDayOff,
      hasResultContext: hasResultContext,
      dayBalanceLabel: dayBalanceLabel,
      dayBalanceValue: dayBalanceValue,
      dayBalanceColor: dayBalanceColor,
      overtimeLabel: overtimeLabel,
      overtimeValue: overtimeValue,
      overtimeColor: overtimeColor,
      overtimeHelperText: overtimeHelperText,
      showOvertimeConfigurationHint: showOvertimeConfigurationHint,
      overtimeConfigurationHint: overtimeConfigurationHint,
      limitWarningText: limitWarningText,
      onOpenWorkSettings: onOpenWorkSettings,
      monthBalanceInfo: monthBalanceInfo,
      periodBalanceInfo: periodBalanceInfo,
      dayBalanceAggregation: dayBalanceAggregation,
      onDayBalanceAggregationChanged: onDayBalanceAggregationChanged,
      remainingToProgrammedExitLabel: remainingToProgrammedExitLabel,
    );
  }
}

class _QuickDayHero extends StatelessWidget {
  const _QuickDayHero({
    required this.workedMinutes,
    required this.isDayOff,
    required this.hasResultContext,
    required this.dayBalanceLabel,
    required this.dayBalanceValue,
    required this.dayBalanceColor,
    required this.overtimeLabel,
    required this.overtimeValue,
    required this.overtimeColor,
    required this.overtimeHelperText,
    required this.limitWarningText,
    required this.showOvertimeConfigurationHint,
    required this.overtimeConfigurationHint,
    required this.onOpenWorkSettings,
    required this.monthBalanceInfo,
    required this.periodBalanceInfo,
    required this.dayBalanceAggregation,
    required this.onDayBalanceAggregationChanged,
    required this.remainingToProgrammedExitLabel,
  });

  final int workedMinutes;
  final bool isDayOff;
  final bool hasResultContext;
  final String dayBalanceLabel;
  final String dayBalanceValue;
  final Color dayBalanceColor;
  final String overtimeLabel;
  final String overtimeValue;
  final Color overtimeColor;
  final String? overtimeHelperText;
  final String? limitWarningText;
  final bool showOvertimeConfigurationHint;
  final String? overtimeConfigurationHint;
  final VoidCallback onOpenWorkSettings;
  final _DisplayedMonthBalanceInfo monthBalanceInfo;
  final _DisplayedPeriodBalanceInfo periodBalanceInfo;
  final DayBalanceAggregation dayBalanceAggregation;
  final ValueChanged<DayBalanceAggregation> onDayBalanceAggregationChanged;
  final String? remainingToProgrammedExitLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final secondaryValueStyle = theme.textTheme.titleLarge?.copyWith(
      fontSize: 18,
      height: 1.05,
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );
    final helperStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      height: 1.15,
    );
    final workedHelperText = switch ((isDayOff, hasResultContext)) {
      (true, _) => 'Nessuna ora da registrare',
      (false, false) => 'Inserisci l\'entrata per iniziare',
      _ => remainingToProgrammedExitLabel,
    };
    final hasRemainingToProgrammedExit =
        remainingToProgrammedExitLabel != null && !isDayOff && hasResultContext;
    final neutralValueColor = colorScheme.onSurfaceVariant;
    Widget metricBlock({
      required String label,
      required String value,
      required Key valueKey,
      required Color valueColor,
      String? helperText,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 4),
          Text(
            value,
            key: valueKey,
            style: secondaryValueStyle?.copyWith(color: valueColor),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 2),
            Text(helperText, style: helperStyle),
          ],
        ],
      );
    }

    final workedBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lavorate', style: labelStyle),
        const SizedBox(height: 4),
        Text(
          _formatHoursInput(workedMinutes),
          key: const ValueKey('calendar-live-worked-value'),
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w900,
            color: colorScheme.primary,
          ),
        ),
        if (workedHelperText != null) ...[
          const SizedBox(height: 2),
          Text(
            workedHelperText,
            style: helperStyle?.copyWith(
              color: hasRemainingToProgrammedExit
                  ? colorScheme.secondary
                  : helperStyle.color,
              fontWeight: hasRemainingToProgrammedExit
                  ? FontWeight.w700
                  : helperStyle.fontWeight,
            ),
          ),
        ],
      ],
    );
    final balanceBlock = metricBlock(
      label: dayBalanceLabel,
      value: dayBalanceValue,
      valueKey: const ValueKey('calendar-live-day-balance-value'),
      valueColor: hasResultContext || isDayOff
          ? dayBalanceColor
          : neutralValueColor,
    );
    final overtimeBlock = metricBlock(
      label: overtimeLabel,
      value: overtimeValue,
      valueKey: const ValueKey('calendar-live-overtime-value'),
      valueColor: overtimeColor,
      helperText: overtimeHelperText,
    );
    final monthBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saldo mese', style: labelStyle),
        const SizedBox(height: 3),
        Text(
          monthBalanceInfo.value,
          key: const ValueKey('calendar-live-month-balance-value'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: secondaryValueStyle?.copyWith(
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
    final periodSuffix = switch (dayBalanceAggregation) {
      DayBalanceAggregation.monthly => 'mensile',
      DayBalanceAggregation.weekly => 'settimanale',
    };
    final periodBalanceLabel = switch (periodBalanceInfo.balanceMinutes) {
      > 0 => 'Credito $periodSuffix',
      < 0 => 'Debito $periodSuffix',
      _ => 'In pari $periodSuffix',
    };
    final periodBalanceColor = switch (periodBalanceInfo.balanceMinutes) {
      > 0 => const Color(0xFF0B6E69),
      < 0 => const Color(0xFF9D3D2F),
      _ => neutralValueColor,
    };
    final periodBalanceValue = periodBalanceInfo.balanceMinutes == 0
        ? '0:00'
        : _formatHoursInput(periodBalanceInfo.balanceMinutes.abs());
    final periodBalanceBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopupMenuButton<DayBalanceAggregation>(
          key: const ValueKey('calendar-live-period-balance-menu'),
          tooltip: 'Scegli periodo saldo',
          onSelected: onDayBalanceAggregationChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: DayBalanceAggregation.monthly,
              child: Text('Mensile'),
            ),
            PopupMenuItem(
              value: DayBalanceAggregation.weekly,
              child: Text('Settimanale'),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                periodBalanceLabel,
                key: const ValueKey('calendar-live-period-balance-label'),
                style: labelStyle,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          periodBalanceValue,
          key: const ValueKey('calendar-live-expected-value'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: secondaryValueStyle?.copyWith(
            fontSize: 16,
            color: periodBalanceColor,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(
          colorScheme.surfaceContainerLow,
          colorScheme.primary,
          0.05,
        )!,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 300) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: workedBlock),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          balanceBlock,
                          const SizedBox(height: 10),
                          overtimeBlock,
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  workedBlock,
                  const SizedBox(height: 12),
                  balanceBlock,
                  const SizedBox(height: 10),
                  overtimeBlock,
                ],
              );
            },
          ),
          if (showOvertimeConfigurationHint) ...[
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  overtimeConfigurationHint ??
                      'Per attivare limiti credito/straordinario ',
                  style: helperStyle,
                ),
                GestureDetector(
                  onTap: onOpenWorkSettings,
                  child: Text(
                    'clicca qui',
                    style: helperStyle?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text('.', style: helperStyle),
              ],
            ),
          ],
          if (limitWarningText != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: const Color(0xFF9D3D2F),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    limitWarningText!,
                    style: helperStyle?.copyWith(
                      color: const Color(0xFF9D3D2F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 280) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: periodBalanceBlock),
                    const SizedBox(width: 10),
                    Expanded(child: monthBlock),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  periodBalanceBlock,
                  const SizedBox(height: 10),
                  monthBlock,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WheelPickerBottomSheet<T> extends StatefulWidget {
  const _WheelPickerBottomSheet({
    required this.title,
    required this.initialValue,
    required this.valueBuilder,
    required this.pickerBuilder,
    this.clearLabel,
    this.clearValue,
  });

  final String title;
  final T initialValue;
  final Widget Function(ValueNotifier<T> controller) valueBuilder;
  final Widget Function(ValueNotifier<T> controller) pickerBuilder;
  final String? clearLabel;
  final T? clearValue;

  @override
  State<_WheelPickerBottomSheet<T>> createState() =>
      _WheelPickerBottomSheetState<T>();
}

class _WheelPickerBottomSheetState<T>
    extends State<_WheelPickerBottomSheet<T>> {
  late final ValueNotifier<T> _valueNotifier;

  @override
  void initState() {
    super.initState();
    _valueNotifier = ValueNotifier<T>(widget.initialValue);
  }

  @override
  void dispose() {
    _valueNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                if (widget.clearLabel != null && widget.clearValue != null)
                  TextButton(
                    key: const ValueKey('wheel-picker-clear-button'),
                    onPressed: () => Navigator.of(context).pop(widget.clearValue),
                    child: Text(
                      widget.clearLabel!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton.tonal(
                  onPressed: () =>
                      Navigator.of(context).pop(_valueNotifier.value),
                  child: const Text('Conferma'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            widget.valueBuilder(_valueNotifier),
            const SizedBox(height: 12),
            widget.pickerBuilder(_valueNotifier),
          ],
        ),
      ),
    );
  }
}

_CalendarView _calendarViewOrDefault(_CalendarView value) => value;

class _CalendarPeriodSummary extends StatelessWidget {
  const _CalendarPeriodSummary({
    required this.calendarView,
    required this.days,
    required this.dayMetrics,
    required this.daySchedule,
    required this.dayPauseWindow,
    required this.isDayScheduleProvisional,
    required this.workdaySession,
    required this.weekMetrics,
    required this.monthMetrics,
    required this.yearMetrics,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onOpenDay,
    required this.onCalendarViewChanged,
    required this.onDaySchedulePreviewChanged,
    required this.onDaySchedulePreviewCleared,
    required this.onDayScheduleChanged,
    required this.onAgendaInteractionChanged,
    required this.isDayAgendaExpanded,
    required this.onToggleDayAgendaExpanded,
  });

  final _CalendarView calendarView;
  final List<_CalendarDay> days;
  final _DayMetrics dayMetrics;
  final DaySchedule daySchedule;
  final _CalendarPauseWindow? dayPauseWindow;
  final bool isDayScheduleProvisional;
  final WorkdaySession? workdaySession;
  final List<_DayMetrics> weekMetrics;
  final _MonthMetrics monthMetrics;
  final List<_MonthMetrics> yearMetrics;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final Future<void> Function(DateTime date) onOpenDay;
  final Future<void> Function(_CalendarView view) onCalendarViewChanged;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onDaySchedulePreviewChanged;
  final VoidCallback onDaySchedulePreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onDayScheduleChanged;
  final ValueChanged<bool> onAgendaInteractionChanged;
  final bool isDayAgendaExpanded;
  final ValueChanged<bool> onToggleDayAgendaExpanded;

  @override
  Widget build(BuildContext context) {
    return switch (calendarView) {
      _CalendarView.day => _CalendarDaySummary(
        metrics: dayMetrics,
        schedule: daySchedule,
        pauseWindow: dayPauseWindow,
        isProvisional: isDayScheduleProvisional,
        workdaySession: workdaySession,
        onSchedulePreviewChanged: onDaySchedulePreviewChanged,
        onSchedulePreviewCleared: onDaySchedulePreviewCleared,
        onScheduleChanged: onDayScheduleChanged,
        onAgendaInteractionChanged: onAgendaInteractionChanged,
        isExpanded: isDayAgendaExpanded,
        onToggleExpanded: onToggleDayAgendaExpanded,
      ),
      _CalendarView.week => _CalendarWeekSummary(
        metrics: weekMetrics,
        selectedDate: selectedDate,
        todayWorkdaySession: workdaySession,
        onOpenDay: onOpenDay,
      ),
      _CalendarView.month => _CalendarMonthSummary(
        days: days,
        monthMetrics: monthMetrics,
        onOpenDay: onOpenDay,
      ),
      _CalendarView.year => _CalendarYearSummary(
        yearMetrics: yearMetrics,
        onOpenMonth: (month) {
          onSelectDate(_monthToDate(month));
          unawaited(onCalendarViewChanged(_CalendarView.month));
        },
      ),
    };
  }
}

class _CalendarDaySummary extends StatelessWidget {
  const _CalendarDaySummary({
    required this.metrics,
    required this.schedule,
    required this.pauseWindow,
    required this.isProvisional,
    required this.workdaySession,
    required this.onSchedulePreviewChanged,
    required this.onSchedulePreviewCleared,
    required this.onScheduleChanged,
    required this.onAgendaInteractionChanged,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final _DayMetrics metrics;
  final DaySchedule schedule;
  final _CalendarPauseWindow? pauseWindow;
  final bool isProvisional;
  final WorkdaySession? workdaySession;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onSchedulePreviewChanged;
  final VoidCallback onSchedulePreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onScheduleChanged;
  final ValueChanged<bool> onAgendaInteractionChanged;
  final bool isExpanded;
  final ValueChanged<bool> onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final measurementSegments = _buildAgendaMeasurementSegments(
      schedule: schedule,
      session: workdaySession,
      nowMinutes: nowMinutes,
      pauseWindow: pauseWindow,
    );
    final scheduledStartMinutes = parseTimeInput(schedule.startTime);
    final scheduledEndMinutes = parseTimeInput(schedule.endTime);
    final hasStructuredSchedule =
        scheduledStartMinutes != null &&
        scheduledEndMinutes != null &&
        scheduledEndMinutes > scheduledStartMinutes;
    final hasMeasuredSegments = measurementSegments.isNotEmpty;
    final agendaRange = _resolveCompactAgendaRangeForBounds(
      startMinutes: hasStructuredSchedule
          ? scheduledStartMinutes
          : (hasMeasuredSegments
                ? measurementSegments
                      .map((segment) => segment.startMinutes)
                      .reduce(math.min)
                : null),
      endMinutes: hasStructuredSchedule
          ? scheduledEndMinutes
          : (hasMeasuredSegments
                ? measurementSegments
                      .map((segment) => segment.endMinutes)
                      .reduce(math.max)
                : null),
    );
    final hasAgendaTimeline = hasStructuredSchedule || hasMeasuredSegments;
    final workedSummary = _buildAgendaWorkedSummary(
      measurementSegments: measurementSegments,
    );
    final toggleButton = IconButton(
      key: const ValueKey('calendar-day-agenda-toggle-button'),
      onPressed: () => onToggleExpanded(!isExpanded),
      tooltip: isExpanded ? 'Riduci agenda' : 'Espandi agenda',
      visualDensity: VisualDensity.compact,
      iconSize: isExpanded ? 20 : 18,
      splashRadius: isExpanded ? 18 : 16,
      constraints: BoxConstraints.tightFor(
        width: isExpanded ? 36 : 30,
        height: isExpanded ? 36 : 30,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(
        isExpanded
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onToggleExpanded(!isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Agenda oraria',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            toggleButton,
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    if (hasAgendaTimeline)
                      _AgendaDayTimeline(
                        metrics: metrics,
                        range: agendaRange,
                        schedule: schedule,
                        isProvisional: isProvisional,
                        measurementSegments: measurementSegments,
                        onPreviewChanged: onSchedulePreviewChanged,
                        onPreviewCleared: onSchedulePreviewCleared,
                        onScheduleChanged: onScheduleChanged,
                        onInteractionChanged: onAgendaInteractionChanged,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Text(
                          'Nessun orario da mostrare. Inserisci entrata e uscita per vedere la timeline.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    if (workedSummary != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        workedSummary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CalendarWeekSummary extends StatelessWidget {
  const _CalendarWeekSummary({
    required this.metrics,
    required this.selectedDate,
    required this.todayWorkdaySession,
    required this.onOpenDay,
  });

  final List<_DayMetrics> metrics;
  final DateTime selectedDate;
  final WorkdaySession? todayWorkdaySession;
  final Future<void> Function(DateTime date) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final agendaRange = _resolveAgendaRange(metrics);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactLayout = constraints.maxWidth < 760;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agenda settimanale',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (useCompactLayout)
              _AgendaWeekCompactOverview(
                metrics: metrics,
                todayWorkdaySession: todayWorkdaySession,
                onOpenDay: onOpenDay,
              )
            else
              _AgendaWeekTimeline(
                metrics: metrics,
                selectedDate: selectedDate,
                todayWorkdaySession: todayWorkdaySession,
                onOpenDay: onOpenDay,
                range: agendaRange,
              ),
          ],
        );
      },
    );
  }
}

class _AgendaWeekCompactOverview extends StatelessWidget {
  const _AgendaWeekCompactOverview({
    required this.metrics,
    required this.todayWorkdaySession,
    required this.onOpenDay,
  });

  final List<_DayMetrics> metrics;
  final WorkdaySession? todayWorkdaySession;
  final Future<void> Function(DateTime date) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final overviewRange = _resolveAgendaRangeForSchedules(
      metrics.map((day) => day.schedule),
    );
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < metrics.length; index += 1) ...[
          (() {
            final day = metrics[index];
            final isToday = _isSameDay(day.date, DateUtils.dateOnly(now));
            final effectiveSession = isToday ? todayWorkdaySession : null;
            return _CompactWeekTimelineRow(
              metrics: day,
              range: overviewRange,
              measurementSegments: _buildAgendaMeasurementSegments(
                schedule: day.schedule,
                session: effectiveSession,
                nowMinutes: nowMinutes,
              ),
              workdaySession: effectiveSession,
              onTap: () => unawaited(onOpenDay(day.date)),
            );
          })(),
          if (index < metrics.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CompactWeekTimelineRow extends StatelessWidget {
  const _CompactWeekTimelineRow({
    required this.metrics,
    required this.range,
    required this.measurementSegments,
    required this.workdaySession,
    this.onTap,
  });

  final _DayMetrics metrics;
  final _AgendaRange range;
  final List<_AgendaMeasurementSegment> measurementSegments;
  final WorkdaySession? workdaySession;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final schedule = metrics.schedule;
    final startMinutes = parseTimeInput(schedule.startTime);
    final endMinutes = parseTimeInput(schedule.endTime);
    final hasStructuredSchedule =
        startMinutes != null && endMinutes != null && endMinutes > startMinutes;
    final effectiveSegments = hasStructuredSchedule
        ? _resolveEffectiveAgendaSegments(
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            measurementSegments: measurementSegments,
          )
        : const <_AgendaMeasurementSegment>[];
    final workColor = metrics.hasOverride
        ? colorScheme.secondary.withValues(alpha: 0.28)
        : colorScheme.primary.withValues(alpha: 0.26);
    final pauseColor = colorScheme.secondary.withValues(alpha: 0.56);
    final rowBorderColor = metrics.hasOverride
        ? colorScheme.secondary.withValues(alpha: 0.45)
        : colorScheme.outlineVariant;
    final rowFillColor = metrics.hasOverride
        ? Color.lerp(
            colorScheme.surfaceContainerLow,
            colorScheme.secondary,
            0.1,
          )!
        : colorScheme.surfaceContainerLow;
    final relation = switch (_compareDateToToday(metrics.date)) {
      0 => _CalendarDayRelation.today,
      < 0 => _CalendarDayRelation.past,
      _ => _CalendarDayRelation.future,
    };
    final dayDetails = _buildCalendarDayDetails(
      relation: relation,
      schedule: schedule,
      workedMinutes: metrics.workedMinutes,
      leaveMinutes: metrics.leaveMinutes,
      session: relation == _CalendarDayRelation.today ? workdaySession : null,
    );
    final helperText = schedule.targetMinutes <= 0
        ? 'Giorno libero'
        : _compactWeekScheduleLabel(schedule);
    final effectiveWorkedMinutes =
        relation == _CalendarDayRelation.today && workdaySession == null
        ? metrics.workedMinutes
        : (dayDetails?.workedMinutes ?? metrics.workedMinutes);
    final hasRegisteredWorkOrLeave =
        effectiveWorkedMinutes > 0 || metrics.leaveMinutes > 0;
    final workedDeltaMinutes = hasRegisteredWorkOrLeave
        ? (effectiveWorkedMinutes + metrics.leaveMinutes) - metrics.expectedMinutes
        : 0;
    final isCurrentWithoutRegistrations =
        relation != _CalendarDayRelation.future &&
        !hasRegisteredWorkOrLeave &&
        schedule.targetMinutes > 0;
    final workedLabelColor = workedDeltaMinutes >= 0
        ? const Color(0xFF0B6E69)
        : const Color(0xFF9D3D2F);
    final footerColor = isCurrentWithoutRegistrations
        ? colorScheme.onSurfaceVariant
        : workedLabelColor;
    final workedFooterLabel = dayDetails == null
        ? null
        : isCurrentWithoutRegistrations
        ? 'Nessuna timbratura'
        : 'Ore ${_formatHoursInput(effectiveWorkedMinutes)}';
    final balanceFooterLabel = isCurrentWithoutRegistrations
        ? relation == _CalendarDayRelation.past
              ? 'Da registrare'
              : 'Da iniziare'
        : workedDeltaMinutes > 0
        ? 'Credito: ${_formatHoursInput(workedDeltaMinutes)}'
        : workedDeltaMinutes < 0
        ? 'Debito: ${_formatHoursInput(workedDeltaMinutes.abs())}'
        : 'In pari';

    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatWeekdayShortLabel(metrics.date),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatCompactDate(metrics.date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            key: ValueKey(
              'calendar-week-row-${DashboardService.defaultEntryDateOf(metrics.date)}',
            ),
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: rowFillColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: rowBorderColor),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double leftForMinute(int minute) {
                  if (range.totalMinutes <= 0) {
                    return 0;
                  }
                  final clamped = minute.clamp(
                    range.startMinutes,
                    range.endMinutes,
                  );
                  return ((clamped - range.startMinutes) / range.totalMinutes) *
                      constraints.maxWidth;
                }

                return Stack(
                  children: [
                    for (final mark in range.hourMarks)
                      Positioned(
                        left: leftForMinute(mark),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.24,
                          ),
                        ),
                      ),
                    if (!hasStructuredSchedule)
                      Center(
                        child: Text(
                          helperText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (hasStructuredSchedule) ...[
                      for (final segment in effectiveSegments)
                        Positioned(
                          left: leftForMinute(segment.startMinutes),
                          top: 16,
                          width: math.max(
                            10,
                            leftForMinute(segment.endMinutes) -
                                leftForMinute(segment.startMinutes),
                          ),
                          height: 18,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  segment.kind ==
                                      _AgendaMeasurementSegmentKind.pause
                                  ? pauseColor
                                  : workColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Text(
                          formatTimeInput(startMinutes),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Text(
                          formatTimeInput(endMinutes),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: hasStructuredSchedule && dayDetails != null
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      workedFooterLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: footerColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      balanceFooterLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: footerColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                helperText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );

    if (onTap == null) {
      return rowContent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: rowContent,
      ),
    );
  }
}

class _AgendaDayTimeline extends StatefulWidget {
  const _AgendaDayTimeline({
    required this.metrics,
    required this.range,
    required this.schedule,
    required this.isProvisional,
    required this.measurementSegments,
    required this.onPreviewChanged,
    required this.onPreviewCleared,
    required this.onScheduleChanged,
    required this.onInteractionChanged,
  });

  final _DayMetrics metrics;
  final _AgendaRange range;
  final DaySchedule schedule;
  final bool isProvisional;
  final List<_AgendaMeasurementSegment> measurementSegments;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onPreviewChanged;
  final VoidCallback onPreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })
  onScheduleChanged;
  final ValueChanged<bool> onInteractionChanged;

  @override
  State<_AgendaDayTimeline> createState() => _AgendaDayTimelineState();
}

class _AgendaDayTimelineState extends State<_AgendaDayTimeline> {
  _AgendaRange? _lockedRange;

  @override
  void didUpdateWidget(covariant _AgendaDayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schedule.startTime != oldWidget.schedule.startTime ||
        widget.schedule.endTime != oldWidget.schedule.endTime ||
        widget.schedule.breakMinutes != oldWidget.schedule.breakMinutes) {
      _lockedRange = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTimelineHeight = widget.range.timelineHeight(
      pixelsPerHour: 30,
      minHeight: 260,
    );
    final effectiveRange = _lockedRange ?? widget.range;
    final timelineHeight = baseTimelineHeight;

    return SizedBox(
      height: timelineHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AgendaHourRail(range: effectiveRange, height: timelineHeight),
          const SizedBox(width: 12),
          Expanded(
            child: _AgendaDaySurface(
              metrics: widget.metrics,
              schedule: widget.schedule,
              range: effectiveRange,
              height: timelineHeight,
              displayMode: _AgendaSurfaceDisplayMode.day,
              isProvisional: widget.isProvisional,
              measurementSegments: widget.measurementSegments,
              onPreviewChanged:
                  ({
                    required int startMinutes,
                    required int endMinutes,
                    int? breakMinutes,
                    int? pauseStartMinutes,
                    int? pauseEndMinutes,
                  }) {
                    setState(() {
                      _lockedRange ??= widget.range;
                    });
                    widget.onPreviewChanged(
                      startMinutes: startMinutes,
                      endMinutes: endMinutes,
                      breakMinutes: breakMinutes,
                      pauseStartMinutes: pauseStartMinutes,
                      pauseEndMinutes: pauseEndMinutes,
                    );
                  },
              onPreviewCleared: () {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _lockedRange = null;
                });
                widget.onPreviewCleared();
              },
              onScheduleChanged: widget.onScheduleChanged,
              onInteractionChanged: widget.onInteractionChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaWeekTimeline extends StatelessWidget {
  const _AgendaWeekTimeline({
    required this.metrics,
    required this.selectedDate,
    required this.todayWorkdaySession,
    required this.onOpenDay,
    required this.range,
  });

  final List<_DayMetrics> metrics;
  final DateTime selectedDate;
  final WorkdaySession? todayWorkdaySession;
  final Future<void> Function(DateTime date) onOpenDay;
  final _AgendaRange range;

  @override
  Widget build(BuildContext context) {
    const headerHeight = 74.0;
    const columnWidth = 134.0;
    final timelineHeight = range.timelineHeight(
      pixelsPerHour: 18,
      minHeight: 180,
    );
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;

    return SizedBox(
      height: headerHeight + 10 + timelineHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  const SizedBox(height: headerHeight),
                  const SizedBox(height: 10),
                  _AgendaHourRail(range: range, height: timelineHeight),
                ],
              ),
            ),
            const SizedBox(width: 12),
            for (final day in metrics) ...[
              (() {
                final isToday = _isSameDay(day.date, DateUtils.dateOnly(now));
                final effectiveSession = isToday ? todayWorkdaySession : null;
                return SizedBox(
                  width: columnWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: headerHeight,
                        child: _AgendaDayHeader(
                          metrics: day,
                          isSelected: _isSameDay(day.date, selectedDate),
                          onTap: () => unawaited(onOpenDay(day.date)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AgendaDaySurface(
                        metrics: day,
                        schedule: day.schedule,
                        range: range,
                        height: timelineHeight,
                        displayMode: _AgendaSurfaceDisplayMode.week,
                        isSelected: _isSameDay(day.date, selectedDate),
                        measurementSegments: _buildAgendaMeasurementSegments(
                          schedule: day.schedule,
                          session: effectiveSession,
                          nowMinutes: nowMinutes,
                        ),
                        onTap: () => unawaited(onOpenDay(day.date)),
                      ),
                    ],
                  ),
                );
              })(),
              if (day != metrics.last) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgendaDayHeader extends StatelessWidget {
  const _AgendaDayHeader({
    required this.metrics,
    required this.isSelected,
    required this.onTap,
  });

  final _DayMetrics metrics;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isSelected
        ? colorScheme.primary
        : colorScheme.surface;
    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final primaryTextColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final secondaryTextColor = isSelected
        ? colorScheme.onPrimary.withValues(alpha: 0.86)
        : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.78) ??
              colorScheme.onSurface.withValues(alpha: 0.78);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatWeekdayShortLabel(metrics.date),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatCompactDate(metrics.date),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaHourRail extends StatelessWidget {
  const _AgendaHourRail({required this.range, required this.height});

  final _AgendaRange range;
  final double height;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(
        context,
      ).textTheme.bodySmall?.color?.withValues(alpha: 0.78),
    );

    return SizedBox(
      width: 52,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final mark in range.hourMarks)
            Positioned(
              top: _resolveAgendaLabelTop(
                range.positionFor(mark, height),
                height,
              ),
              right: 0,
              child: Text(formatTimeInput(mark), style: labelStyle),
            ),
        ],
      ),
    );
  }
}

class _AgendaDaySurface extends StatefulWidget {
  const _AgendaDaySurface({
    required this.metrics,
    required this.schedule,
    required this.range,
    required this.height,
    this.displayMode = _AgendaSurfaceDisplayMode.day,
    this.isSelected = false,
    this.isProvisional = false,
    this.measurementSegments = const [],
    this.onTap,
    this.onPreviewChanged,
    this.onPreviewCleared,
    this.onScheduleChanged,
    this.onInteractionChanged,
  });

  final _DayMetrics metrics;
  final DaySchedule schedule;
  final _AgendaRange range;
  final double height;
  final _AgendaSurfaceDisplayMode displayMode;
  final bool isSelected;
  final bool isProvisional;
  final List<_AgendaMeasurementSegment> measurementSegments;
  final VoidCallback? onTap;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })?
  onPreviewChanged;
  final VoidCallback? onPreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })?
  onScheduleChanged;
  final ValueChanged<bool>? onInteractionChanged;

  @override
  State<_AgendaDaySurface> createState() => _AgendaDaySurfaceState();
}

class _AgendaDaySurfaceState extends State<_AgendaDaySurface> {
  int? _previewStartMinutes;
  int? _previewEndMinutes;
  int? _previewBreakMinutes;

  @override
  void didUpdateWidget(covariant _AgendaDaySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scheduledStart = parseTimeInput(widget.schedule.startTime);
    final scheduledEnd = parseTimeInput(widget.schedule.endTime);
    final previewMatchesCommitted =
        _previewStartMinutes != null &&
        _previewEndMinutes != null &&
        scheduledStart == _previewStartMinutes &&
        scheduledEnd == _previewEndMinutes &&
        widget.schedule.breakMinutes ==
            (_previewBreakMinutes ?? widget.schedule.breakMinutes);

    if (previewMatchesCommitted ||
        oldWidget.schedule.startTime != widget.schedule.startTime ||
        oldWidget.schedule.endTime != widget.schedule.endTime ||
        oldWidget.schedule.breakMinutes != widget.schedule.breakMinutes) {
      _previewStartMinutes = null;
      _previewEndMinutes = null;
      _previewBreakMinutes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lineColor = colorScheme.outlineVariant.withValues(alpha: 0.45);
    final surfaceColor = widget.isSelected
        ? Color.lerp(colorScheme.surface, colorScheme.primary, 0.08)!
        : colorScheme.surface;
    final borderColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final scheduledStart =
        _previewStartMinutes ?? parseTimeInput(widget.schedule.startTime);
    final scheduledEnd =
        _previewEndMinutes ?? parseTimeInput(widget.schedule.endTime);
    final inferredSegments =
        scheduledStart != null &&
            scheduledEnd != null &&
            scheduledEnd > scheduledStart
        ? _resolveEffectiveAgendaSegments(
            startMinutes: scheduledStart,
            endMinutes: scheduledEnd,
            measurementSegments: widget.measurementSegments,
          )
        : const <_AgendaMeasurementSegment>[];
    final inferredStart = inferredSegments.isEmpty
        ? null
        : inferredSegments
              .map((segment) => segment.startMinutes)
              .reduce(math.min);
    final inferredEnd = inferredSegments.isEmpty
        ? null
        : inferredSegments
              .map((segment) => segment.endMinutes)
              .reduce(math.max);
    final resolvedStart = scheduledStart ?? inferredStart;
    final resolvedEnd = scheduledEnd ?? inferredEnd;
    final hasStructuredSchedule =
        resolvedStart != null &&
        resolvedEnd != null &&
        resolvedEnd > resolvedStart;
    const blockRightInset = 10.0;

    final content = Ink(
      height: widget.height,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
          width: widget.isSelected ? 1.4 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final mark in widget.range.hourMarks)
            Positioned(
              top: widget.range.positionFor(mark, widget.height),
              left: 0,
              right: 0,
              child: Container(height: 1, color: lineColor),
            ),
          if (hasStructuredSchedule)
            Positioned(
              top: widget.range.positionFor(resolvedStart, widget.height),
              left: 10,
              right: blockRightInset,
              height: math.max(
                widget.range.positionFor(resolvedEnd, widget.height) -
                    widget.range.positionFor(resolvedStart, widget.height),
                28,
              ),
              child: _AgendaScheduleBlock(
                metrics: widget.metrics,
                schedule: widget.schedule,
                startMinutes: resolvedStart,
                endMinutes: resolvedEnd,
                range: widget.range,
                height: widget.height,
                displayMode: widget.displayMode,
                measurementSegments: widget.measurementSegments,
                isProvisional: widget.isProvisional,
                onPreviewChanged:
                    ({
                      required int startMinutes,
                      required int endMinutes,
                      int? breakMinutes,
                      int? pauseStartMinutes,
                      int? pauseEndMinutes,
                    }) {
                      setState(() {
                        _previewStartMinutes = startMinutes;
                        _previewEndMinutes = endMinutes;
                        _previewBreakMinutes = breakMinutes;
                      });
                      widget.onPreviewChanged?.call(
                        startMinutes: startMinutes,
                        endMinutes: endMinutes,
                        breakMinutes: breakMinutes,
                        pauseStartMinutes: pauseStartMinutes,
                        pauseEndMinutes: pauseEndMinutes,
                      );
                    },
                onPreviewCleared: () {
                  setState(() {
                    _previewStartMinutes = null;
                    _previewEndMinutes = null;
                    _previewBreakMinutes = null;
                  });
                  widget.onPreviewCleared?.call();
                },
                onScheduleChanged: widget.onScheduleChanged,
                onInteractionChanged: widget.onInteractionChanged,
              ),
            ),
          if (!hasStructuredSchedule &&
              widget.displayMode == _AgendaSurfaceDisplayMode.day)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.schedule_outlined,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}

enum _AgendaSurfaceDisplayMode { day, week }

class _AgendaScheduleBlock extends StatefulWidget {
  const _AgendaScheduleBlock({
    required this.metrics,
    required this.schedule,
    required this.startMinutes,
    required this.endMinutes,
    required this.range,
    required this.height,
    required this.displayMode,
    this.measurementSegments = const [],
    this.isProvisional = false,
    this.onPreviewChanged,
    this.onPreviewCleared,
    this.onScheduleChanged,
    this.onInteractionChanged,
  });

  final _DayMetrics metrics;
  final DaySchedule schedule;
  final int startMinutes;
  final int endMinutes;
  final _AgendaRange range;
  final double height;
  final _AgendaSurfaceDisplayMode displayMode;
  final List<_AgendaMeasurementSegment> measurementSegments;
  final bool isProvisional;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })?
  onPreviewChanged;
  final VoidCallback? onPreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })?
  onScheduleChanged;
  final ValueChanged<bool>? onInteractionChanged;

  @override
  State<_AgendaScheduleBlock> createState() => _AgendaScheduleBlockState();
}

enum _AgendaDragMode {
  move,
  resizeStart,
  resizeEnd,
  movePause,
  resizePauseStart,
  resizePauseEnd,
}

class _AgendaScheduleBlockState extends State<_AgendaScheduleBlock> {
  _AgendaDragMode? _dragMode;
  double _dragOffset = 0;
  double _dragMinutesPerPixel = 1;
  late int _dragStartMinutes;
  late int _dragEndMinutes;
  int? _dragPauseStartMinutes;
  int? _dragPauseEndMinutes;
  int? _previewStartMinutes;
  int? _previewEndMinutes;
  int? _previewBreakMinutes;
  int? _previewPauseStartMinutes;
  int? _previewPauseEndMinutes;

  @override
  void dispose() {
    widget.onInteractionChanged?.call(false);
    super.dispose();
  }

  int get _displayStartMinutes => _previewStartMinutes ?? widget.startMinutes;

  int get _displayEndMinutes => _previewEndMinutes ?? widget.endMinutes;

  _AgendaMeasurementSegment? _resolveFirstPauseSegment(
    List<_AgendaMeasurementSegment> segments,
  ) {
    for (final segment in segments) {
      if (segment.kind == _AgendaMeasurementSegmentKind.pause) {
        return segment;
      }
    }
    return null;
  }

  List<_AgendaMeasurementSegment> _buildSegmentsFromPauseWindow({
    required int startMinutes,
    required int endMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
    required List<_AgendaMeasurementSegment> fallbackSegments,
  }) {
    if (pauseStartMinutes == null ||
        pauseEndMinutes == null ||
        pauseEndMinutes <= pauseStartMinutes) {
      return fallbackSegments;
    }

    final segments = <_AgendaMeasurementSegment>[];
    if (pauseStartMinutes > startMinutes) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: startMinutes,
          endMinutes: pauseStartMinutes,
          label: '',
          kind: _AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    segments.add(
      _AgendaMeasurementSegment(
        startMinutes: pauseStartMinutes,
        endMinutes: pauseEndMinutes,
        label: '',
        kind: _AgendaMeasurementSegmentKind.pause,
      ),
    );
    if (pauseEndMinutes < endMinutes) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: pauseEndMinutes,
          endMinutes: endMinutes,
          label: '',
          kind: _AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    return segments;
  }

  List<_AgendaMeasurementSegment> _displaySegments({
    required int startMinutes,
    required int endMinutes,
  }) {
    final fallbackSegments = _resolveEffectiveAgendaSegments(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      measurementSegments: widget.measurementSegments,
    );
    return _buildSegmentsFromPauseWindow(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      pauseStartMinutes: _previewPauseStartMinutes,
      pauseEndMinutes: _previewPauseEndMinutes,
      fallbackSegments: fallbackSegments,
    );
  }

  void _emitPreviewChanged() {
    final committedStartMinutes = _previewStartMinutes ?? widget.startMinutes;
    final committedEndMinutes = _previewEndMinutes ?? widget.endMinutes;
    final committedBreakMinutes =
        (_previewPauseStartMinutes != null && _previewPauseEndMinutes != null)
        ? _previewPauseEndMinutes! - _previewPauseStartMinutes!
        : (_previewBreakMinutes ?? widget.schedule.breakMinutes);
    widget.onPreviewChanged?.call(
      startMinutes: committedStartMinutes,
      endMinutes: committedEndMinutes,
      breakMinutes: committedBreakMinutes,
      pauseStartMinutes: _previewPauseStartMinutes,
      pauseEndMinutes: _previewPauseEndMinutes,
    );
  }

  int _clampAgendaMinute(int minutes) {
    return minutes.clamp(0, (23 * 60) + 59).toInt();
  }

  void _handleDragStart(_AgendaDragMode mode) {
    final initialSegments = _displaySegments(
      startMinutes: _displayStartMinutes,
      endMinutes: _displayEndMinutes,
    );
    final pauseSegment = _resolveFirstPauseSegment(initialSegments);
    setState(() {
      _dragMode = mode;
      _dragOffset = 0;
      _dragMinutesPerPixel = widget.height <= 0
          ? 1
          : widget.range.totalMinutes / widget.height;
      _dragStartMinutes = _displayStartMinutes;
      _dragEndMinutes = _displayEndMinutes;
      _dragPauseStartMinutes = pauseSegment?.startMinutes;
      _dragPauseEndMinutes = pauseSegment?.endMinutes;
      _previewStartMinutes = _displayStartMinutes;
      _previewEndMinutes = _displayEndMinutes;
      _previewBreakMinutes = widget.schedule.breakMinutes;
      _previewPauseStartMinutes = pauseSegment?.startMinutes;
      _previewPauseEndMinutes = pauseSegment?.endMinutes;
    });
    widget.onInteractionChanged?.call(true);
    assert(() {
      debugPrint(
        '[agenda-drag-start] mode=$mode start=${formatTimeInput(_dragStartMinutes)} end=${formatTimeInput(_dragEndMinutes)} '
        'pauseStart=${_dragPauseStartMinutes == null ? '-' : formatTimeInput(_dragPauseStartMinutes!)} '
        'pauseEnd=${_dragPauseEndMinutes == null ? '-' : formatTimeInput(_dragPauseEndMinutes!)} '
        'minutesPerPixel=${_dragMinutesPerPixel.toStringAsFixed(4)}',
      );
      return true;
    }());
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragMode == null || widget.onScheduleChanged == null) {
      return;
    }

    _dragOffset += details.primaryDelta ?? 0;
    final durationMinutes = _dragEndMinutes - _dragStartMinutes;
    final deltaMinutes = (_dragOffset * _dragMinutesPerPixel).round();

    void applyPreview({
      required int startMinutes,
      required int endMinutes,
      int? pauseStartMinutes,
      int? pauseEndMinutes,
    }) {
      setState(() {
        _previewStartMinutes = startMinutes;
        _previewEndMinutes = endMinutes;
        _previewPauseStartMinutes = pauseStartMinutes;
        _previewPauseEndMinutes = pauseEndMinutes;
        _previewBreakMinutes =
            pauseStartMinutes != null && pauseEndMinutes != null
            ? pauseEndMinutes - pauseStartMinutes
            : math.min(widget.schedule.breakMinutes, endMinutes - startMinutes);
      });
      _emitPreviewChanged();
    }

    switch (_dragMode!) {
      case _AgendaDragMode.move:
        final maxStart = math.max(0, ((23 * 60) + 59) - durationMinutes);
        final clampedStart = _clampAgendaMinute(
          _dragStartMinutes + deltaMinutes,
        ).clamp(0, maxStart).toInt();
        final actualDeltaMinutes = clampedStart - _dragStartMinutes;
        final shiftedPauseStart = _dragPauseStartMinutes == null
            ? null
            : _dragPauseStartMinutes! + actualDeltaMinutes;
        final shiftedPauseEnd = _dragPauseEndMinutes == null
            ? null
            : _dragPauseEndMinutes! + actualDeltaMinutes;
        applyPreview(
          startMinutes: clampedStart,
          endMinutes: clampedStart + durationMinutes,
          pauseStartMinutes: shiftedPauseStart,
          pauseEndMinutes: shiftedPauseEnd,
        );
        return;
      case _AgendaDragMode.resizeStart:
        final clampedStart = _clampAgendaMinute(
          _dragStartMinutes + deltaMinutes,
        ).clamp(0, _dragEndMinutes - 1).toInt();
        final nextPauseStart = _dragPauseStartMinutes == null
            ? null
            : math.max(_dragPauseStartMinutes!, clampedStart);
        final nextPauseEnd = _dragPauseEndMinutes == null
            ? null
            : math.max(
                _dragPauseEndMinutes!,
                (nextPauseStart ?? clampedStart) + 1,
              );
        applyPreview(
          startMinutes: clampedStart,
          endMinutes: _dragEndMinutes,
          pauseStartMinutes: nextPauseStart,
          pauseEndMinutes: nextPauseEnd == null
              ? null
              : math.min(nextPauseEnd, _dragEndMinutes),
        );
        return;
      case _AgendaDragMode.resizeEnd:
        final clampedEnd = _clampAgendaMinute(
          _dragEndMinutes + deltaMinutes,
        ).clamp(_dragStartMinutes + 1, (23 * 60) + 59).toInt();
        final nextPauseStart = _dragPauseStartMinutes;
        final nextPauseEnd = _dragPauseEndMinutes == null
            ? null
            : math.min(_dragPauseEndMinutes!, clampedEnd);
        applyPreview(
          startMinutes: _dragStartMinutes,
          endMinutes: clampedEnd,
          pauseStartMinutes: nextPauseStart,
          pauseEndMinutes: nextPauseEnd,
        );
        return;
      case _AgendaDragMode.movePause:
        if (_dragPauseStartMinutes == null || _dragPauseEndMinutes == null) {
          return;
        }
        final pauseDurationMinutes =
            _dragPauseEndMinutes! - _dragPauseStartMinutes!;
        final clampedPauseStart = (_dragPauseStartMinutes! + deltaMinutes)
            .clamp(_dragStartMinutes, _dragEndMinutes - pauseDurationMinutes)
            .toInt();
        applyPreview(
          startMinutes: _dragStartMinutes,
          endMinutes: _dragEndMinutes,
          pauseStartMinutes: clampedPauseStart,
          pauseEndMinutes: clampedPauseStart + pauseDurationMinutes,
        );
        return;
      case _AgendaDragMode.resizePauseStart:
        if (_dragPauseStartMinutes == null || _dragPauseEndMinutes == null) {
          return;
        }
        final clampedPauseStart = (_dragPauseStartMinutes! + deltaMinutes)
            .clamp(_dragStartMinutes, _dragPauseEndMinutes! - 1)
            .toInt();
        applyPreview(
          startMinutes: _dragStartMinutes,
          endMinutes: _dragEndMinutes,
          pauseStartMinutes: clampedPauseStart,
          pauseEndMinutes: _dragPauseEndMinutes,
        );
        return;
      case _AgendaDragMode.resizePauseEnd:
        if (_dragPauseStartMinutes == null || _dragPauseEndMinutes == null) {
          return;
        }
        final clampedPauseEnd = (_dragPauseEndMinutes! + deltaMinutes)
            .clamp(_dragPauseStartMinutes! + 1, _dragEndMinutes)
            .toInt();
        applyPreview(
          startMinutes: _dragStartMinutes,
          endMinutes: _dragEndMinutes,
          pauseStartMinutes: _dragPauseStartMinutes,
          pauseEndMinutes: clampedPauseEnd,
        );
        return;
    }
  }

  void _handleDragEnd([DragEndDetails? _]) {
    final committedStartMinutes = _previewStartMinutes ?? widget.startMinutes;
    final committedEndMinutes = _previewEndMinutes ?? widget.endMinutes;
    final committedBreakMinutes =
        (_previewPauseStartMinutes != null && _previewPauseEndMinutes != null)
        ? _previewPauseEndMinutes! - _previewPauseStartMinutes!
        : (_previewBreakMinutes ?? widget.schedule.breakMinutes);
    final committedPauseStartMinutes = _previewPauseStartMinutes;
    final committedPauseEndMinutes = _previewPauseEndMinutes;
    final initialBreakMinutes =
        (_dragPauseStartMinutes != null && _dragPauseEndMinutes != null)
        ? _dragPauseEndMinutes! - _dragPauseStartMinutes!
        : widget.schedule.breakMinutes;
    final hasChanged =
        committedStartMinutes != _dragStartMinutes ||
        committedEndMinutes != _dragEndMinutes ||
        committedBreakMinutes != initialBreakMinutes ||
        committedPauseStartMinutes != _dragPauseStartMinutes ||
        committedPauseEndMinutes != _dragPauseEndMinutes;

    assert(() {
      debugPrint(
        '[agenda-drag-end] mode=$_dragMode changed=$hasChanged '
        'initialStart=${formatTimeInput(_dragStartMinutes)} initialEnd=${formatTimeInput(_dragEndMinutes)} '
        'start=${formatTimeInput(committedStartMinutes)} end=${formatTimeInput(committedEndMinutes)} '
        'break=$committedBreakMinutes '
        'pauseStart=${committedPauseStartMinutes == null ? '-' : formatTimeInput(committedPauseStartMinutes)} '
        'pauseEnd=${committedPauseEndMinutes == null ? '-' : formatTimeInput(committedPauseEndMinutes)}',
      );
      return true;
    }());

    if (!hasChanged || widget.onScheduleChanged == null) {
      setState(() {
        _dragMode = null;
        _dragOffset = 0;
        _previewStartMinutes = null;
        _previewEndMinutes = null;
        _previewBreakMinutes = null;
        _previewPauseStartMinutes = null;
        _previewPauseEndMinutes = null;
      });
      widget.onInteractionChanged?.call(false);
      widget.onPreviewCleared?.call();
      return;
    }

    setState(() {
      _dragMode = null;
      _dragOffset = 0;
    });
    widget.onInteractionChanged?.call(false);

    widget.onScheduleChanged!(
      startMinutes: committedStartMinutes,
      endMinutes: committedEndMinutes,
      breakMinutes: committedBreakMinutes,
      pauseStartMinutes: committedPauseStartMinutes,
      pauseEndMinutes: committedPauseEndMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDayMode = widget.displayMode == _AgendaSurfaceDisplayMode.day;
    final backgroundColor = widget.metrics.hasOverride
        ? Color.lerp(colorScheme.surface, colorScheme.secondary, 0.28)!
        : Color.lerp(colorScheme.surface, colorScheme.primary, 0.22)!;
    final surfaceFillColor = isDayMode ? Colors.transparent : backgroundColor;
    final segmentCanvasColor = isDayMode
        ? colorScheme.surfaceContainerHigh.withValues(
            alpha: isDark ? 0.72 : 0.94,
          )
        : surfaceFillColor;
    final borderColor = widget.metrics.hasOverride
        ? colorScheme.secondary
        : colorScheme.primary;
    final displayStartMinutes = _previewStartMinutes ?? widget.startMinutes;
    final displayEndMinutes = _previewEndMinutes ?? widget.endMinutes;
    final effectiveSegments = _displaySegments(
      startMinutes: displayStartMinutes,
      endMinutes: displayEndMinutes,
    );
    final pauseSegment = _resolveFirstPauseSegment(effectiveSegments);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showHandles =
            widget.displayMode == _AgendaSurfaceDisplayMode.day &&
            widget.onScheduleChanged != null &&
            constraints.maxHeight >= 72;
        final textColor = widget.metrics.hasOverride
            ? colorScheme.onSecondaryContainer
            : colorScheme.onPrimaryContainer;
        final verticalInset = isDayMode ? 0.0 : 6.0;
        final drawableHeight = math.max(
          1.0,
          constraints.maxHeight - (verticalInset * 2),
        );
        final blockDurationMinutes = math.max(
          1,
          displayEndMinutes - displayStartMinutes,
        );
        double localTopForMinute(int minute) {
          final clampedMinute = minute.clamp(
            displayStartMinutes,
            displayEndMinutes,
          );
          final normalizedMinute =
              (clampedMinute - displayStartMinutes) / blockDurationMinutes;
          return verticalInset + (normalizedMinute * drawableHeight);
        }

        final content = Container(
          padding: EdgeInsets.fromLTRB(10, verticalInset, 10, verticalInset),
          decoration: BoxDecoration(
            color: surfaceFillColor,
            borderRadius: BorderRadius.circular(18),
            border: isDayMode
                ? null
                : Border.all(color: borderColor, width: 1.2),
            boxShadow: isDayMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.08,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              if (widget.isProvisional)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                        painter: _AgendaTentativeOverlayPainter(
                          color: textColor.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ),
                ),
              DefaultTextStyle(
                style:
                    theme.textTheme.bodySmall?.copyWith(color: textColor) ??
                    TextStyle(color: textColor),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, bodyConstraints) {
                          final interactiveHeight = bodyConstraints.maxHeight;
                          return GestureDetector(
                            dragStartBehavior: DragStartBehavior.down,
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart:
                                widget.onScheduleChanged == null
                                ? null
                                : (_) => _handleDragStart(_AgendaDragMode.move),
                            onVerticalDragUpdate:
                                widget.onScheduleChanged == null
                                ? null
                                : _handleDragUpdate,
                            onVerticalDragEnd: widget.onScheduleChanged == null
                                ? null
                                : _handleDragEnd,
                            child: Stack(
                              children: [
                                if (widget.displayMode ==
                                        _AgendaSurfaceDisplayMode.day ||
                                    widget.displayMode ==
                                        _AgendaSurfaceDisplayMode.week)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: segmentCanvasColor,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: _AgendaSegmentFillOverlay(
                                            startMinutes: displayStartMinutes,
                                            endMinutes: displayEndMinutes,
                                            segments: effectiveSegments,
                                            workColor: colorScheme.primary
                                                .withValues(
                                                  alpha:
                                                      widget.displayMode ==
                                                          _AgendaSurfaceDisplayMode
                                                              .day
                                                      ? 0.3
                                                      : 0.26,
                                                ),
                                            pauseColor: colorScheme.secondary
                                                .withValues(
                                                  alpha:
                                                      widget.displayMode ==
                                                          _AgendaSurfaceDisplayMode
                                                              .day
                                                      ? 0.68
                                                      : 0.62,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (widget.displayMode ==
                                        _AgendaSurfaceDisplayMode.day &&
                                    pauseSegment != null)
                                  _AgendaPauseEditOverlay(
                                    range: widget.range,
                                    height: interactiveHeight,
                                    blockStartMinutes: displayStartMinutes,
                                    blockEndMinutes: displayEndMinutes,
                                    pauseSegment: pauseSegment,
                                    onMovePauseStart:
                                        widget.onScheduleChanged == null
                                        ? null
                                        : () => _handleDragStart(
                                            _AgendaDragMode.movePause,
                                          ),
                                    onResizePauseStart:
                                        widget.onScheduleChanged == null
                                        ? null
                                        : () => _handleDragStart(
                                            _AgendaDragMode.resizePauseStart,
                                          ),
                                    onResizePauseEnd:
                                        widget.onScheduleChanged == null
                                        ? null
                                        : () => _handleDragStart(
                                            _AgendaDragMode.resizePauseEnd,
                                          ),
                                    onDragUpdate:
                                        widget.onScheduleChanged == null
                                        ? null
                                        : _handleDragUpdate,
                                    onDragEnd: widget.onScheduleChanged == null
                                        ? null
                                        : _handleDragEnd,
                                    chipColor: colorScheme.secondary,
                                    surfaceColor: colorScheme.surface,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (showHandles)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            dragStartBehavior: DragStartBehavior.down,
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) =>
                                _handleDragStart(_AgendaDragMode.resizeStart),
                            onVerticalDragUpdate: _handleDragUpdate,
                            onVerticalDragEnd: _handleDragEnd,
                            child: _AgendaResizeHandle(color: textColor),
                          ),
                        ),
                      ),
                    if (showHandles)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: GestureDetector(
                            dragStartBehavior: DragStartBehavior.down,
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) =>
                                _handleDragStart(_AgendaDragMode.resizeEnd),
                            onVerticalDragUpdate: _handleDragUpdate,
                            onVerticalDragEnd: _handleDragEnd,
                            child: _AgendaResizeHandle(color: textColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

        final decoratedContent =
            widget.displayMode == _AgendaSurfaceDisplayMode.day ||
                widget.displayMode == _AgendaSurfaceDisplayMode.week
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  content,
                  Positioned(
                    top: widget.displayMode == _AgendaSurfaceDisplayMode.day
                        ? -12
                        : -10,
                    right: widget.displayMode == _AgendaSurfaceDisplayMode.day
                        ? 12
                        : 8,
                    child: _AgendaDragTimeChip(
                      label: formatTimeInput(displayStartMinutes),
                      compact:
                          widget.displayMode == _AgendaSurfaceDisplayMode.week,
                    ),
                  ),
                  Positioned(
                    bottom: widget.displayMode == _AgendaSurfaceDisplayMode.day
                        ? -12
                        : -10,
                    right: widget.displayMode == _AgendaSurfaceDisplayMode.day
                        ? 12
                        : 8,
                    child: _AgendaDragTimeChip(
                      label: formatTimeInput(displayEndMinutes),
                      compact:
                          widget.displayMode == _AgendaSurfaceDisplayMode.week,
                    ),
                  ),
                  if (pauseSegment != null) ...[
                    Positioned(
                      top:
                          localTopForMinute(pauseSegment.startMinutes) -
                          (widget.displayMode == _AgendaSurfaceDisplayMode.day
                              ? 12
                              : 10),
                      left: widget.displayMode == _AgendaSurfaceDisplayMode.day
                          ? 12
                          : 8,
                      child: _AgendaDragTimeChip(
                        label: formatTimeInput(pauseSegment.startMinutes),
                        accentColor: colorScheme.secondary,
                        compact:
                            widget.displayMode ==
                            _AgendaSurfaceDisplayMode.week,
                      ),
                    ),
                    Positioned(
                      top:
                          localTopForMinute(pauseSegment.endMinutes) -
                          (widget.displayMode == _AgendaSurfaceDisplayMode.day
                              ? 12
                              : 10),
                      left: widget.displayMode == _AgendaSurfaceDisplayMode.day
                          ? 12
                          : 8,
                      child: _AgendaDragTimeChip(
                        label: formatTimeInput(pauseSegment.endMinutes),
                        accentColor: colorScheme.secondary,
                        compact:
                            widget.displayMode ==
                            _AgendaSurfaceDisplayMode.week,
                      ),
                    ),
                  ],
                ],
              )
            : content;

        if (widget.onScheduleChanged == null) {
          return decoratedContent;
        }

        return MouseRegion(
          cursor: SystemMouseCursors.move,
          child: decoratedContent,
        );
      },
    );
  }
}

class _AgendaResizeHandle extends StatelessWidget {
  const _AgendaResizeHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 18,
      alignment: Alignment.center,
      child: Container(
        width: 28,
        height: 4,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _AgendaDragTimeChip extends StatelessWidget {
  const _AgendaDragTimeChip({
    required this.label,
    this.accentColor,
    this.compact = false,
  });

  final String label;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = accentColor ?? theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style:
            (compact ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)
                ?.copyWith(color: borderColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AgendaPauseEditOverlay extends StatelessWidget {
  const _AgendaPauseEditOverlay({
    required this.range,
    required this.height,
    required this.blockStartMinutes,
    required this.blockEndMinutes,
    required this.pauseSegment,
    required this.chipColor,
    required this.surfaceColor,
    this.onMovePauseStart,
    this.onResizePauseStart,
    this.onResizePauseEnd,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final _AgendaRange range;
  final double height;
  final int blockStartMinutes;
  final int blockEndMinutes;
  final _AgendaMeasurementSegment pauseSegment;
  final Color chipColor;
  final Color surfaceColor;
  final VoidCallback? onMovePauseStart;
  final VoidCallback? onResizePauseStart;
  final VoidCallback? onResizePauseEnd;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = math.max(1, blockEndMinutes - blockStartMinutes);
    final pauseTop =
        ((pauseSegment.startMinutes - blockStartMinutes) / totalMinutes) *
        height;
    final pauseHeight = math
        .max(
          16,
          ((pauseSegment.endMinutes - pauseSegment.startMinutes) /
                  totalMinutes) *
              height,
        )
        .toDouble();

    return Positioned(
      top: pauseTop,
      left: 14,
      right: 14,
      height: pauseHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              dragStartBehavior: DragStartBehavior.down,
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: onMovePauseStart == null
                  ? null
                  : (_) => onMovePauseStart!(),
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: chipColor.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                dragStartBehavior: DragStartBehavior.down,
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: onResizePauseStart == null
                    ? null
                    : (_) => onResizePauseStart!(),
                onVerticalDragUpdate: onDragUpdate,
                onVerticalDragEnd: onDragEnd,
                child: _AgendaResizeHandle(color: surfaceColor),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                dragStartBehavior: DragStartBehavior.down,
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: onResizePauseEnd == null
                    ? null
                    : (_) => onResizePauseEnd!(),
                onVerticalDragUpdate: onDragUpdate,
                onVerticalDragEnd: onDragEnd,
                child: _AgendaResizeHandle(color: surfaceColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaSegmentFillOverlay extends StatelessWidget {
  const _AgendaSegmentFillOverlay({
    required this.startMinutes,
    required this.endMinutes,
    required this.segments,
    required this.workColor,
    required this.pauseColor,
  });

  final int startMinutes;
  final int endMinutes;
  final List<_AgendaMeasurementSegment> segments;
  final Color workColor;
  final Color pauseColor;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = math.max(1, endMinutes - startMinutes);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final segment in segments)
              () {
                final segmentHeight = math
                    .max(
                      10,
                      ((segment.endMinutes - segment.startMinutes) /
                              totalMinutes) *
                          constraints.maxHeight,
                    )
                    .toDouble();
                final segmentColor =
                    segment.kind == _AgendaMeasurementSegmentKind.pause
                    ? pauseColor
                    : workColor;
                final segmentMinutes =
                    segment.endMinutes - segment.startMinutes;
                final showLabel =
                    segmentHeight >= 34 && constraints.maxWidth >= 72;
                return Positioned(
                  top:
                      ((segment.startMinutes - startMinutes) / totalMinutes) *
                      constraints.maxHeight,
                  left: 0,
                  right: 0,
                  height: segmentHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: segmentColor),
                    child: showLabel
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                _formatHoursInput(segmentMinutes),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color:
                                      ThemeData.estimateBrightnessForColor(
                                            segmentColor,
                                          ) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black.withValues(alpha: 0.78),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}

class _AgendaTentativeOverlayPainter extends CustomPainter {
  const _AgendaTentativeOverlayPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const spacing = 14.0;
    for (double startX = -size.height; startX < size.width; startX += spacing) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AgendaTentativeOverlayPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

enum _AgendaMeasurementSegmentKind { work, pause }

class _AgendaMeasurementSegment {
  const _AgendaMeasurementSegment({
    required this.startMinutes,
    required this.endMinutes,
    required this.label,
    required this.kind,
  });

  final int startMinutes;
  final int endMinutes;
  final String label;
  final _AgendaMeasurementSegmentKind kind;
}

List<_AgendaMeasurementSegment> _resolveEffectiveAgendaSegments({
  required int startMinutes,
  required int endMinutes,
  required List<_AgendaMeasurementSegment> measurementSegments,
}) {
  if (measurementSegments.isEmpty) {
    return [
      _AgendaMeasurementSegment(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        label: '',
        kind: _AgendaMeasurementSegmentKind.work,
      ),
    ];
  }

  return [
    for (final segment in measurementSegments)
      if (segment.endMinutes > startMinutes &&
          segment.startMinutes < endMinutes)
        _AgendaMeasurementSegment(
          startMinutes: math.max(segment.startMinutes, startMinutes),
          endMinutes: math.min(segment.endMinutes, endMinutes),
          label: segment.label,
          kind: segment.kind,
        ),
  ];
}

class _CalendarMonthSummary extends StatelessWidget {
  const _CalendarMonthSummary({
    required this.days,
    required this.monthMetrics,
    required this.onOpenDay,
  });

  final List<_CalendarDay> days;
  final _MonthMetrics monthMetrics;
  final Future<void> Function(DateTime date) onOpenDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WeekdayHeader(),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompactCalendar = constraints.maxWidth < 420;
            final isUltraCompactCalendar = constraints.maxWidth < 460;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: isCompactCalendar ? 6 : 8,
                mainAxisSpacing: isCompactCalendar ? 6 : 8,
                childAspectRatio: isUltraCompactCalendar
                    ? 1.12
                    : isCompactCalendar
                    ? 0.9
                    : 0.82,
              ),
              itemBuilder: (context, index) {
                final day = days[index];
                return _CalendarDayCell(
                  day: day,
                  isCompact: isCompactCalendar,
                  onTap: day.date == null
                      ? null
                      : () => unawaited(onOpenDay(day.date!)),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CalendarYearSummary extends StatelessWidget {
  const _CalendarYearSummary({
    required this.yearMetrics,
    required this.onOpenMonth,
  });

  final List<_MonthMetrics> yearMetrics;
  final ValueChanged<String> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: yearMetrics
              .map(
                (metrics) => _YearMonthCard(
                  metrics: metrics,
                  onTap: () => onOpenMonth(metrics.month),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const weekDays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

    return Row(
      children: weekDays
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isCompact,
    required this.onTap,
  });

  final _CalendarDay day;
  final bool isCompact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (day.date == null) {
      return const SizedBox.shrink();
    }

    final isSelected = day.isSelected;
    final baseBackgroundColor = switch (day.relation) {
      _CalendarDayRelation.past => Color.lerp(
        colorScheme.surface,
        colorScheme.secondary,
        0.12,
      )!,
      _CalendarDayRelation.today => Color.lerp(
        colorScheme.surface,
        colorScheme.primary,
        0.2,
      )!,
      _CalendarDayRelation.future => Color.lerp(
        colorScheme.surface,
        colorScheme.tertiary,
        0.1,
      )!,
    };
    final backgroundColor = isSelected
        ? Color.lerp(baseBackgroundColor, colorScheme.primary, 0.18)!
        : baseBackgroundColor;
    final borderColor = switch (day.relation) {
      _CalendarDayRelation.past => colorScheme.secondary,
      _CalendarDayRelation.today => colorScheme.primary,
      _CalendarDayRelation.future => colorScheme.tertiary,
    };
    final textColor = switch (day.relation) {
      _CalendarDayRelation.past => colorScheme.onSecondaryContainer,
      _CalendarDayRelation.today => colorScheme.onPrimaryContainer,
      _CalendarDayRelation.future => colorScheme.onTertiaryContainer,
    };
    final detailColor = textColor.withValues(alpha: 0.88);
    final workColor = switch (day.relation) {
      _CalendarDayRelation.past => colorScheme.secondary,
      _CalendarDayRelation.today => colorScheme.primary,
      _CalendarDayRelation.future => colorScheme.tertiary,
    };
    final pauseColor = Color.lerp(workColor, colorScheme.secondary, 0.6)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isUltraCompactCell = constraints.maxWidth < 68;
        final isMicroCell =
            constraints.maxWidth < 56 || constraints.maxHeight < 40;
        final isTinySummaryCell =
            isUltraCompactCell ||
            constraints.maxWidth < 86 ||
            constraints.maxHeight < 80;
        final isTooShortForSummary =
            constraints.maxHeight < 64 || constraints.maxWidth < 56;
        final dayNumberAlignment = isTooShortForSummary
            ? Alignment.center
            : Alignment.centerLeft;
        final cellPadding = isMicroCell
            ? 3.0
            : (isUltraCompactCell ? 5.0 : (isCompact ? 7.0 : 9.0));
        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('calendar-day-${day.isoDate}'),
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              padding: EdgeInsets.all(cellPadding),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: isSelected || day.isToday ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: isTooShortForSummary
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                crossAxisAlignment: isTooShortForSummary
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: dayNumberAlignment,
                    child: Text(
                      '${day.date!.day}',
                      maxLines: 1,
                      softWrap: false,
                      style:
                          (isMicroCell
                                  ? Theme.of(context).textTheme.labelLarge
                                  : isUltraCompactCell
                                  ? Theme.of(context).textTheme.titleSmall
                                  : Theme.of(context).textTheme.titleMedium)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                    ),
                  ),
                  if (!isTooShortForSummary) ...[
                    SizedBox(
                      height: isMicroCell
                          ? 1
                          : (isUltraCompactCell ? 3 : (isCompact ? 4 : 6)),
                    ),
                    Expanded(
                      child: isTinySummaryCell
                          ? _MonthCellTinySummary(
                              day: day,
                              details: day.details,
                              detailColor: detailColor,
                              workColor: workColor,
                              pauseColor: pauseColor,
                            )
                          : day.details == null
                          ? _MonthCellFallback(
                              day: day,
                              detailColor: detailColor,
                            )
                          : _MonthCellCompactSummary(
                              details: day.details!,
                              textColor: detailColor,
                              workColor: workColor,
                              pauseColor: pauseColor,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthCellFallback extends StatelessWidget {
  const _MonthCellFallback({required this.day, required this.detailColor});

  final _CalendarDay day;
  final Color detailColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (day.primaryLabel != null)
            Text(
              day.primaryLabel!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: detailColor,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (day.secondaryLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              day.secondaryLabel!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: detailColor.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthCellCompactSummary extends StatelessWidget {
  const _MonthCellCompactSummary({
    required this.details,
    required this.textColor,
    required this.workColor,
    required this.pauseColor,
  });

  final _CalendarDayDetails details;
  final Color textColor;
  final Color workColor;
  final Color pauseColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Center(
            child: _MonthMiniTimeline(
              details: details,
              workColor: workColor,
              pauseColor: pauseColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _MonthDataToken(
          color: workColor,
          label: _formatHoursInput(details.workedMinutes),
          textColor: textColor,
        ),
        const SizedBox(height: 2),
        _MonthDataToken(
          color: pauseColor,
          label: _formatHoursInput(details.pauseMinutes),
          textColor: textColor.withValues(alpha: 0.92),
        ),
      ],
    );
  }
}

class _MonthCellTinySummary extends StatelessWidget {
  const _MonthCellTinySummary({
    required this.day,
    required this.details,
    required this.detailColor,
    required this.workColor,
    required this.pauseColor,
  });

  final _CalendarDay day;
  final _CalendarDayDetails? details;
  final Color detailColor;
  final Color workColor;
  final Color pauseColor;

  @override
  Widget build(BuildContext context) {
    final hasWorkedData =
        details != null &&
        (details!.workedMinutes > 0 || details!.pauseMinutes > 0);
    final isDayOff =
        details == null && (day.primaryLabel?.startsWith('Libero') ?? false);

    return Stack(
      children: [
        if (details != null)
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: _MonthMiniTimeline(
                  details: details!,
                  workColor: workColor,
                  pauseColor: pauseColor,
                ),
              ),
            ),
          ),
        if (hasWorkedData || isDayOff)
          Positioned(
            left: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MonthTinyIndicator(
                  color: isDayOff
                      ? detailColor.withValues(alpha: 0.7)
                      : workColor,
                ),
                if (hasWorkedData && details!.pauseMinutes > 0) ...[
                  const SizedBox(width: 4),
                  _MonthTinyIndicator(color: pauseColor),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthMiniTimeline extends StatelessWidget {
  const _MonthMiniTimeline({
    required this.details,
    required this.workColor,
    required this.pauseColor,
  });

  final _CalendarDayDetails details;
  final Color workColor;
  final Color pauseColor;

  @override
  Widget build(BuildContext context) {
    final startMinutes = details.startMinutes;
    final endMinutes = details.endMinutes;
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return Container(
        width: 10,
        decoration: BoxDecoration(
          color: workColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    final pauseStartMinutes = details.pauseStartMinutes;
    final resumeMinutes = details.resumeMinutes;
    final totalMinutes = endMinutes - startMinutes;

    return SizedBox(
      width: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double topFor(int minutes) =>
              ((minutes - startMinutes) / totalMinutes) * constraints.maxHeight;
          double heightFor(int from, int to) =>
              math.max(6, ((to - from) / totalMinutes) * constraints.maxHeight);

          return Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: workColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              if (pauseStartMinutes != null &&
                  resumeMinutes != null &&
                  resumeMinutes > pauseStartMinutes) ...[
                Positioned(
                  top: 0,
                  left: 2,
                  right: 2,
                  height: heightFor(startMinutes, pauseStartMinutes),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: workColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  top: topFor(pauseStartMinutes),
                  left: 2,
                  right: 2,
                  height: heightFor(pauseStartMinutes, resumeMinutes),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: pauseColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  top: topFor(resumeMinutes),
                  left: 2,
                  right: 2,
                  height: heightFor(resumeMinutes, endMinutes),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: workColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ] else
                Positioned(
                  top: 0,
                  left: 2,
                  right: 2,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: workColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthTinyIndicator extends StatelessWidget {
  const _MonthTinyIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MonthDataToken extends StatelessWidget {
  const _MonthDataToken({
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InlineInfoPanel extends StatelessWidget {
  const _InlineInfoPanel({
    required this.title,
    required this.description,
    required this.statusText,
  });

  final String title;
  final String description;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162121) : const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _YearMonthCard extends StatelessWidget {
  const _YearMonthCard({required this.metrics, required this.onTap});

  final _MonthMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162121) : const Color(0xFFF7F3EC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatMonthLabel(metrics.month),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (metrics.overrideCount > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    metrics.overrideCount == 1
                        ? '1 modifica presente'
                        : '${metrics.overrideCount} modifiche presenti',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.weekPlan,
    required this.onOpenDay,
    required this.onOpenWorkEntry,
    required this.onOpenLeaveEntry,
  });

  final List<_WeekPlanDay> weekPlan;
  final Future<void> Function(DateTime date) onOpenDay;
  final void Function(DateTime date, {int? prefilledMinutes, String? note})
  onOpenWorkEntry;
  final void Function(
    DateTime date, {
    int? prefilledMinutes,
    LeaveType leaveType,
    String? note,
  })
  onOpenLeaveEntry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Settimana',
      subtitle:
          'Controlla in pochi secondi i prossimi 7 giorni, con stato e fascia prevista.',
      child: Column(
        children: [
          for (var index = 0; index < weekPlan.length; index += 1) ...[
            _WeekPlanRow(
              day: weekPlan[index],
              onOpenDay: () => onOpenDay(weekPlan[index].date),
              onOpenWorkEntry: () => onOpenWorkEntry(
                weekPlan[index].date,
                prefilledMinutes: weekPlan[index].metrics.expectedMinutes,
              ),
              onOpenLeaveEntry: () => onOpenLeaveEntry(
                weekPlan[index].date,
                prefilledMinutes: weekPlan[index].metrics.expectedMinutes == 0
                    ? null
                    : weekPlan[index].metrics.expectedMinutes,
                leaveType: LeaveType.permit,
              ),
            ),
            if (index < weekPlan.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _WeekPlanRow extends StatelessWidget {
  const _WeekPlanRow({
    required this.day,
    required this.onOpenDay,
    required this.onOpenWorkEntry,
    required this.onOpenLeaveEntry,
  });

  final _WeekPlanDay day;
  final VoidCallback onOpenDay;
  final VoidCallback onOpenWorkEntry;
  final VoidCallback onOpenLeaveEntry;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _todayStatusMeta(context, day.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatLongDate(day.date),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatScheduleWindowDetails(day.metrics.schedule),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _TodayStatusBadge(
              label: statusMeta.label,
              color: statusMeta.color,
              icon: statusMeta.icon,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onOpenDay,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Apri giorno'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenWorkEntry,
              icon: const Icon(Icons.work_history_outlined),
              label: const Text('Registra'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenLeaveEntry,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Assenza'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.formKey,
    required this.fullNameController,
    required this.isBusy,
    required this.isReloading,
    required this.isDarkTheme,
    required this.appearanceSettings,
    required this.availableUpdate,
    required this.isCheckingForUpdate,
    required this.isOpeningUpdate,
    required this.isBackgroundUpdateDownloadInProgress,
    required this.backgroundUpdateProgress,
    required this.backgroundUpdate,
    required this.isUpdatingThemeMode,
    required this.accountSession,
    required this.selectedAuthMode,
    required this.accountEmailController,
    required this.accountPasswordController,
    required this.isAuthenticatingAccount,
    required this.isRecoveringPassword,
    required this.isRestoringCloudBackup,
    required this.isSyncingCloudBackup,
    required this.onDarkThemeChanged,
    required this.onOpenUpdateFromSettings,
    required this.onAppearanceSettingsChanged,
    required this.onRegisterAccount,
    required this.onLoginAccount,
    required this.onAuthModeChanged,
    required this.onOpenPasswordRecovery,
    required this.onBackupNow,
    required this.onRestoreCloudBackup,
    required this.onLogoutAccount,
    required this.onReload,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final bool isBusy;
  final bool isReloading;
  final bool isDarkTheme;
  final AppAppearanceSettings appearanceSettings;
  final AppUpdate? availableUpdate;
  final bool isCheckingForUpdate;
  final bool isOpeningUpdate;
  final bool isBackgroundUpdateDownloadInProgress;
  final UpdateDownloadProgress backgroundUpdateProgress;
  final AppUpdate? backgroundUpdate;
  final bool isUpdatingThemeMode;
  final AccountSession? accountSession;
  final _AccountAuthMode selectedAuthMode;
  final TextEditingController accountEmailController;
  final TextEditingController accountPasswordController;
  final bool isAuthenticatingAccount;
  final bool isRecoveringPassword;
  final bool isRestoringCloudBackup;
  final bool isSyncingCloudBackup;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function() onOpenUpdateFromSettings;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;
  final Future<void> Function() onRegisterAccount;
  final Future<void> Function() onLoginAccount;
  final ValueChanged<_AccountAuthMode> onAuthModeChanged;
  final Future<void> Function() onOpenPasswordRecovery;
  final Future<void> Function() onBackupNow;
  final Future<void> Function() onRestoreCloudBackup;
  final Future<void> Function() onLogoutAccount;
  final Future<void> Function() onReload;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Impostazioni app',
      subtitle: 'Gestisci profilo, backup e aspetto dell app.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci il nome completo.';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy || isReloading ? null : () => onReload(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(isReloading ? 'Carico...' : 'Carica profilo'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy || isReloading ? null : () => onSubmit(),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isBusy ? 'Salvo...' : 'Salva nome'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            _CloudBackupAccountCard(
              accountSession: accountSession,
              selectedAuthMode: selectedAuthMode,
              emailController: accountEmailController,
              passwordController: accountPasswordController,
              isAuthenticating: isAuthenticatingAccount,
              isRecoveringPassword: isRecoveringPassword,
              isRestoring: isRestoringCloudBackup,
              isSyncing: isSyncingCloudBackup,
              onRegister: onRegisterAccount,
              onLogin: onLoginAccount,
              onAuthModeChanged: onAuthModeChanged,
              onOpenPasswordRecovery: onOpenPasswordRecovery,
              onBackupNow: onBackupNow,
              onRestoreFromCloud: onRestoreCloudBackup,
              onLogout: onLogoutAccount,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            _AppUpdateSettingsCard(
              availableUpdate: availableUpdate,
              isCheckingForUpdate: isCheckingForUpdate,
              isOpeningUpdate: isOpeningUpdate,
              isBackgroundDownloadInProgress:
                  isBackgroundUpdateDownloadInProgress,
              backgroundDownloadProgress: backgroundUpdateProgress,
              backgroundUpdate: backgroundUpdate,
              onPressed: onOpenUpdateFromSettings,
            ),
            const SizedBox(height: 20),
            _AppearanceSettingsPanel(
              isDarkTheme: isDarkTheme,
              appearanceSettings: appearanceSettings,
              isUpdatingThemeMode: isUpdatingThemeMode,
              onDarkThemeChanged: onDarkThemeChanged,
              onAppearanceSettingsChanged: onAppearanceSettingsChanged,
            ),
            const SizedBox(height: 20),
            _DayCalendarSettingsCard(
              appearanceSettings: appearanceSettings,
              isUpdatingThemeMode: isUpdatingThemeMode,
              onAppearanceSettingsChanged: onAppearanceSettingsChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkSettingsCard extends StatelessWidget {
  const _WorkSettingsCard({
    required this.formKey,
    required this.appearanceSettings,
    required this.useUniformDailyTarget,
    required this.onUniformDailyTargetChanged,
    required this.uniformDailyTargetController,
    required this.uniformStartTimeController,
    required this.uniformEndTimeController,
    required this.uniformBreakController,
    required this.rulesMinimumBreakController,
    required this.rulesMaximumDailyCreditController,
    required this.rulesMaximumDailyDebitController,
    required this.rulesMaximumMonthlyCreditController,
    required this.rulesMaximumMonthlyDebitController,
    required this.rulesOvertimeEnabled,
    required this.rulesOvertimeCapEnabled,
    required this.rulesFixedScheduleEnabled,
    required this.rulesFlexibleStartEnabled,
    required this.rulesWalletEnabled,
    required this.rulesImplicitCreditEnabled,
    required this.rulesOvertimeDailyCapController,
    required this.rulesOvertimeWeeklyCapController,
    required this.rulesOvertimeMonthlyCapController,
    required this.rulesFlexibleStartWindowController,
    required this.rulesWalletDailyExitController,
    required this.rulesWalletWeeklyExitController,
    required this.rulesImplicitCreditDailyCapController,
    required this.rulesAdditionalPermissions,
    required this.rulesLeaveBanks,
    required this.weekdayControllers,
    required this.weekdayStartTimeControllers,
    required this.weekdayEndTimeControllers,
    required this.weekdayBreakControllers,
    required this.isBusy,
    required this.isReloading,
    required this.onPickUniformTargetMinutes,
    required this.onPickUniformScheduleTime,
    required this.onPickUniformBreakMinutes,
    required this.onUniformLunchBreakChanged,
    required this.onPickRulesMinimumBreakMinutes,
    required this.onPickRulesMaximumDailyCreditMinutes,
    required this.onPickRulesMaximumDailyDebitMinutes,
    required this.onPickRulesMaximumMonthlyCreditMinutes,
    required this.onPickRulesMaximumMonthlyDebitMinutes,
    required this.onRulesOvertimeEnabledChanged,
    required this.onRulesOvertimeCapEnabledChanged,
    required this.onRulesFixedScheduleEnabledChanged,
    required this.onRulesFlexibleStartEnabledChanged,
    required this.onRulesWalletEnabledChanged,
    required this.onRulesImplicitCreditEnabledChanged,
    required this.onPickRulesOvertimeDailyCapMinutes,
    required this.onPickRulesOvertimeWeeklyCapMinutes,
    required this.onPickRulesOvertimeMonthlyCapMinutes,
    required this.onPickRulesFlexibleStartWindowMinutes,
    required this.onPickRulesWalletDailyExitMinutes,
    required this.onPickRulesWalletWeeklyExitMinutes,
    required this.onPickRulesImplicitCreditDailyCapMinutes,
    required this.onAddAdditionalPermission,
    required this.onAddLeaveBank,
    required this.onRemoveAdditionalPermission,
    required this.onRemoveLeaveBank,
    required this.onPickWeekdayTargetMinutes,
    required this.onPickWeekdayScheduleTime,
    required this.onPickWeekdayBreakMinutes,
    required this.onWeekdayLunchBreakChanged,
    required this.onWeekdayWorkingDayChanged,
    required this.onAppearanceSettingsChanged,
    required this.onReload,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final AppAppearanceSettings appearanceSettings;
  final bool useUniformDailyTarget;
  final ValueChanged<bool> onUniformDailyTargetChanged;
  final TextEditingController uniformDailyTargetController;
  final TextEditingController uniformStartTimeController;
  final TextEditingController uniformEndTimeController;
  final TextEditingController uniformBreakController;
  final TextEditingController rulesMinimumBreakController;
  final TextEditingController rulesMaximumDailyCreditController;
  final TextEditingController rulesMaximumDailyDebitController;
  final TextEditingController rulesMaximumMonthlyCreditController;
  final TextEditingController rulesMaximumMonthlyDebitController;
  final bool rulesOvertimeEnabled;
  final bool rulesOvertimeCapEnabled;
  final bool rulesFixedScheduleEnabled;
  final bool rulesFlexibleStartEnabled;
  final bool rulesWalletEnabled;
  final bool rulesImplicitCreditEnabled;
  final TextEditingController rulesOvertimeDailyCapController;
  final TextEditingController rulesOvertimeWeeklyCapController;
  final TextEditingController rulesOvertimeMonthlyCapController;
  final TextEditingController rulesFlexibleStartWindowController;
  final TextEditingController rulesWalletDailyExitController;
  final TextEditingController rulesWalletWeeklyExitController;
  final TextEditingController rulesImplicitCreditDailyCapController;
  final List<WorkPermissionRule> rulesAdditionalPermissions;
  final List<WorkPermissionRule> rulesLeaveBanks;
  final Map<WeekdayKey, TextEditingController> weekdayControllers;
  final Map<WeekdayKey, TextEditingController> weekdayStartTimeControllers;
  final Map<WeekdayKey, TextEditingController> weekdayEndTimeControllers;
  final Map<WeekdayKey, TextEditingController> weekdayBreakControllers;
  final bool isBusy;
  final bool isReloading;
  final Future<void> Function() onPickUniformTargetMinutes;
  final Future<void> Function(_CalendarTimeField field)
  onPickUniformScheduleTime;
  final Future<void> Function() onPickUniformBreakMinutes;
  final ValueChanged<bool> onUniformLunchBreakChanged;
  final Future<void> Function() onPickRulesMinimumBreakMinutes;
  final Future<void> Function() onPickRulesMaximumDailyCreditMinutes;
  final Future<void> Function() onPickRulesMaximumDailyDebitMinutes;
  final Future<void> Function() onPickRulesMaximumMonthlyCreditMinutes;
  final Future<void> Function() onPickRulesMaximumMonthlyDebitMinutes;
  final ValueChanged<bool> onRulesOvertimeEnabledChanged;
  final ValueChanged<bool> onRulesOvertimeCapEnabledChanged;
  final ValueChanged<bool> onRulesFixedScheduleEnabledChanged;
  final ValueChanged<bool> onRulesFlexibleStartEnabledChanged;
  final ValueChanged<bool> onRulesWalletEnabledChanged;
  final ValueChanged<bool> onRulesImplicitCreditEnabledChanged;
  final Future<void> Function() onPickRulesOvertimeDailyCapMinutes;
  final Future<void> Function() onPickRulesOvertimeWeeklyCapMinutes;
  final Future<void> Function() onPickRulesOvertimeMonthlyCapMinutes;
  final Future<void> Function() onPickRulesFlexibleStartWindowMinutes;
  final Future<void> Function() onPickRulesWalletDailyExitMinutes;
  final Future<void> Function() onPickRulesWalletWeeklyExitMinutes;
  final Future<void> Function() onPickRulesImplicitCreditDailyCapMinutes;
  final Future<void> Function() onAddAdditionalPermission;
  final Future<void> Function() onAddLeaveBank;
  final ValueChanged<String> onRemoveAdditionalPermission;
  final ValueChanged<String> onRemoveLeaveBank;
  final Future<void> Function(WeekdayKey weekday) onPickWeekdayTargetMinutes;
  final Future<void> Function(WeekdayKey weekday, _CalendarTimeField field)
  onPickWeekdayScheduleTime;
  final Future<void> Function(WeekdayKey weekday) onPickWeekdayBreakMinutes;
  final void Function(WeekdayKey weekday, bool hasLunchBreak)
  onWeekdayLunchBreakChanged;
  final void Function(WeekdayKey weekday, bool isWorking)
  onWeekdayWorkingDayChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;
  final Future<void> Function() onReload;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    bool isWorkingWeekday(WeekdayKey weekday) {
      final targetMinutes =
          _resolveDraftTargetMinutes(
            targetText: weekdayControllers[weekday]!.text,
            startTimeText: weekdayStartTimeControllers[weekday]!.text,
            endTimeText: weekdayEndTimeControllers[weekday]!.text,
            breakText: weekdayBreakControllers[weekday]!.text,
          ) ??
          0;
      return targetMinutes > 0;
    }

    final configuredWorkingDays = WeekdayKey.values
        .where(isWorkingWeekday)
        .toList(growable: false);
    final flexibleStartWindowMinutes =
        parseHoursInput(rulesFlexibleStartWindowController.text) ?? 0;
    final flexibleStartRangeHints = <String>[];
    if (rulesFlexibleStartEnabled && flexibleStartWindowMinutes > 0) {
      for (final weekday in configuredWorkingDays) {
        final weekdayStartMinutes = parseTimeInput(
          weekdayStartTimeControllers[weekday]!.text,
        );
        if (weekdayStartMinutes == null) {
          continue;
        }
        final latestStartMinutes = weekdayStartMinutes + flexibleStartWindowMinutes;
        final dayLabel = _compactWeekdayLabel(weekday);
        final overflowSuffix = latestStartMinutes >= (24 * 60) ? ' +1g' : '';
        flexibleStartRangeHints.add(
          '$dayLabel ${formatTimeInput(weekdayStartMinutes)} - ${formatTimeInput(latestStartMinutes % (24 * 60))}$overflowSuffix',
        );
      }
      if (flexibleStartRangeHints.isEmpty) {
        final uniformStartMinutes = parseTimeInput(uniformStartTimeController.text);
        if (uniformStartMinutes != null) {
          final latestStartMinutes = uniformStartMinutes + flexibleStartWindowMinutes;
          final overflowSuffix = latestStartMinutes >= (24 * 60) ? ' +1g' : '';
          flexibleStartRangeHints.add(
            'Fascia ${formatTimeInput(uniformStartMinutes)} - ${formatTimeInput(latestStartMinutes % (24 * 60))}$overflowSuffix',
          );
        }
      }
    }

    return _SectionCard(
      title: 'Orari e permessi',
      subtitle: 'Orario di lavoro, regole contratto e permessi personali.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsSectionPanel(
              icon: Icons.schedule_outlined,
              title: 'Orario di lavoro',
              subtitle:
                  'Definisci quando lavori normalmente e i valori base per i calcoli.',
              isExpanded: appearanceSettings.expandWorkSettingsSchedule,
              toggleButtonKey: const ValueKey(
                'work-settings-schedule-toggle-button',
              ),
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(
                    expandWorkSettingsSchedule: expanded,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: useUniformDailyTarget,
                    onChanged: isBusy ? null : onUniformDailyTargetChanged,
                    title: const Text('Stesso orario lun-ven'),
                    subtitle: const Text(
                      'Disattiva per personalizzare i giorni.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (useUniformDailyTarget)
                    _SettingsScheduleEditor(
                      title: 'Orario standard',
                      targetText: uniformDailyTargetController.text,
                      startTimeText: uniformStartTimeController.text,
                      endTimeText: uniformEndTimeController.text,
                      breakText: uniformBreakController.text,
                      hasLunchBreak:
                          (parseBreakDurationInput(
                                uniformBreakController.text,
                              ) ??
                              0) >
                          0,
                      lunchBreakToggleKey: const ValueKey(
                        'work-settings-lunch-break-uniform',
                      ),
                      onLunchBreakChanged: onUniformLunchBreakChanged,
                      onPickTarget: onPickUniformTargetMinutes,
                      onPickStartTime: () =>
                          onPickUniformScheduleTime(_CalendarTimeField.start),
                      onPickEndTime: () =>
                          onPickUniformScheduleTime(_CalendarTimeField.end),
                      onPickBreak: onPickUniformBreakMinutes,
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleziona i tuoi giorni lavorativi',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        _WorkingWeekdaySelector(
                          selectedWeekdays: configuredWorkingDays.toSet(),
                          onChanged: onWeekdayWorkingDayChanged,
                        ),
                        const SizedBox(height: 12),
                        if (configuredWorkingDays.isEmpty)
                          Text(
                            'Nessun giorno selezionato. Attiva almeno un giorno dalla riga sopra.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          Column(
                            children: configuredWorkingDays
                                .map(
                                  (weekday) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _DayScheduleEditorRow(
                                      weekday: weekday,
                                      targetController:
                                          weekdayControllers[weekday]!,
                                      startTimeController:
                                          weekdayStartTimeControllers[weekday]!,
                                      endTimeController:
                                          weekdayEndTimeControllers[weekday]!,
                                      breakController:
                                          weekdayBreakControllers[weekday]!,
                                      hasLunchBreak:
                                          (parseBreakDurationInput(
                                                weekdayBreakControllers[weekday]!
                                                    .text,
                                              ) ??
                                              0) >
                                          0,
                                      lunchBreakToggleKey: ValueKey(
                                        'work-settings-lunch-break-${weekday.name}',
                                      ),
                                      onLunchBreakChanged: (value) =>
                                          onWeekdayLunchBreakChanged(
                                            weekday,
                                            value,
                                          ),
                                      onPickTarget: () =>
                                          onPickWeekdayTargetMinutes(weekday),
                                      onPickStartTime: () =>
                                          onPickWeekdayScheduleTime(
                                            weekday,
                                            _CalendarTimeField.start,
                                          ),
                                      onPickEndTime: () =>
                                          onPickWeekdayScheduleTime(
                                            weekday,
                                            _CalendarTimeField.end,
                                          ),
                                      onPickBreak: () =>
                                          onPickWeekdayBreakMinutes(weekday),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Valori usati nei calcoli',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _WorkRulesCoreEditor(
                    minimumBreakText: rulesMinimumBreakController.text,
                    onPickMinimumBreak: onPickRulesMinimumBreakMinutes,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Inserisci solo quello che ti serve. Il resto è automatico.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSectionPanel(
              icon: Icons.tune_rounded,
              title: 'Limiti',
              subtitle:
                  'Scegli il massimo credito o debito che l app puo conteggiare nel giorno e nel mese. Se non vuoi limiti, lascia Nessun limite.',
              isExpanded: appearanceSettings.expandWorkSettingsLimits,
              toggleButtonKey: const ValueKey(
                'work-settings-limits-toggle-button',
              ),
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(
                    expandWorkSettingsLimits: expanded,
                  ),
                ),
              ),
              child: _WorkRulesLimitsEditor(
                maximumDailyCreditText: rulesMaximumDailyCreditController.text,
                maximumDailyDebitText: rulesMaximumDailyDebitController.text,
                maximumMonthlyCreditText:
                    rulesMaximumMonthlyCreditController.text,
                maximumMonthlyDebitText:
                    rulesMaximumMonthlyDebitController.text,
                onPickMaximumDailyCredit: onPickRulesMaximumDailyCreditMinutes,
                onPickMaximumDailyDebit: onPickRulesMaximumDailyDebitMinutes,
                onPickMaximumMonthlyCredit:
                    onPickRulesMaximumMonthlyCreditMinutes,
                onPickMaximumMonthlyDebit:
                    onPickRulesMaximumMonthlyDebitMinutes,
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSectionPanel(
              icon: Icons.bolt_outlined,
              title: 'Straordinario',
              subtitle:
                  'Attiva straordinario e definisci eventuali massimali giornalieri, settimanali o mensili.',
              isExpanded: appearanceSettings.expandWorkSettingsOvertime,
              toggleButtonKey: const ValueKey(
                'work-settings-overtime-toggle-button',
              ),
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(
                    expandWorkSettingsOvertime: expanded,
                  ),
                ),
              ),
              child: _WorkRulesOvertimeEditor(
                overtimeEnabled: rulesOvertimeEnabled,
                overtimeCapEnabled: rulesOvertimeCapEnabled,
                overtimeDailyCapText: rulesOvertimeDailyCapController.text,
                overtimeWeeklyCapText: rulesOvertimeWeeklyCapController.text,
                overtimeMonthlyCapText: rulesOvertimeMonthlyCapController.text,
                onOvertimeEnabledChanged: onRulesOvertimeEnabledChanged,
                onOvertimeCapEnabledChanged: onRulesOvertimeCapEnabledChanged,
                onPickDailyCap: onPickRulesOvertimeDailyCapMinutes,
                onPickWeeklyCap: onPickRulesOvertimeWeeklyCapMinutes,
                onPickMonthlyCap: onPickRulesOvertimeMonthlyCapMinutes,
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSectionPanel(
              icon: Icons.login_outlined,
              title: 'Ingresso e uscita',
              subtitle:
                  'Imposta l ingresso fisso e, se ti serve, aggiungi la flessibilita: la fascia viene calcolata in automatico (es. 07:30 + 2:00 = 07:30-09:30).',
              isExpanded: appearanceSettings.expandWorkSettingsAttendance,
              toggleButtonKey: const ValueKey(
                'work-settings-attendance-toggle-button',
              ),
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(
                    expandWorkSettingsAttendance: expanded,
                  ),
                ),
              ),
              child: _WorkRulesAttendanceEditor(
                fixedScheduleEnabled: rulesFixedScheduleEnabled,
                flexibleStartEnabled: rulesFlexibleStartEnabled,
                flexibleStartWindowText: rulesFlexibleStartWindowController.text,
                flexibleStartRangeHints: flexibleStartRangeHints,
                onFixedScheduleChanged: onRulesFixedScheduleEnabledChanged,
                onFlexibleStartChanged: onRulesFlexibleStartEnabledChanged,
                onPickFlexibleStartWindow: onPickRulesFlexibleStartWindowMinutes,
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSectionPanel(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Permessi orari automatici',
              subtitle:
                  'Imposta limiti automatici per uscita anticipata e credito extra. Per regole con nomi personalizzati usa Regole permessi.',
              isExpanded: appearanceSettings.expandWorkSettingsWallet,
              toggleButtonKey: const ValueKey(
                'work-settings-wallet-toggle-button',
              ),
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(
                    expandWorkSettingsWallet: expanded,
                  ),
                ),
              ),
              child: _WorkRulesWalletEditor(
                walletEnabled: rulesWalletEnabled,
                walletDailyExitText: rulesWalletDailyExitController.text,
                walletWeeklyExitText: rulesWalletWeeklyExitController.text,
                implicitCreditEnabled: rulesImplicitCreditEnabled,
                implicitCreditDailyCapText:
                    rulesImplicitCreditDailyCapController.text,
                onWalletEnabledChanged: onRulesWalletEnabledChanged,
                onImplicitCreditEnabledChanged:
                    onRulesImplicitCreditEnabledChanged,
                onPickWalletDailyExit: onPickRulesWalletDailyExitMinutes,
                onPickWalletWeeklyExit: onPickRulesWalletWeeklyExitMinutes,
                onPickImplicitCreditDailyCap:
                    onPickRulesImplicitCreditDailyCapMinutes,
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSectionPanel(
              icon: Icons.rule_folder_outlined,
              title: 'Regole permessi',
              subtitle:
                  'Crea permessi con nome personalizzato (es. P36), movimenti consentiti e monte ore.',
              isExpanded: appearanceSettings.expandWorkSettingsPermissions,
              toggleButtonKey: const ValueKey(
                'work-settings-permissions-toggle-button',
              ),
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(
                    expandWorkSettingsPermissions: expanded,
                  ),
                ),
              ),
              child: _PermissionRulesEditor(
                rules: rulesAdditionalPermissions,
                emptyMessage:
                    'Nessun permesso aggiuntivo configurato. Usa Aggiungi permesso.',
                addButtonLabel: 'Aggiungi permesso',
                onAddRule: onAddAdditionalPermission,
                onRemoveRule: onRemoveAdditionalPermission,
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSectionPanel(
              icon: Icons.event_available_outlined,
              title: 'Ferie e assenze',
              subtitle:
                  'Gestisci ferie, permessi, malattia e altre causali di assenza.',
              isExpanded: appearanceSettings.expandWorkSettingsLeaveBanks,
              toggleButtonKey: const ValueKey(
                'work-settings-leave-banks-toggle-button',
              ),
              onToggleExpanded: (expanded) => unawaited(
                onAppearanceSettingsChanged(
                  appearanceSettings.copyWith(
                    expandWorkSettingsLeaveBanks: expanded,
                  ),
                ),
              ),
              child: _LeaveBanksEditor(
                rules: rulesLeaveBanks,
                referenceWorkingDayMinutes: useUniformDailyTarget
                    ? (_resolveDraftTargetMinutes(
                            targetText: uniformDailyTargetController.text,
                            startTimeText: uniformStartTimeController.text,
                            endTimeText: uniformEndTimeController.text,
                            breakText: uniformBreakController.text,
                          ) ??
                          8 * 60)
                    : (() {
                        final activeTargetMinutes = configuredWorkingDays
                            .map(
                              (weekday) =>
                                  _resolveDraftTargetMinutes(
                                    targetText:
                                        weekdayControllers[weekday]!.text,
                                    startTimeText:
                                        weekdayStartTimeControllers[weekday]!
                                            .text,
                                    endTimeText:
                                        weekdayEndTimeControllers[weekday]!
                                            .text,
                                    breakText:
                                        weekdayBreakControllers[weekday]!.text,
                                  ) ??
                                  0,
                            )
                            .where((minutes) => minutes > 0)
                            .toList(growable: false);
                        if (activeTargetMinutes.isEmpty) {
                          return 8 * 60;
                        }
                        final total = activeTargetMinutes.reduce(
                          (left, right) => left + right,
                        );
                        return (total / activeTargetMinutes.length).round();
                      })(),
                emptyMessage:
                    'Nessuna causale configurata. Usa Aggiungi causale.',
                addButtonLabel: 'Aggiungi causale',
                onAddRule: onAddLeaveBank,
                onRemoveRule: onRemoveLeaveBank,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy || isReloading ? null : () => onReload(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    isReloading ? 'Ripristino...' : 'Ripristina valori',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy || isReloading ? null : () => onSubmit(),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isBusy ? 'Salvo...' : 'Salva'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionPanel extends StatelessWidget {
  const _SettingsSectionPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.toggleButtonKey,
    required this.onToggleExpanded,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isExpanded;
  final Key toggleButtonKey;
  final ValueChanged<bool> onToggleExpanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggleButtonSize = isExpanded ? 36.0 : 30.0;
    final toggleIconSize = isExpanded ? 20.0 : 18.0;
    final expandedIcon = isExpanded
        ? Icons.keyboard_arrow_up_rounded
        : Icons.keyboard_arrow_down_rounded;
    final toggleButton = IconButton(
      key: toggleButtonKey,
      onPressed: () => onToggleExpanded(!isExpanded),
      tooltip: isExpanded ? 'Riduci $title' : 'Espandi $title',
      visualDensity: VisualDensity.compact,
      iconSize: toggleIconSize,
      splashRadius: isExpanded ? 18 : 16,
      constraints: BoxConstraints.tightFor(
        width: toggleButtonSize,
        height: toggleButtonSize,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(expandedIcon),
    );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isExpanded) ...[
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onToggleExpanded(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ),
        toggleButton,
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(18, isExpanded ? 18 : 12, 18, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isExpanded)
            header
          else
            SizedBox(
              height: 30,
              child: Align(alignment: Alignment.centerLeft, child: header),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const SizedBox(height: 16), child],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DayScheduleEditorRow extends StatelessWidget {
  const _DayScheduleEditorRow({
    required this.weekday,
    required this.targetController,
    required this.startTimeController,
    required this.endTimeController,
    required this.breakController,
    required this.hasLunchBreak,
    this.lunchBreakToggleKey,
    required this.onLunchBreakChanged,
    required this.onPickTarget,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickBreak,
  });

  final WeekdayKey weekday;
  final TextEditingController targetController;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final TextEditingController breakController;
  final bool hasLunchBreak;
  final Key? lunchBreakToggleKey;
  final ValueChanged<bool> onLunchBreakChanged;
  final Future<void> Function() onPickTarget;
  final Future<void> Function() onPickStartTime;
  final Future<void> Function() onPickEndTime;
  final Future<void> Function() onPickBreak;

  @override
  Widget build(BuildContext context) {
    return _SettingsScheduleEditor(
      title: weekday.label,
      targetText: targetController.text,
      startTimeText: startTimeController.text,
      endTimeText: endTimeController.text,
      breakText: breakController.text,
      hasLunchBreak: hasLunchBreak,
      lunchBreakToggleKey: lunchBreakToggleKey,
      onLunchBreakChanged: onLunchBreakChanged,
      onPickTarget: onPickTarget,
      onPickStartTime: onPickStartTime,
      onPickEndTime: onPickEndTime,
      onPickBreak: onPickBreak,
    );
  }
}

class _WorkingWeekdaySelector extends StatelessWidget {
  const _WorkingWeekdaySelector({
    required this.selectedWeekdays,
    required this.onChanged,
  });

  final Set<WeekdayKey> selectedWeekdays;
  final void Function(WeekdayKey weekday, bool isWorking) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (var index = 0; index < WeekdayKey.values.length; index++) ...[
            Expanded(
              child: _WorkingWeekdayToggle(
                key: ValueKey(
                  'work-settings-working-day-toggle-${WeekdayKey.values[index].name}',
                ),
                label: _compactWeekdayLabel(WeekdayKey.values[index]),
                isSelected: selectedWeekdays.contains(WeekdayKey.values[index]),
                onTap: () => onChanged(
                  WeekdayKey.values[index],
                  !selectedWeekdays.contains(WeekdayKey.values[index]),
                ),
              ),
            ),
            if (index < WeekdayKey.values.length - 1)
              Container(
                width: 1,
                height: 28,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
              ),
          ],
        ],
      ),
    );
  }
}

class _WorkingWeekdayToggle extends StatelessWidget {
  const _WorkingWeekdayToggle({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredSettingsValuesWrap extends StatelessWidget {
  const _CenteredSettingsValuesWrap({
    required this.constraints,
    required this.values,
  });

  final BoxConstraints constraints;
  final List<Widget> values;

  @override
  Widget build(BuildContext context) {
    final itemWidth = math.max(190.0, math.min(260.0, constraints.maxWidth - 8));
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      children: [
        for (final value in values) SizedBox(width: itemWidth, child: value),
      ],
    );
  }
}

class _SettingsScheduleEditor extends StatelessWidget {
  const _SettingsScheduleEditor({
    required this.title,
    required this.targetText,
    required this.startTimeText,
    required this.endTimeText,
    required this.breakText,
    required this.hasLunchBreak,
    this.lunchBreakToggleKey,
    required this.onLunchBreakChanged,
    required this.onPickTarget,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickBreak,
  });

  final String title;
  final String targetText;
  final String startTimeText;
  final String endTimeText;
  final String breakText;
  final bool hasLunchBreak;
  final Key? lunchBreakToggleKey;
  final ValueChanged<bool> onLunchBreakChanged;
  final Future<void> Function() onPickTarget;
  final Future<void> Function() onPickStartTime;
  final Future<void> Function() onPickEndTime;
  final Future<void> Function() onPickBreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = <Widget>[
      _SlimSettingsScheduleValue(
        label: 'Durata giornata',
        value: targetText.isEmpty ? '--' : targetText,
        icon: Icons.timelapse_rounded,
        kind: _SettingsValueKind.duration,
        onTap: onPickTarget,
      ),
      _SlimSettingsScheduleValue(
        label: 'Entrata',
        value: startTimeText.isEmpty ? '--:--' : startTimeText,
        icon: Icons.login_rounded,
        kind: _SettingsValueKind.schedule,
        onTap: onPickStartTime,
      ),
      _SlimSettingsScheduleValue(
        label: 'Uscita',
        value: endTimeText.isEmpty ? '--:--' : endTimeText,
        icon: Icons.logout_rounded,
        kind: _SettingsValueKind.schedule,
        onTap: onPickEndTime,
      ),
    ];
    if (hasLunchBreak) {
      values.add(
        _SlimSettingsScheduleValue(
          label: 'Pausa',
          value: _formatSettingsBreakValue(breakText, isMinimumBreak: false),
          icon: Icons.coffee_outlined,
          kind: _SettingsValueKind.duration,
          onTap: onPickBreak,
        ),
      );
    }
    final lunchBreakToggle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox.adaptive(
          key: lunchBreakToggleKey,
          value: hasLunchBreak,
          visualDensity: VisualDensity.compact,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onLunchBreakChanged(value);
          },
        ),
        Text(
          hasLunchBreak ? 'Si pausa pranzo' : 'Nessuna pausa pranzo',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: hasLunchBreak
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useHorizontalLayout = constraints.maxWidth >= 720;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (useHorizontalLayout)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          lunchBreakToggle,
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.start,
                            children: values,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                lunchBreakToggle,
                const SizedBox(height: 8),
                _CenteredSettingsValuesWrap(
                  constraints: constraints,
                  values: values,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WorkRulesCoreEditor extends StatelessWidget {
  const _WorkRulesCoreEditor({
    required this.minimumBreakText,
    required this.onPickMinimumBreak,
  });

  final String minimumBreakText;
  final Future<void> Function() onPickMinimumBreak;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SlimSettingsScheduleValue(
          label: 'Pausa minima',
          value: _formatSettingsBreakValue(
            minimumBreakText,
            isMinimumBreak: true,
          ),
          icon: Icons.free_breakfast_outlined,
          kind: _SettingsValueKind.duration,
          onTap: onPickMinimumBreak,
        ),
      ],
    );
  }
}

class _WorkRulesLimitsEditor extends StatelessWidget {
  const _WorkRulesLimitsEditor({
    required this.maximumDailyCreditText,
    required this.maximumDailyDebitText,
    required this.maximumMonthlyCreditText,
    required this.maximumMonthlyDebitText,
    required this.onPickMaximumDailyCredit,
    required this.onPickMaximumDailyDebit,
    required this.onPickMaximumMonthlyCredit,
    required this.onPickMaximumMonthlyDebit,
  });

  final String maximumDailyCreditText;
  final String maximumDailyDebitText;
  final String maximumMonthlyCreditText;
  final String maximumMonthlyDebitText;
  final Future<void> Function() onPickMaximumDailyCredit;
  final Future<void> Function() onPickMaximumDailyDebit;
  final Future<void> Function() onPickMaximumMonthlyCredit;
  final Future<void> Function() onPickMaximumMonthlyDebit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SlimSettingsScheduleValue(
          label: 'Max credito giorno',
          value: _formatSettingsLimitValue(
            maximumDailyCreditText,
            unboundedMinutes: 24 * 60,
          ),
          icon: Icons.trending_up_rounded,
          kind: _SettingsValueKind.limit,
          onTap: onPickMaximumDailyCredit,
        ),
        _SlimSettingsScheduleValue(
          label: 'Max debito giorno',
          value: _formatSettingsLimitValue(
            maximumDailyDebitText,
            unboundedMinutes: 24 * 60,
          ),
          icon: Icons.trending_down_rounded,
          kind: _SettingsValueKind.limit,
          onTap: onPickMaximumDailyDebit,
        ),
        _SlimSettingsScheduleValue(
          label: 'Max credito mese',
          value: _formatSettingsLimitValue(
            maximumMonthlyCreditText,
            unboundedMinutes: 31 * 24 * 60,
          ),
          icon: Icons.calendar_month_outlined,
          kind: _SettingsValueKind.limit,
          onTap: onPickMaximumMonthlyCredit,
        ),
        _SlimSettingsScheduleValue(
          label: 'Max debito mese',
          value: _formatSettingsLimitValue(
            maximumMonthlyDebitText,
            unboundedMinutes: 31 * 24 * 60,
          ),
          icon: Icons.event_note_outlined,
          kind: _SettingsValueKind.limit,
          onTap: onPickMaximumMonthlyDebit,
        ),
      ],
    );
  }
}

class _WorkRulesOvertimeEditor extends StatelessWidget {
  const _WorkRulesOvertimeEditor({
    required this.overtimeEnabled,
    required this.overtimeCapEnabled,
    required this.overtimeDailyCapText,
    required this.overtimeWeeklyCapText,
    required this.overtimeMonthlyCapText,
    required this.onOvertimeEnabledChanged,
    required this.onOvertimeCapEnabledChanged,
    required this.onPickDailyCap,
    required this.onPickWeeklyCap,
    required this.onPickMonthlyCap,
  });

  final bool overtimeEnabled;
  final bool overtimeCapEnabled;
  final String overtimeDailyCapText;
  final String overtimeWeeklyCapText;
  final String overtimeMonthlyCapText;
  final ValueChanged<bool> onOvertimeEnabledChanged;
  final ValueChanged<bool> onOvertimeCapEnabledChanged;
  final Future<void> Function() onPickDailyCap;
  final Future<void> Function() onPickWeeklyCap;
  final Future<void> Function() onPickMonthlyCap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: overtimeEnabled,
          onChanged: onOvertimeEnabledChanged,
          title: const Text('Straordinario abilitato'),
          subtitle: const Text(
            'Se disattivo, il credito extra viene bloccato o limitato da altre regole.',
          ),
        ),
        if (overtimeEnabled) ...[
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: overtimeCapEnabled,
            onChanged: onOvertimeCapEnabledChanged,
            title: const Text('Massimale straordinario attivo'),
            subtitle: const Text(
              'Puoi limitare il massimo accumulabile su giorno, settimana e mese.',
            ),
          ),
          if (overtimeCapEnabled) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SlimSettingsScheduleValue(
                  label: 'Max giorno',
                  value: _formatOptionalHoursValue(
                    overtimeDailyCapText,
                    zeroLabel: 'Nessun limite',
                  ),
                  icon: Icons.calendar_today_outlined,
                  kind: _SettingsValueKind.limit,
                  onTap: onPickDailyCap,
                ),
                _SlimSettingsScheduleValue(
                  label: 'Max settimana',
                  value: _formatOptionalHoursValue(
                    overtimeWeeklyCapText,
                    zeroLabel: 'Nessun limite',
                  ),
                  icon: Icons.date_range_rounded,
                  kind: _SettingsValueKind.limit,
                  onTap: onPickWeeklyCap,
                ),
                _SlimSettingsScheduleValue(
                  label: 'Max mese',
                  value: _formatOptionalHoursValue(
                    overtimeMonthlyCapText,
                    zeroLabel: 'Nessun limite',
                  ),
                  icon: Icons.calendar_month_outlined,
                  kind: _SettingsValueKind.limit,
                  onTap: onPickMonthlyCap,
                ),
              ],
            ),
          ],
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Nessun credito straordinario viene conteggiato.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _WorkRulesAttendanceEditor extends StatelessWidget {
  const _WorkRulesAttendanceEditor({
    required this.fixedScheduleEnabled,
    required this.flexibleStartEnabled,
    required this.flexibleStartWindowText,
    required this.flexibleStartRangeHints,
    required this.onFixedScheduleChanged,
    required this.onFlexibleStartChanged,
    required this.onPickFlexibleStartWindow,
  });

  final bool fixedScheduleEnabled;
  final bool flexibleStartEnabled;
  final String flexibleStartWindowText;
  final List<String> flexibleStartRangeHints;
  final ValueChanged<bool> onFixedScheduleChanged;
  final ValueChanged<bool> onFlexibleStartChanged;
  final Future<void> Function() onPickFlexibleStartWindow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRangeHints = flexibleStartRangeHints.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: fixedScheduleEnabled,
          onChanged: onFixedScheduleChanged,
          title: const Text('Uso un orario fisso di entrata'),
          subtitle: const Text(
            'Serve come base per calcolare la fascia di ingresso consentita.',
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: flexibleStartEnabled,
          onChanged: onFlexibleStartChanged,
          title: const Text('Flessibilita in entrata'),
          subtitle: const Text(
            'Imposti solo il ritardo massimo dall entrata fissa (esempio: 07:30 + 2:00 = 07:30-09:30).',
          ),
        ),
        if (flexibleStartEnabled) ...[
          const SizedBox(height: 10),
          _SlimSettingsScheduleValue(
            label: 'Ritardo massimo consentito',
            value: _formatOptionalHoursValue(
              flexibleStartWindowText,
              zeroLabel: 'Nessuna flessibilita',
            ),
            icon: Icons.access_time_rounded,
            kind: _SettingsValueKind.duration,
            onTap: onPickFlexibleStartWindow,
          ),
          const SizedBox(height: 10),
          Text(
            'Fascia di ingresso calcolata',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (showRangeHints)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hint in flexibleStartRangeHints)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      hint,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            )
          else
            Text(
              fixedScheduleEnabled
                  ? 'Imposta Entrata in Orario di lavoro per vedere l intervallo.'
                  : 'Attiva l ingresso fisso e imposta Entrata in Orario di lavoro.',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ],
    );
  }
}

class _WorkRulesWalletEditor extends StatelessWidget {
  const _WorkRulesWalletEditor({
    required this.walletEnabled,
    required this.walletDailyExitText,
    required this.walletWeeklyExitText,
    required this.implicitCreditEnabled,
    required this.implicitCreditDailyCapText,
    required this.onWalletEnabledChanged,
    required this.onImplicitCreditEnabledChanged,
    required this.onPickWalletDailyExit,
    required this.onPickWalletWeeklyExit,
    required this.onPickImplicitCreditDailyCap,
  });

  final bool walletEnabled;
  final String walletDailyExitText;
  final String walletWeeklyExitText;
  final bool implicitCreditEnabled;
  final String implicitCreditDailyCapText;
  final ValueChanged<bool> onWalletEnabledChanged;
  final ValueChanged<bool> onImplicitCreditEnabledChanged;
  final Future<void> Function() onPickWalletDailyExit;
  final Future<void> Function() onPickWalletWeeklyExit;
  final Future<void> Function() onPickImplicitCreditDailyCap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: walletEnabled,
          onChanged: onWalletEnabledChanged,
          title: const Text('Permesso uscita anticipata con limite'),
          subtitle: const Text(
            'Permette di uscire prima entro i limiti giornalieri e settimanali.',
          ),
        ),
        if (walletEnabled) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SlimSettingsScheduleValue(
                label: 'Max giorno',
                value: _formatOptionalHoursValue(
                  walletDailyExitText,
                  zeroLabel: 'Nessun limite',
                ),
                icon: Icons.today_outlined,
                kind: _SettingsValueKind.limit,
                onTap: onPickWalletDailyExit,
              ),
              _SlimSettingsScheduleValue(
                label: 'Max settimana',
                value: _formatOptionalHoursValue(
                  walletWeeklyExitText,
                  zeroLabel: 'Nessun limite',
                ),
                icon: Icons.view_week_outlined,
                kind: _SettingsValueKind.limit,
                onTap: onPickWalletWeeklyExit,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        const Divider(),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: implicitCreditEnabled,
          onChanged: onImplicitCreditEnabledChanged,
          title: const Text('Credito extra senza straordinario'),
          subtitle: const Text(
            'Limita il credito maturabile se resti oltre l orario standard.',
          ),
        ),
        if (implicitCreditEnabled) ...[
          const SizedBox(height: 10),
          _SlimSettingsScheduleValue(
            label: 'Max credito giorno',
            value: _formatOptionalHoursValue(
              implicitCreditDailyCapText,
              zeroLabel: 'Nessun credito',
            ),
            icon: Icons.trending_up_rounded,
            kind: _SettingsValueKind.limit,
            onTap: onPickImplicitCreditDailyCap,
          ),
        ],
      ],
    );
  }
}

class _LeaveBanksEditor extends StatelessWidget {
  const _LeaveBanksEditor({
    required this.rules,
    required this.referenceWorkingDayMinutes,
    required this.emptyMessage,
    required this.addButtonLabel,
    required this.onAddRule,
    required this.onRemoveRule,
  });

  final List<WorkPermissionRule> rules;
  final int referenceWorkingDayMinutes;
  final String emptyMessage;
  final String addButtonLabel;
  final Future<void> Function() onAddRule;
  final ValueChanged<String> onRemoveRule;

  bool _matchesCategory(WorkPermissionRule rule, List<String> keywords) {
    final normalizedName = rule.name.toLowerCase().trim();
    return keywords.any(normalizedName.contains);
  }

  WorkPermissionRule? _firstRuleByCategory(List<String> keywords) {
    for (final rule in rules) {
      if (_matchesCategory(rule, keywords)) {
        return rule;
      }
    }
    return null;
  }

  int _remainingMinutes(WorkPermissionRule rule) {
    final usedMinutes = math.min(rule.usedMinutes, rule.allowanceMinutes);
    return math.max(rule.allowanceMinutes - usedMinutes, 0);
  }

  String _formatVacationSummary(WorkPermissionRule? rule) {
    if (rule == null) {
      return 'Non configurate';
    }

    final remainingMinutes = _remainingMinutes(rule);
    final safeWorkingDayMinutes = math.max(referenceWorkingDayMinutes, 60);
    final remainingDays = remainingMinutes / safeWorkingDayMinutes;
    final isWholeDays =
        remainingDays == remainingDays.truncateToDouble();
    final formattedDays = isWholeDays
        ? remainingDays.toStringAsFixed(0)
        : remainingDays.toStringAsFixed(1).replaceFirst('.', ',');
    return '$formattedDays giorni disponibili';
  }

  String _formatHoursSummary(WorkPermissionRule? rule) {
    if (rule == null) {
      return 'Non configurati';
    }
    return '${_formatHoursInput(_remainingMinutes(rule))} disponibili';
  }

  String _formatSicknessSummary(WorkPermissionRule? rule) {
    if (rule == null) {
      return 'Non configurata';
    }
    return rule.enabled ? 'Senza monte ore' : 'Disattivata';
  }

  @override
  Widget build(BuildContext context) {
    final ferieRule = _firstRuleByCategory(['ferie', 'vacation']);
    final permitsRule = _firstRuleByCategory(['permess', 'permit']);
    final sicknessRule = _firstRuleByCategory(['malatt', 'sick']);
    final categorizedRuleIds = <String>{
      if (ferieRule != null) ferieRule.id,
      if (permitsRule != null) permitsRule.id,
      if (sicknessRule != null) sicknessRule.id,
    };
    final otherRules = rules
        .where((rule) => !categorizedRuleIds.contains(rule.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LeaveBankSummaryTile(
          icon: Icons.beach_access_outlined,
          title: 'Ferie',
          value: _formatVacationSummary(ferieRule),
        ),
        const SizedBox(height: 10),
        _LeaveBankSummaryTile(
          icon: Icons.schedule_outlined,
          title: 'Permessi',
          value: _formatHoursSummary(permitsRule),
        ),
        const SizedBox(height: 10),
        _LeaveBankSummaryTile(
          icon: Icons.local_hospital_outlined,
          title: 'Malattia',
          value: _formatSicknessSummary(sicknessRule),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => onAddRule(),
          icon: const Icon(Icons.add_rounded),
          label: Text(addButtonLabel),
        ),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          Text(
            emptyMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else if (otherRules.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Altre causali',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: otherRules
                    .map(
                      (rule) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PermissionRuleTile(
                          rule: rule,
                          onRemove: () => onRemoveRule(rule.id),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
      ],
    );
  }
}

class _LeaveBankSummaryTile extends StatelessWidget {
  const _LeaveBankSummaryTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRulesEditor extends StatelessWidget {
  const _PermissionRulesEditor({
    required this.rules,
    required this.emptyMessage,
    required this.addButtonLabel,
    required this.onAddRule,
    required this.onRemoveRule,
  });

  final List<WorkPermissionRule> rules;
  final String emptyMessage;
  final String addButtonLabel;
  final Future<void> Function() onAddRule;
  final ValueChanged<String> onRemoveRule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => onAddRule(),
          icon: const Icon(Icons.add_rounded),
          label: Text(addButtonLabel),
        ),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          Text(
            emptyMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Column(
            children: rules
                .map(
                  (rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PermissionRuleTile(
                      rule: rule,
                      onRemove: () => onRemoveRule(rule.id),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _PermissionRuleTile extends StatelessWidget {
  const _PermissionRuleTile({required this.rule, required this.onRemove});

  final WorkPermissionRule rule;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeUsedMinutes = math.min(rule.usedMinutes, rule.allowanceMinutes);
    final remainingMinutes = math.max(rule.allowanceMinutes - safeUsedMinutes, 0);
    final movementLabels = rule.movements.map((movement) => movement.label).join(
      ', ',
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(rule.enabled ? 'Attivo' : 'Disattivato'),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Rimuovi ${rule.name}',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${rule.period.label} - Disponibili ${_formatHoursInput(remainingMinutes)} su ${_formatHoursInput(rule.allowanceMinutes)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Usate ${_formatHoursInput(safeUsedMinutes)} - $movementLabels',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

enum _SettingsValueKind { schedule, duration, limit }

class _SlimSettingsScheduleValue extends StatelessWidget {
  const _SlimSettingsScheduleValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.kind,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final _SettingsValueKind kind;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = switch (kind) {
      _SettingsValueKind.schedule => theme.colorScheme.primary,
      _SettingsValueKind.duration => theme.colorScheme.secondary,
      _SettingsValueKind.limit => theme.colorScheme.tertiary,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onTap(),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentColor.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Flexible(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: '$label ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 14,
                color: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatSettingsBreakValue(
  String rawValue, {
  required bool isMinimumBreak,
}) {
  final minutes = parseBreakDurationInput(rawValue) ?? 0;
  if (minutes <= 0) {
    return isMinimumBreak ? 'Nessuna pausa minima' : 'Nessuna pausa';
  }
  return _formatBreakInput(minutes);
}

String _formatSettingsLimitValue(
  String rawValue, {
  required int unboundedMinutes,
}) {
  final parsedMinutes = parseHoursInput(rawValue);
  if (parsedMinutes == null) {
    return '--';
  }
  if (parsedMinutes == unboundedMinutes) {
    return 'Nessun limite';
  }
  return _formatHoursInput(parsedMinutes);
}

String _formatOptionalHoursValue(
  String rawValue, {
  required String zeroLabel,
}) {
  final parsedMinutes = parseHoursInput(rawValue);
  if (parsedMinutes == null || parsedMinutes <= 0) {
    return zeroLabel;
  }
  return _formatHoursInput(parsedMinutes);
}

class _AppearanceSettingsPanel extends StatefulWidget {
  const _AppearanceSettingsPanel({
    required this.isDarkTheme,
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onDarkThemeChanged,
    required this.onAppearanceSettingsChanged,
  });

  final bool isDarkTheme;
  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  State<_AppearanceSettingsPanel> createState() =>
      _AppearanceSettingsPanelState();
}

class _AppearanceSettingsPanelState extends State<_AppearanceSettingsPanel> {
  _AppearanceTab _selectedTab = _AppearanceTab.theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aspetto app',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        _AppearanceTabs(
          selectedTab: _selectedTab,
          onTabChanged: (tab) => setState(() {
            _selectedTab = tab;
          }),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(_selectedTab),
            child: _AppearanceTabContent(
              tab: _selectedTab,
              appearanceSettings: widget.appearanceSettings,
              isUpdatingThemeMode: widget.isUpdatingThemeMode,
              onDarkThemeChanged: widget.onDarkThemeChanged,
              onAppearanceSettingsChanged: widget.onAppearanceSettingsChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _CloudBackupAccountCard extends StatelessWidget {
  const _CloudBackupAccountCard({
    required this.accountSession,
    required this.selectedAuthMode,
    required this.emailController,
    required this.passwordController,
    required this.isAuthenticating,
    required this.isRecoveringPassword,
    required this.isRestoring,
    required this.isSyncing,
    required this.onRegister,
    required this.onLogin,
    required this.onAuthModeChanged,
    required this.onOpenPasswordRecovery,
    required this.onBackupNow,
    required this.onRestoreFromCloud,
    required this.onLogout,
  });

  final AccountSession? accountSession;
  final _AccountAuthMode selectedAuthMode;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isAuthenticating;
  final bool isRecoveringPassword;
  final bool isRestoring;
  final bool isSyncing;
  final Future<void> Function() onRegister;
  final Future<void> Function() onLogin;
  final ValueChanged<_AccountAuthMode> onAuthModeChanged;
  final Future<void> Function() onOpenPasswordRecovery;
  final Future<void> Function() onBackupNow;
  final Future<void> Function() onRestoreFromCloud;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoggedIn = accountSession != null;
    final isBusy = isAuthenticating || isRecoveringPassword;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account e backup cloud opzionale',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLoggedIn
                ? 'Sei registrato come ${accountSession!.user.email}. I dati restano su questo dispositivo e vengono anche salvati nel cloud, cosi puoi recuperarli dopo una disinstallazione o su un altro telefono.'
                : 'Puoi usare l app anche senza registrarti. In quel caso i dati restano solo su questo dispositivo e si perdono se disinstalli l app o cambi telefono. Se ti registri, profilo e impostazioni vengono salvati anche nel cloud.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (!isLoggedIn) ...[
            SegmentedButton<_AccountAuthMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _AccountAuthMode.login,
                  icon: Icon(Icons.login_rounded),
                  label: Text('Login'),
                ),
                ButtonSegment(
                  value: _AccountAuthMode.register,
                  icon: Icon(Icons.person_add_alt_1_rounded),
                  label: Text('Registrati'),
                ),
              ],
              selected: {selectedAuthMode},
              onSelectionChanged: isBusy
                  ? null
                  : (selection) => onAuthModeChanged(selection.first),
            ),
            const SizedBox(height: 12),
            Text(
              selectedAuthMode == _AccountAuthMode.register
                  ? 'Dopo la registrazione ricevi un codice recupero da conservare.'
                  : 'Accedi con email e password. Se non ricordi la password usa "Password dimenticata?".',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'Almeno 8 caratteri',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (selectedAuthMode == _AccountAuthMode.register)
                  FilledButton.tonalIcon(
                    onPressed: isBusy ? null : () => onRegister(),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      isAuthenticating ? 'Attendi...' : 'Registrati e salva',
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: isBusy ? null : () => onLogin(),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      isAuthenticating ? 'Attendi...' : 'Accedi e ripristina',
                    ),
                  ),
                if (selectedAuthMode == _AccountAuthMode.login)
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => onAuthModeChanged(_AccountAuthMode.register),
                    child: const Text('Non hai un account? Registrati'),
                  )
                else
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => onAuthModeChanged(_AccountAuthMode.login),
                    child: const Text('Hai gia un account? Accedi'),
                  ),
                if (selectedAuthMode == _AccountAuthMode.login)
                  TextButton(
                    onPressed: isBusy ? null : () => onOpenPasswordRecovery(),
                    child: Text(
                      isRecoveringPassword
                          ? 'Recupero in corso...'
                          : 'Password dimenticata?',
                    ),
                  ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: (isSyncing || isAuthenticating)
                      ? null
                      : () => onBackupNow(),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(isSyncing ? 'Sincronizzo...' : 'Backup ora'),
                ),
                OutlinedButton.icon(
                  onPressed: (isRestoring || isAuthenticating)
                      ? null
                      : () => onRestoreFromCloud(),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(
                    isRestoring ? 'Ripristino...' : 'Ripristina dal cloud',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isAuthenticating ? null : () => onLogout(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Esci'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AppUpdateSettingsCard extends StatelessWidget {
  const _AppUpdateSettingsCard({
    required this.availableUpdate,
    required this.isCheckingForUpdate,
    required this.isOpeningUpdate,
    required this.isBackgroundDownloadInProgress,
    required this.backgroundDownloadProgress,
    required this.backgroundUpdate,
    required this.onPressed,
  });

  final AppUpdate? availableUpdate;
  final bool isCheckingForUpdate;
  final bool isOpeningUpdate;
  final bool isBackgroundDownloadInProgress;
  final UpdateDownloadProgress backgroundDownloadProgress;
  final AppUpdate? backgroundUpdate;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUpdate = availableUpdate != null;
    final backgroundVersion = backgroundUpdate?.latestVersion ?? availableUpdate?.latestVersion;
    final title = isBackgroundDownloadInProgress
        ? 'Download in background'
        : hasUpdate
        ? 'Aggiornamento disponibile'
        : 'Aggiornamenti app';
    final subtitle = isBackgroundDownloadInProgress
        ? backgroundVersion == null
              ? 'Sto scaricando l aggiornamento in background. Puoi continuare a usare l app.'
              : 'Sto scaricando la versione $backgroundVersion in background. Puoi continuare a usare l app.'
        : hasUpdate
        ? 'Versione attuale ${availableUpdate!.currentVersion} -> nuova versione ${availableUpdate!.latestVersion}'
        : 'Controlla manualmente se c e una nuova versione, anche se hai scelto di ricordartelo piu tardi.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          if (isBackgroundDownloadInProgress) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: backgroundDownloadProgress.fractionCompleted,
            ),
            const SizedBox(height: 8),
            Text(
              backgroundDownloadProgress.totalBytes == null
                  ? '${_formatDownloadSize(backgroundDownloadProgress.receivedBytes)} scaricati'
                  : '${_formatDownloadSize(backgroundDownloadProgress.receivedBytes)} di ${_formatDownloadSize(backgroundDownloadProgress.totalBytes!)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            key: const ValueKey('settings-update-button'),
            onPressed:
                (isCheckingForUpdate ||
                    isOpeningUpdate ||
                    isBackgroundDownloadInProgress)
                ? null
                : () => onPressed(),
            icon: Icon(
              isBackgroundDownloadInProgress
                  ? Icons.download_rounded
                  : hasUpdate
                  ? Icons.system_update_alt
                  : Icons.refresh_rounded,
            ),
            label: Text(
              isCheckingForUpdate
                  ? 'Controllo...'
                  : isOpeningUpdate
                  ? 'Apro...'
                  : isBackgroundDownloadInProgress
                  ? 'Download in background...'
                  : hasUpdate
                  ? 'Aggiorna ora'
                  : 'Controlla aggiornamenti',
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCalendarSettingsCard extends StatelessWidget {
  const _DayCalendarSettingsCard({
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onAppearanceSettingsChanged,
  });

  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Future<void> updateSettings(AppAppearanceSettings nextSettings) {
      return onAppearanceSettingsChanged(nextSettings);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sezione Oggi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Decidi cosa vuoi vedere e in che ordine nella sezione Oggi.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Formato layout',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<DayCalendarLayoutMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: DayCalendarLayoutMode.quickEditorFirst,
                label: Text('Rapido sopra'),
              ),
              ButtonSegment(
                value: DayCalendarLayoutMode.agendaFirst,
                label: Text('Agenda sopra'),
              ),
            ],
            selected: {appearanceSettings.dayCalendarLayoutMode},
            onSelectionChanged: isUpdatingThemeMode
                ? null
                : (selection) => unawaited(
                    updateSettings(
                      appearanceSettings.copyWith(
                        dayCalendarLayoutMode: selection.first,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: appearanceSettings.showDayWorkdayCard,
            onChanged: isUpdatingThemeMode
                ? null
                : (value) => unawaited(
                    updateSettings(
                      appearanceSettings.copyWith(showDayWorkdayCard: value),
                    ),
                  ),
            title: const Text('Mostra "Giornata di oggi"'),
            subtitle: const Text(
              'Se preferisci, puoi usare solo modifica rapida e agenda oraria.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Campi della modifica rapida',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Entrata e durata restano sempre visibili. Attiva solo i campi opzionali che ti servono davvero.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilterChip(
                label: const Text('Uscita'),
                selected: appearanceSettings.showDayEndTime,
                onSelected: isUpdatingThemeMode
                    ? null
                    : (selected) => unawaited(
                        updateSettings(
                          appearanceSettings.copyWith(showDayEndTime: selected),
                        ),
                      ),
              ),
              FilterChip(
                label: const Text('Pausa'),
                selected: appearanceSettings.showDayBreakMinutes,
                onSelected: isUpdatingThemeMode
                    ? null
                    : (selected) => unawaited(
                        updateSettings(
                          appearanceSettings.copyWith(
                            showDayBreakMinutes: selected,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppearanceTabs extends StatelessWidget {
  const _AppearanceTabs({
    required this.selectedTab,
    required this.onTabChanged,
  });

  final _AppearanceTab selectedTab;
  final ValueChanged<_AppearanceTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (final tab in _AppearanceTab.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _AppearanceTabButton(
                  label: switch (tab) {
                    _AppearanceTab.theme => 'Tema',
                    _AppearanceTab.colors => 'Colori',
                    _AppearanceTab.typography => 'Tipografia',
                  },
                  selected: selectedTab == tab,
                  onTap: () => onTabChanged(tab),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppearanceTabButton extends StatelessWidget {
  const _AppearanceTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AppearanceTabContent extends StatelessWidget {
  const _AppearanceTabContent({
    required this.tab,
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onDarkThemeChanged,
    required this.onAppearanceSettingsChanged,
  });

  final _AppearanceTab tab;
  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: switch (tab) {
        _AppearanceTab.theme => _ThemeAppearanceTab(
          appearanceSettings: appearanceSettings,
          isUpdatingThemeMode: isUpdatingThemeMode,
          onDarkThemeChanged: onDarkThemeChanged,
          onAppearanceSettingsChanged: onAppearanceSettingsChanged,
        ),
        _AppearanceTab.colors => _ColorsAppearanceTab(
          appearanceSettings: appearanceSettings,
          isUpdatingThemeMode: isUpdatingThemeMode,
          onAppearanceSettingsChanged: onAppearanceSettingsChanged,
        ),
        _AppearanceTab.typography => _TypographyAppearanceTab(
          appearanceSettings: appearanceSettings,
          isUpdatingThemeMode: isUpdatingThemeMode,
          onAppearanceSettingsChanged: onAppearanceSettingsChanged,
        ),
      },
    );
  }
}

class _ThemeAppearanceTab extends StatelessWidget {
  const _ThemeAppearanceTab({
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onDarkThemeChanged,
    required this.onAppearanceSettingsChanged,
  });

  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tema',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('Chiaro')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Scuro')),
            ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
          ],
          selected: {appearanceSettings.themeMode},
          onSelectionChanged: isUpdatingThemeMode
              ? null
              : (selection) => unawaited(
                  onAppearanceSettingsChanged(
                    appearanceSettings.copyWith(themeMode: selection.first),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ColorsAppearanceTab extends StatelessWidget {
  const _ColorsAppearanceTab({
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onAppearanceSettingsChanged,
  });

  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor =
        appearanceSettings.textColor ?? Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RgbColorEditor(
          title: 'Colore principale',
          color: appearanceSettings.primaryColor,
          enabled: !isUpdatingThemeMode,
          onChanged: (color) => unawaited(
            onAppearanceSettingsChanged(
              appearanceSettings.copyWith(primaryColor: color),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 18),
        _RgbColorEditor(
          title: 'Colore secondario',
          color: appearanceSettings.secondaryColor,
          enabled: !isUpdatingThemeMode,
          onChanged: (color) => unawaited(
            onAppearanceSettingsChanged(
              appearanceSettings.copyWith(secondaryColor: color),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 18),
        _RgbColorEditor(
          title: 'Colore testo',
          color: effectiveTextColor,
          enabled: !isUpdatingThemeMode,
          onChanged: (color) => unawaited(
            onAppearanceSettingsChanged(
              appearanceSettings.copyWith(textColor: color),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypographyAppearanceTab extends StatelessWidget {
  const _TypographyAppearanceTab({
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onAppearanceSettingsChanged,
  });

  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Font',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<AppFontFamily>(
          key: ValueKey(appearanceSettings.fontFamily),
          initialValue: appearanceSettings.fontFamily,
          decoration: const InputDecoration(labelText: 'Font del testo'),
          items: const [
            DropdownMenuItem(
              value: AppFontFamily.system,
              child: Text('Sistema'),
            ),
            DropdownMenuItem(
              value: AppFontFamily.sansSerif,
              child: Text('Sans serif'),
            ),
            DropdownMenuItem(value: AppFontFamily.serif, child: Text('Serif')),
            DropdownMenuItem(
              value: AppFontFamily.monospace,
              child: Text('Mono'),
            ),
            DropdownMenuItem(
              value: AppFontFamily.rounded,
              child: Text('Rounded'),
            ),
            DropdownMenuItem(
              value: AppFontFamily.condensed,
              child: Text('Condensed'),
            ),
          ],
          onChanged: isUpdatingThemeMode
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  unawaited(
                    onAppearanceSettingsChanged(
                      appearanceSettings.copyWith(fontFamily: value),
                    ),
                  );
                },
        ),
        const SizedBox(height: 18),
        Text(
          'Dimensione testo',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Slider(
          value: appearanceSettings.textScale,
          min: 0.8,
          max: 1.5,
          divisions: 14,
          onChanged: isUpdatingThemeMode
              ? null
              : (value) => unawaited(
                  onAppearanceSettingsChanged(
                    appearanceSettings.copyWith(textScale: value),
                  ),
                ),
        ),
        Text(
          '${_textScaleLabel(appearanceSettings.textScale)} (${(appearanceSettings.textScale * 100).round()}%)',
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Testo standard',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Anteprima dal vivo del font e della dimensione scelta.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RgbColorEditor extends StatelessWidget {
  const _RgbColorEditor({
    required this.title,
    required this.color,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final Color color;
  final bool enabled;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatColorHex(color),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _RgbSliderRow(
          label: 'Rosso',
          value: _colorChannel(color, _RgbColorChannel.red),
          color: Colors.redAccent,
          enabled: enabled,
          onChanged: (value) =>
              onChanged(_replaceColorChannel(color, red: value)),
        ),
        const SizedBox(height: 8),
        _RgbSliderRow(
          label: 'Verde',
          value: _colorChannel(color, _RgbColorChannel.green),
          color: Colors.green,
          enabled: enabled,
          onChanged: (value) =>
              onChanged(_replaceColorChannel(color, green: value)),
        ),
        const SizedBox(height: 8),
        _RgbSliderRow(
          label: 'Blu',
          value: _colorChannel(color, _RgbColorChannel.blue),
          color: Colors.blue,
          enabled: enabled,
          onChanged: (value) =>
              onChanged(_replaceColorChannel(color, blue: value)),
        ),
      ],
    );
  }
}

class _RgbSliderRow extends StatelessWidget {
  const _RgbSliderRow({
    required this.label,
    required this.value,
    required this.color,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: SliderTheme(
            data: Theme.of(
              context,
            ).sliderTheme.copyWith(activeTrackColor: color, thumbColor: color),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: enabled ? (next) => onChanged(next.round()) : null,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({
    required this.ticketApiBaseUrl,
    required this.formKey,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.nameController,
    required this.emailController,
    required this.subjectController,
    required this.messageController,
    required this.replyController,
    required this.recoveryTicketIdController,
    required this.appVersionController,
    required this.attachments,
    required this.trackedTickets,
    required this.ticketThreadsById,
    required this.selectedTicketId,
    required this.isSubmitting,
    required this.isLoadingThreads,
    required this.isSubmittingReply,
    required this.isRecoveringTicket,
    required this.unreadReplyCount,
    required this.onSelectTicket,
    required this.onRefreshThreads,
    required this.onRecoverTicketById,
    required this.onPickAttachments,
    required this.onRemoveAttachment,
    required this.onSubmit,
    required this.onSubmitReply,
  });

  final String ticketApiBaseUrl;
  final GlobalKey<FormState> formKey;
  final SupportTicketCategory selectedCategory;
  final ValueChanged<SupportTicketCategory> onCategoryChanged;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final TextEditingController replyController;
  final TextEditingController recoveryTicketIdController;
  final TextEditingController appVersionController;
  final List<SupportTicketUploadAttachment> attachments;
  final List<TrackedSupportTicket> trackedTickets;
  final Map<String, SupportTicketThread> ticketThreadsById;
  final String? selectedTicketId;
  final bool isSubmitting;
  final bool isLoadingThreads;
  final bool isSubmittingReply;
  final bool isRecoveringTicket;
  final int unreadReplyCount;
  final Future<void> Function(String ticketId) onSelectTicket;
  final Future<void> Function({bool notifyAboutNewReplies}) onRefreshThreads;
  final Future<void> Function() onRecoverTicketById;
  final Future<void> Function() onPickAttachments;
  final void Function(int index) onRemoveAttachment;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSubmitReply;

  TrackedSupportTicket? _selectedTrackedTicket() {
    final currentSelectedTicketId = selectedTicketId;
    if (currentSelectedTicketId == null) {
      return null;
    }

    for (final trackedTicket in trackedTickets) {
      if (trackedTicket.id == currentSelectedTicketId) {
        return trackedTicket;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTrackedTicket = _selectedTrackedTicket();
    final selectedThread = selectedTrackedTicket == null
        ? null
        : ticketThreadsById[selectedTrackedTicket.id];
    final isSelectedThreadClosed =
        selectedThread?.status == SupportTicketStatus.closed;

    return _SectionCard(
      title: 'Ticket',
      subtitle:
          'Segnala bug, chiedi nuove funzioni o invia una richiesta di supporto senza uscire dall app.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'I tuoi ticket',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                if (unreadReplyCount > 0)
                  _TicketPill(
                    label: unreadReplyCount == 1
                        ? '1 risposta nuova'
                        : '$unreadReplyCount risposte nuove',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                const Spacer(),
                IconButton.outlined(
                  tooltip: 'Aggiorna ticket',
                  onPressed: isLoadingThreads
                      ? null
                      : () => onRefreshThreads(notifyAboutNewReplies: false),
                  icon: isLoadingThreads
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trackedTickets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Quando apri un ticket dall app, qui troverai il thread e le eventuali risposte admin.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: trackedTickets
                    .map((trackedTicket) {
                      final thread = ticketThreadsById[trackedTicket.id];
                      final unreadReplies = thread == null
                          ? 0
                          : math.max(
                              0,
                              thread.adminReplyCount -
                                  trackedTicket.lastSeenAdminReplyCount,
                            );
                      final isSelected = trackedTicket.id == selectedTicketId;
                      return FilterChip(
                        key: ValueKey('tracked-ticket-${trackedTicket.id}'),
                        selected: isSelected,
                        onSelected: (_) => onSelectTicket(trackedTicket.id),
                        label: Text(
                          unreadReplies > 0
                              ? '${trackedTicket.subject} · $unreadReplies nuove'
                              : trackedTicket.subject,
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              if (selectedThread != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            selectedThread.subject,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          _TicketPill(
                            label: selectedThread.status.label,
                            color: _ticketStatusColor(
                              context,
                              selectedThread.status,
                            ),
                          ),
                          Text(
                            'Aggiornato ${_formatTicketDateTime(selectedThread.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        'Codice ticket: ${selectedThread.id}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messaggio iniziale',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(selectedThread.message),
                          ],
                        ),
                      ),
                      if (selectedThread.attachments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Screenshot allegati',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: selectedThread.attachments
                              .map(
                                (attachment) => _TicketAttachmentChip(
                                  fileName: attachment.fileName,
                                  sizeLabel: _formatTicketAttachmentSize(
                                    attachment.sizeBytes,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      if (selectedThread.replies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...selectedThread.replies.map((reply) {
                          final isAdminReply = reply.isAdminReply;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isAdminReply
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAdminReply
                                      ? 'Risposta admin'
                                      : 'Tua replica',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTicketDateTime(reply.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(reply.message),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (isSelectedThreadClosed) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            'Ticket chiuso: non puoi inviare nuove risposte.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: replyController,
                        maxLines: 4,
                        enabled: !isSelectedThreadClosed && !isSubmittingReply,
                        decoration: InputDecoration(
                          labelText: isSelectedThreadClosed
                              ? 'Ticket chiuso'
                              : 'Rispondi al ticket',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: isSubmittingReply || isSelectedThreadClosed
                            ? null
                            : () => onSubmitReply(),
                        icon: const Icon(Icons.reply_rounded),
                        label: Text(
                          isSelectedThreadClosed
                              ? 'Ticket chiuso'
                              : isSubmittingReply
                              ? 'Invio risposta...'
                              : 'Invia risposta',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Recupera ticket con codice',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Anche senza account: salva il codice ticket e incollalo qui se cambi telefono o reinstalli l app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('ticket-recovery-id-field'),
                    controller: recoveryTicketIdController,
                    enabled: !isRecoveringTicket,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Codice ticket',
                      hintText: 'es. 8f72c4b2-...',
                    ),
                    onFieldSubmitted: (_) {
                      if (!isRecoveringTicket) {
                        unawaited(onRecoverTicketById());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  key: const ValueKey('ticket-recovery-submit-button'),
                  onPressed: isRecoveringTicket
                      ? null
                      : () => unawaited(onRecoverTicketById()),
                  icon: isRecoveringTicket
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(
                    isRecoveringTicket ? 'Recupero...' : 'Recupera',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Apri un nuovo ticket',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: SupportTicketCategory.values
                  .map(
                    (category) => ChoiceChip(
                      key: ValueKey('ticket-category-${category.apiValue}'),
                      label: Text(category.label),
                      selected: selectedCategory == category,
                      onSelected: isSubmitting
                          ? null
                          : (_) => onCategoryChanged(category),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Text(
              selectedCategory.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Facoltativa, se vuoi una risposta',
              ),
              validator: (value) {
                final normalizedValue = value?.trim() ?? '';
                if (normalizedValue.isEmpty) {
                  return null;
                }

                final isValidEmail = RegExp(
                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                ).hasMatch(normalizedValue);
                return isValidEmail ? null : 'Inserisci un email valida.';
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('ticket-subject-field'),
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Oggetto'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci un oggetto.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('ticket-message-field'),
              controller: messageController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Messaggio',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Descrivi la richiesta o il problema.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Screenshot',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Puoi scegliere fino a 3 screenshot dalla galleria in PNG, JPG o WEBP da massimo 4 MB ciascuno.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('ticket-attachments-button'),
                  onPressed: isSubmitting ? null : () => onPickAttachments(),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    attachments.isEmpty
                        ? 'Scegli dalla galleria'
                        : 'Aggiungi altri screenshot',
                  ),
                ),
                if (attachments.isNotEmpty)
                  _TicketPill(
                    label:
                        '${attachments.length}/$_maxTicketAttachments allegati',
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: attachments
                    .asMap()
                    .entries
                    .map(
                      (entry) => _TicketAttachmentChip(
                        fileName: entry.value.fileName,
                        sizeLabel: _formatTicketAttachmentSize(
                          entry.value.sizeBytes,
                        ),
                        onDeleted: () => onRemoveAttachment(entry.key),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: appVersionController,
              decoration: const InputDecoration(
                labelText: 'Versione app',
                hintText: 'Facoltativa',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('ticket-submit-button'),
              onPressed: isSubmitting ? null : () => onSubmit(),
              icon: const Icon(Icons.send_outlined),
              label: Text(isSubmitting ? 'Invio...' : 'Invia ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketPill extends StatelessWidget {
  const _TicketPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TicketAttachmentChip extends StatelessWidget {
  const _TicketAttachmentChip({
    required this.fileName,
    required this.sizeLabel,
    this.onDeleted,
  });

  final String fileName;
  final String sizeLabel;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: onDeleted == null ? 200 : 160,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(sizeLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDeleted,
              visualDensity: VisualDensity.compact,
              tooltip: 'Rimuovi screenshot',
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

enum _UpdateDialogAction { updateNow, remindLater }

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aggiornamento disponibile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hai la versione ${update.currentVersion}. E disponibile la ${update.latestVersion}.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Vuoi scaricare subito la nuova APK dentro l app oppure preferisci un promemoria piu tardi?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_UpdateDialogAction.remindLater);
          },
          child: const Text('Ricordamelo piu tardi'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(_UpdateDialogAction.updateNow);
          },
          icon: const Icon(Icons.system_update_alt),
          label: const Text('Aggiorna subito'),
        ),
      ],
    );
  }
}

enum _UpdateDownloadState { downloading, readyToInstall, failed, installing }
enum _UpdateDownloadDialogAction { downloadInBackground }

class _UpdateDownloadDialog extends StatefulWidget {
  const _UpdateDownloadDialog({
    required this.update,
    required this.appUpdateService,
    required this.onOpenReleasePage,
    required this.onBackgroundDownloadEnabled,
    required this.onBackgroundProgress,
    required this.onBackgroundDownloadCompleted,
    required this.onBackgroundDownloadFailed,
  });

  final AppUpdate update;
  final AppUpdateService appUpdateService;
  final Future<void> Function() onOpenReleasePage;
  final VoidCallback onBackgroundDownloadEnabled;
  final ValueChanged<UpdateDownloadProgress> onBackgroundProgress;
  final Future<void> Function(DownloadedAppUpdate downloadedUpdate)
  onBackgroundDownloadCompleted;
  final VoidCallback onBackgroundDownloadFailed;

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  UpdateDownloadProgress _progress = const UpdateDownloadProgress(
    receivedBytes: 0,
    totalBytes: null,
  );
  DownloadedAppUpdate? _downloadedUpdate;
  _UpdateDownloadState _state = _UpdateDownloadState.downloading;
  bool _isNewFeatureExpanded = false;
  bool _continueInBackground = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = _UpdateDownloadState.downloading;
      _message = null;
      _downloadedUpdate = null;
      _progress = const UpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      );
    });

    try {
      final downloadedUpdate = await widget.appUpdateService.downloadUpdate(
        widget.update,
        onProgress: (progress) {
          if (_continueInBackground) {
            widget.onBackgroundProgress(progress);
          }
          if (!mounted) {
            return;
          }

          setState(() {
            _progress = progress;
          });
        },
      );

      if (_continueInBackground) {
        unawaited(widget.onBackgroundDownloadCompleted(downloadedUpdate));
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _downloadedUpdate = downloadedUpdate;
        _state = _UpdateDownloadState.readyToInstall;
      });
    } catch (_) {
      if (!mounted) {
        if (_continueInBackground) {
          widget.onBackgroundDownloadFailed();
        }
        return;
      }

      setState(() {
        _state = _UpdateDownloadState.failed;
        _message = 'Download non riuscito. Controlla la connessione e riprova.';
      });
      if (_continueInBackground) {
        widget.onBackgroundDownloadFailed();
      }
    }
  }

  void _continueDownloadInBackground() {
    if (_state != _UpdateDownloadState.downloading || _continueInBackground) {
      return;
    }

    _continueInBackground = true;
    widget.onBackgroundDownloadEnabled();
    Navigator.of(context).pop(_UpdateDownloadDialogAction.downloadInBackground);
  }

  Future<void> _installDownloadedUpdate() async {
    final downloadedUpdate = _downloadedUpdate;
    if (downloadedUpdate == null || _state == _UpdateDownloadState.installing) {
      return;
    }

    setState(() {
      _state = _UpdateDownloadState.installing;
      _message = null;
    });

    final result = await widget.appUpdateService.installUpdate(
      downloadedUpdate,
    );
    if (!mounted) {
      return;
    }

    switch (result) {
      case UpdateInstallResult.started:
        Navigator.of(context).pop();
        break;
      case UpdateInstallResult.permissionRequired:
        setState(() {
          _state = _UpdateDownloadState.readyToInstall;
          _message =
              'Per installare l APK devi autorizzare questa app nelle impostazioni Android, poi tocca di nuovo Installa.';
        });
        break;
      case UpdateInstallResult.failed:
        setState(() {
          _state = _UpdateDownloadState.readyToInstall;
          _message = 'Impossibile avviare l installazione dell aggiornamento.';
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final newFeatureItems = _resolveNewFeatureItems(widget.update.releaseNotes);
    final progressText = _progress.totalBytes == null
        ? '${_formatDownloadSize(_progress.receivedBytes)} scaricati'
        : '${_formatDownloadSize(_progress.receivedBytes)} di ${_formatDownloadSize(_progress.totalBytes!)}';

    return AlertDialog(
      title: Text(_resolveTitle()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versione attuale ${widget.update.currentVersion} -> nuova versione ${widget.update.latestVersion}',
            ),
            const SizedBox(height: 12),
            _buildNewFeatureSection(
              context,
              featureItems: newFeatureItems,
            ),
            const SizedBox(height: 16),
            if (_state == _UpdateDownloadState.downloading) ...[
              LinearProgressIndicator(value: _progress.fractionCompleted),
              const SizedBox(height: 12),
              Text(progressText),
            ] else if (_state == _UpdateDownloadState.readyToInstall) ...[
              const Text(
                'Download completato. Quando sei pronto puoi avviare subito l installazione.',
              ),
              const SizedBox(height: 12),
              if (_downloadedUpdate != null)
                Text(
                  'File pronto: ${_downloadedUpdate!.fileName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ] else if (_state == _UpdateDownloadState.installing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Avvio dell installazione in corso...'),
            ] else ...[
              const Text(
                'Non siamo riusciti a scaricare l aggiornamento dentro l app.',
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9D3D2F),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _state == _UpdateDownloadState.installing ||
                  _state == _UpdateDownloadState.downloading
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Piu tardi'),
        ),
        if (_state == _UpdateDownloadState.downloading)
          OutlinedButton.icon(
            onPressed: _continueDownloadInBackground,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Scarica in background'),
          ),
        if (_state == _UpdateDownloadState.failed)
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton(
                onPressed: () async {
                  await widget.onOpenReleasePage();
                },
                child: const Text('Apri pagina release'),
              ),
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          )
        else if (_state == _UpdateDownloadState.readyToInstall)
          FilledButton.icon(
            onPressed: _installDownloadedUpdate,
            icon: const Icon(Icons.install_mobile_outlined),
            label: const Text('Installa'),
          ),
      ],
    );
  }

  Widget _buildNewFeatureSection(
    BuildContext context, {
    required List<String> featureItems,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasFeatures = featureItems.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF142121) : const Color(0xFFF4FBFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2C4747) : const Color(0xFFD4E8E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _isNewFeatureExpanded = !_isNewFeatureExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'New Feature',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isNewFeatureExpanded ? 'Nascondi' : 'Apri',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isNewFeatureExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_isNewFeatureExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: hasFeatures
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: featureItems
                          .map((item) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '- $item',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ))
                          .toList(growable: false),
                    )
                  : Text(
                      'Nessun dettaglio disponibile per questo update.',
                      style: theme.textTheme.bodyMedium,
                    ),
            ),
        ],
      ),
    );
  }

  List<String> _resolveNewFeatureItems(String? releaseNotes) {
    if (releaseNotes == null) {
      return const [];
    }

    final lines = releaseNotes.replaceAll('\r\n', '\n').split('\n');
    final items = <String>[];
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      if (line.startsWith('#') || line.startsWith('```')) {
        continue;
      }

      final lowerLine = line.toLowerCase();
      if (lowerLine.startsWith('what\'s changed') ||
          lowerLine.startsWith("what’s changed") ||
          lowerLine.startsWith('new contributors')) {
        continue;
      }

      if (line.toLowerCase().startsWith('full changelog')) {
        continue;
      }

      final cleaned = line
          .replaceFirst(RegExp(r'^[-*+]\s+'), '')
          .replaceFirst(RegExp(r'^\d+\.\s+'), '')
          .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
          .replaceAll(RegExp(r'\s*\(#\d+\)$'), '')
          .replaceAll(RegExp(r'\s+by\s+@[\w-]+\s*$', caseSensitive: false), '')
          .trim();
      if (cleaned.isEmpty) {
        continue;
      }
      if (_isGenericBuildNote(cleaned)) {
        continue;
      }

      items.add(cleaned);
      if (items.length >= 5) {
        break;
      }
    }

    if (items.isNotEmpty) {
      return items;
    }

    final compact = releaseNotes
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.isEmpty) {
      return const [];
    }
    if (_isGenericBuildNote(compact)) {
      return const [];
    }

    if (compact.length <= 120) {
      return [compact];
    }

    return ['${compact.substring(0, 117)}...'];
  }

  String _resolveTitle() {
    switch (_state) {
      case _UpdateDownloadState.downloading:
        return 'Scarico aggiornamento';
      case _UpdateDownloadState.readyToInstall:
        return 'Aggiornamento pronto';
      case _UpdateDownloadState.failed:
        return 'Download non riuscito';
      case _UpdateDownloadState.installing:
        return 'Avvio installazione';
    }
  }

  bool _isGenericBuildNote(String value) {
    final normalized = value.toLowerCase().trim();
    return RegExp(r'^android apk build[\s:]+v?\d+(\.\d+){1,4}\.?$').hasMatch(
      normalized,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A201B) : const Color(0xFFFFF1EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF704033) : const Color(0xFFE6B8A5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operazione non riuscita',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasTitle = title.trim().isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final hasHeader = hasTitle || hasSubtitle || trailing != null;

    final header = switch ((hasTitle || hasSubtitle, trailing != null)) {
      (true, true) => Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTitle)
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (hasSubtitle) ...[
                  if (hasTitle) const SizedBox(height: 6),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          trailing!,
        ],
      ),
      (true, false) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle)
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          if (hasSubtitle) ...[
            if (hasTitle) const SizedBox(height: 6),
            Text(subtitle!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
      (false, true) => trailing!,
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111919) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF324343) : const Color(0xFFE0D8CA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?header,
          if (hasHeader) SizedBox(height: hasTitle || hasSubtitle ? 18 : 14),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor = const Color(0xFF123131),
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162121) : const Color(0xFFF7F3EC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: item.accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: item.accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.subtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(item.date, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatHours(item.minutes),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: item.accentColor,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.controller, required this.onPickDate});

  final TextEditingController controller;
  final Future<void> Function() onPickDate;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey('quick-entry-date-field'),
      controller: controller,
      readOnly: true,
      onTap: () => onPickDate(),
      decoration: const InputDecoration(
        labelText: 'Data',
        suffixIcon: Icon(Icons.calendar_today),
      ),
      validator: (value) {
        if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
          return 'Seleziona una data valida.';
        }

        return null;
      },
    );
  }
}

class _MinutesField extends StatelessWidget {
  const _MinutesField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsedValue = int.tryParse(value?.trim() ?? '');
        if (parsedValue == null || parsedValue <= 0) {
          return 'Inserisci un numero di minuti valido.';
        }

        return null;
      },
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.key,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.accentColor,
    required this.icon,
  });

  final String key;
  final String date;
  final String title;
  final String subtitle;
  final int minutes;
  final Color accentColor;
  final IconData icon;
}

class _CalendarDay {
  const _CalendarDay({
    required this.date,
    required this.isoDate,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.hasOverride,
    required this.isToday,
    required this.isSelected,
    required this.relation,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.details,
  });

  const _CalendarDay.empty()
    : date = null,
      isoDate = '',
      expectedMinutes = 0,
      workedMinutes = 0,
      leaveMinutes = 0,
      hasOverride = false,
      isToday = false,
      isSelected = false,
      relation = _CalendarDayRelation.future,
      primaryLabel = null,
      secondaryLabel = null,
      details = null;

  final DateTime? date;
  final String isoDate;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final bool hasOverride;
  final bool isToday;
  final bool isSelected;
  final _CalendarDayRelation relation;
  final String? primaryLabel;
  final String? secondaryLabel;
  final _CalendarDayDetails? details;
}

enum _CalendarDayRelation { past, today, future }

class _CalendarDayDetails {
  const _CalendarDayDetails({
    required this.timelineLines,
    required this.workedLabel,
    required this.pauseLabel,
    required this.workedMinutes,
    required this.pauseMinutes,
    this.startMinutes,
    this.pauseStartMinutes,
    this.resumeMinutes,
    this.endMinutes,
  });

  final List<String> timelineLines;
  final String workedLabel;
  final String pauseLabel;
  final int workedMinutes;
  final int pauseMinutes;
  final int? startMinutes;
  final int? pauseStartMinutes;
  final int? resumeMinutes;
  final int? endMinutes;
}

class _CalendarPauseWindow {
  const _CalendarPauseWindow({
    required this.pauseStartMinutes,
    required this.resumeMinutes,
  });

  final int pauseStartMinutes;
  final int resumeMinutes;
}

class _ScheduleOverrideDraftState {
  const _ScheduleOverrideDraftState({required this.schedule, this.pauseWindow});

  final DaySchedule schedule;
  final _CalendarPauseWindow? pauseWindow;
}

class _DayMetrics {
  const _DayMetrics({
    required this.date,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.rawBalanceMinutes,
    required this.balanceMinutes,
    required this.hasOverride,
    required this.schedule,
    this.overrideNote,
  });

  factory _DayMetrics.empty(DateTime date) {
    return _DayMetrics(
      date: date,
      expectedMinutes: 0,
      workedMinutes: 0,
      leaveMinutes: 0,
      rawBalanceMinutes: 0,
      balanceMinutes: 0,
      hasOverride: false,
      schedule: const DaySchedule(targetMinutes: 0),
    );
  }

  final DateTime date;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int rawBalanceMinutes;
  final int balanceMinutes;
  final bool hasOverride;
  final DaySchedule schedule;
  final String? overrideNote;
}

class _AgendaRange {
  const _AgendaRange({required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;

  int get totalMinutes => endMinutes - startMinutes;

  Iterable<int> get hourMarks sync* {
    for (var mark = startMinutes; mark <= endMinutes; mark += 60) {
      yield mark;
    }
  }

  double timelineHeight({double pixelsPerHour = 32, double minHeight = 280}) {
    final computedHeight = (totalMinutes / 60) * pixelsPerHour;
    return math.max(computedHeight, minHeight).toDouble();
  }

  double positionFor(int minutes, double height) {
    if (totalMinutes <= 0) {
      return 0;
    }

    final clampedMinutes = minutes.clamp(startMinutes, endMinutes).toDouble();
    return ((clampedMinutes - startMinutes) / totalMinutes) * height;
  }

  int minutesForPosition(double position, double height, {int snapStep = 1}) {
    if (height <= 0 || totalMinutes <= 0) {
      return startMinutes;
    }

    final ratio = (position / height).clamp(0.0, 1.0);
    final rawMinutes = startMinutes + (ratio * totalMinutes);
    final snappedMinutes = ((rawMinutes / snapStep).round() * snapStep).toInt();
    return snappedMinutes.clamp(startMinutes, endMinutes);
  }
}

class _MonthMetrics {
  const _MonthMetrics({
    required this.month,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.rawBalanceMinutes,
    required this.balanceMinutes,
    required this.overrideCount,
  });

  factory _MonthMetrics.empty(String month) {
    return _MonthMetrics(
      month: month,
      expectedMinutes: 0,
      workedMinutes: 0,
      leaveMinutes: 0,
      rawBalanceMinutes: 0,
      balanceMinutes: 0,
      overrideCount: 0,
    );
  }

  final String month;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int rawBalanceMinutes;
  final int balanceMinutes;
  final int overrideCount;
}

class _DisplayedMonthBalanceInfo {
  const _DisplayedMonthBalanceInfo({required this.value});

  final String value;
}

class _DisplayedPeriodBalanceInfo {
  const _DisplayedPeriodBalanceInfo({required this.balanceMinutes});

  final int balanceMinutes;
}

class _QuickDayControlInsights {
  const _QuickDayControlInsights({
    required this.controlledBalanceMinutes,
    required this.todayOvertimeMinutes,
    required this.exceededOvertimeMinutes,
    required this.showConfigurationHint,
    this.limitWarningText,
    this.configurationHint,
  });

  final int controlledBalanceMinutes;
  final int todayOvertimeMinutes;
  final int exceededOvertimeMinutes;
  final bool showConfigurationHint;
  final String? limitWarningText;
  final String? configurationHint;
}

class _WeekPlanDay {
  const _WeekPlanDay({
    required this.date,
    required this.status,
    required this.metrics,
    this.overrideNote,
  });

  factory _WeekPlanDay.empty(DateTime date) {
    return _WeekPlanDay(
      date: date,
      status: _TodayStatus.planned,
      metrics: _DayMetrics.empty(date),
    );
  }

  final DateTime date;
  final _TodayStatus status;
  final _DayMetrics metrics;
  final String? overrideNote;
}

String _formatHours(int minutes, {bool signed = false}) {
  final absoluteHours = minutes.abs() / 60;
  final formattedHours = absoluteHours == absoluteHours.truncateToDouble()
      ? absoluteHours.toStringAsFixed(0)
      : absoluteHours.toStringAsFixed(1);

  if (!signed) {
    return '${minutes < 0 ? '-' : ''}${formattedHours}h';
  }

  if (minutes == 0) {
    return '0h';
  }

  final prefix = minutes > 0 ? '+' : '-';
  return '$prefix${formattedHours}h';
}

String _formatHoursInput(int minutes) {
  return formatHoursInput(minutes);
}

String _formatSignedHoursInput(int minutes) {
  if (minutes == 0) {
    return '0:00';
  }

  final prefix = minutes > 0 ? '+' : '-';
  return '$prefix${_formatHoursInput(minutes.abs())}';
}

bool _matchesDaySchedule(DaySchedule left, DaySchedule right) {
  return left.targetMinutes == right.targetMinutes &&
      left.startTime == right.startTime &&
      left.endTime == right.endTime &&
      left.breakMinutes == right.breakMinutes;
}

bool _isExplicitDayOffSchedule(DaySchedule schedule) {
  final startTime = schedule.startTime?.trim() ?? '';
  final endTime = schedule.endTime?.trim() ?? '';
  return schedule.targetMinutes == 0 &&
      schedule.breakMinutes == 0 &&
      startTime.isEmpty &&
      endTime.isEmpty;
}

int _resolveDisplayedExpectedMinutes({
  required DaySchedule effectiveSchedule,
  required DaySchedule quickEditorSchedule,
}) {
  if (_isExplicitDayOffSchedule(quickEditorSchedule)) {
    return 0;
  }

  return effectiveSchedule.targetMinutes;
}

int? _resolveComputedWorkedMinutes({
  required DaySchedule schedule,
  int minimumBreakMinutes = 0,
}) {
  final startMinutes = parseTimeInput(schedule.startTime);
  final endMinutes = parseTimeInput(schedule.endTime);
  if (startMinutes == null ||
      endMinutes == null ||
      endMinutes <= startMinutes) {
    return null;
  }

  final effectiveBreakMinutes = math.max(
    schedule.breakMinutes,
    minimumBreakMinutes,
  );
  return math.max(0, endMinutes - startMinutes - effectiveBreakMinutes);
}

int _resolveDisplayedWorkedMinutes({
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
}) {
  return _resolveComputedWorkedMinutes(
        schedule: quickEditorSchedule,
        minimumBreakMinutes: workRules.minimumBreakMinutes,
      ) ??
      0;
}

int _resolveLiveWorkedMinutes({
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
  required WorkdaySession? session,
  required _CalendarPauseWindow? pauseWindow,
  required int nowMinutes,
  String? rawStartTimeText,
  String? rawEndTimeText,
  bool treatEndAsActual = false,
}) {
  if (session != null) {
    final measurementSegments = _buildAgendaMeasurementSegments(
      schedule: quickEditorSchedule,
      session: session,
      nowMinutes: nowMinutes,
      pauseWindow: pauseWindow,
    );
    if (measurementSegments.isNotEmpty) {
      return measurementSegments
          .where((segment) => segment.kind == _AgendaMeasurementSegmentKind.work)
          .fold<int>(
            0,
            (total, segment) =>
                total + (segment.endMinutes - segment.startMinutes),
          );
    }
  }

  final resolvedStartMinutes =
      parseTimeInput(rawStartTimeText?.trim()) ??
      parseTimeInput(quickEditorSchedule.startTime);
  final resolvedEndMinutes =
      parseTimeInput(rawEndTimeText?.trim()) ??
      parseTimeInput(quickEditorSchedule.endTime);

  if (resolvedStartMinutes == null) {
    return _resolveDisplayedWorkedMinutes(
      quickEditorSchedule: quickEditorSchedule,
      workRules: workRules,
    );
  }

  if (treatEndAsActual &&
      resolvedEndMinutes != null &&
      resolvedEndMinutes > resolvedStartMinutes &&
      resolvedEndMinutes <= nowMinutes) {
    final breakMinutes = quickEditorSchedule.breakMinutes.clamp(
      0,
      resolvedEndMinutes - resolvedStartMinutes,
    );
    return math.max(
      0,
      resolvedEndMinutes - resolvedStartMinutes - breakMinutes,
    );
  }

  // For today we keep the worked counter aligned with the current clock time.
  // The planned/scheduled end time does not freeze the live counter.
  final runningMinutes = math.max(0, nowMinutes - resolvedStartMinutes);
  return math.max(0, runningMinutes - quickEditorSchedule.breakMinutes);
}

int? _resolveSuggestedExitTotalMinutes({
  required DaySchedule effectiveSchedule,
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
  String? rawStartTimeText,
}) {
  final expectedMinutes = _resolveDisplayedExpectedMinutes(
    effectiveSchedule: effectiveSchedule,
    quickEditorSchedule: quickEditorSchedule,
  );
  if (expectedMinutes <= 0) {
    return null;
  }

  final startMinutes =
      parseTimeInput(rawStartTimeText?.trim()) ??
      parseTimeInput(quickEditorSchedule.startTime) ??
      parseTimeInput(effectiveSchedule.startTime);
  if (startMinutes == null) {
    return null;
  }

  final effectiveBreakMinutes = math.max(
    quickEditorSchedule.breakMinutes,
    math.max(effectiveSchedule.breakMinutes, workRules.minimumBreakMinutes),
  );
  return startMinutes + expectedMinutes + effectiveBreakMinutes;
}

String _resolveSuggestedExitLabel({
  required DaySchedule effectiveSchedule,
  required DaySchedule quickEditorSchedule,
  required UserWorkRules workRules,
  String? rawStartTimeText,
  String? rawEndTimeText,
}) {
  final expectedMinutes = _resolveDisplayedExpectedMinutes(
    effectiveSchedule: effectiveSchedule,
    quickEditorSchedule: quickEditorSchedule,
  );
  if (expectedMinutes <= 0) {
    return 'Libero';
  }

  final suggestedExitTotalMinutes = _resolveSuggestedExitTotalMinutes(
    effectiveSchedule: effectiveSchedule,
    quickEditorSchedule: quickEditorSchedule,
    workRules: workRules,
    rawStartTimeText: rawStartTimeText,
  );
  if (suggestedExitTotalMinutes == null) {
    final fallbackEndMinutes =
        parseTimeInput(rawEndTimeText?.trim()) ??
        parseTimeInput(effectiveSchedule.endTime) ??
        parseTimeInput(quickEditorSchedule.endTime);
    return fallbackEndMinutes == null
        ? '--:--'
        : formatTimeInput(fallbackEndMinutes);
  }

  final normalizedMinutes = suggestedExitTotalMinutes % (24 * 60);
  final nextDaySuffix = suggestedExitTotalMinutes >= (24 * 60) ? ' +1g' : '';
  return '${formatTimeInput(normalizedMinutes)}$nextDaySuffix';
}

_DisplayedMonthBalanceInfo _buildDisplayedMonthBalanceInfo({
  required DateTime selectedDate,
  required List<_CalendarDay> days,
  required int liveExpectedMinutes,
  required int liveWorkedMinutes,
  required int liveLeaveMinutes,
}) {
  final selectedDay = DateUtils.dateOnly(selectedDate);
  final monthDays = days
      .where((day) => day.date != null)
      .toList(growable: false);
  if (monthDays.isEmpty) {
    return const _DisplayedMonthBalanceInfo(value: '0:00');
  }

  var monthWorkedMinutes = 0;
  var monthExpectedMinutes = 0;
  final hasLiveContext = _hasRegisteredBalanceContext(
    workedMinutes: liveWorkedMinutes,
    leaveMinutes: liveLeaveMinutes,
  );

  for (final day in monthDays) {
    final date = day.date;
    if (date == null) {
      continue;
    }

    final isSelectedCalendarDay = _isSameDay(date, selectedDay);
    monthExpectedMinutes += isSelectedCalendarDay
        ? liveExpectedMinutes
        : day.expectedMinutes;

    if (day.relation == _CalendarDayRelation.future && !isSelectedCalendarDay) {
      continue;
    }

    if (isSelectedCalendarDay) {
      monthWorkedMinutes += hasLiveContext
          ? liveWorkedMinutes
          : _resolveWorkedMinutesForCalendarDay(day);
      continue;
    }

    monthWorkedMinutes += _resolveWorkedMinutesForCalendarDay(day);
  }

  if (monthExpectedMinutes <= 0) {
    return _DisplayedMonthBalanceInfo(
      value: _formatHoursInput(monthWorkedMinutes),
    );
  }

  return _DisplayedMonthBalanceInfo(
    value:
        '${_formatHoursInput(monthWorkedMinutes)} / ${_formatHoursInput(monthExpectedMinutes)}',
  );
}

int _resolveWorkedMinutesForCalendarDay(_CalendarDay day) {
  if (day.workedMinutes > 0) {
    return day.workedMinutes;
  }

  if (day.relation == _CalendarDayRelation.past && day.hasOverride) {
    final derivedWorkedMinutes = day.details?.workedMinutes ?? 0;
    if (derivedWorkedMinutes > 0) {
      return derivedWorkedMinutes;
    }
  }

  return 0;
}

_DisplayedPeriodBalanceInfo _buildDisplayedPeriodBalanceInfo({
  required DateTime selectedDate,
  required List<_CalendarDay> days,
  required List<_DayMetrics> weekMetrics,
  required DayBalanceAggregation aggregation,
  required int liveExpectedMinutes,
  required int liveWorkedMinutes,
  required int liveLeaveMinutes,
}) {
  final selectedDay = DateUtils.dateOnly(selectedDate);
  final hasLiveContext = _hasRegisteredBalanceContext(
    workedMinutes: liveWorkedMinutes,
    leaveMinutes: liveLeaveMinutes,
  );
  final liveDayBalanceMinutes =
      (liveWorkedMinutes + liveLeaveMinutes) - liveExpectedMinutes;

  switch (aggregation) {
    case DayBalanceAggregation.weekly:
      var hasWeeklyEntries = false;
      final weeklyBalanceMinutes = weekMetrics.fold<int>(0, (total, metric) {
        if (_isSameDay(metric.date, selectedDay)) {
          if (!hasLiveContext) {
            return total;
          }
          hasWeeklyEntries = true;
          return total + liveDayBalanceMinutes;
        }
        final hasMetricContext = _hasRegisteredBalanceContext(
          workedMinutes: metric.workedMinutes,
          leaveMinutes: metric.leaveMinutes,
        );
        if (!hasMetricContext) {
          return total;
        }
        hasWeeklyEntries = true;
        return total + metric.rawBalanceMinutes;
      });
      return _DisplayedPeriodBalanceInfo(
        balanceMinutes: hasWeeklyEntries ? weeklyBalanceMinutes : 0,
      );
    case DayBalanceAggregation.monthly:
      var monthlyBalanceMinutes = 0;
      var hasMonthlyEntries = false;
      for (final day in days) {
        final date = day.date;
        if (date == null) {
          continue;
        }
        if (day.relation == _CalendarDayRelation.future) {
          continue;
        }
        if (_isSameDay(date, selectedDay)) {
          if (!hasLiveContext) {
            continue;
          }
          hasMonthlyEntries = true;
          monthlyBalanceMinutes += liveDayBalanceMinutes;
          continue;
        }
        final workedMinutes = _resolveWorkedMinutesForCalendarDay(day);
        final hasDayContext = _hasRegisteredBalanceContext(
          workedMinutes: workedMinutes,
          leaveMinutes: day.leaveMinutes,
        );
        if (!hasDayContext) {
          continue;
        }
        hasMonthlyEntries = true;
        monthlyBalanceMinutes +=
            (workedMinutes + day.leaveMinutes) - day.expectedMinutes;
      }
      return _DisplayedPeriodBalanceInfo(
        balanceMinutes: hasMonthlyEntries ? monthlyBalanceMinutes : 0,
      );
  }
}

bool _hasRegisteredBalanceContext({
  required int workedMinutes,
  required int leaveMinutes,
}) {
  return workedMinutes > 0 || leaveMinutes > 0;
}

const int _unboundedDailyLimitMinutes = 24 * 60;
const int _unboundedMonthlyLimitMinutes = 31 * 24 * 60;

_QuickDayControlInsights _buildQuickDayControlInsights({
  required DateTime selectedDate,
  required UserWorkRules workRules,
  required List<_CalendarDay> days,
  required List<_DayMetrics> weekMetrics,
  required int liveExpectedMinutes,
  required int liveWorkedMinutes,
  required int liveLeaveMinutes,
  required bool hasLiveResultContext,
}) {
  final dailyCreditLimit = _resolveConfiguredDailyCreditLimit(workRules);
  final dailyDebitLimit = _resolveConfiguredDailyDebitLimit(workRules);
  final liveRawBalanceMinutes =
      (liveWorkedMinutes + liveLeaveMinutes) - liveExpectedMinutes;

  final controlledBalanceMinutes = _resolveControlledDayBalanceMinutes(
    rawBalanceMinutes: liveRawBalanceMinutes,
    dailyCreditLimitMinutes: dailyCreditLimit,
    dailyDebitLimitMinutes: dailyDebitLimit,
  );
  final todayOvertimeMinutes = _resolveDailyOvertimeMinutes(
    rawBalanceMinutes: liveRawBalanceMinutes,
    dailyCreditLimitMinutes: dailyCreditLimit,
  );

  final selectedDay = DateUtils.dateOnly(selectedDate);
  var weeklyOvertimeMinutes = 0;
  for (final metric in weekMetrics) {
    final isSelectedMetric = _isSameDay(metric.date, selectedDay);
    final hasMetricContext = isSelectedMetric
        ? hasLiveResultContext
        : _hasRegisteredBalanceContext(
            workedMinutes: metric.workedMinutes,
            leaveMinutes: metric.leaveMinutes,
          );
    if (!hasMetricContext) {
      continue;
    }

    final rawBalanceMinutes = isSelectedMetric
        ? liveRawBalanceMinutes
        : metric.rawBalanceMinutes;
    weeklyOvertimeMinutes += _resolveDailyOvertimeMinutes(
      rawBalanceMinutes: rawBalanceMinutes,
      dailyCreditLimitMinutes: dailyCreditLimit,
    );
  }

  var monthlyOvertimeMinutes = 0;
  var monthlyRawBalanceMinutes = 0;
  for (final day in days) {
    final date = day.date;
    if (date == null || day.relation == _CalendarDayRelation.future) {
      continue;
    }
    final isSelectedCalendarDay = _isSameDay(date, selectedDay);
    final hasDayContext = isSelectedCalendarDay
        ? hasLiveResultContext
        : _hasRegisteredBalanceContext(
            workedMinutes: _resolveWorkedMinutesForCalendarDay(day),
            leaveMinutes: day.leaveMinutes,
          );
    if (!hasDayContext) {
      continue;
    }

    final rawBalanceMinutes = isSelectedCalendarDay
        ? liveRawBalanceMinutes
        : (_resolveWorkedMinutesForCalendarDay(day) +
              day.leaveMinutes -
              day.expectedMinutes);
    monthlyRawBalanceMinutes += rawBalanceMinutes;
    monthlyOvertimeMinutes += _resolveDailyOvertimeMinutes(
      rawBalanceMinutes: rawBalanceMinutes,
      dailyCreditLimitMinutes: dailyCreditLimit,
    );
  }

  final exceedsWithoutOvertime = todayOvertimeMinutes > 0 && !workRules.overtimeEnabled;
  final dailyOverflow = workRules.overtimeEnabled &&
          workRules.overtimeCapEnabled &&
          workRules.overtimeDailyCapMinutes > 0
      ? math.max(0, todayOvertimeMinutes - workRules.overtimeDailyCapMinutes)
      : 0;
  final weeklyOverflow = workRules.overtimeEnabled &&
          workRules.overtimeCapEnabled &&
          workRules.overtimeWeeklyCapMinutes > 0
      ? math.max(0, weeklyOvertimeMinutes - workRules.overtimeWeeklyCapMinutes)
      : 0;
  final monthlyOverflow = workRules.overtimeEnabled &&
          workRules.overtimeCapEnabled &&
          workRules.overtimeMonthlyCapMinutes > 0
      ? math.max(0, monthlyOvertimeMinutes - workRules.overtimeMonthlyCapMinutes)
      : 0;
  final exceededOvertimeMinutes = exceedsWithoutOvertime
      ? todayOvertimeMinutes
      : [dailyOverflow, weeklyOverflow, monthlyOverflow].reduce(math.max);

  final hasMissingCreditLimit = workRules.maximumDailyCreditMinutes <= 0;
  final showConfigurationHint =
      hasLiveResultContext &&
      liveRawBalanceMinutes > 0 &&
      hasMissingCreditLimit;

  final configurationHint = hasMissingCreditLimit
      ? 'Imposta il massimo credito giornaliero in Orari e permessi, '
      : null;

  final exceededDailyCreditLimitMinutes =
      dailyCreditLimit != null && liveRawBalanceMinutes > dailyCreditLimit
      ? liveRawBalanceMinutes - dailyCreditLimit
      : 0;
  final exceededDailyDebitLimitMinutes =
      dailyDebitLimit != null && liveRawBalanceMinutes < -dailyDebitLimit
      ? (-liveRawBalanceMinutes) - dailyDebitLimit
      : 0;

  final monthlyCreditLimit = _resolveConfiguredMonthlyCreditLimit(workRules);
  final monthlyDebitLimit = _resolveConfiguredMonthlyDebitLimit(workRules);
  final exceededMonthlyCreditLimitMinutes =
      monthlyCreditLimit != null && monthlyRawBalanceMinutes > monthlyCreditLimit
      ? monthlyRawBalanceMinutes - monthlyCreditLimit
      : 0;
  final exceededMonthlyDebitLimitMinutes =
      monthlyDebitLimit != null && monthlyRawBalanceMinutes < -monthlyDebitLimit
      ? (-monthlyRawBalanceMinutes) - monthlyDebitLimit
      : 0;

  final limitWarningText = switch ((
    exceededMonthlyCreditLimitMinutes,
    exceededMonthlyDebitLimitMinutes,
    exceededDailyCreditLimitMinutes,
    exceededDailyDebitLimitMinutes,
  )) {
    (> 0, _, _, _) =>
      'Superato limite credito mensile di ${_formatHoursInput(exceededMonthlyCreditLimitMinutes)}',
    (_, > 0, _, _) =>
      'Superato limite debito mensile di ${_formatHoursInput(exceededMonthlyDebitLimitMinutes)}',
    (_, _, > 0, _) =>
      'Superato limite credito giornaliero di ${_formatHoursInput(exceededDailyCreditLimitMinutes)}',
    (_, _, _, > 0) =>
      'Superato limite debito giornaliero di ${_formatHoursInput(exceededDailyDebitLimitMinutes)}',
    _ => null,
  };

  return _QuickDayControlInsights(
    controlledBalanceMinutes: controlledBalanceMinutes,
    todayOvertimeMinutes: todayOvertimeMinutes,
    exceededOvertimeMinutes: exceededOvertimeMinutes,
    showConfigurationHint: showConfigurationHint,
    limitWarningText: limitWarningText,
    configurationHint: configurationHint,
  );
}

int _resolveControlledDayBalanceMinutes({
  required int rawBalanceMinutes,
  required int? dailyCreditLimitMinutes,
  required int? dailyDebitLimitMinutes,
}) {
  if (rawBalanceMinutes > 0) {
    if (dailyCreditLimitMinutes == null) {
      return rawBalanceMinutes;
    }
    return math.min(rawBalanceMinutes, dailyCreditLimitMinutes);
  }
  if (rawBalanceMinutes < 0) {
    if (dailyDebitLimitMinutes == null) {
      return rawBalanceMinutes;
    }
    return -math.min(-rawBalanceMinutes, dailyDebitLimitMinutes);
  }
  return 0;
}

int _resolveDailyOvertimeMinutes({
  required int rawBalanceMinutes,
  required int? dailyCreditLimitMinutes,
}) {
  if (rawBalanceMinutes <= 0 || dailyCreditLimitMinutes == null) {
    return 0;
  }
  return math.max(0, rawBalanceMinutes - dailyCreditLimitMinutes);
}

int? _resolveConfiguredDailyCreditLimit(UserWorkRules workRules) {
  final creditLimit = workRules.maximumDailyCreditMinutes;
  if (creditLimit <= 0 || creditLimit >= _unboundedDailyLimitMinutes) {
    return null;
  }
  return creditLimit;
}

int? _resolveConfiguredDailyDebitLimit(UserWorkRules workRules) {
  final debitLimit = workRules.maximumDailyDebitMinutes;
  if (debitLimit <= 0 || debitLimit >= _unboundedDailyLimitMinutes) {
    return null;
  }
  return debitLimit;
}

int? _resolveConfiguredMonthlyCreditLimit(UserWorkRules workRules) {
  final creditLimit = workRules.maximumMonthlyCreditMinutes;
  if (creditLimit <= 0 || creditLimit >= _unboundedMonthlyLimitMinutes) {
    return null;
  }
  return creditLimit;
}

int? _resolveConfiguredMonthlyDebitLimit(UserWorkRules workRules) {
  final debitLimit = workRules.maximumMonthlyDebitMinutes;
  if (debitLimit <= 0 || debitLimit >= _unboundedMonthlyLimitMinutes) {
    return null;
  }
  return debitLimit;
}

DateTime _monthToDate(String month) {
  final parts = month.split('-');
  final year = int.parse(parts[0]);
  final monthValue = int.parse(parts[1]);
  return DateTime(year, monthValue, 1);
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}

bool _isSameDay(DateTime left, DateTime right) {
  return _isSameMonth(left, right) && left.day == right.day;
}

int _compareDateToToday(DateTime date) {
  final target = DateUtils.dateOnly(date);
  final today = DateUtils.dateOnly(DateTime.now());
  return target.compareTo(today);
}

String? _buildCalendarDayPrimaryLabel({
  required _CalendarDayRelation relation,
  required DaySchedule schedule,
  required int workedMinutes,
  required int leaveMinutes,
  required bool hasOverride,
}) {
  return switch (relation) {
    _CalendarDayRelation.past => _buildPastCalendarDayLabel(
      workedMinutes: workedMinutes,
      leaveMinutes: leaveMinutes,
      hasOverride: hasOverride,
      schedule: schedule,
    ),
    _CalendarDayRelation.today ||
    _CalendarDayRelation.future => _buildScheduledCalendarDayLabel(schedule),
  };
}

String? _buildCalendarDaySecondaryLabel({
  required _CalendarDayRelation relation,
  required int workedMinutes,
  required int leaveMinutes,
  required bool hasOverride,
  required String? todayStatusLabel,
}) {
  return switch (relation) {
    _CalendarDayRelation.past => switch ((
      workedMinutes > 0,
      leaveMinutes > 0,
      hasOverride,
    )) {
      (true, true, _) => 'Registrato + permesso',
      (true, false, _) => 'Registrato',
      (false, true, _) => 'Permesso',
      (false, false, true) => 'Modificato',
      _ => null,
    },
    _CalendarDayRelation.today => todayStatusLabel ?? 'Oggi',
    _CalendarDayRelation.future => hasOverride ? 'Personalizzato' : 'Default',
  };
}

String? _buildPastCalendarDayLabel({
  required int workedMinutes,
  required int leaveMinutes,
  required bool hasOverride,
  required DaySchedule schedule,
}) {
  if (workedMinutes > 0 && leaveMinutes > 0) {
    return '${_formatHoursInput(workedMinutes)} + ${_formatHoursInput(leaveMinutes)}';
  }
  if (workedMinutes > 0) {
    return '${_formatHoursInput(workedMinutes)} lavoro';
  }
  if (leaveMinutes > 0) {
    return '${_formatHoursInput(leaveMinutes)} permesso';
  }
  if (hasOverride) {
    return _buildScheduledCalendarDayLabel(schedule) ?? 'Modificato';
  }
  return null;
}

String? _buildScheduledCalendarDayLabel(DaySchedule schedule) {
  final start = schedule.startTime?.trim();
  final end = schedule.endTime?.trim();
  if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
    return '$start-$end';
  }
  if (schedule.targetMinutes > 0) {
    return _formatHoursInput(schedule.targetMinutes);
  }
  return 'Libero';
}

_CalendarDayDetails? _buildCalendarDayDetails({
  required _CalendarDayRelation relation,
  required DaySchedule schedule,
  required int workedMinutes,
  required int leaveMinutes,
  required WorkdaySession? session,
}) {
  final startMinutes =
      session?.startMinutes ?? parseTimeInput(schedule.startTime);
  final explicitEndMinutes = parseTimeInput(schedule.endTime);
  final nowMinutes = (DateTime.now().hour * 60) + DateTime.now().minute;
  final endMinutes = session?.endMinutes ?? explicitEndMinutes;
  final pauseMinutes = session != null
      ? _currentSessionBreakMinutes(session, nowMinutes)
      : schedule.breakMinutes;
  final hasRegisteredWorkOrLeave = workedMinutes > 0 || leaveMinutes > 0;
  final resolvedWorkedMinutes = session != null
      ? math.max(
          0,
          ((session.endMinutes ?? nowMinutes) - session.startMinutes) -
              pauseMinutes,
        )
      : relation == _CalendarDayRelation.past
      ? hasRegisteredWorkOrLeave
            ? workedMinutes
            : (_resolveComputedWorkedMinutes(schedule: schedule) ?? 0)
      : 0;

  if (startMinutes == null &&
      endMinutes == null &&
      resolvedWorkedMinutes == 0 &&
      pauseMinutes == 0 &&
      leaveMinutes == 0) {
    return null;
  }

  final timelineLines = <String>[];
  if (startMinutes != null) {
    timelineLines.add('Inizio: ${formatTimeInput(startMinutes)}');
  }

  final pauseWindow = _resolveCalendarPauseWindow(
    schedule: schedule,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    session: session,
    nowMinutes: nowMinutes,
  );
  if (pauseWindow != null) {
    timelineLines.add(
      'Pausa: ${formatTimeInput(pauseWindow.pauseStartMinutes)}',
    );
    timelineLines.add('Ripresa: ${formatTimeInput(pauseWindow.resumeMinutes)}');
  }

  if (endMinutes != null) {
    timelineLines.add('Fine: ${formatTimeInput(endMinutes)}');
  }

  return _CalendarDayDetails(
    timelineLines: timelineLines,
    workedLabel: 'Lavorato: ${_formatHoursInput(resolvedWorkedMinutes)}',
    pauseLabel: 'Pausa: ${_formatHoursInput(pauseMinutes)}',
    workedMinutes: resolvedWorkedMinutes,
    pauseMinutes: pauseMinutes,
    startMinutes: startMinutes,
    pauseStartMinutes: pauseWindow?.pauseStartMinutes,
    resumeMinutes: pauseWindow?.resumeMinutes,
    endMinutes: endMinutes,
  );
}

_CalendarPauseWindow? _resolveCalendarPauseWindow({
  required DaySchedule schedule,
  required int? startMinutes,
  required int? endMinutes,
  required WorkdaySession? session,
  required int nowMinutes,
}) {
  if (session != null) {
    final orderedBreakSegments = [...session.breakSegments]
      ..sort((left, right) => left.startMinutes.compareTo(right.startMinutes));
    if (orderedBreakSegments.isNotEmpty) {
      final firstBreak = orderedBreakSegments.first;
      return _CalendarPauseWindow(
        pauseStartMinutes: firstBreak.startMinutes,
        resumeMinutes: firstBreak.endMinutes,
      );
    }
    if (session.breakStartedMinutes != null) {
      final pauseEndMinutes = session.endMinutes ?? nowMinutes;
      if (pauseEndMinutes > session.breakStartedMinutes!) {
        return _CalendarPauseWindow(
          pauseStartMinutes: session.breakStartedMinutes!,
          resumeMinutes: pauseEndMinutes,
        );
      }
    }
  }

  if (schedule.breakMinutes <= 0 ||
      startMinutes == null ||
      endMinutes == null) {
    return null;
  }

  final totalPresenceMinutes = endMinutes - startMinutes;
  if (totalPresenceMinutes <= schedule.breakMinutes) {
    return null;
  }

  final workMinutes = totalPresenceMinutes - schedule.breakMinutes;
  final pauseStartMinutes = startMinutes + (workMinutes ~/ 2);
  final resumeMinutes = pauseStartMinutes + schedule.breakMinutes;
  if (resumeMinutes > endMinutes) {
    return null;
  }

  return _CalendarPauseWindow(
    pauseStartMinutes: pauseStartMinutes,
    resumeMinutes: resumeMinutes,
  );
}

String _formatDownloadSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

_AgendaRange _resolveAgendaRange(Iterable<_DayMetrics> metricsCollection) {
  return _resolveAgendaRangeForSchedules(
    metricsCollection.map((metrics) => metrics.schedule),
  );
}

_AgendaRange _resolveCompactAgendaRangeForBounds({
  required int? startMinutes,
  required int? endMinutes,
}) {
  if (startMinutes == null ||
      endMinutes == null ||
      endMinutes <= startMinutes) {
    return const _AgendaRange(startMinutes: 6 * 60, endMinutes: 22 * 60);
  }

  var stableStartMinutes = math.max(0, startMinutes - 30);
  var stableEndMinutes = math.min((23 * 60) + 59, endMinutes + 45);
  stableStartMinutes = (stableStartMinutes ~/ 60) * 60;
  stableEndMinutes = ((stableEndMinutes + 59) ~/ 60) * 60;
  stableEndMinutes = math.min(stableEndMinutes, (23 * 60) + 59);

  if ((stableEndMinutes - stableStartMinutes) < 8 * 60) {
    final midpoint = (startMinutes + endMinutes) ~/ 2;
    stableStartMinutes = (midpoint - (8 * 60 ~/ 2)).clamp(0, 16 * 60).toInt();
    stableStartMinutes = (stableStartMinutes ~/ 60) * 60;
    stableEndMinutes = math.min(stableStartMinutes + 8 * 60, (23 * 60) + 59);
  }

  if (stableEndMinutes <= stableStartMinutes) {
    return const _AgendaRange(startMinutes: 6 * 60, endMinutes: 22 * 60);
  }

  return _AgendaRange(
    startMinutes: stableStartMinutes,
    endMinutes: stableEndMinutes,
  );
}

_AgendaRange _resolveAgendaRangeForSchedules(Iterable<DaySchedule> schedules) {
  final starts = <int>[];
  final ends = <int>[];

  for (final schedule in schedules) {
    final startMinutes = parseTimeInput(schedule.startTime);
    final endMinutes = parseTimeInput(schedule.endTime);
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      continue;
    }
    starts.add(startMinutes);
    ends.add(endMinutes);
  }

  if (starts.isEmpty || ends.isEmpty) {
    return const _AgendaRange(startMinutes: 6 * 60, endMinutes: 22 * 60);
  }
  return _resolveCompactAgendaRangeForBounds(
    startMinutes: starts.reduce(math.min),
    endMinutes: ends.reduce(math.max),
  );
}

String _formatMonthLabel(String month) {
  final monthDate = _monthToDate(month);
  const monthNames = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  return '${monthNames[monthDate.month - 1]} ${monthDate.year}';
}

String _formatLongDate(DateTime date) {
  const monthNames = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
}

String _formatCompactDate(DateTime date) {
  const monthNames = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];

  return '${date.day} ${monthNames[date.month - 1]}';
}

String _formatTicketDateTime(DateTime value) {
  return '${_formatCompactDate(value)}, ${formatTimeInput((value.hour * 60) + value.minute)}';
}

String _formatTicketAttachmentSize(int sizeBytes) {
  if (sizeBytes >= 1024 * 1024) {
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  return '${(sizeBytes / 1024).ceil()} KB';
}

Color _ticketStatusColor(BuildContext context, SupportTicketStatus status) {
  switch (status) {
    case SupportTicketStatus.newTicket:
      return Theme.of(context).colorScheme.primary;
    case SupportTicketStatus.inProgress:
      return Colors.orange.shade600;
    case SupportTicketStatus.answered:
      return Colors.green.shade600;
    case SupportTicketStatus.closed:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

String _formatWeekdayShortLabel(DateTime date) {
  const weekdayNames = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  return weekdayNames[date.weekday - 1];
}

String _compactWeekdayLabel(WeekdayKey weekday) {
  switch (weekday) {
    case WeekdayKey.monday:
      return 'Lu';
    case WeekdayKey.tuesday:
      return 'Ma';
    case WeekdayKey.wednesday:
      return 'Me';
    case WeekdayKey.thursday:
      return 'Gi';
    case WeekdayKey.friday:
      return 'Ve';
    case WeekdayKey.saturday:
      return 'Sa';
    case WeekdayKey.sunday:
      return 'Do';
  }
}

double _resolveAgendaLabelTop(double position, double height) {
  const labelHeight = 18.0;
  return math.min(
    math.max(position - (labelHeight / 2), 0),
    height - labelHeight,
  );
}

List<_AgendaMeasurementSegment> _buildAgendaMeasurementSegments({
  required DaySchedule schedule,
  required WorkdaySession? session,
  required int nowMinutes,
  _CalendarPauseWindow? pauseWindow,
}) {
  final startMinutes = parseTimeInput(schedule.startTime);
  final endMinutes = parseTimeInput(schedule.endTime);
  if (pauseWindow != null &&
      startMinutes != null &&
      endMinutes != null &&
      endMinutes > startMinutes) {
    final segments = <_AgendaMeasurementSegment>[];
    if (pauseWindow.pauseStartMinutes > startMinutes) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: startMinutes,
          endMinutes: pauseWindow.pauseStartMinutes,
          label:
              '${_formatHoursInput(pauseWindow.pauseStartMinutes - startMinutes)} lavoro',
          kind: _AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    if (pauseWindow.resumeMinutes > pauseWindow.pauseStartMinutes) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: pauseWindow.pauseStartMinutes,
          endMinutes: pauseWindow.resumeMinutes,
          label:
              '${_formatHoursInput(pauseWindow.resumeMinutes - pauseWindow.pauseStartMinutes)} pausa',
          kind: _AgendaMeasurementSegmentKind.pause,
        ),
      );
    }
    if (pauseWindow.resumeMinutes < endMinutes) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: pauseWindow.resumeMinutes,
          endMinutes: endMinutes,
          label:
              '${_formatHoursInput(endMinutes - pauseWindow.resumeMinutes)} lavoro',
          kind: _AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    if (segments.isNotEmpty) {
      return segments;
    }
  }

  if (session == null) {
    if (schedule.targetMinutes <= 0 ||
        startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return const [];
    }
    final pauseWindow = _resolveCalendarPauseWindow(
      schedule: schedule,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      session: null,
      nowMinutes: nowMinutes,
    );
    if (pauseWindow == null) {
      return [
        _AgendaMeasurementSegment(
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          label: '${_formatHours(schedule.targetMinutes)} lavoro',
          kind: _AgendaMeasurementSegmentKind.work,
        ),
      ];
    }

    final segments = <_AgendaMeasurementSegment>[];
    if (pauseWindow.pauseStartMinutes > startMinutes) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: startMinutes,
          endMinutes: pauseWindow.pauseStartMinutes,
          label:
              '${_formatHoursInput(pauseWindow.pauseStartMinutes - startMinutes)} lavoro',
          kind: _AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    segments.add(
      _AgendaMeasurementSegment(
        startMinutes: pauseWindow.pauseStartMinutes,
        endMinutes: pauseWindow.resumeMinutes,
        label:
            '${_formatHoursInput(pauseWindow.resumeMinutes - pauseWindow.pauseStartMinutes)} pausa',
        kind: _AgendaMeasurementSegmentKind.pause,
      ),
    );
    if (pauseWindow.resumeMinutes < endMinutes) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: pauseWindow.resumeMinutes,
          endMinutes: endMinutes,
          label:
              '${_formatHoursInput(endMinutes - pauseWindow.resumeMinutes)} lavoro',
          kind: _AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    return segments;
  }

  final segments = <_AgendaMeasurementSegment>[];
  final resolvedEndMinutes = session.endMinutes ?? nowMinutes;
  final breakSegments = [...session.breakSegments]
    ..sort((left, right) => left.startMinutes.compareTo(right.startMinutes));

  var cursor = session.startMinutes;
  for (final breakSegment in breakSegments) {
    if (breakSegment.startMinutes > cursor) {
      final workMinutes = breakSegment.startMinutes - cursor;
      if (workMinutes > 0) {
        segments.add(
          _AgendaMeasurementSegment(
            startMinutes: cursor,
            endMinutes: breakSegment.startMinutes,
            label: '${_formatHoursInput(workMinutes)} lavoro',
            kind: _AgendaMeasurementSegmentKind.work,
          ),
        );
      }
    }

    final pauseMinutes = breakSegment.endMinutes - breakSegment.startMinutes;
    if (pauseMinutes > 0) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: breakSegment.startMinutes,
          endMinutes: breakSegment.endMinutes,
          label: '${_formatHoursInput(pauseMinutes)} pausa',
          kind: _AgendaMeasurementSegmentKind.pause,
        ),
      );
    }
    cursor = math.max(cursor, breakSegment.endMinutes);
  }

  if (session.breakStartedMinutes != null &&
      resolvedEndMinutes > session.breakStartedMinutes!) {
    if (session.breakStartedMinutes! > cursor) {
      final workMinutes = session.breakStartedMinutes! - cursor;
      if (workMinutes > 0) {
        segments.add(
          _AgendaMeasurementSegment(
            startMinutes: cursor,
            endMinutes: session.breakStartedMinutes!,
            label: '${_formatHoursInput(workMinutes)} lavoro',
            kind: _AgendaMeasurementSegmentKind.work,
          ),
        );
      }
    }

    final activePauseMinutes =
        resolvedEndMinutes - session.breakStartedMinutes!;
    if (activePauseMinutes > 0) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: session.breakStartedMinutes!,
          endMinutes: resolvedEndMinutes,
          label: '${_formatHoursInput(activePauseMinutes)} pausa',
          kind: _AgendaMeasurementSegmentKind.pause,
        ),
      );
    }
    return segments;
  }

  if (resolvedEndMinutes > cursor) {
    final workMinutes = resolvedEndMinutes - cursor;
    if (workMinutes > 0) {
      segments.add(
        _AgendaMeasurementSegment(
          startMinutes: cursor,
          endMinutes: resolvedEndMinutes,
          label: '${_formatHoursInput(workMinutes)} lavoro',
          kind: _AgendaMeasurementSegmentKind.work,
        ),
      );
    }
  }

  return segments;
}

String? _buildAgendaWorkedSummary({
  required List<_AgendaMeasurementSegment> measurementSegments,
}) {
  if (measurementSegments.isEmpty) {
    return null;
  }

  final workedMinutes = measurementSegments
      .where((segment) => segment.kind == _AgendaMeasurementSegmentKind.work)
      .fold<int>(
        0,
        (total, segment) => total + (segment.endMinutes - segment.startMinutes),
      );
  final totalBreakMinutes = measurementSegments
      .where((segment) => segment.kind == _AgendaMeasurementSegmentKind.pause)
      .fold<int>(
        0,
        (total, segment) => total + (segment.endMinutes - segment.startMinutes),
      );

  return 'Totale: ${_formatHoursInput(workedMinutes)} lavorate | ${_formatHoursInput(totalBreakMinutes)} pausa';
}

String? _validateScheduleDraft({
  required String targetText,
  required String startTimeText,
  required String endTimeText,
  required String breakText,
}) {
  final normalizedStart = startTimeText.trim();
  final normalizedEnd = endTimeText.trim();
  final hasStart = normalizedStart.isNotEmpty;
  final hasEnd = normalizedEnd.isNotEmpty;
  if (hasStart != hasEnd) {
    return 'Compila sia inizio che fine.';
  }

  final startMinutes = hasStart ? parseTimeInput(normalizedStart) : null;
  final endMinutes = hasEnd ? parseTimeInput(normalizedEnd) : null;
  if ((hasStart && startMinutes == null) || (hasEnd && endMinutes == null)) {
    return 'Controlla l orario inserito.';
  }

  final breakMinutes = parseBreakDurationInput(breakText);
  if (breakMinutes == null) {
    return 'Controlla la pausa.';
  }
  if ((!hasStart || !hasEnd) && breakMinutes > 0) {
    return 'La pausa richiede anche inizio e fine.';
  }

  final targetMinutes = _resolveDraftTargetMinutes(
    targetText: targetText,
    startTimeText: startTimeText,
    endTimeText: endTimeText,
    breakText: breakText,
  );
  if (targetMinutes == null) {
    return 'Imposta inizio, fine e pausa della giornata.';
  }

  if (startMinutes != null && endMinutes != null) {
    final elapsedMinutes = endMinutes - startMinutes;
    if (elapsedMinutes < 0) {
      return 'L orario di fine deve essere dopo l inizio.';
    }
    if (breakMinutes > elapsedMinutes) {
      return 'La pausa non puo superare la durata della giornata.';
    }
  }

  return null;
}

int? _resolveDraftTargetMinutes({
  required String targetText,
  required String startTimeText,
  required String endTimeText,
  required String breakText,
}) {
  final explicitTargetMinutes = parseHoursInput(targetText);
  if (explicitTargetMinutes != null) {
    return explicitTargetMinutes;
  }

  final startMinutes = parseTimeInput(startTimeText.trim());
  final endMinutes = parseTimeInput(endTimeText.trim());
  final breakMinutes = parseBreakDurationInput(breakText);
  if (startMinutes == null ||
      endMinutes == null ||
      breakMinutes == null ||
      endMinutes < startMinutes) {
    return null;
  }

  final elapsedMinutes = endMinutes - startMinutes;
  if (breakMinutes > elapsedMinutes) {
    return null;
  }

  return elapsedMinutes - breakMinutes;
}

String _formatDayScheduleDetails(DaySchedule schedule) {
  final scheduleParts = <String>[];
  if (schedule.startTime != null && schedule.endTime != null) {
    scheduleParts.add('${schedule.startTime} - ${schedule.endTime}');
  }
  if (schedule.breakMinutes > 0) {
    scheduleParts.add('pausa ${_formatHoursInput(schedule.breakMinutes)}');
  }
  if (scheduleParts.isEmpty) {
    return 'Orari da definire';
  }
  return scheduleParts.join(' - ');
}

String _formatScheduleWindowDetails(DaySchedule schedule) {
  return _formatDayScheduleDetails(schedule);
}

String _compactWeekScheduleLabel(DaySchedule schedule) {
  if (schedule.startTime != null && schedule.endTime != null) {
    return '${schedule.startTime} - ${schedule.endTime}';
  }
  if (schedule.targetMinutes <= 0) {
    return 'Nessun turno';
  }
  return '${_formatHoursInput(schedule.targetMinutes)} previste';
}

String _formatBreakInput(int minutes) {
  return minutes == 0 ? '' : formatHoursInput(minutes);
}

int _currentSessionBreakMinutes(WorkdaySession? session, int nowMinutes) {
  if (session == null) {
    return 0;
  }

  final runningBreakMinutes = session.breakStartedMinutes == null
      ? 0
      : math.max(0, nowMinutes - session.breakStartedMinutes!);
  return session.accumulatedBreakMinutes + runningBreakMinutes;
}

_WorkdaySessionStatus _resolveWorkdaySessionStatus(WorkdaySession? session) {
  if (session == null) {
    return _WorkdaySessionStatus.notStarted;
  }
  if (session.isCompleted) {
    return _WorkdaySessionStatus.completed;
  }
  if (session.isOnBreak) {
    return _WorkdaySessionStatus.onBreak;
  }

  return _WorkdaySessionStatus.active;
}

String _workdaySessionDescription({
  required WorkdaySession? session,
  required DaySchedule schedule,
  required _CalendarPauseWindow? pauseWindow,
  required _WorkdaySessionStatus status,
  required int currentBreakMinutes,
}) {
  final displayedStart =
      parseTimeInput(schedule.startTime) ?? session?.startMinutes;
  final displayedEnd = parseTimeInput(schedule.endTime) ?? session?.endMinutes;

  return switch (status) {
    _WorkdaySessionStatus.notStarted =>
      'Premi Entrata e salvo l orario attuale. Da li ti mostro subito quando puoi uscire.',
    _WorkdaySessionStatus.active =>
      displayedStart == null
          ? 'Entrata registrata.'
          : 'Entrata registrata alle ${formatTimeInput(displayedStart)}.',
    _WorkdaySessionStatus.onBreak =>
      'Sei in pausa dalle ${formatTimeInput(pauseWindow?.pauseStartMinutes ?? session!.breakStartedMinutes!)}. Pausa totale: ${currentBreakMinutes.toString()} min.',
    _WorkdaySessionStatus.completed =>
      displayedStart == null || displayedEnd == null
          ? 'Giornata chiusa.'
          : 'Giornata chiusa. Entrata ${formatTimeInput(displayedStart)}, uscita ${formatTimeInput(displayedEnd)}.',
  };
}

String _workdaySessionStatusLabel(_WorkdaySessionStatus status) {
  return switch (status) {
    _WorkdaySessionStatus.notStarted => 'Da iniziare',
    _WorkdaySessionStatus.active => 'Dentro',
    _WorkdaySessionStatus.onBreak => 'In pausa',
    _WorkdaySessionStatus.completed => 'Chiusa',
  };
}

String? _resolveExpectedEndInfo({
  required WorkdaySession? session,
  required DaySchedule schedule,
  required int nowMinutes,
}) {
  if (session == null || session.isCompleted || schedule.targetMinutes <= 0) {
    return null;
  }

  final explicitEndMinutes = parseTimeInput(schedule.endTime);
  if (explicitEndMinutes != null) {
    return 'Puoi uscire alle ${formatTimeInput(explicitEndMinutes)}.';
  }

  final actualBreakMinutes = _currentSessionBreakMinutes(session, nowMinutes);
  final effectiveBreakMinutes = math.max(
    schedule.breakMinutes,
    actualBreakMinutes,
  );
  final totalMinutes =
      session.startMinutes + schedule.targetMinutes + effectiveBreakMinutes;
  final normalizedMinutes = totalMinutes % (24 * 60);
  final nextDaySuffix = totalMinutes >= (24 * 60) ? ' del giorno dopo' : '';
  return 'Puoi uscire alle ${formatTimeInput(normalizedMinutes)}$nextDaySuffix.';
}

String? _resolveWorkedSessionInfo({
  required WorkdaySession? session,
  required DaySchedule schedule,
  required _CalendarPauseWindow? pauseWindow,
  required int nowMinutes,
}) {
  if (session == null &&
      (schedule.startTime == null || schedule.endTime == null)) {
    return null;
  }

  final measurementSegments = _buildAgendaMeasurementSegments(
    schedule: schedule,
    session: session,
    nowMinutes: nowMinutes,
    pauseWindow: pauseWindow,
  );
  if (measurementSegments.isEmpty) {
    return null;
  }

  final workedMinutes = measurementSegments
      .where((segment) => segment.kind == _AgendaMeasurementSegmentKind.work)
      .fold<int>(
        0,
        (total, segment) => total + (segment.endMinutes - segment.startMinutes),
      );
  final totalBreakMinutes = measurementSegments
      .where((segment) => segment.kind == _AgendaMeasurementSegmentKind.pause)
      .fold<int>(
        0,
        (total, segment) => total + (segment.endMinutes - segment.startMinutes),
      );
  return 'Lavoro ${_formatHoursInput(workedMinutes)} | Pausa ${_formatHoursInput(totalBreakMinutes)}.';
}

Color _balanceColor(BuildContext context, int balanceMinutes) {
  if (balanceMinutes == 0) {
    return Theme.of(context).colorScheme.primary;
  }

  return balanceMinutes > 0 ? const Color(0xFF0B6E69) : const Color(0xFF9D3D2F);
}

String _textScaleLabel(double value) {
  if (value <= 0.95) {
    return 'Testo compatto';
  }
  if (value >= 1.18) {
    return 'Testo grande';
  }

  return 'Testo standard';
}

String _formatColorHex(Color color) {
  return '#'
          '${_colorChannel(color, _RgbColorChannel.red).toRadixString(16).padLeft(2, '0')}'
          '${_colorChannel(color, _RgbColorChannel.green).toRadixString(16).padLeft(2, '0')}'
          '${_colorChannel(color, _RgbColorChannel.blue).toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

enum _RgbColorChannel { red, green, blue }

int _colorChannel(Color color, _RgbColorChannel channel) {
  final value = switch (channel) {
    _RgbColorChannel.red => color.r,
    _RgbColorChannel.green => color.g,
    _RgbColorChannel.blue => color.b,
  };
  return (value * 255).round().clamp(0, 255);
}

Color _replaceColorChannel(Color color, {int? red, int? green, int? blue}) {
  return Color.fromARGB(
    (color.a * 255).round().clamp(0, 255),
    red ?? _colorChannel(color, _RgbColorChannel.red),
    green ?? _colorChannel(color, _RgbColorChannel.green),
    blue ?? _colorChannel(color, _RgbColorChannel.blue),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedSection,
    required this.hasCloudAccount,
    required this.unreadTicketReplyCount,
    required this.onSelectSection,
    required this.onOpenRegistration,
  });

  final _HomeSection selectedSection;
  final bool hasCloudAccount;
  final int unreadTicketReplyCount;
  final ValueChanged<_HomeSection> onSelectSection;
  final VoidCallback onOpenRegistration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCloudWarning =
        selectedSection == _HomeSection.workSettings && !hasCloudAccount;
    final navigationButtons = List<Widget>.generate(
      _mainNavigationSections.length,
      (index) {
        final section = _mainNavigationSections[index];
        return Padding(
          padding: EdgeInsets.only(
            right: index < _mainNavigationSections.length - 1 ? 10 : 0,
          ),
          child: _HeaderSectionIconButton(
            section: section,
            isSelected: selectedSection == section,
            badgeCount: section == _HomeSection.ticket ? unreadTicketReplyCount : 0,
            onTap: () => onSelectSection(section),
          ),
        );
      },
      growable: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const ValueKey('navigation-menu-button'),
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(width: 1, height: 1),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: navigationButtons,
                  ),
                ),
              ),
            );
          },
        ),
        if (showCloudWarning) ...[
          const SizedBox(height: 10),
          Text(
            'Le impostazioni si perdono se non crei un account.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onOpenRegistration,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Registrati'),
          ),
        ],
      ],
    );
  }
}

class _HeaderSectionIconButton extends StatelessWidget {
  const _HeaderSectionIconButton({
    required this.section,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final _HomeSection section;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: section.label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: IconButton.filledTonal(
              key: ValueKey(_legacyNavigationOptionKey(section)),
              onPressed: onTap,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.20)
                    : theme.colorScheme.surfaceContainerLow,
                foregroundColor: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              icon: Icon(section.icon, size: 20),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onError,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _legacyNavigationOptionKey(_HomeSection section) {
  return switch (section) {
    _HomeSection.day => 'navigation-option-day',
    _HomeSection.calendar => 'navigation-option-calendar',
    _HomeSection.workSettings => 'navigation-option-workSettings',
    _HomeSection.profile => 'navigation-option-profile',
    _HomeSection.ticket => 'navigation-option-ticket',
    _HomeSection.overview => 'top-nav-overview',
    _HomeSection.quickEntry => 'top-nav-quickEntry',
    _HomeSection.recentActivity => 'top-nav-recentActivity',
  };
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.selectedDate,
    required this.todayMetrics,
    required this.todayStatus,
    required this.effectiveSchedule,
    required this.todayOverride,
    required this.todayActivities,
    required this.reminders,
    required this.onOpenWorkEntry,
    required this.onOpenLeaveEntry,
    required this.onOpenTodayCalendar,
    required this.onApplyPreset,
    this.onRemoveTodayOverride,
  });

  final DateTime selectedDate;
  final _DayMetrics todayMetrics;
  final _TodayStatus todayStatus;
  final DaySchedule effectiveSchedule;
  final ScheduleOverride? todayOverride;
  final List<_ActivityItem> todayActivities;
  final List<({IconData icon, String title, String description})> reminders;
  final VoidCallback onOpenWorkEntry;
  final VoidCallback onOpenLeaveEntry;
  final Future<void> Function() onOpenTodayCalendar;
  final Future<void> Function(_TodayOverridePreset preset) onApplyPreset;
  final Future<void> Function()? onRemoveTodayOverride;

  @override
  Widget build(BuildContext context) {
    final registeredMinutes =
        todayMetrics.workedMinutes + todayMetrics.leaveMinutes;
    final remainingMinutes = (todayMetrics.expectedMinutes - registeredMinutes)
        .clamp(0, 24 * 60);
    final statusMeta = _todayStatusMeta(context, todayStatus);
    final primaryAction = _primaryAction();

    return _SectionCard(
      title: 'Oggi',
      subtitle:
          'Controlla subito come e organizzata la giornata e fai solo la prossima azione utile.',
      trailing: _TodayStatusBadge(
        label: statusMeta.label,
        color: statusMeta.color,
        icon: statusMeta.icon,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineInfoPanel(
            title: _formatLongDate(selectedDate),
            description: _formatDayScheduleDetails(effectiveSchedule),
            statusText: todayOverride == null
                ? 'Programma standard di oggi'
                : 'Programma personalizzato per oggi',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                icon: Icons.flag_outlined,
                label: 'Previsto oggi',
                value: _formatHours(todayMetrics.expectedMinutes),
              ),
              _MetricCard(
                icon: Icons.schedule_outlined,
                label: 'Registrato',
                value: _formatHours(registeredMinutes),
              ),
              _MetricCard(
                icon: Icons.pending_actions_outlined,
                label: 'Ancora da fare',
                value: _formatHours(remainingMinutes),
              ),
              _MetricCard(
                icon: Icons.compare_arrows_outlined,
                label: 'Scostamento',
                value: _formatHours(todayMetrics.balanceMinutes, signed: true),
                accentColor: _balanceColor(
                  context,
                  todayMetrics.balanceMinutes,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Prossima azione',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: primaryAction.onPressed,
            icon: Icon(primaryAction.icon),
            label: Text(primaryAction.label),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenWorkEntry,
                icon: const Icon(Icons.work_history_outlined),
                label: const Text('Registra lavoro'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLeaveEntry,
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Segna assenza'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenTodayCalendar(),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Apri giorno'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Eccezioni guidate',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                label: const Text('Entro piu tardi'),
                onPressed: () =>
                    unawaited(onApplyPreset(_TodayOverridePreset.startLater)),
              ),
              ActionChip(
                label: const Text('Esco prima'),
                onPressed: () => unawaited(
                  onApplyPreset(_TodayOverridePreset.finishEarlier),
                ),
              ),
              ActionChip(
                label: const Text('Pausa diversa'),
                onPressed: () =>
                    unawaited(onApplyPreset(_TodayOverridePreset.longerBreak)),
              ),
              ActionChip(
                label: const Text('Oggi non lavoro'),
                onPressed: () =>
                    unawaited(onApplyPreset(_TodayOverridePreset.dayOff)),
              ),
              if (onRemoveTodayOverride != null)
                ActionChip(
                  label: const Text('Ripristina standard'),
                  onPressed: () => unawaited(onRemoveTodayOverride!()),
                ),
            ],
          ),
          if (reminders.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Promemoria di oggi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < reminders.length; index += 1) ...[
              _TodayReminderCard(
                icon: reminders[index].icon,
                title: reminders[index].title,
                description: reminders[index].description,
              ),
              if (index < reminders.length - 1) const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 20),
          Text(
            'Attivita di oggi',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (todayActivities.isEmpty)
            Text(
              'Nessuna registrazione per oggi.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            Column(
              children: [
                for (
                  var index = 0;
                  index < todayActivities.length;
                  index += 1
                ) ...[
                  _ActivityRow(item: todayActivities[index]),
                  if (index < todayActivities.length - 1)
                    const Divider(height: 22),
                ],
              ],
            ),
        ],
      ),
    );
  }

  ({String label, IconData icon, VoidCallback onPressed}) _primaryAction() {
    return switch (todayStatus) {
      _TodayStatus.dayOff => (
        label: 'Controlla il giorno',
        icon: Icons.calendar_month_outlined,
        onPressed: () => unawaited(onOpenTodayCalendar()),
      ),
      _TodayStatus.planned => (
        label: 'Registra la giornata di oggi',
        icon: Icons.play_arrow_outlined,
        onPressed: onOpenWorkEntry,
      ),
      _TodayStatus.needsAttention => (
        label: 'Completa la giornata',
        icon: Icons.task_alt_outlined,
        onPressed: onOpenWorkEntry,
      ),
      _TodayStatus.inProgress => (
        label: 'Aggiorna le ore di oggi',
        icon: Icons.schedule_send_outlined,
        onPressed: onOpenWorkEntry,
      ),
      _TodayStatus.completed => (
        label: 'Rivedi la giornata',
        icon: Icons.visibility_outlined,
        onPressed: () => unawaited(onOpenTodayCalendar()),
      ),
      _TodayStatus.absent => (
        label: 'Gestisci l assenza di oggi',
        icon: Icons.event_note_outlined,
        onPressed: onOpenLeaveEntry,
      ),
    };
  }
}

class _TodayStatusBadge extends StatelessWidget {
  const _TodayStatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayReminderCard extends StatelessWidget {
  const _TodayReminderCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162121) : const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({String label, IconData icon, Color color}) _workdaySessionStatusMeta(
  BuildContext context,
  _WorkdaySessionStatus status,
) {
  return switch (status) {
    _WorkdaySessionStatus.notStarted => (
      label: 'Da iniziare',
      icon: Icons.play_circle_outline,
      color: Theme.of(context).colorScheme.secondary,
    ),
    _WorkdaySessionStatus.active => (
      label: 'Dentro',
      icon: Icons.badge_outlined,
      color: const Color(0xFF0B6E69),
    ),
    _WorkdaySessionStatus.onBreak => (
      label: 'In pausa',
      icon: Icons.free_breakfast_outlined,
      color: Theme.of(context).colorScheme.secondary,
    ),
    _WorkdaySessionStatus.completed => (
      label: 'Chiusa',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF0B6E69),
    ),
  };
}

({String label, IconData icon, Color color}) _todayStatusMeta(
  BuildContext context,
  _TodayStatus status,
) {
  return switch (status) {
    _TodayStatus.dayOff => (
      label: 'Libero',
      icon: Icons.free_breakfast_outlined,
      color: Theme.of(context).colorScheme.secondary,
    ),
    _TodayStatus.planned => (
      label: 'Pianificata',
      icon: Icons.schedule_outlined,
      color: Theme.of(context).colorScheme.primary,
    ),
    _TodayStatus.needsAttention => (
      label: 'Da completare',
      icon: Icons.priority_high_outlined,
      color: const Color(0xFF9D3D2F),
    ),
    _TodayStatus.inProgress => (
      label: 'In corso',
      icon: Icons.play_circle_outline,
      color: const Color(0xFF0B6E69),
    ),
    _TodayStatus.completed => (
      label: 'Completata',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF0B6E69),
    ),
    _TodayStatus.absent => (
      label: 'Assenza registrata',
      icon: Icons.event_busy_outlined,
      color: Theme.of(context).colorScheme.secondary,
    ),
  };
}

extension on _HomeSection {
  String get label {
    switch (this) {
      case _HomeSection.day:
        return 'Oggi';
      case _HomeSection.overview:
        return 'Oggi';
      case _HomeSection.quickEntry:
        return 'Registra';
      case _HomeSection.calendar:
        return 'Calendario';
      case _HomeSection.recentActivity:
        return 'Settimana';
      case _HomeSection.workSettings:
        return 'Orari e permessi';
      case _HomeSection.profile:
        return 'Impostazioni app';
      case _HomeSection.ticket:
        return 'Ticket';
    }
  }

  IconData get icon {
    switch (this) {
      case _HomeSection.day:
        return Icons.view_day_outlined;
      case _HomeSection.overview:
        return Icons.today_outlined;
      case _HomeSection.quickEntry:
        return Icons.edit_calendar_outlined;
      case _HomeSection.calendar:
        return Icons.calendar_month_outlined;
      case _HomeSection.recentActivity:
        return Icons.view_week_outlined;
      case _HomeSection.workSettings:
        return Icons.schedule_outlined;
      case _HomeSection.profile:
        return Icons.settings_outlined;
      case _HomeSection.ticket:
        return Icons.support_agent_outlined;
    }
  }
}
