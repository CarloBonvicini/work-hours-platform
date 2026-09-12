// Voce dell'elenco attivita (ore lavorate o causali) con il riferimento alla
// registrazione originale, per modificarla o eliminarla.

import 'package:flutter/material.dart';

enum ActivityEntryKind { work, leave }

/// Riferimento alla registrazione in modifica nell'inserimento rapido.
typedef EditingEntryRef = ({ActivityEntryKind kind, String id});

class ActivityItem {
  const ActivityItem({
    required this.key,
    required this.entryId,
    required this.kind,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.accentColor,
    required this.icon,
  });

  final String key;
  final String entryId;
  final ActivityEntryKind kind;
  final String date;
  final String title;
  final String subtitle;
  final int minutes;
  final Color accentColor;
  final IconData icon;
}
