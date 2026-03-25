import 'dart:typed_data';

enum SupportTicketCategory { bug, feature, support }

enum SupportTicketStatus { newTicket, inProgress, answered, closed }

class SupportTicketAttachment {
  const SupportTicketAttachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.downloadPath,
  });

  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String? downloadPath;

  factory SupportTicketAttachment.fromJson(Map<String, dynamic> json) {
    return SupportTicketAttachment(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? 'screenshot',
      contentType: json['contentType'] as String? ?? 'image/png',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      downloadPath: json['downloadPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      if (downloadPath != null) 'downloadPath': downloadPath,
    };
  }
}

class SupportTicketUploadAttachment {
  const SupportTicketUploadAttachment({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}

class SupportTicketReply {
  const SupportTicketReply({
    required this.id,
    required this.author,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String message;
  final DateTime createdAt;

  bool get isAdminReply => author == 'admin';

  factory SupportTicketReply.fromJson(Map<String, dynamic> json) {
    return SupportTicketReply(
      id: json['id'] as String,
      author: json['author'] as String? ?? 'admin',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class SupportTicketThread {
  const SupportTicketThread({
    required this.id,
    required this.category,
    required this.status,
    required this.subject,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
    required this.attachments,
    required this.replies,
    this.name,
    this.email,
    this.appVersion,
  });

  final String id;
  final SupportTicketCategory category;
  final SupportTicketStatus status;
  final String subject;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportTicketAttachment> attachments;
  final List<SupportTicketReply> replies;
  final String? name;
  final String? email;
  final String? appVersion;

  int get adminReplyCount =>
      replies.where((reply) => reply.isAdminReply).length;

  factory SupportTicketThread.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    final rawReplies = json['replies'];
    return SupportTicketThread(
      id: json['id'] as String,
      category: SupportTicketCategoryX.fromApiValue(
        json['category'] as String? ?? 'support',
      ),
      status: SupportTicketStatusX.fromApiValue(
        json['status'] as String? ?? 'new',
      ),
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(
        (json['updatedAt'] as String?) ?? (json['createdAt'] as String),
      ),
      attachments: rawAttachments is List
          ? rawAttachments
                .map(
                  (entry) => SupportTicketAttachment.fromJson(
                    entry as Map<String, dynamic>,
                  ),
                )
                .toList(growable: false)
          : const [],
      replies: rawReplies is List
          ? rawReplies
                .map(
                  (entry) => SupportTicketReply.fromJson(
                    entry as Map<String, dynamic>,
                  ),
                )
                .toList(growable: false)
          : const [],
      name: json['name'] as String?,
      email: json['email'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.apiValue,
      'status': status.apiValue,
      'subject': subject,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      'replies': replies.map((reply) => reply.toJson()).toList(growable: false),
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (appVersion != null) 'appVersion': appVersion,
    };
  }
}

extension SupportTicketCategoryX on SupportTicketCategory {
  static SupportTicketCategory fromApiValue(String value) {
    switch (value) {
      case 'bug':
        return SupportTicketCategory.bug;
      case 'feature':
        return SupportTicketCategory.feature;
      case 'support':
      default:
        return SupportTicketCategory.support;
    }
  }

  String get apiValue {
    switch (this) {
      case SupportTicketCategory.bug:
        return 'bug';
      case SupportTicketCategory.feature:
        return 'feature';
      case SupportTicketCategory.support:
        return 'support';
    }
  }

  String get label {
    switch (this) {
      case SupportTicketCategory.bug:
        return 'Bug';
      case SupportTicketCategory.feature:
        return 'Nuova funzione';
      case SupportTicketCategory.support:
        return 'Supporto';
    }
  }

  String get description {
    switch (this) {
      case SupportTicketCategory.bug:
        return 'Segnala un problema trovato nell app.';
      case SupportTicketCategory.feature:
        return 'Proponi un miglioramento o una nuova idea.';
      case SupportTicketCategory.support:
        return 'Scrivi per dubbi, blocchi o chiarimenti.';
    }
  }
}

extension SupportTicketStatusX on SupportTicketStatus {
  static SupportTicketStatus fromApiValue(String value) {
    switch (value) {
      case 'new':
        return SupportTicketStatus.newTicket;
      case 'in_progress':
        return SupportTicketStatus.inProgress;
      case 'answered':
        return SupportTicketStatus.answered;
      case 'closed':
        return SupportTicketStatus.closed;
      default:
        return SupportTicketStatus.newTicket;
    }
  }

  String get apiValue {
    switch (this) {
      case SupportTicketStatus.newTicket:
        return 'new';
      case SupportTicketStatus.inProgress:
        return 'in_progress';
      case SupportTicketStatus.answered:
        return 'answered';
      case SupportTicketStatus.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case SupportTicketStatus.newTicket:
        return 'Nuovo';
      case SupportTicketStatus.inProgress:
        return 'In lavorazione';
      case SupportTicketStatus.answered:
        return 'Risposto';
      case SupportTicketStatus.closed:
        return 'Chiuso';
    }
  }
}
