// Voce dell'elenco attivita recenti.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ActivityItem {
  const ActivityItem({
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
