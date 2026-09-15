// Cambio sezione e tasto indietro.

part of '../home_screen.dart';

mixin _SectionNavigationState on _HomeScreenStateBase {
  /// Porta a una sezione ricordando da dove vieni.
  ///
  /// Unico punto che cambia sezione: prima erano otto assegnazioni sparse, e
  /// nessuna lasciava traccia, per questo il tasto indietro non aveva niente a
  /// cui tornare.
  @override
  void _goToSection(HomeSection section) {
    if (_selectedSection == section) {
      return;
    }

    _sectionHistory.record(_selectedSection, section);
    _selectedSection = section;
  }

  /// Gestisce il "torna indietro": vero se l'app se n'e' occupata.
  bool _handleBackRequest() {
    final previousSection = _sectionHistory.back();
    if (previousSection == null) {
      return false;
    }

    setState(() {
      _selectedSection = previousSection;
    });
    return true;
  }

  /// Cambio sezione dal menu in alto, con quel che ogni sezione deve caricare.
  ///
  /// Sta qui e non nel `build`: la regia disegna, non decide cosa ricaricare.
  void _selectSectionFromHeader(HomeSection section) {
    setState(() {
      _goToSection(section);
      if (section == HomeSection.calendar &&
          _calendarView == CalendarView.day) {
        _calendarView = CalendarView.month;
      }
    });

    if (section == HomeSection.ticket) {
      unawaited(_refreshTrackedSupportTickets());
      final selectedTicketId = _selectedTrackedTicketId;
      if (selectedTicketId != null) {
        unawaited(_markTrackedTicketRepliesSeen(selectedTicketId));
      }
    }
    if (section == HomeSection.consuntivo) {
      unawaited(_ensureConsuntivoDataLoaded());
    }
  }
}
