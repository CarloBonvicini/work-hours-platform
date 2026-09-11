// Limiti e costanti degli allegati e del polling dei ticket di supporto.

const int maxTicketAttachments = 3;

const int maxTicketAttachmentBytes = 4 * 1024 * 1024;

const int maxTicketDiagnosticLogChars = 12000;

const Duration ticketNotificationPollingInterval = Duration(minutes: 1);

const List<String> ticketAudioAttachmentExtensions = [
  'm4a',
  'mp3',
  'wav',
  'ogg',
  'aac',
  'webm',
];
