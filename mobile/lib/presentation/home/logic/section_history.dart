// Dove sei stato, per sapere dove torna il tasto indietro.

import 'package:work_hours_mobile/presentation/home/models/home_section.dart';

/// Le sezioni visitate, in ordine, per far funzionare il "torna indietro".
///
/// L'app vive in una schermata sola e cambia sezione: senza questa memoria il
/// tasto indietro di Android non ha niente da cui tornare e chiude l'app anche
/// quando sei dentro le impostazioni.
class SectionHistory {
  SectionHistory({this.maxEntries = 20});

  /// Oltre questo si dimentica il passato remoto: serve a tornare indietro di
  /// qualche passo, non a tenere la cronologia di una giornata intera.
  final int maxEntries;

  final List<HomeSection> _entries = [];

  bool get canGoBack => _entries.isNotEmpty;

  /// Sezioni ricordate, dalla piu' vecchia alla piu' recente.
  List<HomeSection> get entries => List.unmodifiable(_entries);

  /// Registra la sezione che stai lasciando.
  ///
  /// Tornare sulla stessa sezione non aggiunge un passo: premere due volte lo
  /// stesso pulsante non deve costare due "indietro".
  void record(HomeSection leavingSection, HomeSection nextSection) {
    if (leavingSection == nextSection) {
      return;
    }

    _entries.add(leavingSection);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  /// La sezione a cui tornare, o `null` se non c'e' piu' niente dietro.
  HomeSection? back() {
    if (_entries.isEmpty) {
      return null;
    }

    return _entries.removeLast();
  }

  void clear() {
    _entries.clear();
  }
}
