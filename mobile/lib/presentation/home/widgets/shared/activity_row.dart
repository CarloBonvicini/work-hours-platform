// Riga di un'attivita (ore lavorate o causale) con azioni opzionali.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/logic/hours_labels.dart';
import 'package:work_hours_mobile/presentation/home/models/activity_item.dart';

enum _ActivityAction { edit, delete }

class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.item,
    this.showDate = true,
    this.onEdit,
    this.onDelete,
  });

  final ActivityItem item;
  final bool showDate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  bool get _hasActions => onEdit != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: item.accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: item.accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.subtitle, style: theme.textTheme.bodyMedium),
              if (showDate) ...[
                const SizedBox(height: 6),
                Text(item.date, style: theme.textTheme.labelMedium),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatHours(item.minutes),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: item.accentColor,
          ),
        ),
        if (_hasActions)
          _ActivityActionsMenu(item: item, onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}

class _ActivityActionsMenu extends StatelessWidget {
  const _ActivityActionsMenu({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ActivityItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ActivityAction>(
      key: ValueKey('activity-menu-${item.key}'),
      tooltip: 'Azioni registrazione',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => switch (action) {
        _ActivityAction.edit => onEdit?.call(),
        _ActivityAction.delete => onDelete?.call(),
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            key: ValueKey('activity-edit-${item.key}'),
            value: _ActivityAction.edit,
            child: const ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Modifica'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            key: ValueKey('activity-delete-${item.key}'),
            value: _ActivityAction.delete,
            child: const ListTile(
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Elimina'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}
