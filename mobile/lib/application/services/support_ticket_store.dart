import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TrackedSupportTicket {
  const TrackedSupportTicket({
    required this.id,
    required this.subject,
    required this.createdAt,
    required this.lastSeenAdminReplyCount,
  });

  final String id;
  final String subject;
  final DateTime createdAt;
  final int lastSeenAdminReplyCount;

  TrackedSupportTicket copyWith({
    String? id,
    String? subject,
    DateTime? createdAt,
    int? lastSeenAdminReplyCount,
  }) {
    return TrackedSupportTicket(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAdminReplyCount:
          lastSeenAdminReplyCount ?? this.lastSeenAdminReplyCount,
    );
  }

  factory TrackedSupportTicket.fromJson(Map<String, dynamic> json) {
    return TrackedSupportTicket(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeenAdminReplyCount:
          (json['lastSeenAdminReplyCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'createdAt': createdAt.toIso8601String(),
      'lastSeenAdminReplyCount': lastSeenAdminReplyCount,
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
}

class SharedPreferencesSupportTicketStore implements SupportTicketStore {
  const SharedPreferencesSupportTicketStore();

  static const _key = 'support_ticket_store.items';

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
    final currentTickets = await loadTrackedTickets();
    final updatedTickets = [
      ticket,
      ...currentTickets.where((entry) => entry.id != ticket.id),
    ];
    await saveTrackedTickets(updatedTickets);
  }

  @override
  Future<void> markAdminRepliesSeen({
    required String ticketId,
    required int adminReplyCount,
  }) async {
    final currentTickets = await loadTrackedTickets();
    final updatedTickets = currentTickets
        .map(
          (ticket) => ticket.id == ticketId
              ? ticket.copyWith(lastSeenAdminReplyCount: adminReplyCount)
              : ticket,
        )
        .toList(growable: false);
    await saveTrackedTickets(updatedTickets);
  }
}
