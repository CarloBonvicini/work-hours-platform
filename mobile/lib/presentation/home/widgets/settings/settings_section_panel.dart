// Pannello di sezione delle impostazioni e valori compatti.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsSectionPanel extends StatelessWidget {
  const SettingsSectionPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.toggleButtonKey,
    required this.onToggleExpanded,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isExpanded;
  final Key toggleButtonKey;
  final ValueChanged<bool> onToggleExpanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggleButtonSize = isExpanded ? 36.0 : 30.0;
    final toggleIconSize = isExpanded ? 20.0 : 18.0;
    final expandedIcon = isExpanded
        ? Icons.keyboard_arrow_up_rounded
        : Icons.keyboard_arrow_down_rounded;
    final toggleButton = IconButton(
      key: toggleButtonKey,
      onPressed: () => onToggleExpanded(!isExpanded),
      tooltip: isExpanded ? 'Riduci $title' : 'Espandi $title',
      visualDensity: VisualDensity.compact,
      iconSize: toggleIconSize,
      splashRadius: isExpanded ? 18 : 16,
      constraints: BoxConstraints.tightFor(
        width: toggleButtonSize,
        height: toggleButtonSize,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(expandedIcon),
    );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isExpanded) ...[
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onToggleExpanded(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ),
        toggleButton,
      ],
    );

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, isExpanded ? 18 : 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isExpanded)
              header
            else
              SizedBox(
                height: 30,
                child: Align(alignment: Alignment.centerLeft, child: header),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const SizedBox(height: 16), child],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class CenteredSettingsValuesWrap extends StatelessWidget {
  const CenteredSettingsValuesWrap({
    super.key,
    required this.constraints,
    required this.values,
  });

  final BoxConstraints constraints;
  final List<Widget> values;

  @override
  Widget build(BuildContext context) {
    final itemWidth = math.max(
      190.0,
      math.min(260.0, constraints.maxWidth - 8),
    );
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      children: [
        for (final value in values) SizedBox(width: itemWidth, child: value),
      ],
    );
  }
}

enum SettingsValueKind { schedule, duration, limit }

class SlimSettingsScheduleValue extends StatelessWidget {
  const SlimSettingsScheduleValue({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.kind,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final SettingsValueKind kind;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = switch (kind) {
      SettingsValueKind.schedule => theme.colorScheme.primary,
      SettingsValueKind.duration => theme.colorScheme.secondary,
      SettingsValueKind.limit => theme.colorScheme.tertiary,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onTap(),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentColor.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Flexible(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: '$label ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 14,
                color: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
