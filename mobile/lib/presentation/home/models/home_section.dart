// Sezioni della home e navigazione principale.

import 'package:flutter/material.dart';

enum HomeSection {
  day,
  consuntivo,
  quickEntry,
  calendar,
  workSettings,
  profile,
  ticket,
}

const mainNavigationSections = [
  HomeSection.day,
  HomeSection.consuntivo,
  HomeSection.calendar,
  HomeSection.workSettings,
  HomeSection.profile,
  HomeSection.ticket,
];

String legacyNavigationOptionKey(HomeSection section) {
  return switch (section) {
    HomeSection.day => 'navigation-option-day',
    HomeSection.consuntivo => 'navigation-option-consuntivo',
    HomeSection.calendar => 'navigation-option-calendar',
    HomeSection.workSettings => 'navigation-option-workSettings',
    HomeSection.profile => 'navigation-option-profile',
    HomeSection.ticket => 'navigation-option-ticket',
    HomeSection.quickEntry => 'top-nav-quickEntry',
  };
}

/// Etichette e icone delle sezioni (estensione nominata: usata anche da altri file).
extension HomeSectionPresentation on HomeSection {
  String get label {
    switch (this) {
      case HomeSection.day:
        return 'Oggi';
      case HomeSection.consuntivo:
        return 'Consuntivo';
      case HomeSection.quickEntry:
        return 'Registra';
      case HomeSection.calendar:
        return 'Calendario';
      case HomeSection.workSettings:
        return 'Orari e permessi';
      case HomeSection.profile:
        return 'Impostazioni app';
      case HomeSection.ticket:
        return 'Ticket';
    }
  }

  IconData get icon {
    switch (this) {
      case HomeSection.day:
        return Icons.view_day_outlined;
      case HomeSection.consuntivo:
        return Icons.analytics_outlined;
      case HomeSection.quickEntry:
        return Icons.edit_calendar_outlined;
      case HomeSection.calendar:
        return Icons.calendar_month_outlined;
      case HomeSection.workSettings:
        return Icons.schedule_outlined;
      case HomeSection.profile:
        return Icons.settings_outlined;
      case HomeSection.ticket:
        return Icons.support_agent_outlined;
    }
  }
}
