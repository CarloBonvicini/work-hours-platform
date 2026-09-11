// Chip di stato e allegato dei ticket.

import 'package:flutter/material.dart';

class TicketPill extends StatelessWidget {
  const TicketPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TicketAttachmentChip extends StatelessWidget {
  const TicketAttachmentChip({
    super.key,
    required this.fileName,
    required this.contentType,
    required this.sizeLabel,
    this.onDeleted,
  });

  final String fileName;
  final String contentType;
  final String sizeLabel;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final isAudio = contentType.startsWith('audio/');
    final icon = isAudio ? Icons.mic_rounded : Icons.image_outlined;
    final removeTooltip = isAudio ? 'Rimuovi vocale' : 'Rimuovi screenshot';

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: onDeleted == null ? 200 : 160,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(sizeLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDeleted,
              visualDensity: VisualDensity.compact,
              tooltip: removeTooltip,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}
