// Il tasto indietro di sistema, collegato alla navigazione interna dell'app.

import 'package:flutter/material.dart';

/// Fa tornare indietro dentro l'app invece di chiuderla.
///
/// L'app vive in una schermata sola e cambia sezione: senza questo il tasto
/// indietro di Android esce anche quando sei entrato nelle impostazioni.
class BackNavigationScope extends StatelessWidget {
  const BackNavigationScope({
    super.key,
    required this.canGoBack,
    required this.onBack,
    required this.child,
  });

  final bool canGoBack;

  /// Torna indietro; vero se se n'e' occupata l'app.
  final bool Function() onBack;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onBack();
        }
      },
      child: child,
    );
  }
}
