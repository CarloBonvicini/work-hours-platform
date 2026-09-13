List<String> resolveUserFacingReleaseNotes(
  String? releaseNotes, {
  int maxItems = 5,
}) {
  if (releaseNotes == null) {
    return const [];
  }

  final normalizedNotes = releaseNotes.replaceAll('\r\n', '\n').trim();
  if (normalizedNotes.isEmpty) {
    return const [];
  }

  final preferredSection = _extractPreferredSection(normalizedNotes);
  final sourceLines = preferredSection.isNotEmpty
      ? preferredSection
      : normalizedNotes.split('\n');
  final seen = <String>{};
  final items = <String>[];

  for (final rawLine in sourceLines) {
    final cleaned = _cleanLine(rawLine);
    if (cleaned == null) {
      continue;
    }

    final key = cleaned.toLowerCase();
    if (!seen.add(key)) {
      continue;
    }

    items.add(cleaned);
    if (items.length >= maxItems) {
      break;
    }
  }

  if (items.isNotEmpty) {
    return items;
  }

  return const ['Miglioramenti generali e correzioni di stabilita.'];
}

List<String> _extractPreferredSection(String releaseNotes) {
  final lines = releaseNotes.split('\n');
  final sectionLines = <String>[];
  var inPreferredSection = false;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      if (inPreferredSection) {
        sectionLines.add(line);
      }
      continue;
    }

    if (line.startsWith('#')) {
      final heading = line
          .replaceFirst(RegExp(r'^#+\s*'), '')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      inPreferredSection = _isPreferredHeading(heading);
      continue;
    }

    if (inPreferredSection) {
      sectionLines.add(line);
    }
  }

  return sectionLines;
}

bool _isPreferredHeading(String heading) {
  const preferredHeadings = <String>[
    'novita',
    'novita per te',
    'cosa cambia',
    'cosa c e di nuovo',
    'miglioramenti',
    'what s new',
    'what is new',
    'user changes',
  ];

  for (final value in preferredHeadings) {
    if (heading.contains(value)) {
      return true;
    }
  }

  return false;
}

String? _cleanLine(String line) {
  var cleaned = line.trim();
  if (cleaned.isEmpty) {
    return null;
  }

  if (cleaned.startsWith('#') || cleaned.startsWith('```')) {
    return null;
  }

  final lower = cleaned.toLowerCase();
  if (lower.startsWith('full changelog') ||
      lower.startsWith('what s changed') ||
      lower.startsWith("what's changed") ||
      lower.startsWith('new contributors')) {
    return null;
  }

  cleaned = cleaned
      .replaceFirst(RegExp(r'^[-*+]\s+'), '')
      .replaceFirst(RegExp(r'^\d+\.\s+'), '')
      .replaceAll(RegExp(r'\s*\(#\d+\)$'), '')
      .replaceAll(RegExp(r'\s*\(#\d+\)'), '')
      .replaceAll(RegExp(r'\s+by\s+@[\w-]+\s*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  cleaned = cleaned
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1) ?? '')
      .replaceAllMapped(
        RegExp(r'\*\*([^*]+)\*\*'),
        (match) => match.group(1) ?? '',
      )
      .trim();

  if (cleaned.isEmpty || _looksTechnical(cleaned)) {
    return null;
  }

  if (cleaned.length > 140) {
    return '${cleaned.substring(0, 137)}...';
  }

  return cleaned;
}

bool _looksTechnical(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.isEmpty) {
    return true;
  }

  if (RegExp(
    r'^android apk build[\s:]+v?\d+(\.\d+){1,4}\.?$',
  ).hasMatch(normalized)) {
    return true;
  }

  if (RegExp(
    r'^(feat|fix|chore|refactor|build|ci|docs|test)\s*:',
  ).hasMatch(normalized)) {
    return true;
  }

  if (RegExp(r'https?://', caseSensitive: false).hasMatch(normalized)) {
    return true;
  }

  if (RegExp(
    r'[\w\-/]+\.(dart|ts|js|yml|yaml|md|json)\b',
  ).hasMatch(normalized)) {
    return true;
  }

  const technicalTokens = <String>[
    'workflow',
    'pipeline',
    'ci',
    'cd',
    'docker',
    'gradle',
    'flutter',
    'backend',
    'frontend',
    'endpoint',
    'api',
    'branch',
    'merge',
    'commit',
    'pull request',
    'github actions',
    'lint',
    'unit test',
    'integration test',
    'sha',
  ];

  for (final token in technicalTokens) {
    if (token.length <= 3) {
      if (RegExp(r'\b' + RegExp.escape(token) + r'\b').hasMatch(normalized)) {
        return true;
      }
      continue;
    }

    if (normalized.contains(token)) {
      return true;
    }
  }

  return false;
}
