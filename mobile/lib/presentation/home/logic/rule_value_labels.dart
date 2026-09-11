// Etichette per monte ore, usato e residuo delle regole permessi e dei limiti impostazioni.

import 'dart:math' as math;
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';

int ruleSafeUsedMinutes(WorkPermissionRule rule) {
  return math.min(rule.usedMinutes, rule.allowanceMinutes);
}

int ruleRemainingMinutes(WorkPermissionRule rule) {
  return math.max(rule.allowanceMinutes - ruleSafeUsedMinutes(rule), 0);
}

int ruleSafeUsedDays(WorkPermissionRule rule) {
  return math.min(rule.usedDays, rule.allowanceDays);
}

int ruleRemainingDays(WorkPermissionRule rule) {
  return math.max(rule.allowanceDays - ruleSafeUsedDays(rule), 0);
}

String formatRuleDaysValue(int days) {
  return days == 1 ? '1 g' : '$days gg';
}

String formatRuleAllowanceValue(WorkPermissionRule rule) {
  switch (rule.allowanceType) {
    case WorkPermissionAllowanceType.hours:
      return formatHoursInput(rule.allowanceMinutes);
    case WorkPermissionAllowanceType.days:
      return formatRuleDaysValue(rule.allowanceDays);
    case WorkPermissionAllowanceType.both:
      return '${formatRuleDaysValue(rule.allowanceDays)} + ${formatHoursInput(rule.allowanceMinutes)}';
  }
}

String formatRuleUsedValue(WorkPermissionRule rule) {
  switch (rule.allowanceType) {
    case WorkPermissionAllowanceType.hours:
      return formatHoursInput(ruleSafeUsedMinutes(rule));
    case WorkPermissionAllowanceType.days:
      return formatRuleDaysValue(ruleSafeUsedDays(rule));
    case WorkPermissionAllowanceType.both:
      return '${formatRuleDaysValue(ruleSafeUsedDays(rule))} + ${formatHoursInput(ruleSafeUsedMinutes(rule))}';
  }
}

String formatRuleRemainingValue(WorkPermissionRule rule) {
  switch (rule.allowanceType) {
    case WorkPermissionAllowanceType.hours:
      return formatHoursInput(ruleRemainingMinutes(rule));
    case WorkPermissionAllowanceType.days:
      return formatRuleDaysValue(ruleRemainingDays(rule));
    case WorkPermissionAllowanceType.both:
      return '${formatRuleDaysValue(ruleRemainingDays(rule))} + ${formatHoursInput(ruleRemainingMinutes(rule))}';
  }
}

String formatRuleAvailabilitySummary(WorkPermissionRule rule) {
  return 'Disponibili ${formatRuleRemainingValue(rule)} su ${formatRuleAllowanceValue(rule)}';
}

String formatSettingsBreakValue(
  String rawValue, {
  required bool isMinimumBreak,
}) {
  final minutes = parseBreakDurationInput(rawValue) ?? 0;
  if (minutes <= 0) {
    return isMinimumBreak ? 'Nessuna pausa minima' : 'Nessuna pausa';
  }
  return formatBreakInput(minutes);
}

String formatSettingsLimitValue(
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
  return formatHoursInput(parsedMinutes);
}

String formatOptionalHoursValue(String rawValue, {required String zeroLabel}) {
  final parsedMinutes = parseHoursInput(rawValue);
  if (parsedMinutes == null || parsedMinutes <= 0) {
    return zeroLabel;
  }
  return formatHoursInput(parsedMinutes);
}
