// Selettori a rotella condivisi per orari, pause, obiettivi e durate.

part of '../home_screen.dart';

mixin _WheelPickersState on _HomeScreenStateBase {
  @override
  Future<_ScheduleTimeWheelSelection?> _showScheduleTimeWheelPicker({
    required String title,
    required int initialMinutes,
    bool allowClear = false,
    String? Function(int pickedMinutes)? helperTextBuilder,
  }) async {
    final clearSentinel = DateTime(1900, 1, 1);
    final initialDateTime = DateTime(
      2026,
      1,
      1,
      (initialMinutes ~/ 60).clamp(0, 23),
      initialMinutes % 60,
    );
    final pickedDateTime = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => WheelPickerBottomSheet<DateTime>(
        title: title,
        initialValue: initialDateTime,
        clearLabel: allowClear ? 'Rimuovi' : null,
        clearValue: allowClear ? clearSentinel : null,
        valueBuilder: (controller) => ValueListenableBuilder<DateTime>(
          valueListenable: controller,
          builder: (context, value, _) {
            final pickedMinutes = (value.hour * 60) + value.minute;
            final helperText = helperTextBuilder?.call(pickedMinutes);
            final theme = Theme.of(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTimeInput(pickedMinutes),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (helperText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    helperText,
                    key: const ValueKey('schedule-time-wheel-helper-text'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        pickerBuilder: (controller) => SizedBox(
          height: 220,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: initialDateTime,
            onDateTimeChanged: (value) => controller.value = value,
          ),
        ),
      ),
    );
    if (pickedDateTime == null) {
      return null;
    }
    if (allowClear &&
        pickedDateTime.year == clearSentinel.year &&
        pickedDateTime.month == clearSentinel.month &&
        pickedDateTime.day == clearSentinel.day) {
      return const _ScheduleTimeWheelSelection.cleared();
    }
    return _ScheduleTimeWheelSelection.confirmed(
      (pickedDateTime.hour * 60) + pickedDateTime.minute,
    );
  }

  @override
  Future<int?> _showScheduleBreakWheelPicker({
    required int initialMinutes,
    String? standardScheduleLinkLabel,
    Future<void> Function()? onOpenStandardScheduleLink,
  }) async {
    final allowedValues = List<int>.generate(241, (index) => index);
    final initialIndex = initialMinutes.clamp(0, allowedValues.length - 1);
    var openStandardScheduleRequested = false;
    final pickedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => WheelPickerBottomSheet<int>(
        title: 'Pausa',
        initialValue: allowedValues[initialIndex],
        valueBuilder: (controller) => ValueListenableBuilder<int>(
          valueListenable: controller,
          builder: (context, value, _) {
            final linkLabel = standardScheduleLinkLabel;
            if (linkLabel != null && onOpenStandardScheduleLink != null) {
              return Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () {
                    openStandardScheduleRequested = true;
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      linkLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Text(
              value == 0 ? 'Nessuna pausa' : '$value min',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            );
          },
        ),
        pickerBuilder: (controller) => SizedBox(
          height: 220,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex,
            ),
            itemExtent: 38,
            onSelectedItemChanged: (index) {
              controller.value = allowedValues[index];
            },
            children: [
              for (final value in allowedValues)
                Center(
                  child: Text(value == 0 ? 'Nessuna pausa' : '$value min'),
                ),
            ],
          ),
        ),
      ),
    );
    if (openStandardScheduleRequested && onOpenStandardScheduleLink != null) {
      await onOpenStandardScheduleLink();
      return null;
    }
    return pickedMinutes;
  }

  @override
  Future<int?> _showScheduleTargetWheelPicker({
    required String title,
    required int initialMinutes,
    String? standardScheduleLinkLabel,
    Future<void> Function()? onOpenStandardScheduleLink,
  }) async {
    const maxHours = 16;
    final normalizedInitialMinutes = initialMinutes
        .clamp(0, maxHours * 60)
        .toInt();
    final initialHours = normalizedInitialMinutes ~/ 60;
    final initialMinute = normalizedInitialMinutes % 60;
    final hourValues = List<int>.generate(maxHours + 1, (index) => index);
    final minuteValues = List<int>.generate(60, (index) => index);
    var openStandardScheduleRequested = false;

    final pickedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var selectedHour = initialHours;
        var selectedMinute = initialMinute;
        return WheelPickerBottomSheet<int>(
          title: title,
          initialValue: normalizedInitialMinutes,
          valueBuilder: (controller) => ValueListenableBuilder<int>(
            valueListenable: controller,
            builder: (context, value, _) {
              final linkLabel = standardScheduleLinkLabel;
              if (linkLabel != null && onOpenStandardScheduleLink != null) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      openStandardScheduleRequested = true;
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        linkLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Text(
                formatHoursInput(value),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              );
            },
          ),
          pickerBuilder: (controller) => SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: initialHours,
                    ),
                    itemExtent: 38,
                    onSelectedItemChanged: (index) {
                      selectedHour = hourValues[index];
                      controller.value = (selectedHour * 60) + selectedMinute;
                    },
                    children: [
                      for (final hour in hourValues)
                        Center(child: Text(hour.toString().padLeft(2, '0'))),
                    ],
                  ),
                ),
                Text(
                  ':',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: initialMinute,
                    ),
                    itemExtent: 38,
                    onSelectedItemChanged: (index) {
                      selectedMinute = minuteValues[index];
                      controller.value = (selectedHour * 60) + selectedMinute;
                    },
                    children: [
                      for (final minute in minuteValues)
                        Center(child: Text(minute.toString().padLeft(2, '0'))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (openStandardScheduleRequested && onOpenStandardScheduleLink != null) {
      await onOpenStandardScheduleLink();
      return null;
    }
    return pickedMinutes;
  }

  @override
  Future<int?> _showDurationWheelPicker({
    required String title,
    required int initialMinutes,
    required int maxMinutes,
    int stepMinutes = 5,
    String? zeroLabel,
    int? specialValue,
    String? specialLabel,
  }) async {
    final allowedValues = [
      ...?specialValue == null ? null : [specialValue],
      ...List<int>.generate(
        (maxMinutes ~/ stepMinutes) + 1,
        (index) => index * stepMinutes,
      ),
    ];
    final normalizedInitial =
        initialMinutes == specialValue && specialValue != null
        ? specialValue
        : ((initialMinutes / stepMinutes).round() * stepMinutes).clamp(
            0,
            maxMinutes,
          );
    final initialIndex = allowedValues.indexOf(normalizedInitial);
    final resolvedInitialIndex = initialIndex < 0 ? 0 : initialIndex;
    String labelFor(int value) {
      if (specialValue != null &&
          value == specialValue &&
          specialLabel != null) {
        return specialLabel;
      }
      if (value == 0 && zeroLabel != null) {
        return zeroLabel;
      }
      return formatHoursInput(value);
    }

    final pickedMinutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => WheelPickerBottomSheet<int>(
        title: title,
        initialValue: allowedValues[resolvedInitialIndex],
        valueBuilder: (controller) => ValueListenableBuilder<int>(
          valueListenable: controller,
          builder: (context, value, _) => Text(
            labelFor(value),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        pickerBuilder: (controller) => SizedBox(
          height: 220,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: resolvedInitialIndex,
            ),
            itemExtent: 38,
            onSelectedItemChanged: (index) {
              controller.value = allowedValues[index];
            },
            children: [
              for (final value in allowedValues)
                Center(child: Text(labelFor(value))),
            ],
          ),
        ),
      ),
    );
    return pickedMinutes;
  }

  @override
  List<int> get _minutesPresets {
    if (_selectedEntryMode == QuickEntryMode.work) {
      return const [240, 360, 420, 480];
    }

    return const [60, 120, 240, 480];
  }
}
