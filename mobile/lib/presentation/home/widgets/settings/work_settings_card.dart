// Card Orari e permessi delle impostazioni.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/application/services/theme_preference_store.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';
import 'package:work_hours_mobile/presentation/home/logic/schedule_draft.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_view.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/leave_banks_editor.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/permission_rules_editor.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/settings_schedule_editor.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/settings_section_panel.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/work_rules_core_editors.dart';
import 'package:work_hours_mobile/presentation/home/widgets/settings/work_rules_overtime_wallet_editors.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/section_cards.dart';

class WorkSettingsCard extends StatelessWidget {
  const WorkSettingsCard({
    super.key,
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
    required this.rulesPauseAdjustmentMode,
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
    required this.onRulesPauseAdjustmentModeChanged,
    required this.onPickRulesOvertimeDailyCapMinutes,
    required this.onPickRulesOvertimeWeeklyCapMinutes,
    required this.onPickRulesOvertimeMonthlyCapMinutes,
    required this.onPickRulesFlexibleStartWindowMinutes,
    required this.onPickRulesWalletDailyExitMinutes,
    required this.onPickRulesWalletWeeklyExitMinutes,
    required this.onPickRulesImplicitCreditDailyCapMinutes,
    required this.onAddAdditionalPermission,
    required this.onAddLeaveBank,
    required this.onEditAdditionalPermission,
    required this.onEditLeaveBank,
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
  final WorkRulesPauseAdjustmentMode rulesPauseAdjustmentMode;
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
  final Future<void> Function(CalendarTimeField field)
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
  final ValueChanged<WorkRulesPauseAdjustmentMode>
  onRulesPauseAdjustmentModeChanged;
  final Future<void> Function() onPickRulesOvertimeDailyCapMinutes;
  final Future<void> Function() onPickRulesOvertimeWeeklyCapMinutes;
  final Future<void> Function() onPickRulesOvertimeMonthlyCapMinutes;
  final Future<void> Function() onPickRulesFlexibleStartWindowMinutes;
  final Future<void> Function() onPickRulesWalletDailyExitMinutes;
  final Future<void> Function() onPickRulesWalletWeeklyExitMinutes;
  final Future<void> Function() onPickRulesImplicitCreditDailyCapMinutes;
  final Future<void> Function() onAddAdditionalPermission;
  final Future<void> Function() onAddLeaveBank;
  final ValueChanged<String> onEditAdditionalPermission;
  final ValueChanged<String> onEditLeaveBank;
  final ValueChanged<String> onRemoveAdditionalPermission;
  final ValueChanged<String> onRemoveLeaveBank;
  final Future<void> Function(WeekdayKey weekday) onPickWeekdayTargetMinutes;
  final Future<void> Function(WeekdayKey weekday, CalendarTimeField field)
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
          resolveDraftTargetMinutes(
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
        final latestStartMinutes =
            weekdayStartMinutes + flexibleStartWindowMinutes;
        final dayLabel = compactWeekdayLabel(weekday);
        final overflowSuffix = latestStartMinutes >= (24 * 60) ? ' +1g' : '';
        flexibleStartRangeHints.add(
          '$dayLabel ${formatTimeInput(weekdayStartMinutes)} - ${formatTimeInput(latestStartMinutes % (24 * 60))}$overflowSuffix',
        );
      }
      if (flexibleStartRangeHints.isEmpty) {
        final uniformStartMinutes = parseTimeInput(
          uniformStartTimeController.text,
        );
        if (uniformStartMinutes != null) {
          final latestStartMinutes =
              uniformStartMinutes + flexibleStartWindowMinutes;
          final overflowSuffix = latestStartMinutes >= (24 * 60) ? ' +1g' : '';
          flexibleStartRangeHints.add(
            'Fascia ${formatTimeInput(uniformStartMinutes)} - ${formatTimeInput(latestStartMinutes % (24 * 60))}$overflowSuffix',
          );
        }
      }
    }

    return SectionCard(
      title: 'Orari e permessi',
      subtitle: 'Orario di lavoro, regole contratto e permessi personali.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionPanel(
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
                    SettingsScheduleEditor(
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
                          onPickUniformScheduleTime(CalendarTimeField.start),
                      onPickEndTime: () =>
                          onPickUniformScheduleTime(CalendarTimeField.end),
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
                        WorkingWeekdaySelector(
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
                                    child: DayScheduleEditorRow(
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
                                            CalendarTimeField.start,
                                          ),
                                      onPickEndTime: () =>
                                          onPickWeekdayScheduleTime(
                                            weekday,
                                            CalendarTimeField.end,
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
                  WorkRulesCoreEditor(
                    minimumBreakText: rulesMinimumBreakController.text,
                    pauseAdjustmentMode: rulesPauseAdjustmentMode,
                    onPauseAdjustmentModeChanged:
                        onRulesPauseAdjustmentModeChanged,
                    isBusy: isBusy,
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
            SettingsSectionPanel(
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
              child: WorkRulesLimitsEditor(
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
            SettingsSectionPanel(
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
              child: WorkRulesOvertimeEditor(
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
            SettingsSectionPanel(
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
              child: WorkRulesAttendanceEditor(
                fixedScheduleEnabled: rulesFixedScheduleEnabled,
                flexibleStartEnabled: rulesFlexibleStartEnabled,
                flexibleStartWindowText:
                    rulesFlexibleStartWindowController.text,
                flexibleStartRangeHints: flexibleStartRangeHints,
                onFixedScheduleChanged: onRulesFixedScheduleEnabledChanged,
                onFlexibleStartChanged: onRulesFlexibleStartEnabledChanged,
                onPickFlexibleStartWindow:
                    onPickRulesFlexibleStartWindowMinutes,
              ),
            ),
            const SizedBox(height: 16),
            SettingsSectionPanel(
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
              child: WorkRulesWalletEditor(
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
            SettingsSectionPanel(
              icon: Icons.rule_folder_outlined,
              title: 'Regole permessi',
              subtitle:
                  'Crea causali personalizzate (es. P36), scegli se gestirle a ore, giorni o entrambi e imposta i movimenti consentiti.',
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
              child: PermissionRulesEditor(
                rules: rulesAdditionalPermissions,
                emptyMessage:
                    'Nessun permesso aggiuntivo configurato. Usa Aggiungi permesso.',
                addButtonLabel: 'Aggiungi permesso',
                onAddRule: onAddAdditionalPermission,
                onEditRule: onEditAdditionalPermission,
                onRemoveRule: onRemoveAdditionalPermission,
              ),
            ),
            const SizedBox(height: 16),
            SettingsSectionPanel(
              icon: Icons.event_available_outlined,
              title: 'Ferie e assenze',
              subtitle:
                  'Gestisci ferie, permessi, malattia e altre causali scegliendo per ciascuna ore, giorni o entrambe.',
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
              child: LeaveBanksEditor(
                rules: rulesLeaveBanks,
                referenceWorkingDayMinutes: useUniformDailyTarget
                    ? (resolveDraftTargetMinutes(
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
                                  resolveDraftTargetMinutes(
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
                onEditRule: onEditLeaveBank,
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
