// Formattazione di date, dimensioni allegati e colori di stato dei ticket.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/presentation/home/logic/calendar_dates.dart';

String formatTicketDateTime(DateTime value) {
  return '${formatCompactDate(value)}, ${formatTimeInput((value.hour * 60) + value.minute)}';
}

String formatTicketAttachmentSize(int sizeBytes) {
  if (sizeBytes >= 1024 * 1024) {
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  return '${(sizeBytes / 1024).ceil()} KB';
}

Color ticketStatusColor(BuildContext context, SupportTicketStatus status) {
  switch (status) {
    case SupportTicketStatus.newTicket:
      return Theme.of(context).colorScheme.primary;
    case SupportTicketStatus.inProgress:
      return Colors.orange.shade600;
    case SupportTicketStatus.answered:
      return Colors.green.shade600;
    case SupportTicketStatus.closed:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}
