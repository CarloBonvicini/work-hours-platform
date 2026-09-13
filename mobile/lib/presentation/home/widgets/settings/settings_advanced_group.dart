// Gruppo di impostazioni che si aprono solo quando servono davvero.

import 'package:flutter/material.dart';

/// Raccoglie sotto un'unica riga le sezioni che la maggior parte di chi usa
/// l'app non tocca mai.
///
/// Resta chiuso a ogni apertura di proposito: e' un cassetto, non una sezione
/// di lavoro. Le sezioni dentro conservano il loro stato come sempre.
class SettingsAdvancedGroup extends StatefulWidget {
  const SettingsAdvancedGroup({
    super.key,
    required this.title,
    required this.subtitle,
    required this.toggleButtonKey,
    required this.children,
  });

  final String title;
  final String subtitle;
  final Key toggleButtonKey;
  final List<Widget> children;

  @override
  State<SettingsAdvancedGroup> createState() => _SettingsAdvancedGroupState();
}

class _SettingsAdvancedGroupState extends State<SettingsAdvancedGroup> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: widget.toggleButtonKey,
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          for (final child in widget.children) ...[
            const SizedBox(height: 16),
            child,
          ],
      ],
    );
  }
}
