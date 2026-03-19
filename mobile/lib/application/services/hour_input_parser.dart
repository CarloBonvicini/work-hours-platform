int? parseHoursInput(String? rawValue) {
  var normalizedValue = (rawValue ?? '').trim().toLowerCase();
  if (normalizedValue.isEmpty) {
    return null;
  }

  normalizedValue = normalizedValue
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('ore', 'h')
      .replaceAll('ora', 'h')
      .replaceAll(RegExp(r'(minuti|minuto|min)$'), '');

  if (normalizedValue.isEmpty) {
    return null;
  }

  if (RegExp(r'^\d+$').hasMatch(normalizedValue)) {
    return _parseCompactDigits(normalizedValue);
  }

  if (normalizedValue.contains(':') || normalizedValue.contains('h')) {
    return _parseSeparatedTime(normalizedValue);
  }

  final decimalMatch = RegExp(r'^(\d+)[\.,](\d+)$').firstMatch(normalizedValue);
  if (decimalMatch == null) {
    return null;
  }

  final hours = int.tryParse(decimalMatch.group(1)!);
  final fractionalPart = decimalMatch.group(2)!;
  if (hours == null || hours < 0) {
    return null;
  }

  if (fractionalPart.length == 2) {
    final minutes = int.tryParse(fractionalPart);
    if (minutes != null && minutes >= 0 && minutes < 60) {
      return (hours * 60) + minutes;
    }
  }

  final decimalValue = double.tryParse(
    '${decimalMatch.group(1)}.${decimalMatch.group(2)}',
  );
  if (decimalValue == null || decimalValue < 0) {
    return null;
  }

  return (decimalValue * 60).round();
}

String formatHoursInput(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours:${remainingMinutes.toString().padLeft(2, '0')}';
}

int? _parseCompactDigits(String value) {
  if (value.length <= 2) {
    final hours = int.tryParse(value);
    return hours == null ? null : hours * 60;
  }

  if (value.length == 3 || value.length == 4) {
    final hours = int.tryParse(value.substring(0, value.length - 2));
    final minutes = int.tryParse(value.substring(value.length - 2));
    if (hours == null || minutes == null || minutes < 0 || minutes >= 60) {
      return null;
    }

    return (hours * 60) + minutes;
  }

  return null;
}

int? _parseSeparatedTime(String value) {
  final match = RegExp(r'^(\d+)(?:[:h](\d{1,2})?)?$').firstMatch(value);
  if (match == null) {
    return null;
  }

  final hours = int.tryParse(match.group(1)!);
  final minutePart = match.group(2);
  final minutes = minutePart == null || minutePart.isEmpty
      ? 0
      : int.tryParse(minutePart);

  if (hours == null ||
      hours < 0 ||
      minutes == null ||
      minutes < 0 ||
      minutes >= 60) {
    return null;
  }

  return (hours * 60) + minutes;
}
