int? parseTimeInput(String? rawValue) {
  final normalizedValue = rawValue?.trim() ?? '';
  if (normalizedValue.isEmpty) {
    return null;
  }

  final compactValue = normalizedValue.replaceAll(RegExp(r'\s+'), '');
  final separatorNormalizedValue = compactValue.replaceAll(RegExp(r'[.,]'), ':');

  int? hours;
  int? minutes;

  final splitMatch = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(separatorNormalizedValue);
  if (splitMatch != null) {
    hours = int.tryParse(splitMatch.group(1)!);
    minutes = int.tryParse(splitMatch.group(2)!);
  } else if (RegExp(r'^\d{1,2}$').hasMatch(compactValue)) {
    hours = int.tryParse(compactValue);
    minutes = 0;
  } else if (RegExp(r'^\d{3,4}$').hasMatch(compactValue)) {
    final paddedValue = compactValue.padLeft(4, '0');
    hours = int.tryParse(paddedValue.substring(0, 2));
    minutes = int.tryParse(paddedValue.substring(2, 4));
  }

  if (hours == null || minutes == null) {
    return null;
  }

  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    return null;
  }

  return (hours * 60) + minutes;
}

String formatTimeInput(int minutesOfDay) {
  final normalizedMinutes = minutesOfDay.clamp(0, 23 * 60 + 59);
  final hours = (normalizedMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (normalizedMinutes % 60).toString().padLeft(2, '0');
  return '$hours:$minutes';
}
