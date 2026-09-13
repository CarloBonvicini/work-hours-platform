// Registrazioni gia' salvate sul giorno selezionato, dentro la modifica rapida.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/models/activity_item.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/activity_row.dart';

/// Elenco correttivo delle ore e delle causali del giorno.
///
/// Le ore di una giornata timbrata le salva l'Uscita: qui si interviene solo
/// per correggere o eliminare cio' che e' gia' registrato.
class QuickDayRegistrations extends StatelessWidget {
  const QuickDayRegistrations({
    super.key,
    required this.dayActivities,
    required this.onEditActivity,
    required this.onDeleteActivity,
  });

  final List<ActivityItem> dayActivities;
  final ValueChanged<ActivityItem> onEditActivity;
  final ValueChanged<ActivityItem> onDeleteActivity;

  @override
  Widget build(BuildContext context) {
    if (dayActivities.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gia registrato',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final (index, item) in dayActivities.indexed) ...[
          if (index > 0) const Divider(height: 18),
          // Ogni riga offre Modifica/Elimina: un errore si corregge qui.
          ActivityRow(
            key: ValueKey('quick-day-activity-${item.key}'),
            item: item,
            showDate: false,
            onEdit: () => onEditActivity(item),
            onDelete: () => onDeleteActivity(item),
          ),
        ],
      ],
    );
  }
}
