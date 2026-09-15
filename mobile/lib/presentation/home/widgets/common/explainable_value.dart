// Tieni premuto un numero e l'app ti dice cos'e' e dove si cambia.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:work_hours_mobile/presentation/home/logic/value_explanations.dart';
import 'package:work_hours_mobile/presentation/home/models/home_section.dart';

/// Apre la spiegazione di un valore.
///
/// Risponde alla domanda che la schermata non sapeva rispondere ("questo numero
/// da dove esce?") e porta dritto al posto dove si cambia, invece di lasciare
/// che lo si cerchi fra le impostazioni.
Future<void> showValueExplanation(
  BuildContext context,
  ExplainableValue value, {
  required void Function(HomeSection section) onOpenSettings,
}) async {
  final explanation = explanationFor(value);
  final theme = Theme.of(context);
  final section = explanation.settingsSection;

  final goToSettings = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              explanation.title,
              key: const ValueKey('value-explanation-title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(explanation.meaning, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 14),
            Text(
              'Da dove esce',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(explanation.source, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('Chiudi'),
                  ),
                ),
                if (section != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('value-explanation-settings-button'),
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text('Vai a ${explanation.settingsHint}'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (goToSettings == true && section != null) {
    onOpenSettings(section);
  }
}

/// Rende un numero interrogabile con una pressione prolungata.
///
/// Non doppio tap: la pressione prolungata e' il gesto che su Android vuol dire
/// gia' "dimmi di piu' su questo", e qui il tap singolo e' occupato dalla
/// modifica del valore. Il puntino accanto all'etichetta serve a far sapere che
/// il gesto esiste, perche' un gesto invisibile non lo usa nessuno.
class ExplainableValueBox extends StatelessWidget {
  const ExplainableValueBox({
    super.key,
    required this.value,
    required this.onOpenSettings,
    required this.child,
  });

  final ExplainableValue value;
  final void Function(HomeSection section) onOpenSettings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        unawaitedFeedback();
        showValueExplanation(context, value, onOpenSettings: onOpenSettings);
      },
      child: child,
    );
  }

  void unawaitedFeedback() {
    HapticFeedback.selectionClick();
  }
}

/// Etichetta con il puntino che dice "tieni premuto per saperne di piu'".
class ExplainableLabel extends StatelessWidget {
  const ExplainableLabel({super.key, required this.label, this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.help_outline_rounded,
          size: 12,
          color: style?.color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
