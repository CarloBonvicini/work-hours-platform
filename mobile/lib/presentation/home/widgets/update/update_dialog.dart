// Dialogo di aggiornamento disponibile.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/domain/models/app_update.dart';

enum UpdateDialogAction { updateNow, remindLater }

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aggiornamento disponibile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hai la versione ${update.currentVersion}. E disponibile la ${update.latestVersion}.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Vuoi scaricare subito la nuova APK dentro l app oppure preferisci un promemoria piu tardi?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(UpdateDialogAction.remindLater);
          },
          child: const Text('Ricordamelo piu tardi'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(UpdateDialogAction.updateNow);
          },
          icon: const Icon(Icons.system_update_alt),
          label: const Text('Aggiorna subito'),
        ),
      ],
    );
  }
}
