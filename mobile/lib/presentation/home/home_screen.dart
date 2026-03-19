import 'dart:async';

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/app_update_service.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/data/api/work_hours_api_client.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';
import 'package:work_hours_mobile/domain/models/work_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dashboardService,
    required this.appUpdateService,
  });

  final DashboardService dashboardService;
  final AppUpdateService appUpdateService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _workEntryFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _dailyTargetMinutesController = TextEditingController();
  final _dateController = TextEditingController();
  final _minutesController = TextEditingController();
  final _noteController = TextEditingController();

  DashboardSnapshot? _snapshot;
  AppUpdate? _availableUpdate;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isCheckingForUpdate = true;
  bool _isSavingProfile = false;
  bool _isAddingWorkEntry = false;
  bool _isOpeningUpdate = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = widget.dashboardService.defaultEntryDate;
    unawaited(_checkForUpdate());
    _loadSnapshot();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dailyTargetMinutesController.dispose();
    _dateController.dispose();
    _minutesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await widget.dashboardService.loadSnapshot();
      if (!mounted) {
        return;
      }

      _hydrateControllers(snapshot);
      setState(() {
        _snapshot = snapshot;
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

  void _hydrateControllers(DashboardSnapshot snapshot) {
    _fullNameController.text = snapshot.profile.fullName;
    _dailyTargetMinutesController.text = snapshot.profile.dailyTargetMinutes
        .toString();
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([_loadSnapshot(), _checkForUpdate()]);
  }

  Future<void> _pickDate() async {
    final initialDate =
        DateTime.tryParse(_dateController.text) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    _dateController.text = DashboardService.defaultEntryDateOf(pickedDate);
  }

  Future<void> _submitProfile() async {
    final isValid = _profileFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await widget.dashboardService.saveProfile(
        fullName: _fullNameController.text.trim(),
        dailyTargetMinutes: int.parse(
          _dailyTargetMinutesController.text.trim(),
        ),
        month: _snapshot?.summary.month,
      );

      if (!mounted) {
        return;
      }

      _hydrateControllers(snapshot);
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

  Future<void> _submitWorkEntry() async {
    final isValid = _workEntryFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isAddingWorkEntry = true;
      _errorMessage = null;
    });

    try {
      final note = _noteController.text.trim();
      final snapshot = await widget.dashboardService.addWorkEntry(
        date: _dateController.text.trim(),
        minutes: int.parse(_minutesController.text.trim()),
        note: note.isEmpty ? null : note,
      );

      if (!mounted) {
        return;
      }

      _hydrateControllers(snapshot);
      _minutesController.clear();
      _noteController.clear();
      setState(() {
        _snapshot = snapshot;
        _isAddingWorkEntry = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ore registrate con successo.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
        _isAddingWorkEntry = false;
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
          'Impossibile aprire il link di aggiornamento. Apri manualmente ${availableUpdate.releasePageUrl}',
        ),
      ),
    );
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return 'Impossibile contattare il backend. Verifica che l API sia attiva e raggiungibile.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading && _snapshot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _Header(
              apiBaseUrl: _snapshot?.apiBaseUrl,
              isRefreshing: _isLoading,
              onRefresh: _refreshAll,
            ),
            const SizedBox(height: 20),
            if (_availableUpdate != null) ...[
              _UpdateCard(
                update: _availableUpdate!,
                isOpeningUpdate: _isOpeningUpdate,
                onOpenUpdate: _openUpdate,
              ),
              const SizedBox(height: 20),
            ] else if (_isCheckingForUpdate) ...[
              const _UpdateCheckCard(),
              const SizedBox(height: 20),
            ],
            if (_errorMessage != null) ...[
              _ErrorCard(message: _errorMessage!, onRetry: _refreshAll),
              const SizedBox(height: 20),
            ],
            if (_snapshot != null) ...[
              _HeroCard(snapshot: _snapshot!),
              const SizedBox(height: 20),
              _MetricsGrid(snapshot: _snapshot!),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wideLayout = constraints.maxWidth >= 980;
                  final cardWidth = wideLayout
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _ProfileCard(
                          formKey: _profileFormKey,
                          fullNameController: _fullNameController,
                          dailyTargetMinutesController:
                              _dailyTargetMinutesController,
                          isBusy: _isSavingProfile,
                          onSubmit: _submitProfile,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _WorkEntryCard(
                          formKey: _workEntryFormKey,
                          dateController: _dateController,
                          minutesController: _minutesController,
                          noteController: _noteController,
                          isBusy: _isAddingWorkEntry,
                          onPickDate: _pickDate,
                          onSubmit: _submitWorkEntry,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              _WorkEntriesCard(entries: _snapshot!.workEntries),
              const SizedBox(height: 12),
              Text(
                'Mese osservato: ${_snapshot!.summary.month}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.apiBaseUrl,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final String? apiBaseUrl;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 680,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Work Hours Platform',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                apiBaseUrl == null
                    ? 'Connessione backend in corso.'
                    : 'Backend collegato a $apiBaseUrl',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: isRefreshing ? null : () => onRefresh(),
          icon: const Icon(Icons.refresh),
          label: Text(isRefreshing ? 'Aggiorno...' : 'Aggiorna dati'),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const surfaceColor = Color(0xFF123131);
    const accentColor = Color(0xFFE6B84C);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ciao ${snapshot.profile.fullName}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Profilo e dashboard stanno leggendo il backend reale.',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Mese: ${snapshot.summary.month}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: surfaceColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Le nuove release vengono controllate all avvio e possono aprire il download APK direttamente.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
    required this.isOpeningUpdate,
    required this.onOpenUpdate,
  });

  final AppUpdate update;
  final bool isOpeningUpdate;
  final Future<void> Function() onOpenUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF96B8AF)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aggiornamento disponibile',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Versione installata ${update.currentVersion}. Nuova release ${update.latestVersion}.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'L installazione resta manuale: l app apre il download APK o la pagina release.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: isOpeningUpdate ? null : () => onOpenUpdate(),
            icon: const Icon(Icons.system_update_alt),
            label: Text(
              isOpeningUpdate ? 'Apro link...' : 'Scarica aggiornamento',
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateCheckCard extends StatelessWidget {
  const _UpdateCheckCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0D8CA)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Controllo se esiste una release mobile piu recente.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _MetricCard(
          label: 'Target mensile',
          value: formatHours(summary.expectedMinutes),
        ),
        _MetricCard(
          label: 'Ore tracciate',
          value: formatHours(summary.workedMinutes),
        ),
        _MetricCard(
          label: 'Permessi/Ferie',
          value: formatHours(summary.leaveMinutes),
        ),
        _MetricCard(
          label: 'Saldo attuale',
          value: formatHours(summary.balanceMinutes),
          emphasize: true,
        ),
      ],
    );
  }

  static String formatHours(int minutes) {
    final hours = minutes / 60;
    final isWhole = hours == hours.truncateToDouble();
    final formatted = isWhole
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    return '${formatted}h';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 170,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: emphasize ? const Color(0xFFE6F0EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0D8CA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.formKey,
    required this.fullNameController,
    required this.dailyTargetMinutesController,
    required this.isBusy,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController dailyTargetMinutesController;
  final bool isBusy;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0D8CA)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profilo',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: fullNameController,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci il nome completo.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: dailyTargetMinutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target giornaliero (minuti)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final parsedValue = int.tryParse(value?.trim() ?? '');
                if (parsedValue == null || parsedValue <= 0) {
                  return 'Inserisci un numero di minuti valido.';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: isBusy ? null : () => onSubmit(),
              icon: const Icon(Icons.save),
              label: Text(isBusy ? 'Salvo...' : 'Salva profilo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkEntryCard extends StatelessWidget {
  const _WorkEntryCard({
    required this.formKey,
    required this.dateController,
    required this.minutesController,
    required this.noteController,
    required this.isBusy,
    required this.onPickDate,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController dateController;
  final TextEditingController minutesController;
  final TextEditingController noteController;
  final bool isBusy;
  final Future<void> Function() onPickDate;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0D8CA)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inserisci ore',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: dateController,
              readOnly: true,
              onTap: () => onPickDate(),
              decoration: const InputDecoration(
                labelText: 'Data',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              validator: (value) {
                if (value == null ||
                    !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
                  return 'Seleziona una data valida.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minuti lavorati',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final parsedValue = int.tryParse(value?.trim() ?? '');
                if (parsedValue == null || parsedValue <= 0) {
                  return 'Inserisci un numero di minuti valido.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nota (opzionale)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: isBusy ? null : () => onSubmit(),
              icon: const Icon(Icons.add_task),
              label: Text(isBusy ? 'Invio...' : 'Registra ore'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkEntriesCard extends StatelessWidget {
  const _WorkEntriesCard({required this.entries});

  final List<WorkEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleEntries = entries.take(6).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0D8CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ultime giornate registrate',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (visibleEntries.isEmpty)
            Text(
              'Nessuna giornata registrata per il mese selezionato.',
              style: theme.textTheme.bodyLarge,
            )
          else
            for (var index = 0; index < visibleEntries.length; index += 1) ...[
              _WorkEntryRow(entry: visibleEntries[index]),
              if (index < visibleEntries.length - 1) const Divider(height: 24),
            ],
        ],
      ),
    );
  }
}

class _WorkEntryRow extends StatelessWidget {
  const _WorkEntryRow({required this.entry});

  final WorkEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.date,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.note != null && entry.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entry.note!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        Text(
          _MetricsGrid.formatHours(entry.minutes),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6B8A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connessione backend non riuscita',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
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
