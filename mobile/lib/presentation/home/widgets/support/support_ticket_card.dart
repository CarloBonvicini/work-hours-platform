// Card dei ticket di supporto: elenco, dettaglio e invio.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/support_ticket_store.dart';
import 'package:work_hours_mobile/domain/models/support_ticket.dart';
import 'package:work_hours_mobile/presentation/home/logic/ticket_labels.dart';
import 'package:work_hours_mobile/presentation/home/models/support_ticket_limits.dart';
import 'package:work_hours_mobile/presentation/home/widgets/shared/section_cards.dart';
import 'package:work_hours_mobile/presentation/home/widgets/support/ticket_chips.dart';

class SupportTicketCard extends StatelessWidget {
  const SupportTicketCard({
    super.key,
    required this.ticketApiBaseUrl,
    required this.formKey,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.nameController,
    required this.emailController,
    required this.subjectController,
    required this.messageController,
    required this.replyController,
    required this.recoveryTicketIdController,
    required this.appVersionController,
    required this.attachments,
    required this.includeDiagnosticLogs,
    required this.onIncludeDiagnosticLogsChanged,
    required this.trackedTickets,
    required this.ticketThreadsById,
    required this.selectedTicketId,
    required this.isSubmitting,
    required this.isRecordingVoiceAttachment,
    required this.isLoadingThreads,
    required this.isSubmittingReply,
    required this.isRecoveringTicket,
    required this.unreadReplyCount,
    required this.onSelectTicket,
    required this.onRefreshThreads,
    required this.onRecoverTicketById,
    required this.onPickAttachments,
    required this.onRecordVoiceAttachment,
    required this.onPickVoiceAttachments,
    required this.onRemoveAttachment,
    required this.onSubmit,
    required this.onSubmitReply,
  });

  final String ticketApiBaseUrl;
  final GlobalKey<FormState> formKey;
  final SupportTicketCategory selectedCategory;
  final ValueChanged<SupportTicketCategory> onCategoryChanged;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final TextEditingController replyController;
  final TextEditingController recoveryTicketIdController;
  final TextEditingController appVersionController;
  final List<SupportTicketUploadAttachment> attachments;
  final bool includeDiagnosticLogs;
  final ValueChanged<bool> onIncludeDiagnosticLogsChanged;
  final List<TrackedSupportTicket> trackedTickets;
  final Map<String, SupportTicketThread> ticketThreadsById;
  final String? selectedTicketId;
  final bool isSubmitting;
  final bool isRecordingVoiceAttachment;
  final bool isLoadingThreads;
  final bool isSubmittingReply;
  final bool isRecoveringTicket;
  final int unreadReplyCount;
  final Future<void> Function(String ticketId) onSelectTicket;
  final Future<void> Function({bool notifyAboutNewReplies}) onRefreshThreads;
  final Future<void> Function() onRecoverTicketById;
  final Future<void> Function() onPickAttachments;
  final Future<void> Function() onRecordVoiceAttachment;
  final Future<void> Function() onPickVoiceAttachments;
  final void Function(int index) onRemoveAttachment;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSubmitReply;

