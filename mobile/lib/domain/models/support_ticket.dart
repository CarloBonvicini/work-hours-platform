enum SupportTicketCategory { bug, feature, support }

extension SupportTicketCategoryX on SupportTicketCategory {
  String get apiValue {
    switch (this) {
      case SupportTicketCategory.bug:
        return 'bug';
      case SupportTicketCategory.feature:
        return 'feature';
      case SupportTicketCategory.support:
        return 'support';
    }
  }

  String get label {
    switch (this) {
      case SupportTicketCategory.bug:
        return 'Bug';
      case SupportTicketCategory.feature:
        return 'Nuova funzione';
      case SupportTicketCategory.support:
        return 'Supporto';
    }
  }

  String get description {
    switch (this) {
      case SupportTicketCategory.bug:
        return 'Segnala un problema trovato nell app.';
      case SupportTicketCategory.feature:
        return 'Proponi un miglioramento o una nuova idea.';
      case SupportTicketCategory.support:
        return 'Scrivi per dubbi, blocchi o chiarimenti.';
    }
  }
}
