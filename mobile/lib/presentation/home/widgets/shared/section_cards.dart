// Contenitori e riquadri riusabili della home: sezione, errore, metrica, info inline.

import 'dart:async';
import 'package:flutter/material.dart';

class InlineInfoPanel extends StatelessWidget {
  const InlineInfoPanel({
    super.key,
    required this.title,
    required this.description,
    required this.statusText,
  });

  final String title;
  final String description;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162121) : const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A201B) : const Color(0xFFFFF1EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF704033) : const Color(0xFFE6B8A5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operazione non riuscita',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasTitle = title.trim().isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final hasHeader = hasTitle || hasSubtitle || trailing != null;

    final header = switch ((hasTitle || hasSubtitle, trailing != null)) {
      (true, true) => Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTitle)
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (hasSubtitle) ...[
                  if (hasTitle) const SizedBox(height: 6),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          trailing!,
        ],
      ),
      (true, false) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle)
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          if (hasSubtitle) ...[
            if (hasTitle) const SizedBox(height: 6),
            Text(subtitle!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
      (false, true) => trailing!,
      _ => null,
    };

    return Material(
      color: isDark ? const Color(0xFF111919) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? const Color(0xFF324343) : const Color(0xFFE0D8CA),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?header,
            if (hasHeader) SizedBox(height: hasTitle || hasSubtitle ? 18 : 14),
            child,
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor = const Color(0xFF123131),
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162121) : const Color(0xFFF7F3EC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
