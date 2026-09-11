// Editor RGB con slider per i colori personalizzati.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/logic/rgb_color.dart';

class RgbColorEditor extends StatelessWidget {
  const RgbColorEditor({
    super.key,
    required this.title,
    required this.color,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final Color color;
  final bool enabled;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatColorHex(color),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RgbSliderRow(
          label: 'Rosso',
          value: colorChannel(color, RgbColorChannel.red),
          color: Colors.redAccent,
          enabled: enabled,
          onChanged: (value) =>
              onChanged(replaceColorChannel(color, red: value)),
        ),
        const SizedBox(height: 8),
        RgbSliderRow(
          label: 'Verde',
          value: colorChannel(color, RgbColorChannel.green),
          color: Colors.green,
          enabled: enabled,
          onChanged: (value) =>
              onChanged(replaceColorChannel(color, green: value)),
        ),
        const SizedBox(height: 8),
        RgbSliderRow(
          label: 'Blu',
          value: colorChannel(color, RgbColorChannel.blue),
          color: Colors.blue,
          enabled: enabled,
          onChanged: (value) =>
              onChanged(replaceColorChannel(color, blue: value)),
        ),
      ],
    );
  }
}

class RgbSliderRow extends StatelessWidget {
  const RgbSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: SliderTheme(
            data: Theme.of(
              context,
            ).sliderTheme.copyWith(activeTrackColor: color, thumbColor: color),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: enabled ? (next) => onChanged(next.round()) : null,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}
