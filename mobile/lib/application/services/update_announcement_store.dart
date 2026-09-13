// Memoria di quali versioni sono gia' state annunciate a chi usa l'app.

import 'package:shared_preferences/shared_preferences.dart';

/// Riporta tag e versioni alla stessa forma (`mobile-v0.1.7` e `v0.1.7` -> `0.1.7`).
///
/// Il feed degli update espone il tag, la push espone la versione: senza questa
/// normalizzazione le due strade non si riconoscono e l'annuncio si ripete.
String normalizeReleaseVersion(String rawVersion) {
  return rawVersion
      .trim()
      .replaceFirst(RegExp(r'^mobile-v'), '')
      .replaceFirst(RegExp(r'^v'), '');
}

/// Ricorda l'ultima versione annunciata, cosi' l'avviso di rilascio arriva una volta sola.
///
/// Vale fra un avvio e l'altro e fra isolate diversi: la push ricevuta ad app
/// chiusa segna qui la versione, e all'apertura successiva nessuno la riannuncia.
class UpdateAnnouncementStore {
  const UpdateAnnouncementStore();

  static const _lastAnnouncedVersionKey =
      'local_notifications.last_notified_update_version';

  Future<bool> hasAnnounced(String version) async {
    final normalizedVersion = normalizeReleaseVersion(version);
    if (normalizedVersion.isEmpty) {
      return false;
    }

    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_lastAnnouncedVersionKey) == normalizedVersion;
  }

  Future<void> markAnnounced(String version) async {
    final normalizedVersion = normalizeReleaseVersion(version);
    if (normalizedVersion.isEmpty) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastAnnouncedVersionKey,
      normalizedVersion,
    );
  }
}
