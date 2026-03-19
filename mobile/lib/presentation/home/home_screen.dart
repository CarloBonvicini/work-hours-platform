import 'dart:async';

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/application/services/update_reminder_store.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/leave_entry.dart';
import 'package:work_hours_mobile/domain/models/schedule_override.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';

enum _QuickEntryMode { work, leave }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
    required this.updateReminderStore,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;
  final UpdateReminderStore updateReminderStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _profileFormKey = GlobalKey<FormState>();
  final _quickEntryFormKey = GlobalKey<FormState>();
  final _scheduleOverrideFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _uniformDailyTargetController = TextEditingController();
  final _entryDateController = TextEditingController();
  final _entryMinutesController = TextEditingController();
  final _entryNoteController = TextEditingController();
  final _scheduleOverrideTargetController = TextEditingController();
  final _scheduleOverrideNoteController = TextEditingController();
  final Map<WeekdayKey, TextEditingController> _weekdayControllers = {
    for (final weekday in WeekdayKey.values) weekday: TextEditingController(),
  };

  DashboardSnapshot? _snapshot;
  AppUpdate? _availableUpdate;
  late String _selectedMonth;
  late DateTime _selectedDate;
  bool _useUniformDailyTarget = true;
  LeaveType _selectedLeaveType = LeaveType.vacation;
  _QuickEntryMode _selectedEntryMode = _QuickEntryMode.work;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isCheckingForUpdate = true;
  bool _isSavingProfile = false;
  bool _isSavingScheduleOverride = false;
  bool _isSubmittingEntry = false;
  bool _isOpeningUpdate = false;
  bool _isShowingUpdateDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedMonth = widget.dashboardService.currentMonth;
    _selectedDate = _resolveSelectedDateForMonth(_selectedMonth);
    _entryDateController.text = DashboardService.defaultEntryDateOf(
      _selectedDate,
    );
    unawaited(_checkForUpdate());
    _loadSnapshot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isCheckingForUpdate) {
      unawaited(_checkForUpdate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fullNameController.dispose();
    _uniformDailyTargetController.dispose();
    _entryDateController.dispose();
    _entryMinutesController.dispose();
    _entryNoteController.dispose();
    _scheduleOverrideTargetController.dispose();
    _scheduleOverrideNoteController.dispose();
    for (final controller in _weekdayControllers.values) {
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
      final snapshot = await widget.dashboardService.loadSnapshot(
        month: requestedMonth,
      );
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
        _selectedMonth = snapshot.summary.month;
        _selectedDate = resolvedSelectedDate;
        _isLoading = false;
      });
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

    final shouldPrompt = await widget.updateReminderStore.shouldPromptFor(update);
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
        await _openUpdate();
        break;
      case _UpdateDialogAction.remindLater:
      case null:
        await widget.updateReminderStore.remindLater(update);
        break;
    }
  }

  void _hydrateControllers(
    DashboardSnapshot snapshot,
    DateTime selectedDate,
  ) {
    _fullNameController.text = snapshot.profile.fullName;
    _useUniformDailyTarget = snapshot.profile.useUniformDailyTarget;
    _uniformDailyTargetController.text = _formatHoursInput(
      snapshot.profile.dailyTargetMinutes,
    );
    for (final weekday in WeekdayKey.values) {
      _weekdayControllers[weekday]!.text = _formatHoursInput(
        snapshot.profile.weekdayTargetMinutes.forWeekday(weekday),
      );
    }

    final selectedOverride = _findScheduleOverrideForDate(
      snapshot,
      selectedDate,
    );
    _scheduleOverrideTargetController.text = selectedOverride == null
        ? ''
        : _formatHoursInput(selectedOverride.targetMinutes);
    _scheduleOverrideNoteController.text = selectedOverride?.note ?? '';
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      _loadSnapshot(month: _selectedMonth, selectedDate: _selectedDate),
      _checkForUpdate(),
    ]);
  }

  Future<void> _pickEntryDate() async {
    final initialDate = DateTime.tryParse(_entryDateController.text) ??
        _selectedDate;
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

    final weekdayTargetMinutes = _buildWeekdayTargetMinutesFromControllers();
    if (weekdayTargetMinutes == null) {
      setState(() {
        _errorMessage =
            'Compila un valore valido per ogni giorno, usando formato ore come 7:30.';
      });
      return;
    }

    final uniformDailyTargetMinutes = _parseHoursInput(
      _uniformDailyTargetController.text,
    );
    if (_useUniformDailyTarget && uniformDailyTargetMinutes == null) {
      setState(() {
        _errorMessage = 'Inserisci un orario giornaliero valido.';
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
        dailyTargetMinutes:
            uniformDailyTargetMinutes ??
            _averageWorkingDayTargetMinutes(weekdayTargetMinutes),
        weekdayTargetMinutes: weekdayTargetMinutes,
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
      ).showSnackBar(const SnackBar(content: Text('Profilo aggiornato.')));
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

    final targetMinutes = _parseHoursInput(_scheduleOverrideTargetController.text);
    if (targetMinutes == null) {
      setState(() {
        _errorMessage =
            'Inserisci un orario valido per l eccezione del giorno selezionato.';
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
        targetMinutes: targetMinutes,
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

  void _applyPresetMinutes(int minutes) {
    _entryMinutesController.text = minutes.toString();
  }

  Future<void> _changeMonth(int monthOffset) async {
    final currentMonthDate = _monthToDate(_selectedMonth);
    final targetMonthDate = DateTime(
      currentMonthDate.year,
      currentMonthDate.month + monthOffset,
      1,
    );

    await _loadSnapshot(
      month: DashboardService.formatMonth(targetMonthDate),
      selectedDate: targetMonthDate,
    );
  }

  void _selectDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    _entryDateController.text = DashboardService.defaultEntryDateOf(
      normalizedDate,
    );
    final selectedOverride = _snapshot == null
        ? null
        : _findScheduleOverrideForDate(_snapshot!, normalizedDate);
    _scheduleOverrideTargetController.text = selectedOverride == null
        ? ''
        : _formatHoursInput(selectedOverride.targetMinutes);
    _scheduleOverrideNoteController.text = selectedOverride?.note ?? '';
    setState(() {
      _selectedDate = normalizedDate;
    });
  }

  WeekdayTargetMinutes? _buildWeekdayTargetMinutesFromControllers() {
    final parsedValues = <WeekdayKey, int>{};
    for (final weekday in WeekdayKey.values) {
      final parsedValue = _parseHoursInput(_weekdayControllers[weekday]!.text);
      if (parsedValue == null) {
        return null;
      }
      parsedValues[weekday] = parsedValue;
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

  int _resolveExpectedMinutesForDate(DashboardSnapshot snapshot, DateTime date) {
    final scheduleOverride = _findScheduleOverrideForDate(snapshot, date);
    if (scheduleOverride != null) {
      return scheduleOverride.targetMinutes;
    }

    return snapshot.profile.weekdayTargetMinutes.forDate(date);
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
      days.add(
        _CalendarDay(
          date: date,
          isoDate: isoDate,
          workedMinutes: workMinutesByDate[isoDate] ?? 0,
          leaveMinutes: leaveMinutesByDate[isoDate] ?? 0,
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

  String _humanizeError(Object error) {
    if (error is ApiException) {
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
                  apiBaseUrl: snapshot?.apiBaseUrl,
                  isRefreshing: _isLoading,
                  onRefresh: _refreshAll,
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  _ErrorCard(message: _errorMessage!, onRetry: _refreshAll),
                  const SizedBox(height: 16),
                ],
                if (snapshot != null) ...[
                  _OverviewCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _CalendarCard(
                    month: snapshot.summary.month,
                    selectedDate: _selectedDate,
                    days: _buildCalendarDays(snapshot),
                    expectedMinutes: _resolveExpectedMinutesForDate(
                      snapshot,
                      _selectedDate,
                    ),
                    selectedOverride: _findScheduleOverrideForDate(
                      snapshot,
                      _selectedDate,
                    ),
                    overrideFormKey: _scheduleOverrideFormKey,
                    overrideTargetController: _scheduleOverrideTargetController,
                    overrideNoteController: _scheduleOverrideNoteController,
                    isSavingOverride: _isSavingScheduleOverride,
                    selectedActivities: _buildActivitiesForDate(
                      snapshot,
                      _selectedDate,
                    ),
                    onPreviousMonth: () => _changeMonth(-1),
                    onNextMonth: () => _changeMonth(1),
                    onSelectDate: _selectDate,
                    onSaveOverride: _submitScheduleOverride,
                    onRemoveOverride: _removeScheduleOverride,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final sideBySide = constraints.maxWidth >= 960;
                      final cardWidth = sideBySide
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _QuickEntryCard(
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
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _RecentActivityCard(
                              activities: _buildActivities(snapshot),
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: _ProfileCard(
                              formKey: _profileFormKey,
                              fullNameController: _fullNameController,
                              useUniformDailyTarget: _useUniformDailyTarget,
                              onUniformDailyTargetChanged: (value) {
                                setState(() {
                                  _useUniformDailyTarget = value;
                                });
                              },
                              uniformDailyTargetController:
                                  _uniformDailyTargetController,
                              weekdayControllers: _weekdayControllers,
                              isBusy: _isSavingProfile,
                              onSubmit: _submitProfile,
                            ),
                          ),
                        ],
                      );
                    },
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
                labelText: isWorkMode
                    ? 'Nota opzionale'
                    : 'Motivo opzionale',
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
    required this.month,
    required this.selectedDate,
    required this.days,
    required this.expectedMinutes,
    required this.selectedOverride,
    required this.overrideFormKey,
    required this.overrideTargetController,
    required this.overrideNoteController,
    required this.isSavingOverride,
    required this.selectedActivities,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    required this.onSaveOverride,
    required this.onRemoveOverride,
  });

  final String month;
  final DateTime selectedDate;
  final List<_CalendarDay> days;
  final int expectedMinutes;
  final ScheduleOverride? selectedOverride;
  final GlobalKey<FormState> overrideFormKey;
  final TextEditingController overrideTargetController;
  final TextEditingController overrideNoteController;
  final bool isSavingOverride;
  final List<_ActivityItem> selectedActivities;
  final Future<void> Function() onPreviousMonth;
  final Future<void> Function() onNextMonth;
  final ValueChanged<DateTime> onSelectDate;
  final Future<void> Function() onSaveOverride;
  final Future<void> Function() onRemoveOverride;

  @override
  Widget build(BuildContext context) {
    final selectedDateLabel = _formatLongDate(selectedDate);

    return _SectionCard(
      title: 'Calendario',
      subtitle:
          'Tocca un giorno per usarlo subito nell inserimento rapido e vedere cosa hai registrato.',
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton.outlined(
            key: const ValueKey('calendar-prev-month'),
            onPressed: () => onPreviousMonth(),
            icon: const Icon(Icons.chevron_left),
          ),
          Chip(label: Text(_formatMonthLabel(month))),
          IconButton.outlined(
            key: const ValueKey('calendar-next-month'),
            onPressed: () => onNextMonth(),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WeekdayHeader(),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.84,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              return _CalendarDayCell(
                day: day,
                onTap: day.date == null ? null : () => onSelectDate(day.date!),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Selezionato: $selectedDateLabel',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedOverride == null
                ? 'Target previsto ${_formatHours(expectedMinutes)}'
                : 'Target eccezionale ${_formatHours(expectedMinutes)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (selectedOverride?.note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Nota eccezione: ${selectedOverride!.note!}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Form(
            key: overrideFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: overrideTargetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Ore previste per questo giorno',
                    helperText: 'Usa formato 7:30, 6 oppure 6.5',
                  ),
                  validator: (value) {
                    if (_parseHoursInput(value) == null) {
                      return 'Inserisci un orario valido.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                      onPressed: isSavingOverride ? null : () => onSaveOverride(),
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
                for (var index = 0; index < selectedActivities.length; index += 1) ...[
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
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.day, required this.onTap});

  final _CalendarDay day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (day.date == null) {
      return const SizedBox.shrink();
    }

    final isSelected = day.isSelected;
    final hasEntries = day.workedMinutes > 0 || day.leaveMinutes > 0;
    final backgroundColor = isSelected
        ? const Color(0xFF0B6E69)
        : hasEntries
        ? const Color(0xFFF7F3EC)
        : Colors.white;
    final borderColor = day.isToday
        ? const Color(0xFF0B6E69)
        : const Color(0xFFE0D8CA);
    final textColor = isSelected ? Colors.white : const Color(0xFF1A2A2A);
    final detailColor = isSelected
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF526663);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('calendar-day-${day.isoDate}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: day.isToday ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.date!.day}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (day.workedMinutes > 0)
                Text(
                  'Ore ${_formatHours(day.workedMinutes)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: detailColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (day.leaveMinutes > 0)
                Text(
                  'Ass. ${_formatHours(day.leaveMinutes)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: detailColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activities});

  final List<_ActivityItem> activities;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ultimi movimenti',
      subtitle: 'Uno storico unico con le ultime registrazioni.',
      child: activities.isEmpty
          ? Text(
              'Nessuna registrazione disponibile per questo mese.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          : Column(
              children: [
                for (var index = 0; index < activities.length; index += 1) ...[
                  _ActivityRow(item: activities[index]),
                  if (index < activities.length - 1) const Divider(height: 22),
                ],
              ],
            ),
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
    required this.weekdayControllers,
    required this.isBusy,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final bool useUniformDailyTarget;
  final ValueChanged<bool> onUniformDailyTargetChanged;
  final TextEditingController uniformDailyTargetController;
  final Map<WeekdayKey, TextEditingController> weekdayControllers;
  final bool isBusy;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Profilo',
      subtitle: 'Usa questa sezione solo quando devi cambiare nome o target.',
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
              TextFormField(
                controller: uniformDailyTargetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Ore standard lun-ven',
                  helperText: 'Esempi: 7:30, 6 oppure 6.5',
                ),
                validator: (value) {
                  if (_parseHoursInput(value) == null) {
                    return 'Inserisci un orario valido.';
                  }

                  return null;
                },
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: WeekdayKey.values
                    .map(
                      (weekday) => SizedBox(
                        width: 140,
                        child: TextFormField(
                          controller: weekdayControllers[weekday],
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                          decoration: InputDecoration(
                            labelText: weekday.label,
                            helperText: 'Ore',
                          ),
                          validator: (value) {
                            if (_parseHoursInput(value) == null) {
                              return 'Valore non valido.';
                            }

                            return null;
                          },
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: isBusy ? null : () => onSubmit(),
              icon: const Icon(Icons.save_outlined),
              label: Text(isBusy ? 'Salvo...' : 'Salva profilo'),
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
            'Vuoi aprire subito il download della nuova APK oppure preferisci un promemoria piu tardi?',
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6B8A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connessione backend non riuscita',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0D8CA)),
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

    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3EC),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isConnected, required this.text});

  final bool isConnected;
  final String text;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isConnected
        ? const Color(0xFFE6F4ED)
        : const Color(0xFFFFF1EC);
    final foregroundColor = isConnected
        ? const Color(0xFF0B6E69)
        : const Color(0xFF9D3D2F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    required this.workedMinutes,
    required this.leaveMinutes,
    required this.isToday,
    required this.isSelected,
  });

  const _CalendarDay.empty()
    : date = null,
      isoDate = '',
      workedMinutes = 0,
      leaveMinutes = 0,
      isToday = false,
      isSelected = false;

  final DateTime? date;
  final String isoDate;
  final int workedMinutes;
  final int leaveMinutes;
  final bool isToday;
  final bool isSelected;
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

int? _parseHoursInput(String? rawValue) {
  final normalizedValue = (rawValue ?? '').trim();
  if (normalizedValue.isEmpty) {
    return null;
  }

  if (normalizedValue.contains(':')) {
    final parts = normalizedValue.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null || minutes < 0 || minutes >= 60) {
      return null;
    }

    return (hours * 60) + minutes;
  }

  final decimalValue = double.tryParse(
    normalizedValue.replaceAll(',', '.'),
  );
  if (decimalValue == null || decimalValue < 0) {
    return null;
  }

  return (decimalValue * 60).round();
}

String _formatHoursInput(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours:${remainingMinutes.toString().padLeft(2, '0')}';
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

class _Header extends StatelessWidget {
  const _Header({
    required this.profileName,
    required this.apiBaseUrl,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final String? profileName;
  final String? apiBaseUrl;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profileName == null
                    ? 'Work Hours Platform'
                    : 'Ciao ${profileName!}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Una home unica per vedere il mese e registrare rapidamente ore o assenze.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              _StatusBadge(
                isConnected: apiBaseUrl != null,
                text: apiBaseUrl == null
                    ? 'Connessione backend in corso'
                    : 'Backend collegato a $apiBaseUrl',
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: isRefreshing ? null : () => onRefresh(),
          icon: const Icon(Icons.refresh),
          label: Text(isRefreshing ? 'Aggiorno...' : 'Aggiorna'),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final targetPerDay = _formatHours(snapshot.profile.dailyTargetMinutes);
    final balanceText = _formatHours(summary.balanceMinutes, signed: true);
    final balanceColor = summary.balanceMinutes >= 0
        ? const Color(0xFF0B6E69)
        : const Color(0xFF9D3D2F);

    return _SectionCard(
      title: 'Panoramica del mese',
      subtitle: 'Mese ${summary.month} - target giornaliero $targetPerDay',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: balanceColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Saldo $balanceText',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: balanceColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricCard(
            icon: Icons.flag_outlined,
            label: 'Target mensile',
            value: _formatHours(summary.expectedMinutes),
          ),
          _MetricCard(
            icon: Icons.schedule_outlined,
            label: 'Ore registrate',
            value: _formatHours(summary.workedMinutes),
          ),
          _MetricCard(
            icon: Icons.event_busy_outlined,
            label: 'Ferie e permessi',
            value: _formatHours(summary.leaveMinutes),
          ),
          _MetricCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Saldo',
            value: balanceText,
            accentColor: balanceColor,
          ),
        ],
      ),
    );
  }
}
