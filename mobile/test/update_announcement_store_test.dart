import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_mobile/application/services/remote_push_registration_service.dart';
import 'package:work_hours_mobile/application/services/update_announcement_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = UpdateAnnouncementStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('normalizeReleaseVersion', () {
    test('toglie il prefisso del tag di rilascio', () {
      expect(normalizeReleaseVersion('mobile-v0.1.107'), '0.1.107');
    });

    test('toglie anche la sola v', () {
      expect(normalizeReleaseVersion('v0.1.107'), '0.1.107');
    });

    test('lascia intatta una versione gia pulita', () {
      expect(normalizeReleaseVersion(' 0.1.107 '), '0.1.107');
    });
  });

  group('UpdateAnnouncementStore', () {
    test('una versione mai vista non risulta annunciata', () async {
      expect(await store.hasAnnounced('0.1.107'), isFalse);
    });

    test('dopo l annuncio la stessa versione non si ripete', () async {
      await store.markAnnounced('0.1.107');

      expect(await store.hasAnnounced('0.1.107'), isTrue);
    });

    test('una versione nuova torna ad essere annunciabile', () async {
      await store.markAnnounced('0.1.107');

      expect(await store.hasAnnounced('0.1.108'), isFalse);
    });

    test('il tag del feed e la versione della push sono la stessa cosa', () {
      // Il feed espone `tag_name`, la push espone `version`: se non si
      // riconoscessero, l'avviso arriverebbe due volte per lo stesso rilascio.
      expect(
        normalizeReleaseVersion('mobile-v0.1.107'),
        normalizeReleaseVersion('0.1.107'),
      );
    });

    test('una versione vuota non viene registrata', () async {
      await store.markAnnounced('  ');

      expect(await store.hasAnnounced(''), isFalse);
    });
  });

  group('markUpdatePushAsAnnounced', () {
    test('la push di rilascio segna la versione come gia annunciata', () async {
      await markUpdatePushAsAnnounced(
        const RemoteMessage(
          data: <String, String>{'type': 'app_update', 'version': '0.1.107'},
        ),
      );

      expect(await store.hasAnnounced('0.1.107'), isTrue);
    });

    test('una push di altro tipo non segna nulla', () async {
      await markUpdatePushAsAnnounced(
        const RemoteMessage(
          data: <String, String>{'type': 'ticket_reply', 'version': '0.1.107'},
        ),
      );

      expect(await store.hasAnnounced('0.1.107'), isFalse);
    });

    test('una push senza versione non segna nulla', () async {
      await markUpdatePushAsAnnounced(
        const RemoteMessage(data: <String, String>{'type': 'app_update'}),
      );

      expect(await store.hasAnnounced('0.1.107'), isFalse);
    });
  });
}
