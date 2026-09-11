// Confronti tra date e formattazione di date/mesi/giorni della settimana usati dalla home.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/domain/models/weekday_target_minutes.dart';
import 'package:work_hours_mobile/presentation/home/models/calendar_view.dart';

DateTime monthToDate(String month) {
  final parts = month.split('-');
  final year = int.parse(parts[0]);
  final monthValue = int.parse(parts[1]);
  return DateTime(year, monthValue, 1);
}

bool isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}

bool isSameDay(DateTime left, DateTime right) {
  return isSameMonth(left, right) && left.day == right.day;
}

int compareDateToToday(DateTime date) {
  final target = DateUtils.dateOnly(date);
  final today = DateUtils.dateOnly(DateTime.now());
  return target.compareTo(today);
}

String formatMonthLabel(String month) {
  final monthDate = monthToDate(month);
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

String formatLongDate(DateTime date) {
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

String formatCompactDate(DateTime date) {
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

String formatWeekdayShortLabel(DateTime date) {
  const weekdayNames = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  return weekdayNames[date.weekday - 1];
}

String compactWeekdayLabel(WeekdayKey weekday) {
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

/// Sposta [date] di [days] giorni di calendario. A differenza di
/// `add(Duration(days: n))` (che somma 24 ore esatte) resta corretto anche nei
/// giorni del cambio ora legale, che durano 23 o 25 ore.
DateTime addCalendarDays(DateTime date, int days) {
  return DateUtils.addDaysToDate(date, days);
}

/// Data di riferimento dopo aver spostato la vista [view] di [step] periodi.
DateTime shiftCalendarPeriodDate(
  DateTime selectedDate,
  CalendarView view,
  int step,
) {
  return switch (view) {
    CalendarView.day => addCalendarDays(selectedDate, step),
    CalendarView.week => addCalendarDays(selectedDate, step * 7),
    CalendarView.month => DateTime(
      selectedDate.year,
      selectedDate.month + step,
      1,
    ),
    CalendarView.year => DateTime(
      selectedDate.year + step,
      selectedDate.month,
      1,
    ),
  };
}