  TrackedSupportTicket? _selectedTrackedTicket() {
    final currentSelectedTicketId = selectedTicketId;
    if (currentSelectedTicketId == null) {
      return null;
    }

    for (final trackedTicket in trackedTickets) {
      if (trackedTicket.id == currentSelectedTicketId) {
        return trackedTicket;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTrackedTicket = _selectedTrackedTicket();
    final selectedThread = selectedTrackedTicket == null
        ? null
        : ticketThreadsById[selectedTrackedTicket.id];
    final isSelectedThreadClosed =
        selectedThread?.status == SupportTicketStatus.closed;

    return SectionCard(
      title: 'Ticket',
      subtitle:
          'Segnala bug, chiedi nuove funzioni o invia una richiesta di supporto senza uscire dall app.',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'I tuoi ticket',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                if (unreadReplyCount > 0)
                  TicketPill(
                    label: unreadReplyCount == 1
                        ? '1 risposta nuova'
                        : '$unreadReplyCount risposte nuove',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                const Spacer(),
                IconButton.outlined(
                  tooltip: 'Aggiorna ticket',
                  onPressed: isLoadingThreads
                      ? null
                      : () => onRefreshThreads(notifyAboutNewReplies: false),
                  icon: isLoadingThreads
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trackedTickets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Quando apri un ticket dall app, qui troverai il thread e le eventuali risposte admin.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: trackedTickets
                    .map((trackedTicket) {
                      final thread = ticketThreadsById[trackedTicket.id];
                      final unreadReplies = thread == null
                          ? 0
                          : math.max(
                              0,
                              thread.adminReplyCount -
                                  trackedTicket.lastSeenAdminReplyCount,
                            );
                      final isSelected = trackedTicket.id == selectedTicketId;
                      return FilterChip(
                        key: ValueKey('tracked-ticket-${trackedTicket.id}'),
                        selected: isSelected,
                        onSelected: (_) => onSelectTicket(trackedTicket.id),
                        label: Text(
                          unreadReplies > 0
                              ? '${trackedTicket.subject} · $unreadReplies nuove'
                              : trackedTicket.subject,
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              if (selectedThread != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            selectedThread.subject,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          TicketPill(
                            label: selectedThread.status.label,
                            color: ticketStatusColor(
                              context,
                              selectedThread.status,
                            ),
                          ),
                          Text(
                            'Aggiornato ${formatTicketDateTime(selectedThread.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        'Codice ticket: ${selectedThread.id}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messaggio iniziale',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(selectedThread.message),
                          ],
                        ),
                      ),
                      if (selectedThread.attachments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Allegati ticket',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: selectedThread.attachments
                              .map(
                                (attachment) => TicketAttachmentChip(
                                  fileName: attachment.fileName,
                                  contentType: attachment.contentType,
                                  sizeLabel: formatTicketAttachmentSize(
                                    attachment.sizeBytes,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      if (selectedThread.replies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...selectedThread.replies.map((reply) {
                          final isAdminReply = reply.isAdminReply;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isAdminReply
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAdminReply
                                      ? 'Risposta admin'
                                      : 'Tua replica',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatTicketDateTime(reply.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(reply.message),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (isSelectedThreadClosed) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            'Ticket chiuso: non puoi inviare nuove risposte.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: replyController,
                        maxLines: 4,
                        enabled: !isSelectedThreadClosed && !isSubmittingReply,
                        decoration: InputDecoration(
                          labelText: isSelectedThreadClosed
                              ? 'Ticket chiuso'
                              : 'Rispondi al ticket',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: isSubmittingReply || isSelectedThreadClosed
                            ? null
                            : () => onSubmitReply(),
                        icon: const Icon(Icons.reply_rounded),
                        label: Text(
                          isSelectedThreadClosed
                              ? 'Ticket chiuso'
                              : isSubmittingReply
                              ? 'Invio risposta...'
                              : 'Invia risposta',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Recupera ticket con codice',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Anche senza account: salva il codice ticket e incollalo qui se cambi telefono o reinstalli l app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('ticket-recovery-id-field'),
                    controller: recoveryTicketIdController,
                    enabled: !isRecoveringTicket,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Codice ticket',
                      hintText: 'es. 8f72c4b2-...',
                    ),
                    onFieldSubmitted: (_) {
                      if (!isRecoveringTicket) {
                        unawaited(onRecoverTicketById());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  key: const ValueKey('ticket-recovery-submit-button'),
                  onPressed: isRecoveringTicket
                      ? null
                      : () => unawaited(onRecoverTicketById()),
                  icon: isRecoveringTicket
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(isRecoveringTicket ? 'Recupero...' : 'Recupera'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Apri un nuovo ticket',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: SupportTicketCategory.values
                  .map(
                    (category) => ChoiceChip(
                      key: ValueKey('ticket-category-${category.apiValue}'),
                      label: Text(category.label),
                      selected: selectedCategory == category,
                      onSelected: isSubmitting
                          ? null
                          : (_) => onCategoryChanged(category),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Text(
              selectedCategory.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Facoltativa, se vuoi una risposta',
              ),
              validator: (value) {
                final normalizedValue = value?.trim() ?? '';
                if (normalizedValue.isEmpty) {
                  return null;
                }

                final isValidEmail = RegExp(
                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                ).hasMatch(normalizedValue);
                return isValidEmail ? null : 'Inserisci un email valida.';
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('ticket-subject-field'),
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Oggetto'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci un oggetto.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('ticket-message-field'),
              controller: messageController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Messaggio',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Descrivi la richiesta o il problema.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Allegati',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Puoi allegare fino a 3 file: screenshot (PNG, JPG, WEBP) o vocali (M4A, MP3, WAV, OGG, AAC, WEBM). Puoi registrarli al momento o sceglierli da file. Massimo 4 MB ciascuno.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('ticket-attachments-button'),
                  onPressed: isSubmitting ? null : () => onPickAttachments(),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Scegli screenshot'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('ticket-voice-attachments-button'),
                  onPressed: isSubmitting || isRecordingVoiceAttachment
                      ? null
                      : () => onRecordVoiceAttachment(),
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(
                    isRecordingVoiceAttachment
                        ? 'Registrazione...'
                        : 'Registra vocale',
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('ticket-voice-files-button'),
                  onPressed: isSubmitting || isRecordingVoiceAttachment
                      ? null
                      : () => onPickVoiceAttachments(),
                  icon: const Icon(Icons.audio_file_outlined),
                  label: const Text('Scegli vocale'),
                ),
                if (attachments.isNotEmpty)
                  TicketPill(
                    label:
                        '${attachments.length}/$maxTicketAttachments allegati',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                if (isRecordingVoiceAttachment)
                  TicketPill(
                    label: 'Mic attivo',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
              ],
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: attachments
                    .asMap()
                    .entries
                    .map(
                      (entry) => TicketAttachmentChip(
                        fileName: entry.value.fileName,
                        contentType: entry.value.contentType,
                        sizeLabel: formatTicketAttachmentSize(
                          entry.value.sizeBytes,
                        ),
                        onDeleted: () => onRemoveAttachment(entry.key),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: appVersionController,
              decoration: const InputDecoration(
                labelText: 'Versione app',
                hintText: 'Facoltativa',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: includeDiagnosticLogs,
              onChanged: isSubmitting
                  ? null
                  : (value) => onIncludeDiagnosticLogsChanged(value),
              title: const Text('Condividi log diagnostici (consigliato)'),
              subtitle: const Text(
                'I log tecnici ci aiutano a ricostruire rapidamente cosa e successo nel codice e rendono l intervento piu veloce e preciso.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('ticket-submit-button'),
              onPressed: isSubmitting ? null : () => onSubmit(),
              icon: const Icon(Icons.send_outlined),
              label: Text(isSubmitting ? 'Invio...' : 'Invia ticket'),
            ),
          ],
        ),
      ),
    );
  }
}
