class DiagnosticLogService {
  DiagnosticLogService({this.maxEntries = 120});

  final int maxEntries;
  final List<String> _entries = <String>[];

  void add(
    String event, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    final normalizedEvent = event.trim();
    if (normalizedEvent.isEmpty) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final detailsText = _formatDetails(details);
    final entry = detailsText == null
        ? '[$timestamp] $normalizedEvent'
        : '[$timestamp] $normalizedEvent | $detailsText';

    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  int get count => _entries.length;

  String exportText({String? header}) {
    final lines = <String>[];
    if (header != null && header.trim().isNotEmpty) {
      lines.add(header.trim());
    }

    if (_entries.isEmpty) {
      lines.add('Nessun log diagnostico registrato.');
    } else {
      lines.addAll(_entries);
    }

    return lines.join('\n');
  }

  String? _formatDetails(Map<String, Object?> details) {
    if (details.isEmpty) {
      return null;
    }

    final segments = <String>[];
    for (final entry in details.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final value = entry.value;
      final valueText = value == null ? 'null' : value.toString().trim();
      if (valueText.isEmpty) {
        continue;
      }
      segments.add('$key=$valueText');
    }

    if (segments.isEmpty) {
      return null;
    }
    return segments.join(', ');
  }
}
