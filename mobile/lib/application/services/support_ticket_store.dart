import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TrackedSupportTicket {
  const TrackedSupportTicket({
    required this.id,
    required this.subject,
    required this.createdAt,
    required this.lastSeenAdminReplyCount,
    required this.lastNotifiedAdminReplyCount,
  });

  final String id;
  final String subject;
  final DateTime createdAt;
  final int lastSeenAdminReplyCount;
  final int lastNotifiedAdminReplyCount;

  TrackedSupportTicket copyWith({
    String? id,
    String? subject,
    DateTime? createdAt,
    int? lastSeenAdminReplyCount,
    int? lastNotifiedAdminReplyCount,
  }) {
    return TrackedSupportTicket(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAdminReplyCount:
          lastSeenAdminReplyCount ?? this.lastSeenAdminReplyCount,
      lastNotifiedAdminReplyCount:
          lastNotifiedAdminReplyCount ?? this.lastNotifiedAdminReplyCount,
    );
  }

  factory TrackedSupportTicket.fromJson(Map<String, dynamic> json) {
    final lastSeenAdminReplyCount =
        (json['lastSeenAdminReplyCount'] as num?)?.toInt() ?? 0;
    return TrackedSupportTicket(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeenAdminReplyCount: lastSeenAdminReplyCount,
      lastNotifiedAdminReplyCount:
          (json['lastNotifiedAdminReplyCount'] as num?)?.toInt() ??
          lastSeenAdminReplyCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'createdAt': createdAt.toIso8601String(),
      'lastSeenAdminReplyCount': lastSeenAdminReplyCount,
      'lastNotifiedAdminReplyCount': lastNotifiedAdminReplyCount,
    };
  }
}

abstract class SupportTicketStore {
  Future<List<TrackedSupportTicket>> loadTrackedTickets();

  Future<void> saveTrackedTickets(List<TrackedSupportTicket> tickets);

  Future<void> upsertTrackedTicket(TrackedSupportTicket ticket);

  Future<void> markAdminRepliesSeen({
    required String ticketId,
    required int adminReplyCount,
  });

  Future<void> markAdminRepliesNotified({
    required String ticketId,
    required int adminReplyCount,
  });

  Future<void> markAdminRepliesNotifiedBatch({
    required Map<String, int> adminReplyCountByTicketId,
  });

  Future<void> markAdminRepliesSeenAndNotified({
    required String ticketId,
    required int adminReplyCount,
  });
}

class SharedPreferencesSupportTicketStore implements SupportTicketStore {
  const SharedPreferencesSupportTicketStore();

  static const _key = 'support_ticket_store.items';
  static Future<void> _pendingWrite = Future.value();

  @override
  Future<List<TrackedSupportTicket>> loadTrackedTickets() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_key);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TrackedSupportTicket.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveTrackedTickets(List<TrackedSupportTicket> tickets) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(
        tickets.map((ticket) => ticket.toJson()).toList(growable: false),
      ),
    );
  }

  @override
  Future<void> upsertTrackedTicket(TrackedSupportTicket ticket) async {
    await _updateTrackedTickets((currentTickets) {
      return [
        ticket,
        ...currentTickets.where((entry) => entry.id != ticket.id),
      ];
    });
  }

  @override
  Future<void> markAdminRepliesSeen({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    await _updateTrackedTickets((currentTickets) {
      return currentTickets
          .map(
            (ticket) => ticket.id == ticketId
                ? ticket.copyWith(lastSeenAdminReplyCount: adminReplyCount)
                : ticket,
          )
          .toList(growable: false);
    });
  }

  @override
  Future<void> markAdminRepliesNotified({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    await _updateTrackedTickets((currentTickets) {
      return currentTickets
          .map(
            (ticket) => ticket.id == ticketId
                ? ticket.copyWith(lastNotifiedAdminReplyCount: adminReplyCount)
                : ticket,
          )
          .toList(growable: false);
    });
  }

  @override
  Future<void> markAdminRepliesNotifiedBatch({
    required Map<String, int> adminReplyCountByTicketId,
  }) async {
    if (adminReplyCountByTicketId.isEmpty) {
      return;
    }

    await _updateTrackedTickets((currentTickets) {
      return currentTickets.map((ticket) {
        final adminReplyCount = adminReplyCountByTicketId[ticket.id];
        if (adminReplyCount == null) {
          return ticket;
        }

        if (adminReplyCount <= ticket.lastNotifiedAdminReplyCount) {
          return ticket;
        }

        return ticket.copyWith(lastNotifiedAdminReplyCount: adminReplyCount);
      }).toList(growable: false);
    });
  }

  @override
  Future<void> markAdminRepliesSeenAndNotified({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    await _updateTrackedTickets((currentTickets) {
      return currentTickets.map((ticket) {
        if (ticket.id != ticketId) {
          return ticket;
        }

        return ticket.copyWith(
          lastSeenAdminReplyCount: adminReplyCount,
          lastNotifiedAdminReplyCount: adminReplyCount,
        );
      }).toList(growable: false);
    });
  }

  Future<void> _updateTrackedTickets(
    List<TrackedSupportTicket> Function(List<TrackedSupportTicket>) updater,
  ) async {
    await _runWriteTransaction(() async {
      final currentTickets = await loadTrackedTickets();
      final updatedTickets = updater(currentTickets);
      await saveTrackedTickets(updatedTickets);
    });
  }

  Future<void> _runWriteTransaction(Future<void> Function() action) async {
    final nextWrite = _pendingWrite.then((_) => action());
    _pendingWrite = nextWrite.catchError((_) {});
    await nextWrite;
  }
}
