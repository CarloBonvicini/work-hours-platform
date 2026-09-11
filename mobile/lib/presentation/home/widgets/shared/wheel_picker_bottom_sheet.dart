// Bottom sheet con selettore a rotella generico.

import 'package:flutter/material.dart';

class WheelPickerBottomSheet<T> extends StatefulWidget {
  const WheelPickerBottomSheet({
    super.key,
    required this.title,
    required this.initialValue,
    required this.valueBuilder,
    required this.pickerBuilder,
    this.clearLabel,
    this.clearValue,
  });

  final String title;
  final T initialValue;
  final Widget Function(ValueNotifier<T> controller) valueBuilder;
  final Widget Function(ValueNotifier<T> controller) pickerBuilder;
  final String? clearLabel;
  final T? clearValue;

  @override
  State<WheelPickerBottomSheet<T>> createState() =>
      WheelPickerBottomSheetState<T>();
}

class WheelPickerBottomSheetState<T> extends State<WheelPickerBottomSheet<T>> {
  late final ValueNotifier<T> _valueNotifier;

  @override
  void initState() {
    super.initState();
    _valueNotifier = ValueNotifier<T>(widget.initialValue);
  }

  @override
  void dispose() {
    _valueNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                if (widget.clearLabel != null && widget.clearValue != null)
                  TextButton(
                    key: const ValueKey('wheel-picker-clear-button'),
                    onPressed: () =>
                        Navigator.of(context).pop(widget.clearValue),
                    child: Text(
                      widget.clearLabel!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton.tonal(
                  onPressed: () =>
                      Navigator.of(context).pop(_valueNotifier.value),
                  child: const Text('Conferma'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            widget.valueBuilder(_valueNotifier),
            const SizedBox(height: 12),
            widget.pickerBuilder(_valueNotifier),
          ],
        ),
      ),
    );
  }
}
