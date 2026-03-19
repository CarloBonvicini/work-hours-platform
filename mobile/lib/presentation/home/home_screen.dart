import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/onboarding_preference_store.dart';
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
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/initial_setup_dialog.dart';

enum _QuickEntryMode { work, leave }

enum _CalendarView { day, week, month, year }

enum _HomeSection {
  overview,
  quickEntry,
  calendar,
  recentActivity,
  profile,
  ticket,
}

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

enum _WorkdaySessionStatus { notStarted, active, onBreak, completed }

const _mainNavigationSections = [
  _HomeSection.calendar,
  _HomeSection.profile,
  _HomeSection.ticket,
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
    required this.updateReminderStore,
    required this.onboardingPreferenceStore,
    required this.workdayStartStore,
    required this.hasCompletedInitialSetup,
    required this.isDarkTheme,
    required this.appearanceSettings,
    required this.onAppearanceSettingsChanged,
    required this.onThemeModeChanged,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;
  final UpdateReminderStore updateReminderStore;
  final OnboardingPreferenceStore onboardingPreferenceStore;
  final WorkdayStartStore workdayStartStore;
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
  final _entryDateController = TextEditingController();
  final _entryMinutesController = TextEditingController();
  final _entryNoteController = TextEditingController();
  final _scheduleOverrideTargetController = TextEditingController();
  final _scheduleOverrideStartTimeController = TextEditingController();
  final _scheduleOverrideEndTimeController = TextEditingController();
  final _scheduleOverrideBreakController = TextEditingController();
  final _scheduleOverrideNoteController = TextEditingController();
  final _ticketNameController = TextEditingController();
  final _ticketEmailController = TextEditingController();
  final _ticketSubjectController = TextEditingController();
  final _ticketMessageController = TextEditingController();
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
  LeaveType _selectedLeaveType = LeaveType.vacation;
  _QuickEntryMode _selectedEntryMode = _QuickEntryMode.work;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isCheckingForUpdate = true;
  bool _isSavingProfile = false;
  bool _isSavingScheduleOverride = false;
  bool _isSubmittingEntry = false;
  bool _isSubmittingTicket = false;
  bool _isOpeningUpdate = false;
  bool _isShowingUpdateDialog = false;
  bool _isShowingOnboardingDialog = false;
  bool _isLoadingCalendarData = false;
  bool _isUpdatingThemeMode = false;
  bool _isSavingWorkdaySession = false;
  late bool _hasCompletedInitialSetup;
  _HomeSection _selectedSection = _HomeSection.calendar;
  SupportTicketCategory _selectedTicketCategory = SupportTicketCategory.bug;
  WorkdaySession? _workdaySession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedMonth = widget.dashboardService.currentMonth;
    _selectedDate = _resolveSelectedDateForMonth(_selectedMonth);
    _hasCompletedInitialSetup = widget.hasCompletedInitialSetup;
    _entryDateController.text = DashboardService.defaultEntryDateOf(
      _selectedDate,
    );
    _loadSnapshot();
    unawaited(_loadWorkdaySessionForDate(_selectedDate));
    if (_hasCompletedInitialSetup) {
      unawaited(_checkForUpdate());
    } else {
      _isCheckingForUpdate = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        !_isCheckingForUpdate &&
        _hasCompletedInitialSetup) {
      unawaited(_checkForUpdate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fullNameController.dispose();
    _uniformDailyTargetController.dispose();
    _uniformStartTimeController.dispose();
    _uniformEndTimeController.dispose();
    _uniformBreakController.dispose();
    _entryDateController.dispose();
    _entryMinutesController.dispose();
    _entryNoteController.dispose();
    _scheduleOverrideTargetController.dispose();
    _scheduleOverrideStartTimeController.dispose();
    _scheduleOverrideEndTimeController.dispose();
    _scheduleOverrideBreakController.dispose();
    _scheduleOverrideNoteController.dispose();
    _ticketNameController.dispose();
    _ticketEmailController.dispose();
    _ticketSubjectController.dispose();
    _ticketMessageController.dispose();
    _ticketAppVersionController.dispose();
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

      setState(() {
        _errorMessage = _humanizeError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _maybeShowInitialSetup(DashboardSnapshot snapshot) async {
    if (_hasCompletedInitialSetup || _isShowingOnboardingDialog || !mounted) {
      return;
    }

    _isShowingOnboardingDialog = true;
    final wasCompleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InitialSetupDialog(
        initialProfile: snapshot.profile,
        initialIsDarkTheme: widget.isDarkTheme,
        onCompleteInitialSetup: () async {
          await widget.onboardingPreferenceStore.markInitialSetupCompleted();
          _hasCompletedInitialSetup = true;
        },
        onThemeModeChanged: widget.onThemeModeChanged,
        onSaveProfile: (configuration) async {
          final savedSnapshot = await widget.dashboardService.saveProfile(
            fullName: configuration.fullName,
            useUniformDailyTarget: configuration.useUniformDailyTarget,
            dailyTargetMinutes: configuration.dailyTargetMinutes,
            weekdayTargetMinutes: configuration.weekdayTargetMinutes,
            weekdaySchedule: configuration.weekdaySchedule,
            month: _snapshot?.summary.month,
          );
          _hydrateControllers(savedSnapshot, _selectedDate);
          if (!mounted) {
            return;
          }
          setState(() {
            _snapshot = savedSnapshot;
          });
        },
      ),
    );
    _isShowingOnboardingDialog = false;

    if (wasCompleted == true && mounted) {
      unawaited(_checkForUpdate());
    }
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

  void _hydrateControllers(DashboardSnapshot snapshot, DateTime selectedDate) {
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

    _hydrateSelectedDateControllers(snapshot, selectedDate);
    if (_ticketNameController.text.trim().isEmpty) {
      _ticketNameController.text = snapshot.profile.fullName;
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      _loadSnapshot(month: _selectedMonth, selectedDate: _selectedDate),
      _checkForUpdate(),
    ]);
  }

  Future<void> _loadWorkdaySessionForDate(DateTime date) async {
    final isoDate = DashboardService.defaultEntryDateOf(date);
    final session = await widget.workdayStartStore.loadSession(isoDate);
    if (!mounted || !_isSameDay(_selectedDate, date)) {
      return;
    }

    setState(() {
      _workdaySession = session;
    });
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
      );
      await widget.workdayStartStore.saveSession(isoDate, updatedSession);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = updatedSession;
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
      final updatedSession = session.copyWith(
        breakStartedMinutes: null,
        accumulatedBreakMinutes: totalBreakMinutes,
        endMinutes: nowMinutes,
      );
      await widget.workdayStartStore.saveSession(isoDate, updatedSession);
      if (!mounted) {
        return;
      }

      setState(() {
        _workdaySession = updatedSession;
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

  Future<void> _openNavigationMenu() async {
    final selectedSection = await showModalBottomSheet<_HomeSection>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _NavigationMenuSheet(selectedSection: _selectedSection),
    );
    if (!mounted || selectedSection == null) {
      return;
    }

    setState(() {
      _selectedSection = selectedSection;
    });
  }

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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

  Future<void> _openCalendarForDate(DateTime date) async {
    setState(() {
      _selectedSection = _HomeSection.calendar;
      _calendarView = _CalendarView.day;
    });
    await _setSelectedDate(date, alignToPeriod: false);
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
    _scheduleOverrideNoteController.text = switch (preset) {
      _TodayOverridePreset.startLater => 'Entrata posticipata',
      _TodayOverridePreset.finishEarlier => 'Uscita anticipata',
      _TodayOverridePreset.longerBreak => 'Pausa pranzo modificata',
      _TodayOverridePreset.dayOff => 'Giornata non lavorativa',
    };

    setState(() {
      _selectedSection = _HomeSection.calendar;
      _calendarView = _CalendarView.day;
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

    final snapshot = await widget.dashboardService.loadSnapshot(month: month);
    _snapshotCache[month] = snapshot;
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
        _snapshotCache[month] = snapshot;
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
    final uniformDailyTargetMinutes = _useUniformDailyTarget
        ? weekdaySchedule.monday.targetMinutes
        : null;

    setState(() {
      _isSavingProfile = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await widget.dashboardService.saveProfile(
        fullName: _fullNameController.text.trim(),
        useUniformDailyTarget: _useUniformDailyTarget,
        dailyTargetMinutes:
            uniformDailyTargetMinutes ??
            _averageWorkingDayTargetMinutes(weekdayTargetMinutes),
        weekdayTargetMinutes: weekdayTargetMinutes,
        weekdaySchedule: weekdaySchedule,
        month: _snapshot?.summary.month,
      );

      if (!mounted) {
        return;
      }

      _hydrateControllers(snapshot, _selectedDate);
      setState(() {
        _snapshot = snapshot;
        _isSavingProfile = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Impostazioni aggiornate.')));
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

      final successMessage = _selectedEntryMode == _QuickEntryMode.work
          ? 'Ore registrate con successo.'
          : '${_selectedLeaveType.label} registrato con successo.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
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

  Future<void> _submitScheduleOverride() async {
    final isValid = _scheduleOverrideFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final overrideSchedule = _parseDayScheduleInput(
      targetText: _scheduleOverrideTargetController.text,
      startTimeText: _scheduleOverrideStartTimeController.text,
      endTimeText: _scheduleOverrideEndTimeController.text,
      breakText: _scheduleOverrideBreakController.text,
    );
    if (overrideSchedule == null) {
      setState(() {
        _errorMessage =
            'Controlla ore, inizio, fine e pausa dell eccezione del giorno selezionato.';
      });
      return;
    }

    setState(() {
      _isSavingScheduleOverride = true;
      _errorMessage = null;
    });

    try {
      final note = _scheduleOverrideNoteController.text.trim();
      final snapshot = await widget.dashboardService.saveScheduleOverride(
        date: DashboardService.defaultEntryDateOf(_selectedDate),
        targetMinutes: overrideSchedule.targetMinutes,
        startTime: overrideSchedule.startTime,
        endTime: overrideSchedule.endTime,
        breakMinutes: overrideSchedule.breakMinutes,
        note: note.isEmpty ? null : note,
      );

      if (!mounted) {
        return;
      }

      _hydrateControllers(snapshot, _selectedDate);
      setState(() {
        _snapshot = snapshot;
        _isSavingScheduleOverride = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eccezione oraria salvata.')),
      );
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

      _hydrateControllers(snapshot, _selectedDate);
      setState(() {
        _snapshot = snapshot;
        _isSavingScheduleOverride = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eccezione oraria rimossa.')),
      );
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

  Future<void> _pickScheduleOverrideTime(_CalendarTimeField field) async {
    final initialMinutes = _currentScheduleOverrideTimeMinutes(field);
    final pickedMinutes = await _showScheduleTimeWheelPicker(
      title: switch (field) {
        _CalendarTimeField.start => 'Entrata',
        _CalendarTimeField.end => 'Uscita',
      },
      initialMinutes: initialMinutes,
    );
    if (pickedMinutes == null) {
      return;
    }

    final controller = _scheduleTimeController(field);
    controller.text = formatTimeInput(pickedMinutes);
    _syncScheduleOverrideTargetFromTimes();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickScheduleOverrideBreakMinutes() async {
    final currentBreakMinutes =
        parseBreakDurationInput(_scheduleOverrideBreakController.text) ?? 0;
    final pickedMinutes = await _showScheduleBreakWheelPicker(
      initialMinutes: currentBreakMinutes,
    );
    if (pickedMinutes == null) {
      return;
    }
    _setScheduleOverrideBreakMinutes(pickedMinutes);
  }

  void _setScheduleOverrideBreakMinutes(int minutes) {
    final normalizedMinutes = minutes.clamp(0, 24 * 60);
    _scheduleOverrideBreakController.text = _formatBreakInput(
      normalizedMinutes,
    );
    _syncScheduleOverrideTargetFromTimes();
    setState(() {});
  }

  Future<int?> _showScheduleTimeWheelPicker({
    required String title,
    required int initialMinutes,
  }) async {
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
        valueBuilder: (controller) => ValueListenableBuilder<DateTime>(
          valueListenable: controller,
          builder: (context, value, _) => Text(
            formatTimeInput((value.hour * 60) + value.minute),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
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
    return (pickedDateTime.hour * 60) + pickedDateTime.minute;
  }

  Future<int?> _showScheduleBreakWheelPicker({
    required int initialMinutes,
  }) async {
    final allowedValues = List<int>.generate(241, (index) => index);
    final initialIndex = initialMinutes.clamp(0, allowedValues.length - 1);
    final pickedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _WheelPickerBottomSheet<int>(
        title: 'Pausa',
        initialValue: allowedValues[initialIndex],
        valueBuilder: (controller) => ValueListenableBuilder<int>(
          valueListenable: controller,
          builder: (context, value, _) => Text(
            value == 0 ? 'Nessuna pausa' : '$value min',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
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
    return pickedMinutes;
  }

  void _resetScheduleOverrideEditorToBase() {
    final snapshot = _snapshotForMonth(_selectedMonth) ?? _snapshot;
    if (snapshot == null) {
      return;
    }

    final baseSchedule = _resolveBaseDayScheduleForDate(
      snapshot,
      _selectedDate,
    );
    _scheduleOverrideTargetController.text = _formatHoursInput(
      baseSchedule.targetMinutes,
    );
    _scheduleOverrideStartTimeController.text = baseSchedule.startTime ?? '';
    _scheduleOverrideEndTimeController.text = baseSchedule.endTime ?? '';
    _scheduleOverrideBreakController.text = _formatBreakInput(
      baseSchedule.breakMinutes,
    );
    _scheduleOverrideNoteController.clear();
    setState(() {});
  }

  void _markSelectedDayAsDayOff() {
    _scheduleOverrideTargetController.text = _formatHoursInput(0);
    _scheduleOverrideStartTimeController.clear();
    _scheduleOverrideEndTimeController.clear();
    _scheduleOverrideBreakController.clear();
    _syncScheduleOverrideTargetFromTimes();
    setState(() {});
  }

  TextEditingController _scheduleTimeController(_CalendarTimeField field) {
    return switch (field) {
      _CalendarTimeField.start => _scheduleOverrideStartTimeController,
      _CalendarTimeField.end => _scheduleOverrideEndTimeController,
    };
  }

  int _currentScheduleOverrideTimeMinutes(_CalendarTimeField field) {
    final controller = _scheduleTimeController(field);
    final currentMinutes = parseTimeInput(controller.text);
    if (currentMinutes != null) {
      return currentMinutes;
    }

    final snapshot = _snapshotForMonth(_selectedMonth) ?? _snapshot;
    final fallbackSchedule = snapshot == null
        ? const DaySchedule(targetMinutes: 8 * 60)
        : _resolveEffectiveDayScheduleForDate(snapshot, _selectedDate);
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

  void _syncScheduleOverrideTargetFromTimes() {
    final startMinutes = parseTimeInput(
      _scheduleOverrideStartTimeController.text,
    );
    final endMinutes = parseTimeInput(_scheduleOverrideEndTimeController.text);
    final breakMinutes =
        parseBreakDurationInput(_scheduleOverrideBreakController.text) ?? 0;

    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes < startMinutes) {
      return;
    }

    final elapsedMinutes = endMinutes - startMinutes;
    if (breakMinutes > elapsedMinutes) {
      return;
    }

    _scheduleOverrideTargetController.text = _formatHoursInput(
      elapsedMinutes - breakMinutes,
    );
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
  }) {
    final normalizedStart = startMinutes.clamp(0, 24 * 60).toInt();
    final normalizedEnd = endMinutes.clamp(0, 24 * 60).toInt();
    if (normalizedEnd <= normalizedStart) {
      return;
    }

    _scheduleOverrideStartTimeController.text = formatTimeInput(
      normalizedStart,
    );
    _scheduleOverrideEndTimeController.text = formatTimeInput(normalizedEnd);
    if (breakMinutes != null) {
      _scheduleOverrideBreakController.text = _formatBreakInput(
        breakMinutes.clamp(0, normalizedEnd - normalizedStart),
      );
    }
    _syncScheduleOverrideTargetFromTimes();
    setState(() {});
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

  Future<void> _startInAppUpdateFlow(AppUpdate update) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDownloadDialog(
        update: update,
        appUpdateService: widget.appUpdateService,
        onOpenReleasePage: _openUpdate,
      ),
    );
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
      await widget.dashboardService.submitSupportTicket(
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
      );

      if (!mounted) {
        return;
      }

      _ticketSubjectController.clear();
      _ticketMessageController.clear();
      setState(() {
        _isSubmittingTicket = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket inviato correttamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
        _isSubmittingTicket = false;
      });
    }
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
    DateTime selectedDate,
  ) {
    final selectedOverride = _findScheduleOverrideForDate(
      snapshot,
      selectedDate,
    );
    final daySchedule = _resolveEffectiveDayScheduleForDate(
      snapshot,
      selectedDate,
    );
    _scheduleOverrideTargetController.text = _formatHoursInput(
      daySchedule.targetMinutes,
    );
    _scheduleOverrideStartTimeController.text = daySchedule.startTime ?? '';
    _scheduleOverrideEndTimeController.text = daySchedule.endTime ?? '';
    _scheduleOverrideBreakController.text = _formatBreakInput(
      daySchedule.breakMinutes,
    );
    _scheduleOverrideNoteController.text = selectedOverride?.note ?? '';
  }

  WeekdaySchedule? _buildWeekdayScheduleFromControllers() {
    if (_useUniformDailyTarget) {
      final uniformSchedule = _parseDayScheduleInput(
        targetText: _uniformDailyTargetController.text,
        startTimeText: _uniformStartTimeController.text,
        endTimeText: _uniformEndTimeController.text,
        breakText: _uniformBreakController.text,
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
      final parsedValue = _parseDayScheduleInput(
        targetText: _weekdayControllers[weekday]!.text,
        startTimeText: _weekdayStartTimeControllers[weekday]!.text,
        endTimeText: _weekdayEndTimeControllers[weekday]!.text,
        breakText: _weekdayBreakControllers[weekday]!.text,
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
      if ((elapsedMinutes - breakMinutes) != targetMinutes) {
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

    return _DayMetrics(
      date: date,
      expectedMinutes: effectiveSchedule.targetMinutes,
      workedMinutes: workedMinutes,
      leaveMinutes: leaveMinutes,
      balanceMinutes:
          workedMinutes + leaveMinutes - effectiveSchedule.targetMinutes,
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
        balanceMinutes: snapshot.summary.balanceMinutes,
        overrideCount: _overrideCountForMonth(snapshot),
      );
    }, growable: false);
  }

  String _calendarPeriodLabel() {
    switch (_calendarView) {
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
      final hasOverride = _findScheduleOverrideForDate(snapshot, date) != null;
      days.add(
        _CalendarDay(
          date: date,
          isoDate: isoDate,
          expectedMinutes: effectiveSchedule.targetMinutes,
          workedMinutes: workMinutesByDate[isoDate] ?? 0,
          leaveMinutes: leaveMinutesByDate[isoDate] ?? 0,
          hasOverride: hasOverride,
          isToday: _isSameDay(date, today),
          isSelected: _isSameDay(date, _selectedDate),
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
        title: 'Domani hai un eccezione',
        description:
            'Il programma di domani e diverso dal solito. Controlla la fascia prevista prima di iniziare.',
      ));
    }

    if (metrics.hasOverride) {
      reminders.add((
        icon: Icons.rule_folder_outlined,
        title: 'Oggi c e una regola speciale',
        description:
            'La giornata di oggi usa un orario modificato rispetto alla regola standard.',
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
        _snapshotCache[month] = loadedSnapshot;
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

  String _humanizeError(Object error) {
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

    return 'Impossibile contattare il backend. Verifica che l API sia attiva e raggiungibile.';
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

  Widget _buildSelectedSection(DashboardSnapshot snapshot) {
    switch (_selectedSection) {
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
          onOpenTodayCalendar: () => _openCalendarForDate(today),
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
        final monthSnapshot = _snapshotForMonth(_selectedMonth) ?? snapshot;
        final weekMetrics = _buildWeekMetrics();
        final dayMetrics = _buildDayMetrics(_selectedDate);
        final effectiveDaySchedule = _resolveEffectiveDayScheduleForDate(
          monthSnapshot,
          _selectedDate,
        );
        return _CalendarCard(
          calendarView: _calendarView,
          periodLabel: _calendarPeriodLabel(),
          isLoadingCalendarData: _isLoadingCalendarData,
          month: monthSnapshot.summary.month,
          selectedDate: _selectedDate,
          days: _buildCalendarDays(monthSnapshot),
          baseDaySchedule: _resolveBaseDayScheduleForDate(
            monthSnapshot,
            _selectedDate,
          ),
          effectiveDaySchedule: effectiveDaySchedule,
          draftDaySchedule: _resolveCurrentScheduleDraft(effectiveDaySchedule),
          selectedOverride: _findScheduleOverrideForDate(
            monthSnapshot,
            _selectedDate,
          ),
          overrideFormKey: _scheduleOverrideFormKey,
          overrideTargetController: _scheduleOverrideTargetController,
          overrideStartTimeController: _scheduleOverrideStartTimeController,
          overrideEndTimeController: _scheduleOverrideEndTimeController,
          overrideBreakController: _scheduleOverrideBreakController,
          overrideNoteController: _scheduleOverrideNoteController,
          isSavingOverride: _isSavingScheduleOverride,
          selectedActivities: _buildActivitiesForDate(
            monthSnapshot,
            _selectedDate,
          ),
          dayMetrics: dayMetrics,
          weekMetrics: weekMetrics,
          monthMetrics: _MonthMetrics(
            month: monthSnapshot.summary.month,
            expectedMinutes: monthSnapshot.summary.expectedMinutes,
            workedMinutes: monthSnapshot.summary.workedMinutes,
            leaveMinutes: monthSnapshot.summary.leaveMinutes,
            balanceMinutes: monthSnapshot.summary.balanceMinutes,
            overrideCount: _overrideCountForMonth(monthSnapshot),
          ),
          yearMetrics: _buildYearMetrics(),
          onCalendarViewChanged: _changeCalendarView,
          onPreviousPeriod: () => _shiftCalendarPeriod(-1),
          onNextPeriod: () => _shiftCalendarPeriod(1),
          onSelectDate: _selectDate,
          isSelectedDateToday: _isSameDay(_selectedDate, _todayDate),
          workdaySession: _workdaySession,
          isSavingWorkdaySession: _isSavingWorkdaySession,
          onRecordWorkdayStartNow: _recordWorkdayStartNow,
          onStartWorkdayBreakNow: _startWorkdayBreakNow,
          onResumeWorkdayNow: _resumeWorkdayNow,
          onFinishWorkdayNow: _finishWorkdayNow,
          onClearWorkdaySession: _clearWorkdaySession,
          onPickOverrideTime: _pickScheduleOverrideTime,
          onPickOverrideBreakMinutes: _pickScheduleOverrideBreakMinutes,
          onSetOverrideBreakMinutes: _setScheduleOverrideBreakMinutes,
          onAgendaScheduleChanged: _updateScheduleOverrideFromAgenda,
          onResetOverrideEditor: _resetScheduleOverrideEditorToBase,
          onMarkDayAsOff: _markSelectedDayAsDayOff,
          onSaveOverride: _submitScheduleOverride,
          onRemoveOverride: _removeScheduleOverride,
        );
      case _HomeSection.recentActivity:
        return _RecentActivityCard(
          weekPlan: _buildUpcomingWeekPlan(),
          onOpenDay: _openCalendarForDate,
          onOpenWorkEntry: _openWorkQuickEntryForDate,
          onOpenLeaveEntry: _openLeaveQuickEntryForDate,
        );
      case _HomeSection.profile:
        return _ProfileCard(
          formKey: _profileFormKey,
          fullNameController: _fullNameController,
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
          weekdayControllers: _weekdayControllers,
          weekdayStartTimeControllers: _weekdayStartTimeControllers,
          weekdayEndTimeControllers: _weekdayEndTimeControllers,
          weekdayBreakControllers: _weekdayBreakControllers,
          isBusy: _isSavingProfile,
          isDarkTheme: widget.isDarkTheme,
          appearanceSettings: widget.appearanceSettings,
          isUpdatingThemeMode: _isUpdatingThemeMode,
          onDarkThemeChanged: _toggleThemeMode,
          onAppearanceSettingsChanged: _updateAppearanceSettings,
          onSubmit: _submitProfile,
        );
      case _HomeSection.ticket:
        return _SupportTicketCard(
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
          appVersionController: _ticketAppVersionController,
          isSubmitting: _isSubmittingTicket,
          onSubmit: _submitSupportTicket,
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _Header(
                  profileName: snapshot?.profile.fullName,
                  onOpenNavigationMenu: _openNavigationMenu,
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
    required this.calendarView,
    required this.periodLabel,
    required this.isLoadingCalendarData,
    required this.month,
    required this.selectedDate,
    required this.days,
    required this.baseDaySchedule,
    required this.effectiveDaySchedule,
    required this.draftDaySchedule,
    required this.selectedOverride,
    required this.overrideFormKey,
    required this.overrideTargetController,
    required this.overrideStartTimeController,
    required this.overrideEndTimeController,
    required this.overrideBreakController,
    required this.overrideNoteController,
    required this.isSavingOverride,
    required this.selectedActivities,
    required this.dayMetrics,
    required this.weekMetrics,
    required this.monthMetrics,
    required this.yearMetrics,
    required this.onCalendarViewChanged,
    required this.onPreviousPeriod,
    required this.onNextPeriod,
    required this.onSelectDate,
    required this.isSelectedDateToday,
    required this.workdaySession,
    required this.isSavingWorkdaySession,
    required this.onRecordWorkdayStartNow,
    required this.onStartWorkdayBreakNow,
    required this.onResumeWorkdayNow,
    required this.onFinishWorkdayNow,
    required this.onClearWorkdaySession,
    required this.onPickOverrideTime,
    required this.onPickOverrideBreakMinutes,
    required this.onSetOverrideBreakMinutes,
    required this.onAgendaScheduleChanged,
    required this.onResetOverrideEditor,
    required this.onMarkDayAsOff,
    required this.onSaveOverride,
    required this.onRemoveOverride,
  });

  final _CalendarView calendarView;
  final String periodLabel;
  final bool isLoadingCalendarData;
  final String month;
  final DateTime selectedDate;
  final List<_CalendarDay> days;
  final DaySchedule baseDaySchedule;
  final DaySchedule effectiveDaySchedule;
  final DaySchedule draftDaySchedule;
  final ScheduleOverride? selectedOverride;
  final GlobalKey<FormState> overrideFormKey;
  final TextEditingController overrideTargetController;
  final TextEditingController overrideStartTimeController;
  final TextEditingController overrideEndTimeController;
  final TextEditingController overrideBreakController;
  final TextEditingController overrideNoteController;
  final bool isSavingOverride;
  final List<_ActivityItem> selectedActivities;
  final _DayMetrics dayMetrics;
  final List<_DayMetrics> weekMetrics;
  final _MonthMetrics monthMetrics;
  final List<_MonthMetrics> yearMetrics;
  final Future<void> Function(_CalendarView view) onCalendarViewChanged;
  final Future<void> Function() onPreviousPeriod;
  final Future<void> Function() onNextPeriod;
  final ValueChanged<DateTime> onSelectDate;
  final bool isSelectedDateToday;
  final WorkdaySession? workdaySession;
  final bool isSavingWorkdaySession;
  final Future<void> Function() onRecordWorkdayStartNow;
  final Future<void> Function() onStartWorkdayBreakNow;
  final Future<void> Function() onResumeWorkdayNow;
  final Future<void> Function() onFinishWorkdayNow;
  final Future<void> Function() onClearWorkdaySession;
  final Future<void> Function(_CalendarTimeField field) onPickOverrideTime;
  final Future<void> Function() onPickOverrideBreakMinutes;
  final void Function(int minutes) onSetOverrideBreakMinutes;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
  })
  onAgendaScheduleChanged;
  final VoidCallback onResetOverrideEditor;
  final VoidCallback onMarkDayAsOff;
  final Future<void> Function() onSaveOverride;
  final Future<void> Function() onRemoveOverride;

  @override
  Widget build(BuildContext context) {
    final selectedDateLabel = _formatLongDate(selectedDate);
    final draftValidationMessage = _validateScheduleDraft(
      targetText: overrideTargetController.text,
      startTimeText: overrideStartTimeController.text,
      endTimeText: overrideEndTimeController.text,
      breakText: overrideBreakController.text,
    );
    final draftBreakMinutes = parseBreakDurationInput(
      overrideBreakController.text,
    );

    return _SectionCard(
      title: 'Calendario',
      subtitle:
          'Passa da agenda giorno/settimana alle viste mese e anno per vedere la tua pianificazione.',
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton.outlined(
            key: const ValueKey('calendar-prev-month'),
            onPressed: () => onPreviousPeriod(),
            icon: const Icon(Icons.chevron_left),
          ),
          Chip(label: Text(periodLabel)),
          IconButton.outlined(
            key: const ValueKey('calendar-next-month'),
            onPressed: () => onNextPeriod(),
            icon: const Icon(Icons.chevron_right),
          ),
          if (isLoadingCalendarData)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_CalendarView>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<_CalendarView>(
                  value: _CalendarView.day,
                  label: Text('Giorno'),
                  icon: Icon(Icons.today_outlined),
                ),
                ButtonSegment<_CalendarView>(
                  value: _CalendarView.week,
                  label: Text('Settimana'),
                  icon: Icon(Icons.view_week_outlined),
                ),
                ButtonSegment<_CalendarView>(
                  value: _CalendarView.month,
                  label: Text('Mese'),
                  icon: Icon(Icons.calendar_month_outlined),
                ),
                ButtonSegment<_CalendarView>(
                  value: _CalendarView.year,
                  label: Text('Anno'),
                  icon: Icon(Icons.calendar_view_month_outlined),
                ),
              ],
              selected: {_calendarViewOrDefault(calendarView)},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }
                unawaited(onCalendarViewChanged(selection.first));
              },
            ),
          ),
          const SizedBox(height: 18),
          _CalendarPeriodSummary(
            calendarView: calendarView,
            days: days,
            dayMetrics: dayMetrics,
            daySchedule: draftDaySchedule,
            weekMetrics: weekMetrics,
            monthMetrics: monthMetrics,
            yearMetrics: yearMetrics,
            selectedDate: selectedDate,
            onSelectDate: onSelectDate,
            onCalendarViewChanged: onCalendarViewChanged,
            onDayScheduleChanged: onAgendaScheduleChanged,
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Giorno selezionato: $selectedDateLabel',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _ScheduleSummary(
            label: selectedOverride == null
                ? 'Orario previsto'
                : 'Orario eccezione',
            schedule: effectiveDaySchedule,
          ),
          if (selectedOverride != null) ...[
            const SizedBox(height: 6),
            _ScheduleSummary(
              label: 'Orario base',
              schedule: baseDaySchedule,
              emphasize: false,
            ),
          ],
          if (selectedOverride?.note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Nota eccezione: ${selectedOverride!.note!}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (isSelectedDateToday) ...[
            const SizedBox(height: 16),
            _WorkdaySessionCard(
              session: workdaySession,
              schedule: effectiveDaySchedule,
              isBusy: isSavingWorkdaySession,
              onRecordNow: onRecordWorkdayStartNow,
              onStartBreak: onStartWorkdayBreakNow,
              onResume: onResumeWorkdayNow,
              onFinish: onFinishWorkdayNow,
              onClear: workdaySession == null ? null : onClearWorkdaySession,
            ),
          ],
          const SizedBox(height: 16),
          Form(
            key: overrideFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CalendarQuickScheduleEditor(
                  startTimeText:
                      draftDaySchedule.startTime ??
                      overrideStartTimeController.text,
                  endTimeText:
                      draftDaySchedule.endTime ?? overrideEndTimeController.text,
                  breakMinutes: draftBreakMinutes ?? 0,
                  validationMessage: draftValidationMessage,
                  onPickStartTime: () =>
                      onPickOverrideTime(_CalendarTimeField.start),
                  onPickEndTime: () =>
                      onPickOverrideTime(_CalendarTimeField.end),
                  onPickBreakMinutes: onPickOverrideBreakMinutes,
                  onSetBreakMinutes: onSetOverrideBreakMinutes,
                  onResetToBase: onResetOverrideEditor,
                  onMarkDayAsOff: onMarkDayAsOff,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: overrideNoteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nota eccezione',
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: isSavingOverride
                          ? null
                          : () => onSaveOverride(),
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: Text(
                        isSavingOverride
                            ? 'Salvo...'
                            : selectedOverride == null
                            ? 'Salva eccezione'
                            : 'Aggiorna eccezione',
                      ),
                    ),
                    if (selectedOverride != null)
                      OutlinedButton.icon(
                        onPressed: isSavingOverride
                            ? null
                            : () => onRemoveOverride(),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Rimuovi eccezione'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (selectedActivities.isEmpty)
            Text(
              'Nessuna registrazione per questo giorno.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            Column(
              children: [
                for (
                  var index = 0;
                  index < selectedActivities.length;
                  index += 1
                ) ...[
                  _ActivityRow(item: selectedActivities[index]),
                  if (index < selectedActivities.length - 1)
                    const Divider(height: 22),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _CalendarQuickScheduleEditor extends StatelessWidget {
  const _CalendarQuickScheduleEditor({
    required this.startTimeText,
    required this.endTimeText,
    required this.breakMinutes,
    required this.validationMessage,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickBreakMinutes,
    required this.onSetBreakMinutes,
    required this.onResetToBase,
    required this.onMarkDayAsOff,
  });

  final String startTimeText;
  final String endTimeText;
  final int breakMinutes;
  final String? validationMessage;
  final Future<void> Function() onPickStartTime;
  final Future<void> Function() onPickEndTime;
  final Future<void> Function() onPickBreakMinutes;
  final ValueChanged<int> onSetBreakMinutes;
  final VoidCallback onResetToBase;
  final VoidCallback onMarkDayAsOff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final helperColor = validationMessage == null
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.error;
    final helperText = validationMessage ?? 'Tocca un valore per modificarlo.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modifica rapida del giorno',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickScheduleValue(
                label: 'Entrata',
                value: startTimeText.isEmpty ? '--:--' : startTimeText,
                valueKey: const ValueKey('calendar-override-start-time-button'),
                onTap: onPickStartTime,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _QuickScheduleValue(
                label: 'Uscita',
                value: endTimeText.isEmpty ? '--:--' : endTimeText,
                valueKey: const ValueKey('calendar-override-end-time-button'),
                onTap: onPickEndTime,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _QuickScheduleValue(
                label: 'Pausa',
                value: breakMinutes == 0 ? '0 min' : '$breakMinutes min',
                valueKey: const ValueKey('calendar-override-break-value'),
                onTap: onPickBreakMinutes,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in const [0, 15, 30, 45, 60])
              ChoiceChip(
                selected: breakMinutes == preset,
                label: Text(preset == 0 ? 'Nessuna pausa' : '$preset min'),
                onSelected: (_) => onSetBreakMinutes(preset),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          helperText,
          style: theme.textTheme.bodyMedium?.copyWith(color: helperColor),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onResetToBase,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Ripristina base'),
            ),
            OutlinedButton.icon(
              onPressed: onMarkDayAsOff,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Giornata libera'),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkdaySessionCard extends StatelessWidget {
  const _WorkdaySessionCard({
    required this.session,
    required this.schedule,
    required this.isBusy,
    required this.onRecordNow,
    required this.onStartBreak,
    required this.onResume,
    required this.onFinish,
    this.onClear,
  });

  final WorkdaySession? session;
  final DaySchedule schedule;
  final bool isBusy;
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
              Icon(Icons.login_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Giornata di oggi',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _TodayStatusBadge(
                label: statusMeta.label,
                color: statusMeta.color,
                icon: statusMeta.icon,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _workdaySessionDescription(
              session: session,
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
          if (session?.endMinutes != null) ...[
            const SizedBox(height: 10),
            Text(
              'Uscita registrata alle ${formatTimeInput(session!.endMinutes!)}.',
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
                  key: const ValueKey('calendar-record-start-button'),
                  onPressed: isBusy ? null : onRecordNow,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(isBusy ? 'Salvo...' : 'Entrata'),
                ),
              if (session != null &&
                  !session!.isCompleted &&
                  !session!.isOnBreak)
                FilledButton.tonalIcon(
                  key: const ValueKey('calendar-start-break-button'),
                  onPressed: isBusy ? null : onStartBreak,
                  icon: const Icon(Icons.coffee_outlined),
                  label: const Text('Pausa'),
                ),
              if (session?.isOnBreak == true)
                FilledButton.tonalIcon(
                  key: const ValueKey('calendar-resume-workday-button'),
                  onPressed: isBusy ? null : onResume,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('Riprendi'),
                ),
              if (session != null && !session!.isCompleted)
                FilledButton.icon(
                  key: const ValueKey('calendar-end-workday-button'),
                  onPressed: isBusy ? null : onFinish,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Uscita'),
                ),
              if (onClear != null)
                OutlinedButton.icon(
                  key: const ValueKey('calendar-clear-workday-session-button'),
                  onPressed: isBusy ? null : onClear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Rimuovi'),
                ),
            ],
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
  });

  final String label;
  final String value;
  final Key valueKey;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: valueKey,
          onPressed: () => onTap(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            foregroundColor: theme.colorScheme.primary,
            textStyle: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Row(
            children: [
              Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WheelPickerBottomSheet<T> extends StatefulWidget {
  const _WheelPickerBottomSheet({
    required this.title,
    required this.initialValue,
    required this.valueBuilder,
    required this.pickerBuilder,
  });

  final String title;
  final T initialValue;
  final Widget Function(ValueNotifier<T> controller) valueBuilder;
  final Widget Function(ValueNotifier<T> controller) pickerBuilder;

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
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(_valueNotifier.value),
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
    required this.weekMetrics,
    required this.monthMetrics,
    required this.yearMetrics,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onCalendarViewChanged,
    required this.onDayScheduleChanged,
  });

  final _CalendarView calendarView;
  final List<_CalendarDay> days;
  final _DayMetrics dayMetrics;
  final DaySchedule daySchedule;
  final List<_DayMetrics> weekMetrics;
  final _MonthMetrics monthMetrics;
  final List<_MonthMetrics> yearMetrics;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final Future<void> Function(_CalendarView view) onCalendarViewChanged;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
  })
  onDayScheduleChanged;

  @override
  Widget build(BuildContext context) {
    return switch (calendarView) {
      _CalendarView.day => _CalendarDaySummary(
        metrics: dayMetrics,
        schedule: daySchedule,
        onScheduleChanged: onDayScheduleChanged,
      ),
      _CalendarView.week => _CalendarWeekSummary(
        metrics: weekMetrics,
        selectedDate: selectedDate,
        onSelectDate: onSelectDate,
      ),
      _CalendarView.month => _CalendarMonthSummary(
        days: days,
        monthMetrics: monthMetrics,
        onSelectDate: onSelectDate,
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
    required this.onScheduleChanged,
  });

  final _DayMetrics metrics;
  final DaySchedule schedule;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
  })
  onScheduleChanged;

  @override
  Widget build(BuildContext context) {
    final agendaRange = _resolveAgendaRangeForSchedules([schedule]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agenda oraria',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _AgendaDayTimeline(
          metrics: metrics,
          range: agendaRange,
          schedule: schedule,
          onScheduleChanged: onScheduleChanged,
        ),
      ],
    );
  }
}

class _CalendarWeekSummary extends StatelessWidget {
  const _CalendarWeekSummary({
    required this.metrics,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final List<_DayMetrics> metrics;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final agendaRange = _resolveAgendaRange(metrics);

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
        _AgendaWeekTimeline(
          metrics: metrics,
          selectedDate: selectedDate,
          onSelectDate: onSelectDate,
          range: agendaRange,
        ),
      ],
    );
  }
}

class _AgendaDayTimeline extends StatelessWidget {
  const _AgendaDayTimeline({
    required this.metrics,
    required this.range,
    required this.schedule,
    required this.onScheduleChanged,
  });

  final _DayMetrics metrics;
  final _AgendaRange range;
  final DaySchedule schedule;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
  })
  onScheduleChanged;

  @override
  Widget build(BuildContext context) {
    final timelineHeight = range.timelineHeight();

    return SizedBox(
      height: timelineHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AgendaHourRail(range: range, height: timelineHeight),
          const SizedBox(width: 12),
          Expanded(
            child: _AgendaDaySurface(
              metrics: metrics,
              schedule: schedule,
              range: range,
              height: timelineHeight,
              onScheduleChanged: onScheduleChanged,
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
    required this.onSelectDate,
    required this.range,
  });

  final List<_DayMetrics> metrics;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final _AgendaRange range;

  @override
  Widget build(BuildContext context) {
    const headerHeight = 82.0;
    const columnWidth = 134.0;
    final timelineHeight = range.timelineHeight();

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
              SizedBox(
                width: columnWidth,
                child: Column(
                  children: [
                    _AgendaDayHeader(
                      metrics: day,
                      isSelected: _isSameDay(day.date, selectedDate),
                      onTap: () => onSelectDate(day.date),
                    ),
                    const SizedBox(height: 10),
                    _AgendaDaySurface(
                      metrics: day,
                      schedule: day.schedule,
                      range: range,
                      height: timelineHeight,
                      isSelected: _isSameDay(day.date, selectedDate),
                      onTap: () => onSelectDate(day.date),
                    ),
                  ],
                ),
              ),
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
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isSelected
        ? const Color(0xFF0B6E69)
        : (isDark ? const Color(0xFF111919) : const Color(0xFFF7F3EC));
    final borderColor = isSelected
        ? const Color(0xFF0B6E69)
        : (isDark ? const Color(0xFF2F4341) : const Color(0xFFE2DACA));
    final primaryTextColor = isSelected
        ? Colors.white
        : theme.colorScheme.onSurface;
    final secondaryTextColor = isSelected
        ? Colors.white.withValues(alpha: 0.86)
        : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.78) ??
              theme.colorScheme.onSurface.withValues(alpha: 0.78);
    final timeLabel =
        metrics.schedule.startTime != null && metrics.schedule.endTime != null
        ? '${metrics.schedule.startTime} - ${metrics.schedule.endTime}'
        : 'Orari da definire';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
          ),
          child: Column(
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
              const SizedBox(height: 8),
              Text(
                timeLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

class _AgendaDaySurface extends StatelessWidget {
  const _AgendaDaySurface({
    required this.metrics,
    required this.schedule,
    required this.range,
    required this.height,
    this.isSelected = false,
    this.onTap,
    this.onScheduleChanged,
  });

  final _DayMetrics metrics;
  final DaySchedule schedule;
  final _AgendaRange range;
  final double height;
  final bool isSelected;
  final VoidCallback? onTap;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
  })?
  onScheduleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5DED2);
    final surfaceColor = isSelected
        ? (isDark ? const Color(0xFF122120) : const Color(0xFFF6FBFA))
        : (isDark ? const Color(0xFF0D1414) : Colors.white);
    final borderColor = isSelected
        ? const Color(0xFF0B6E69)
        : (isDark ? const Color(0xFF2F4341) : const Color(0xFFE2DACA));
    final scheduledStart = parseTimeInput(schedule.startTime);
    final scheduledEnd = parseTimeInput(schedule.endTime);
    final hasStructuredSchedule =
        scheduledStart != null &&
        scheduledEnd != null &&
        scheduledEnd > scheduledStart;

    final content = Ink(
      height: height,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
      ),
      child: Stack(
        children: [
          for (final mark in range.hourMarks)
            Positioned(
              top: range.positionFor(mark, height),
              left: 0,
              right: 0,
              child: Container(height: 1, color: lineColor),
            ),
          if (hasStructuredSchedule)
            Positioned(
              top: range.positionFor(scheduledStart, height),
              left: 10,
              right: 10,
              height: math.max(
                range.positionFor(scheduledEnd, height) -
                    range.positionFor(scheduledStart, height),
                28,
              ),
              child: _AgendaScheduleBlock(
                metrics: metrics,
                schedule: schedule,
                startMinutes: scheduledStart,
                endMinutes: scheduledEnd,
                range: range,
                height: height,
                onScheduleChanged: onScheduleChanged,
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nessuna fascia oraria impostata',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _AgendaScheduleBlock extends StatefulWidget {
  const _AgendaScheduleBlock({
    required this.metrics,
    required this.schedule,
    required this.startMinutes,
    required this.endMinutes,
    required this.range,
    required this.height,
    this.onScheduleChanged,
  });

  final _DayMetrics metrics;
  final DaySchedule schedule;
  final int startMinutes;
  final int endMinutes;
  final _AgendaRange range;
  final double height;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
  })?
  onScheduleChanged;

  @override
  State<_AgendaScheduleBlock> createState() => _AgendaScheduleBlockState();
}

enum _AgendaDragMode { move, resizeStart, resizeEnd }

class _AgendaScheduleBlockState extends State<_AgendaScheduleBlock> {
  _AgendaDragMode? _dragMode;
  double _dragOffset = 0;
  late int _dragStartMinutes;
  late int _dragEndMinutes;

  void _handleDragStart(_AgendaDragMode mode) {
    _dragMode = mode;
    _dragOffset = 0;
    _dragStartMinutes = widget.startMinutes;
    _dragEndMinutes = widget.endMinutes;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragMode == null || widget.onScheduleChanged == null) {
      return;
    }

    _dragOffset += details.primaryDelta ?? 0;
    final durationMinutes = _dragEndMinutes - _dragStartMinutes;
    final breakMinutes = math.min(
      widget.schedule.breakMinutes,
      math.max(durationMinutes, 0),
    );
    final initialTop = widget.range.positionFor(
      _dragStartMinutes,
      widget.height,
    );
    final initialBottom = widget.range.positionFor(
      _dragEndMinutes,
      widget.height,
    );

    switch (_dragMode!) {
      case _AgendaDragMode.move:
        final nextStart = widget.range.minutesForPosition(
          initialTop + _dragOffset,
          widget.height,
        );
        final clampedStart = nextStart
            .clamp(
          widget.range.startMinutes,
          widget.range.endMinutes - durationMinutes,
        )
            .toInt();
        widget.onScheduleChanged!(
          startMinutes: clampedStart,
          endMinutes: clampedStart + durationMinutes,
          breakMinutes: math.min(breakMinutes, durationMinutes),
        );
        return;
      case _AgendaDragMode.resizeStart:
        final nextStart = widget.range.minutesForPosition(
          initialTop + _dragOffset,
          widget.height,
        );
        final clampedStart = nextStart
            .clamp(
          widget.range.startMinutes,
          _dragEndMinutes - 5,
        )
            .toInt();
        widget.onScheduleChanged!(
          startMinutes: clampedStart,
          endMinutes: _dragEndMinutes,
          breakMinutes: math.min(
            widget.schedule.breakMinutes,
            _dragEndMinutes - clampedStart,
          ),
        );
        return;
      case _AgendaDragMode.resizeEnd:
        final nextEnd = widget.range.minutesForPosition(
          initialBottom + _dragOffset,
          widget.height,
        );
        final clampedEnd = nextEnd
            .clamp(
          _dragStartMinutes + 5,
          widget.range.endMinutes,
        )
            .toInt();
        widget.onScheduleChanged!(
          startMinutes: _dragStartMinutes,
          endMinutes: clampedEnd,
          breakMinutes: math.min(
            widget.schedule.breakMinutes,
            clampedEnd - _dragStartMinutes,
          ),
        );
        return;
    }
  }

  void _handleDragEnd([DragEndDetails? _]) {
    _dragMode = null;
    _dragOffset = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = widget.metrics.hasOverride
        ? (isDark ? const Color(0xFF5E3D1C) : const Color(0xFFFFE6BF))
        : (isDark ? const Color(0xFF174744) : const Color(0xFFCDEDEA));
    final borderColor = widget.metrics.hasOverride
        ? const Color(0xFFC98421)
        : const Color(0xFF0B6E69);
    final title = widget.metrics.hasOverride ? 'Eccezione' : 'Fascia prevista';

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDetail = constraints.maxHeight >= 84;
        final showExtended = constraints.maxHeight >= 128;
        final showHandles =
            widget.onScheduleChanged != null && constraints.maxHeight >= 72;
        final textColor = isDark ? Colors.white : const Color(0xFF153332);
        final content = Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style:
                theme.textTheme.bodySmall?.copyWith(color: textColor) ??
                TextStyle(color: textColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHandles)
                  Align(
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) =>
                          _handleDragStart(_AgendaDragMode.resizeStart),
                      onVerticalDragUpdate: _handleDragUpdate,
                      onVerticalDragEnd: _handleDragEnd,
                      child: _AgendaResizeHandle(color: textColor),
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: widget.onScheduleChanged == null
                        ? null
                        : (_) => _handleDragStart(_AgendaDragMode.move),
                    onVerticalDragUpdate: widget.onScheduleChanged == null
                        ? null
                        : _handleDragUpdate,
                    onVerticalDragEnd: widget.onScheduleChanged == null
                        ? null
                        : _handleDragEnd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatTimeInput(widget.startMinutes)} - ${formatTimeInput(widget.endMinutes)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showDetail && widget.schedule.breakMinutes > 0) ...[
                          const SizedBox(height: 6),
                          Text('Pausa ${_formatHours(widget.schedule.breakMinutes)}'),
                        ],
                        if (showExtended &&
                            widget.metrics.overrideNote?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.metrics.overrideNote!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showHandles)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) =>
                          _handleDragStart(_AgendaDragMode.resizeEnd),
                      onVerticalDragUpdate: _handleDragUpdate,
                      onVerticalDragEnd: _handleDragEnd,
                      child: _AgendaResizeHandle(color: textColor),
                    ),
                  ),
              ],
            ),
          ),
        );

        if (widget.onScheduleChanged == null) {
          return content;
        }

        return MouseRegion(
          cursor: SystemMouseCursors.move,
          child: content,
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

class _CalendarMonthSummary extends StatelessWidget {
  const _CalendarMonthSummary({
    required this.days,
    required this.monthMetrics,
    required this.onSelectDate,
  });

  final List<_CalendarDay> days;
  final _MonthMetrics monthMetrics;
  final ValueChanged<DateTime> onSelectDate;

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

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: isCompactCalendar ? 6 : 8,
                mainAxisSpacing: isCompactCalendar ? 6 : 8,
                childAspectRatio: isCompactCalendar ? 0.88 : 0.84,
              ),
              itemBuilder: (context, index) {
                final day = days[index];
                return _CalendarDayCell(
                  day: day,
                  isCompact: isCompactCalendar,
                  onTap: day.date == null
                      ? null
                      : () => onSelectDate(day.date!),
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
    final isDark = theme.brightness == Brightness.dark;
    if (day.date == null) {
      return const SizedBox.shrink();
    }

    final isSelected = day.isSelected;
    final hasEntries =
        day.workedMinutes > 0 || day.leaveMinutes > 0 || day.hasOverride;
    final backgroundColor = isSelected
        ? const Color(0xFF0B6E69)
        : hasEntries
        ? (isDark ? const Color(0xFF162121) : const Color(0xFFF7F3EC))
        : (isDark ? const Color(0xFF111919) : Colors.white);
    final borderColor = day.isToday
        ? const Color(0xFF0B6E69)
        : (isDark ? const Color(0xFF324343) : const Color(0xFFE0D8CA));
    final textColor = isSelected
        ? Colors.white
        : (isDark ? theme.colorScheme.onSurface : const Color(0xFF1A2A2A));
    final detailColor = isSelected
        ? Colors.white.withValues(alpha: 0.88)
        : (isDark ? const Color(0xFF9AB0AC) : const Color(0xFF526663));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('calendar-day-${day.isoDate}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(isCompact ? 8 : 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: day.isToday ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${day.date!.day}',
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (day.hasOverride)
                Text(
                  'Eccez.',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: detailColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
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
                const SizedBox(height: 10),
                Text(
                  'Tocca per aprire il mese',
                  style: theme.textTheme.bodyMedium,
                ),
                if (metrics.overrideCount > 0) ...[
                  const SizedBox(height: 6),
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
          'Controlla in pochi secondi i prossimi 7 giorni, con stato, fascia prevista ed eventuali eccezioni.',
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
                  if (day.overrideNote?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Nota: ${day.overrideNote!}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
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
    required this.useUniformDailyTarget,
    required this.onUniformDailyTargetChanged,
    required this.uniformDailyTargetController,
    required this.uniformStartTimeController,
    required this.uniformEndTimeController,
    required this.uniformBreakController,
    required this.weekdayControllers,
    required this.weekdayStartTimeControllers,
    required this.weekdayEndTimeControllers,
    required this.weekdayBreakControllers,
    required this.isBusy,
    required this.isDarkTheme,
    required this.appearanceSettings,
    required this.isUpdatingThemeMode,
    required this.onDarkThemeChanged,
    required this.onAppearanceSettingsChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final bool useUniformDailyTarget;
  final ValueChanged<bool> onUniformDailyTargetChanged;
  final TextEditingController uniformDailyTargetController;
  final TextEditingController uniformStartTimeController;
  final TextEditingController uniformEndTimeController;
  final TextEditingController uniformBreakController;
  final Map<WeekdayKey, TextEditingController> weekdayControllers;
  final Map<WeekdayKey, TextEditingController> weekdayStartTimeControllers;
  final Map<WeekdayKey, TextEditingController> weekdayEndTimeControllers;
  final Map<WeekdayKey, TextEditingController> weekdayBreakControllers;
  final bool isBusy;
  final bool isDarkTheme;
  final AppAppearanceSettings appearanceSettings;
  final bool isUpdatingThemeMode;
  final Future<void> Function(bool) onDarkThemeChanged;
  final Future<void> Function(AppAppearanceSettings settings)
  onAppearanceSettingsChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    const primaryOptions = <({String label, Color color})>[
      (label: 'Verde', color: Color(0xFF0B6E69)),
      (label: 'Blu', color: Color(0xFF2457BF)),
      (label: 'Corallo', color: Color(0xFFC75B39)),
      (label: 'Prato', color: Color(0xFF2C8A52)),
      (label: 'Prugna', color: Color(0xFF7A3F96)),
    ];
    const secondaryOptions = <({String label, Color color})>[
      (label: 'Ambra', color: Color(0xFFBF7A24)),
      (label: 'Sabbia', color: Color(0xFF8A6F4D)),
      (label: 'Turchese', color: Color(0xFF2E8C94)),
      (label: 'Rosato', color: Color(0xFFB45D74)),
      (label: 'Menta', color: Color(0xFF5A9D7A)),
    ];

    return _SectionCard(
      title: 'Impostazioni',
      subtitle: 'Gestisci dati base, orari predefiniti e aspetto dell app.',
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
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: useUniformDailyTarget,
              onChanged: isBusy ? null : onUniformDailyTargetChanged,
              title: const Text('Stesse ore ogni giorno lavorativo'),
              subtitle: const Text(
                'Se disattivi la spunta puoi indicare un orario diverso per ogni giorno.',
              ),
            ),
            const SizedBox(height: 18),
            if (useUniformDailyTarget)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 150,
                    child: TextFormField(
                      controller: uniformDailyTargetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Ore standard lun-ven',
                      ),
                      validator: (_) => _validateScheduleDraft(
                        targetText: uniformDailyTargetController.text,
                        startTimeText: uniformStartTimeController.text,
                        endTimeText: uniformEndTimeController.text,
                        breakText: uniformBreakController.text,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: uniformStartTimeController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(labelText: 'Inizio'),
                      validator: (_) => _validateScheduleDraft(
                        targetText: uniformDailyTargetController.text,
                        startTimeText: uniformStartTimeController.text,
                        endTimeText: uniformEndTimeController.text,
                        breakText: uniformBreakController.text,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: uniformEndTimeController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(labelText: 'Fine'),
                      validator: (_) => _validateScheduleDraft(
                        targetText: uniformDailyTargetController.text,
                        startTimeText: uniformStartTimeController.text,
                        endTimeText: uniformEndTimeController.text,
                        breakText: uniformBreakController.text,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: uniformBreakController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Pausa'),
                      validator: (_) => _validateScheduleDraft(
                        targetText: uniformDailyTargetController.text,
                        startTimeText: uniformStartTimeController.text,
                        endTimeText: uniformEndTimeController.text,
                        breakText: uniformBreakController.text,
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
                        child: _DayScheduleEditorRow(
                          weekday: weekday,
                          targetController: weekdayControllers[weekday]!,
                          startTimeController:
                              weekdayStartTimeControllers[weekday]!,
                          endTimeController:
                              weekdayEndTimeControllers[weekday]!,
                          breakController: weekdayBreakControllers[weekday]!,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 10),
            Text(
              'La pausa e facoltativa e puo cambiare giorno per giorno. Se imposti inizio e fine, il totale deve essere coerente.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: isBusy ? null : () => onSubmit(),
              icon: const Icon(Icons.save_outlined),
              label: Text(isBusy ? 'Salvo...' : 'Salva profilo'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Aspetto app',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Scegli tema, colori, font e dimensione del testo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              key: const ValueKey('dark-theme-switch'),
              contentPadding: EdgeInsets.zero,
              value: isDarkTheme,
              onChanged: isUpdatingThemeMode ? null : onDarkThemeChanged,
              title: const Text('Tema scuro'),
              subtitle: Text(
                isUpdatingThemeMode
                    ? 'Aggiorno l aspetto dell app...'
                    : 'Attiva un tema piu scuro per usare l app con meno luminosita.',
              ),
            ),
            const SizedBox(height: 12),
            _AppearanceChoiceGroup<({String label, Color color}), Color>(
              title: 'Colore principale',
              currentValue: appearanceSettings.primaryColor,
              options: primaryOptions,
              valueOf: (option) => option.color,
              labelOf: (option) => option.label,
              previewColorOf: (option) => option.color,
              onSelected: isUpdatingThemeMode
                  ? null
                  : (color) => onAppearanceSettingsChanged(
                      appearanceSettings.copyWith(primaryColor: color),
                    ),
            ),
            const SizedBox(height: 16),
            _AppearanceChoiceGroup<({String label, Color color}), Color>(
              title: 'Colore secondario',
              currentValue: appearanceSettings.secondaryColor,
              options: secondaryOptions,
              valueOf: (option) => option.color,
              labelOf: (option) => option.label,
              previewColorOf: (option) => option.color,
              onSelected: isUpdatingThemeMode
                  ? null
                  : (color) => onAppearanceSettingsChanged(
                      appearanceSettings.copyWith(secondaryColor: color),
                    ),
            ),
            const SizedBox(height: 16),
            _AppearanceChoiceGroup<AppFontFamily, AppFontFamily>(
              title: 'Font testo',
              currentValue: appearanceSettings.fontFamily,
              options: const [
                AppFontFamily.system,
                AppFontFamily.serif,
                AppFontFamily.monospace,
              ],
              valueOf: (fontFamily) => fontFamily,
              labelOf: (fontFamily) => switch (fontFamily) {
                AppFontFamily.system => 'Sistema',
                AppFontFamily.serif => 'Serif',
                AppFontFamily.monospace => 'Mono',
              },
              onSelected: isUpdatingThemeMode
                  ? null
                  : (fontFamily) => onAppearanceSettingsChanged(
                      appearanceSettings.copyWith(fontFamily: fontFamily),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dimensione testo',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Slider(
              value: appearanceSettings.textScale,
              min: 0.9,
              max: 1.25,
              divisions: 7,
              onChanged: isUpdatingThemeMode
                  ? null
                  : (value) => onAppearanceSettingsChanged(
                      appearanceSettings.copyWith(textScale: value),
                    ),
            ),
            Text(
              _textScaleLabel(appearanceSettings.textScale),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({
    required this.label,
    required this.schedule,
    this.emphasize = true,
  });

  final String label;
  final DaySchedule schedule;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '$label: ${_formatDayScheduleDetails(schedule)}',
      style:
          (emphasize ? theme.textTheme.bodyLarge : theme.textTheme.bodyMedium)
              ?.copyWith(
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
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
                width: 120,
                child: TextFormField(
                  controller: targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Ore'),
                  validator: (_) => _validateScheduleDraft(
                    targetText: targetController.text,
                    startTimeText: startTimeController.text,
                    endTimeText: endTimeController.text,
                    breakText: breakController.text,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: startTimeController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(labelText: 'Inizio'),
                  validator: (_) => _validateScheduleDraft(
                    targetText: targetController.text,
                    startTimeText: startTimeController.text,
                    endTimeText: endTimeController.text,
                    breakText: breakController.text,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: endTimeController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(labelText: 'Fine'),
                  validator: (_) => _validateScheduleDraft(
                    targetText: targetController.text,
                    startTimeText: startTimeController.text,
                    endTimeText: endTimeController.text,
                    breakText: breakController.text,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: breakController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Pausa'),
                  validator: (_) => _validateScheduleDraft(
                    targetText: targetController.text,
                    startTimeText: startTimeController.text,
                    endTimeText: endTimeController.text,
                    breakText: breakController.text,
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

class _AppearanceChoiceGroup<T, V> extends StatelessWidget {
  const _AppearanceChoiceGroup({
    required this.title,
    required this.currentValue,
    required this.options,
    required this.valueOf,
    required this.labelOf,
    required this.onSelected,
    this.previewColorOf,
  });

  final String title;
  final V currentValue;
  final List<T> options;
  final V Function(T option) valueOf;
  final String Function(T option) labelOf;
  final Color Function(T option)? previewColorOf;
  final Future<void> Function(V value)? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options
              .map((option) {
                final optionValue = valueOf(option);
                final previewColor = previewColorOf?.call(option);

                return ChoiceChip(
                  selected: optionValue == currentValue,
                  onSelected: onSelected == null
                      ? null
                      : (_) => unawaited(onSelected!(optionValue)),
                  avatar: previewColor == null
                      ? null
                      : Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: previewColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                  label: Text(labelOf(option)),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({
    required this.formKey,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.nameController,
    required this.emailController,
    required this.subjectController,
    required this.messageController,
    required this.appVersionController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final SupportTicketCategory selectedCategory;
  final ValueChanged<SupportTicketCategory> onCategoryChanged;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final TextEditingController appVersionController;
  final bool isSubmitting;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ticket',
      subtitle:
          'Segnala bug, chiedi nuove funzioni o invia una richiesta di supporto senza uscire dall app.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

class _UpdateDownloadDialog extends StatefulWidget {
  const _UpdateDownloadDialog({
    required this.update,
    required this.appUpdateService,
    required this.onOpenReleasePage,
  });

  final AppUpdate update;
  final AppUpdateService appUpdateService;
  final Future<void> Function() onOpenReleasePage;

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
          if (!mounted) {
            return;
          }

          setState(() {
            _progress = progress;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _downloadedUpdate = downloadedUpdate;
        _state = _UpdateDownloadState.readyToInstall;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _state = _UpdateDownloadState.failed;
        _message = 'Download non riuscito. Controlla la connessione e riprova.';
      });
    }
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
    final progressText = _progress.totalBytes == null
        ? '${_formatDownloadSize(_progress.receivedBytes)} scaricati'
        : '${_formatDownloadSize(_progress.receivedBytes)} di ${_formatDownloadSize(_progress.totalBytes!)}';

    return AlertDialog(
      title: Text(_resolveTitle()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Versione attuale ${widget.update.currentVersion} -> nuova versione ${widget.update.latestVersion}',
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
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9D3D2F)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _state == _UpdateDownloadState.installing
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Piu tardi'),
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
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 620,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
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
  });

  const _CalendarDay.empty()
    : date = null,
      isoDate = '',
      expectedMinutes = 0,
      workedMinutes = 0,
      leaveMinutes = 0,
      hasOverride = false,
      isToday = false,
      isSelected = false;

  final DateTime? date;
  final String isoDate;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final bool hasOverride;
  final bool isToday;
  final bool isSelected;
}

class _DayMetrics {
  const _DayMetrics({
    required this.date,
    required this.expectedMinutes,
    required this.workedMinutes,
    required this.leaveMinutes,
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
      balanceMinutes: 0,
      hasOverride: false,
      schedule: const DaySchedule(targetMinutes: 0),
    );
  }

  final DateTime date;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
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

  int minutesForPosition(double position, double height, {int snapStep = 5}) {
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
    required this.balanceMinutes,
    required this.overrideCount,
  });

  factory _MonthMetrics.empty(String month) {
    return _MonthMetrics(
      month: month,
      expectedMinutes: 0,
      workedMinutes: 0,
      leaveMinutes: 0,
      balanceMinutes: 0,
      overrideCount: 0,
    );
  }

  final String month;
  final int expectedMinutes;
  final int workedMinutes;
  final int leaveMinutes;
  final int balanceMinutes;
  final int overrideCount;
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

  var startMinutes = (starts.reduce(math.min) - 60).clamp(0, 24 * 60).toInt();
  var endMinutes = (ends.reduce(math.max) + 60).clamp(0, 24 * 60).toInt();
  startMinutes = (startMinutes ~/ 60) * 60;
  endMinutes = ((endMinutes + 59) ~/ 60) * 60;
  endMinutes = math.min(endMinutes, 24 * 60);

  if ((endMinutes - startMinutes) < 8 * 60) {
    final centeredStart = (((startMinutes + endMinutes) ~/ 2) - 4 * 60)
        .clamp(0, 16 * 60)
        .toInt();
    startMinutes = (centeredStart ~/ 60) * 60;
    endMinutes = startMinutes + 8 * 60;
  }

  if (endMinutes <= startMinutes) {
    return const _AgendaRange(startMinutes: 6 * 60, endMinutes: 22 * 60);
  }

  return _AgendaRange(startMinutes: startMinutes, endMinutes: endMinutes);
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

String _formatWeekdayShortLabel(DateTime date) {
  const weekdayNames = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  return weekdayNames[date.weekday - 1];
}

double _resolveAgendaLabelTop(double position, double height) {
  const labelHeight = 18.0;
  return math.min(
    math.max(position - (labelHeight / 2), 0),
    height - labelHeight,
  );
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
    if ((elapsedMinutes - breakMinutes) != targetMinutes) {
      return 'Ore, inizio, fine e pausa non coincidono.';
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
  required _WorkdaySessionStatus status,
  required int currentBreakMinutes,
}) {
  return switch (status) {
    _WorkdaySessionStatus.notStarted =>
      'Premi Entrata e salvo l orario attuale. Da li ti mostro subito quando puoi uscire.',
    _WorkdaySessionStatus.active =>
      'Entrata registrata alle ${formatTimeInput(session!.startMinutes)}.',
    _WorkdaySessionStatus.onBreak =>
      'Sei in pausa dalle ${formatTimeInput(session!.breakStartedMinutes!)}. Pausa totale: ${currentBreakMinutes.toString()} min.',
    _WorkdaySessionStatus.completed =>
      'Giornata chiusa. Entrata ${formatTimeInput(session!.startMinutes)}, uscita ${formatTimeInput(session.endMinutes!)}.',
  };
}

String? _resolveExpectedEndInfo({
  required WorkdaySession? session,
  required DaySchedule schedule,
  required int nowMinutes,
}) {
  if (session == null || schedule.targetMinutes <= 0) {
    return null;
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

class _Header extends StatelessWidget {
  const _Header({
    required this.profileName,
    required this.onOpenNavigationMenu,
  });

  final String? profileName;
  final Future<void> Function() onOpenNavigationMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            profileName == null
                ? 'Work Hours Platform'
                : 'Ciao ${profileName!}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          key: const ValueKey('navigation-menu-button'),
          tooltip: 'Apri menu',
          onPressed: onOpenNavigationMenu,
          icon: const Icon(Icons.menu_rounded),
        ),
      ],
    );
  }
}

class _NavigationMenuSheet extends StatelessWidget {
  const _NavigationMenuSheet({required this.selectedSection});

  final _HomeSection selectedSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Apri la sezione che ti serve.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ..._mainNavigationSections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    key: ValueKey('navigation-option-${section.name}'),
                    leading: Icon(section.icon),
                    title: Text(section.label),
                    trailing: selectedSection == section
                        ? Icon(
                            Icons.check_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: selectedSection == section
                            ? theme.colorScheme.primary.withValues(alpha: 0.35)
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    tileColor: selectedSection == section
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          )
                        : theme.colorScheme.surfaceContainerLow,
                    onTap: () => Navigator.of(context).pop(section),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                : 'Eccezione attiva per oggi',
          ),
          if (todayOverride?.note?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Nota: ${todayOverride!.note!}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
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
                label: const Text('Modifica oggi'),
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
        label: 'Controlla il calendario',
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
        label: 'Rivedi i dettagli di oggi',
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      case _HomeSection.overview:
        return 'Oggi';
      case _HomeSection.quickEntry:
        return 'Registra';
      case _HomeSection.calendar:
        return 'Calendario';
      case _HomeSection.recentActivity:
        return 'Settimana';
      case _HomeSection.profile:
        return 'Impostazioni';
      case _HomeSection.ticket:
        return 'Ticket';
    }
  }

  IconData get icon {
    switch (this) {
      case _HomeSection.overview:
        return Icons.today_outlined;
      case _HomeSection.quickEntry:
        return Icons.edit_calendar_outlined;
      case _HomeSection.calendar:
        return Icons.calendar_month_outlined;
      case _HomeSection.recentActivity:
        return Icons.view_week_outlined;
      case _HomeSection.profile:
        return Icons.settings_outlined;
      case _HomeSection.ticket:
        return Icons.support_agent_outlined;
    }
  }
}
