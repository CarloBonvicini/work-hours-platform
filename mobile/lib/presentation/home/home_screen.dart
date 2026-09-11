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

part 'home_state/home_sections_state.dart';
part 'home_state/permission_rules_state.dart';
part 'home_state/wheel_pickers_state.dart';
part 'home_state/notifications_state.dart';
part 'home_state/support_tickets_state.dart';
part 'home_state/cloud_account_state.dart';
part 'home_state/app_updates_state.dart';
part 'home_state/workday_session_state.dart';
part 'home_state/schedule_override_history_state.dart';
part 'home_state/agenda_interaction_state.dart';
part 'home_state/schedule_overrides_state.dart';
part 'home_state/work_schedule_settings_state.dart';
part 'home_state/profile_state.dart';
part 'home_state/consuntivo_state.dart';
part 'home_state/calendar_metrics_state.dart';
part 'home_state/calendar_navigation_state.dart';
part 'home_state/dashboard_data_state.dart';

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

/// Stato condiviso della home: tutti i campi e le firme dei metodi usati
/// da piu' aree (implementati nei mixin in home_state/).
abstract class _HomeScreenStateBase extends State<HomeScreen>
    with WidgetsBindingObserver {
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

  // Implementati in Interazione con l'agenda: anteprima e applicazione delle modifiche trascinate (agenda_interaction_state.dart).
  CalendarPauseWindow? _agendaPreviewPauseWindow();

  void _clearAgendaPreviewState();

  void _clearScheduleOverrideAgendaPreview();

  void _previewScheduleOverrideFromAgenda({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  });

  DaySchedule _resolveAgendaPreviewSchedule(DaySchedule fallbackSchedule);

  void _setAgendaInteracting(bool isInteracting);

  void _updateScheduleOverrideFromAgenda({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  });

  // Implementati in Controllo, download e installazione degli aggiornamenti dell'app (app_updates_state.dart).
  Future<void> _checkForUpdate();

  Future<void> _openUpdateFromSettings();

  // Implementati in Metriche derivate per calendario, settimana, anno, promemoria e attivita (calendar_metrics_state.dart).
  List<ActivityItem> _buildActivitiesForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  );

  List<CalendarDay> _buildCalendarDays(DashboardSnapshot snapshot);

  DayMetrics _buildDayMetrics(DateTime date);

  List<({IconData icon, String title, String description})>
  _buildTodayReminders(DashboardSnapshot snapshot, DayMetrics metrics);

  List<WeekPlanDay> _buildUpcomingWeekPlan();

  List<DayMetrics> _buildWeekMetrics();

  List<MonthMetrics> _buildYearMetrics();

  Future<void> _ensureUpcomingWeekData();

  TodayStatus _resolveTodayStatus(DayMetrics metrics);

  // Implementati in Navigazione di calendario: data/mese/vista selezionati e caricamento mesi (calendar_navigation_state.dart).
  String _calendarPeriodLabel();

  Future<void> _changeCalendarView(CalendarView view);

  Future<void> _ensureCalendarDataForCurrentView();

  Future<DashboardSnapshot> _fetchSnapshotForMonth(String month);

  DateTime _firstDayOfWeek(DateTime date);

  void _hydrateSelectedDateControllers(
    DashboardSnapshot snapshot,
    DateTime selectedDate, {
    bool resetScheduleHistory = true,
  });

  Future<void> _openDayForDate(DateTime date);

  DateTime _resolveSelectedDateForMonth(
    String month, {
    DateTime? preferredDate,
  });

  void _selectDate(DateTime date);

  Future<void> _setSelectedDate(DateTime date);

  Future<void> _shiftCalendarPeriod(int step);

  Future<void> _shiftSelectedDay(int step);

  DashboardSnapshot? _snapshotForMonth(String month);

  DateTime get _todayDate;

  // Implementati in Account cloud: accesso, registrazione, recupero password e backup (cloud_account_state.dart).
  Future<void> _loginAccount();

  Future<void> _logoutAccount();

  Future<void> _openPasswordRecoveryFlow();

  Future<void> _openRecoveryQuestionsSetupFlow();

  Future<void> _queueCloudBackup();

  Future<void> _registerAccount();

  Future<void> _restoreCloudBackup();

  Future<void> _triggerManualCloudBackup();

  // Implementati in Dati e navigazione della sezione Consuntivo (consuntivo_state.dart).
  ConsuntivoSectionData _buildConsuntivoSectionData(
    DashboardSnapshot fallbackSnapshot,
  );

  Future<void> _changeConsuntivoRange(ConsuntivoRangeOption nextRange);

  Future<void> _ensureConsuntivoDataLoaded();

  Future<void> _shiftConsuntivoAnchorMonth(int step);

  // Implementati in Caricamento e cache dello snapshot, inserimento rapido voci ed errori leggibili (dashboard_data_state.dart).
  Future<void> _cacheSnapshot(DashboardSnapshot snapshot);

  String _humanizeError(
    Object error, {
    String? apiBaseUrl,
    bool isTicketRequest = false,
  });

  Future<void> _loadSnapshot({String? month, DateTime? selectedDate});

  void _openLeaveQuickEntryForDate(
    DateTime date, {
    int? prefilledMinutes,
    LeaveType leaveType = LeaveType.permit,
    String? note,
  });

  void _openWorkQuickEntryForDate(
    DateTime date, {
    int? prefilledMinutes,
    String? note,
  });

  int _overrideCountForMonth(DashboardSnapshot snapshot);

  Future<void> _pickEntryDate();

  Future<void> _submitQuickEntry();

  int _sumLeaveMinutesForDate(DashboardSnapshot snapshot, String isoDate);

  int _sumWorkedMinutesForDate(DashboardSnapshot snapshot, String isoDate);

  // Implementati in Notifiche locali e gestione delle push in foreground (notifications_state.dart).
  void _handleOvertimeLimitExceededNotification(int exceededMinutes);

  Future<void> _initializeLocalNotifications();

  // Implementati in Aggiunta, modifica e rimozione delle regole permessi/banche ore (permission_rules_state.dart).
  Future<void> _addPermissionRule({required bool leaveBank});

  Future<void> _editPermissionRule({
    required bool leaveBank,
    required String ruleId,
  });

  void _removePermissionRule({required bool leaveBank, required String ruleId});

  // Implementati in Profilo, bozza impostazioni, setup iniziale e aspetto (profile_state.dart).
  void _hydrateControllers(
    DashboardSnapshot snapshot,
    DateTime selectedDate, {
    bool resetScheduleHistory = true,
  });

  Future<void> _maybeShowInitialSetup(DashboardSnapshot _);

  Future<void> _reloadProfileDraft();

  Future<void> _submitProfile();

  Future<void> _toggleThemeMode(bool useDarkTheme);

  Future<void> _updateAppearanceSettings(
    AppAppearanceSettings appearanceSettings,
  );

  // Implementati in Storico undo/redo della bozza di orario del giorno (schedule_override_history_state.dart).
  bool get _canRedoScheduleOverride;

  bool get _canUndoScheduleOverride;

  void _primeScheduleOverrideHistoryFromCurrentDisplay();

  void _pushCurrentScheduleOverrideDraftToHistory();

  Future<void> _redoScheduleOverrideDraftChange();

  void _resetScheduleOverrideHistoryForDate(
    DateTime date, {
    required DaySchedule schedule,
    CalendarPauseWindow? pauseWindow,
  });

  Future<void> _undoScheduleOverrideDraftChange();

  // Implementati in Bozza e salvataggio dell'orario del giorno selezionato (override), pause e preset (schedule_overrides_state.dart).
  void _applyDayScheduleDraft(
    DaySchedule schedule, {
    CalendarPauseWindow? pauseWindow,
  });

  void _applyPresetMinutes(int minutes);

  Future<void> _autosaveScheduleOverride();

  ({DaySchedule schedule, CalendarPauseWindow? pauseWindow})
  _displayedScheduleStateForSelectedDate();

  DaySchedule _fallbackScheduleForSelectedDate();

  ScheduleOverride? _findScheduleOverrideForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  );

  void _markSelectedDayAsDayOff();

  void _normalizeSelectedDayPauseWindowForCurrentDraft();

  Future<void> _pickScheduleOverrideBreakMinutes();

  Future<void> _pickScheduleOverrideTargetMinutes();

  Future<void> _pickScheduleOverrideTime(CalendarTimeField field);

  Future<void> _prepareTodayOverridePreset(TodayOverridePreset preset);

  Future<void> _removeScheduleOverride();

  Future<void> _removeTodayOverride();

  DaySchedule _resolveBaseDayScheduleForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  );

  DaySchedule _resolveCurrentScheduleDraft(DaySchedule fallbackSchedule);

  DaySchedule _resolveDisplayedDaySchedule(
    DaySchedule schedule,
    DateTime selectedDate,
  );

  DaySchedule _resolveDisplayedDayScheduleForSession(
    DaySchedule schedule,
    DaySchedule baseSchedule,
    WorkdaySession? session,
    DateTime selectedDate,
  );

  DaySchedule _resolveEffectiveDayScheduleForDate(
    DashboardSnapshot snapshot,
    DateTime date,
  );

  CalendarPauseWindow? _resolveSelectedDayPauseWindow({
    required DaySchedule schedule,
    WorkdaySession? session,
  });

  bool _sameDaySchedule(DaySchedule left, DaySchedule right);

  bool _samePauseWindow(CalendarPauseWindow? left, CalendarPauseWindow? right);

  void _seedScheduleOverrideDraftFromCurrentDisplay();

  CalendarPauseWindow? _selectedDayPauseWindowDraft();

  void _setSelectedDayPauseWindowDraft(CalendarPauseWindow? pauseWindow);

  void _syncSelectedDayPauseWindowDraftForCurrentDisplay({
    WorkdaySession? session,
  });

  DayMetrics _withDisplayedDaySchedule(
    DayMetrics metrics,
    DaySchedule displayedSchedule,
  );

  // Implementati in Ticket di supporto: invio, allegati, registrazione vocale, thread e diagnostica (support_tickets_state.dart).
  void _logDiagnostic(
    String event, {
    Map<String, Object?> details = const <String, Object?>{},
  });

  Future<void> _pickTicketAttachments();

  Future<void> _pickTicketVoiceAttachments();

  Future<void> _recordTicketVoiceAttachment();

  Future<void> _recoverTrackedSupportTicketById();

  Future<void> _refreshTrackedSupportTickets({
    bool notifyAboutNewReplies = false,
  });

  void _removeTicketAttachmentAt(int index);

  Future<void> _selectTrackedSupportTicket(String ticketId);

  Future<void> _submitSupportTicket();

  Future<void> _submitSupportTicketReply();

  // Implementati in Selettori a rotella condivisi per orari, pause, obiettivi e durate (wheel_pickers_state.dart).
  List<int> get _minutesPresets;

  Future<int?> _showDurationWheelPicker({
    required String title,
    required int initialMinutes,
    required int maxMinutes,
    int stepMinutes = 5,
    String? zeroLabel,
    int? specialValue,
    String? specialLabel,
  });

  Future<int?> _showScheduleBreakWheelPicker({
    required int initialMinutes,
    String? standardScheduleLinkLabel,
    Future<void> Function()? onOpenStandardScheduleLink,
  });

  Future<int?> _showScheduleTargetWheelPicker({
    required String title,
    required int initialMinutes,
    String? standardScheduleLinkLabel,
    Future<void> Function()? onOpenStandardScheduleLink,
  });

  Future<_ScheduleTimeWheelSelection?> _showScheduleTimeWheelPicker({
    required String title,
    required int initialMinutes,
    bool allowClear = false,
    String? Function(int pickedMinutes)? helperTextBuilder,
  });

  // Implementati in Impostazioni orario settimanale e regole: controller, pick e costruzione delle regole (work_schedule_settings_state.dart).
  DaySchedule? _buildFlexibleDayScheduleInput({
    required String targetText,
    required String startTimeText,
    required String endTimeText,
    required String breakText,
    required DaySchedule fallbackSchedule,
  });

  WeekdaySchedule? _buildWeekdayScheduleFromControllers();

  UserWorkRules? _buildWorkRulesFromControllers({
    required WeekdaySchedule weekdaySchedule,
  });

  WeekdayTargetMinutes _deriveWeekdayTargetMinutesFromSchedule(
    WeekdaySchedule schedule,
  );

  Future<void> _openSelectedWeekdayStandardWorkSettings();

  void _openWorkSettingsSectionFromSummary();

  DaySchedule? _parseDayScheduleInput({
    required String targetText,
    required String startTimeText,
    required String endTimeText,
    required String breakText,
  });

  Future<void> _pickRulesFlexibleStartWindowMinutes();

  Future<void> _pickRulesImplicitCreditDailyCapMinutes();

  Future<void> _pickRulesMaximumDailyCreditMinutes();

  Future<void> _pickRulesMaximumDailyDebitMinutes();

  Future<void> _pickRulesMaximumMonthlyCreditMinutes();

  Future<void> _pickRulesMaximumMonthlyDebitMinutes();

  Future<void> _pickRulesMinimumBreakMinutes();

  Future<void> _pickRulesOvertimeDailyCapMinutes();

  Future<void> _pickRulesOvertimeMonthlyCapMinutes();

  Future<void> _pickRulesOvertimeWeeklyCapMinutes();

  Future<void> _pickRulesWalletDailyExitMinutes();

  Future<void> _pickRulesWalletWeeklyExitMinutes();

  Future<void> _pickUniformBreakMinutes();

  Future<void> _pickUniformScheduleTime(CalendarTimeField field);

  Future<void> _pickUniformTargetMinutes();

  Future<void> _pickWeekdayBreakMinutes(WeekdayKey weekday);

  Future<void> _pickWeekdayScheduleTime(
    WeekdayKey weekday,
    CalendarTimeField field,
  );

  Future<void> _pickWeekdayTargetMinutes(WeekdayKey weekday);

  void _setUniformLunchBreakEnabled(bool enabled);

  void _setWeekdayLunchBreakEnabled(WeekdayKey weekday, bool enabled);

  void _setWeekdayWorkingEnabled(WeekdayKey weekday, bool enabled);

  WeekdayKey _weekdayKeyForDate(DateTime date);

  // Implementati in Timbratura del giorno: entrata, pausa, uscita, promemoria e conferma uscita (workday_session_state.dart).
  void _clearPendingExitConfirmationForSelectedDate();

  Future<void> _clearWorkdaySession();

  Future<void> _confirmSuggestedExitMinutes(int exitMinutes);

  int _currentMinutesOfDay();

  Future<void> _finishWorkdayNow();

  bool get _hasPendingExitConfirmationForSelectedDate;

  Future<void> _loadWorkdaySessionForDate(DateTime date);

  int? get _pendingExitConfirmationForSelectedDate;

  Future<void> _recordWorkdayStartNow();

  Future<void> _resumeWorkdayNow();

  void _setPendingExitConfirmationForSelectedDate(int minutes);

  Future<void> _startWorkdayBreakNow();
}

class _HomeScreenState extends _HomeScreenStateBase
    with
        _HomeSectionsState,
        _PermissionRulesState,
        _WheelPickersState,
        _NotificationsState,
        _SupportTicketsState,
        _CloudAccountState,
        _AppUpdatesState,
        _WorkdaySessionState,
        _ScheduleOverrideHistoryState,
        _AgendaInteractionState,
        _ScheduleOverridesState,
        _WorkScheduleSettingsState,
        _ProfileState,
        _ConsuntivoState,
        _CalendarMetricsState,
        _CalendarNavigationState,
        _DashboardDataState {
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
}
