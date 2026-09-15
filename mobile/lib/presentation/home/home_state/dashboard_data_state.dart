// Caricamento e cache dello snapshot, inserimento rapido voci ed errori leggibili.

part of '../home_screen.dart';

mixin _DashboardDataState on _HomeScreenStateBase {
  @override
  Future<void> _loadSnapshot({
    String? month,
    DateTime? selectedDate,
    bool forceReload = false,
  }) async {
    final requestedMonth = month ?? _selectedMonth;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (forceReload) {
        // Gli altri mesi in cache potrebbero essere cambiati allo stesso modo.
        _snapshotCache.clear();
      }
      final snapshot = await _fetchSnapshotForMonth(
        requestedMonth,
        forceReload: forceReload,
      );
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

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      _loadSnapshot(
        month: _selectedMonth,
        selectedDate: _selectedDate,
        forceReload: true,
      ),
      _checkForUpdate(),
      _refreshTrackedSupportTickets(),
    ]);
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

  @override
  Future<void> _cacheSnapshot(DashboardSnapshot snapshot) async {
    _snapshotCache[snapshot.summary.month] = snapshot;
    await widget.dashboardSnapshotStore.saveSnapshot(snapshot);
  }

  @override
  void _openWorkQuickEntryForDate(DateTime date, {int? prefilledMinutes}) {
    setState(() {
      _goToSection(HomeSection.quickEntry);
      _selectedEntryMode = QuickEntryMode.work;
      _entryDateController.text = DashboardService.defaultEntryDateOf(date);
      _entryMinutesController.text = prefilledMinutes == null
          ? ''
          : prefilledMinutes.toString();
      _entryNoteController.text = '';
    });
  }

  @override
  void _openLeaveQuickEntryForDate(DateTime date, {int? prefilledMinutes}) {
    setState(() {
      _goToSection(HomeSection.quickEntry);
      _selectedEntryMode = QuickEntryMode.leave;
      _selectedLeaveType = LeaveType.permit;
      _entryDateController.text = DashboardService.defaultEntryDateOf(date);
      _entryMinutesController.text = prefilledMinutes == null
          ? ''
          : prefilledMinutes.toString();
      _entryNoteController.text = '';
    });
  }

  @override
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

  @override
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
      final editingEntry = _editingEntry;
      final snapshot = await _persistQuickEntry(editingEntry);

      if (!mounted) {
        return;
      }

      _hydrateControllers(snapshot, _selectedDate);
      _entryMinutesController.clear();
      _entryNoteController.clear();
      setState(() {
        _snapshot = snapshot;
        _editingEntry = null;
        _isSubmittingEntry = false;
      });
      final messenger = ScaffoldMessenger.of(context);
      await _queueCloudBackup();
      if (!mounted) {
        return;
      }

      final successMessage = editingEntry != null
          ? 'Registrazione aggiornata.'
          : _selectedEntryMode == QuickEntryMode.work
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

  /// Aggiunge la voce del modulo rapido oppure, se e' in corso una modifica,
  /// aggiorna la registrazione originale (anche cambiandone il tipo).
  Future<DashboardSnapshot> _persistQuickEntry(EditingEntryRef? editingEntry) {
    final date = _entryDateController.text.trim();
    final minutes = int.parse(_entryMinutesController.text.trim());
    final rawNote = _entryNoteController.text.trim();
    final note = rawNote.isEmpty ? null : rawNote;
    final service = widget.dashboardService;

    if (editingEntry == null) {
      return _selectedEntryMode == QuickEntryMode.work
          ? service.addWorkEntry(date: date, minutes: minutes, note: note)
          : service.addLeaveEntry(
              date: date,
              minutes: minutes,
              type: _selectedLeaveType,
              note: note,
            );
    }

    final keepsKind = switch (editingEntry.kind) {
      ActivityEntryKind.work => _selectedEntryMode == QuickEntryMode.work,
      ActivityEntryKind.leave => _selectedEntryMode == QuickEntryMode.leave,
    };
    if (keepsKind) {
      return editingEntry.kind == ActivityEntryKind.work
          ? service.updateWorkEntry(
              id: editingEntry.id,
              date: date,
              minutes: minutes,
              note: note,
            )
          : service.updateLeaveEntry(
              id: editingEntry.id,
              date: date,
              minutes: minutes,
              type: _selectedLeaveType,
              note: note,
            );
    }

    // Cambio di tipo (ore <-> causale): si elimina la vecchia e si crea la nuova.
    return _replaceEntryWithOtherKind(
      editingEntry,
      date: date,
      minutes: minutes,
      note: note,
    );
  }

  Future<DashboardSnapshot> _replaceEntryWithOtherKind(
    EditingEntryRef editingEntry, {
    required String date,
    required int minutes,
    required String? note,
  }) async {
    final service = widget.dashboardService;
    final month = date.substring(0, 7);
    if (editingEntry.kind == ActivityEntryKind.work) {
      await service.deleteWorkEntry(id: editingEntry.id, month: month);
      return service.addLeaveEntry(
        date: date,
        minutes: minutes,
        type: _selectedLeaveType,
        note: note,
      );
    }
    await service.deleteLeaveEntry(id: editingEntry.id, month: month);
    return service.addWorkEntry(date: date, minutes: minutes, note: note);
  }

  @override
  void _startEditingActivity(ActivityItem item) {
    final snapshot = _snapshotForMonth(item.date.substring(0, 7)) ?? _snapshot;
    final leaveType = snapshot?.leaveEntries
        .where((entry) => entry.id == item.entryId)
        .map((entry) => entry.type)
        .firstOrNull;
    setState(() {
      _editingEntry = (kind: item.kind, id: item.entryId);
      _goToSection(HomeSection.quickEntry);
      _selectedEntryMode = item.kind == ActivityEntryKind.work
          ? QuickEntryMode.work
          : QuickEntryMode.leave;
      if (leaveType != null) {
        _selectedLeaveType = leaveType;
      }
      _entryDateController.text = item.date;
      _entryMinutesController.text = item.minutes.toString();
      _entryNoteController.text = _originalNoteFor(item, snapshot) ?? '';
    });
  }

  String? _originalNoteFor(ActivityItem item, DashboardSnapshot? snapshot) {
    if (snapshot == null) {
      return null;
    }
    return switch (item.kind) {
      ActivityEntryKind.work =>
        snapshot.workEntries
            .where((entry) => entry.id == item.entryId)
            .map((entry) => entry.note)
            .firstOrNull,
      ActivityEntryKind.leave =>
        snapshot.leaveEntries
            .where((entry) => entry.id == item.entryId)
            .map((entry) => entry.note)
            .firstOrNull,
    };
  }

  @override
  void _cancelEntryEditing() {
    setState(() {
      _editingEntry = null;
      _entryMinutesController.clear();
      _entryNoteController.clear();
    });
  }

  @override
  Future<void> _confirmDeleteActivity(ActivityItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare questa registrazione?'),
        content: Text(
          '${item.title} del ${formatLongDate(DateTime.parse(item.date))} '
          '(${formatHoursInput(item.minutes)}). L operazione non si puo annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const ValueKey('activity-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _deleteActivity(item);
  }

  Future<void> _deleteActivity(ActivityItem item) async {
    final month = item.date.substring(0, 7);
    try {
      final snapshot = item.kind == ActivityEntryKind.work
          ? await widget.dashboardService.deleteWorkEntry(
              id: item.entryId,
              month: month,
            )
          : await widget.dashboardService.deleteLeaveEntry(
              id: item.entryId,
              month: month,
            );
      if (!mounted) {
        return;
      }
      _hydrateControllers(snapshot, _selectedDate);
      setState(() {
        _snapshot = snapshot;
        if (_editingEntry?.id == item.entryId) {
          _editingEntry = null;
        }
      });
      final messenger = ScaffoldMessenger.of(context);
      await _queueCloudBackup();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Registrazione eliminata.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _humanizeError(error);
      });
    }
  }

  @override
  int _sumWorkedMinutesForDate(DashboardSnapshot snapshot, String isoDate) {
    var total = 0;
    for (final entry in snapshot.workEntries) {
      if (entry.date == isoDate) {
        total += entry.minutes;
      }
    }
    return total;
  }

  @override
  int _sumLeaveMinutesForDate(DashboardSnapshot snapshot, String isoDate) {
    var total = 0;
    for (final entry in snapshot.leaveEntries) {
      if (entry.date == isoDate) {
        total += entry.minutes;
      }
    }
    return total;
  }

  @override
  int _overrideCountForMonth(DashboardSnapshot snapshot) {
    return snapshot.scheduleOverrides.length;
  }

  @override
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
}
