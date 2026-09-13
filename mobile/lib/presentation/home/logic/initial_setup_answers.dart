// Le tre risposte del primo avvio e come diventano un orario di lavoro.

import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/profile.dart';
import 'package:work_hours_mobile/domain/models/user_work_rules.dart';
import 'package:work_hours_mobile/domain/models/weekday_schedule.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';

/// Cosa serve sapere per far funzionare la giornata: giorni, orari, pausa.
///
/// Tutto il resto (straordinari, banche ore, flessibilita) ha gia un default e
/// si configura piu tardi, solo se serve.
class InitialSetupAnswers {
  const InitialSetupAnswers({
    required this.workingDays,
    required this.startMinutes,
    required this.endMinutes,
    required this.breakMinutes,
  });

  /// Punto di partenza: settimana corta, 9-18 con un'ora di pausa.
  static const defaults = InitialSetupAnswers(
    workingDays: WeekdaySchedule.defaultUniformWorkingDays,
    startMinutes: 9 * 60,
    endMinutes: 18 * 60,
    breakMinutes: 60,
  );

  final Set<WeekdayKey> workingDays;
  final int startMinutes;
  final int endMinutes;
  final int breakMinutes;

  InitialSetupAnswers copyWith({
    Set<WeekdayKey>? workingDays,
    int? startMinutes,
    int? endMinutes,
    int? breakMinutes,
  }) {
    return InitialSetupAnswers(
      workingDays: workingDays ?? this.workingDays,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
    );
  }

  /// Ore di lavoro che restano una volta tolta la pausa.
  int get dailyTargetMinutes {
    final elapsed = endMinutes - startMinutes;
    if (elapsed <= 0) {
      return 0;
    }
    final worked = elapsed - breakMinutes;
    return worked > 0 ? worked : 0;
  }

  /// Le risposte reggono solo se restano ore di lavoro in almeno un giorno.
  bool get isUsable => workingDays.isNotEmpty && dailyTargetMinutes > 0;

  /// Motivo per cui le risposte non bastano, da mostrare a chi le sta dando.
  String? get problem {
    if (workingDays.isEmpty) {
      return 'Scegli almeno un giorno di lavoro.';
    }
    if (endMinutes <= startMinutes) {
      return 'L uscita deve essere dopo l entrata.';
    }
    if (dailyTargetMinutes <= 0) {
      return 'La pausa non puo coprire tutta la giornata.';
    }
    return null;
  }

  WeekdaySchedule buildWeekdaySchedule() {
    return WeekdaySchedule.uniform(
      dailyTargetMinutes,
      startTime: formatTimeInput(startMinutes),
      endTime: formatTimeInput(endMinutes),
      breakMinutes: breakMinutes,
      workingDays: workingDays,
    );
  }

  WeekdayTargetMinutes buildWeekdayTargetMinutes() {
    final schedule = buildWeekdaySchedule();
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

  UserWorkRules buildWorkRules() {
    return UserProfile.defaultWorkRules(
      dailyTargetMinutes: dailyTargetMinutes,
      weekdaySchedule: buildWeekdaySchedule(),
    );
  }
}
