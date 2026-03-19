# Mobile App (Flutter)

Questa cartella ospita il client Flutter di Work Hours Platform.

## Stato

Il bootstrap del progetto e pronto. La prima distribuzione prevista e un APK scaricabile da GitHub Releases.
Il client controlla automaticamente all avvio se esiste una release piu recente e puo aprire il download dell APK.

## Comandi utili

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build apk --release --dart-define=APP_VERSION=0.1.2
```

## Avvio con backend reale

1. Avvia il backend su `http://localhost:8080`
2. Avvia il client Flutter

Per forzare la base URL API:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Per Android emulator usa in genere:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## Aggiornamenti app

- Il client confronta la versione locale (`APP_VERSION`) con una feed release remota.
- Se trova una release piu recente, mostra un banner e apre il download APK o la pagina release.
- Non e un aggiornamento silenzioso: su Android l utente deve comunque confermare l installazione.

### Configurazione feed update

```bash
flutter run ^
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 ^
  --dart-define=APP_VERSION=0.1.2 ^
  --dart-define=UPDATE_FEED_URL=https://api.github.com/repos/CarloBonvicini/work-hours-platform/releases/latest ^
  --dart-define=UPDATE_PAGE_URL=https://github.com/CarloBonvicini/work-hours-platform/releases/latest
```

Nota:
- se la feed release non e pubblica, il controllo automatico non vedra aggiornamenti
- con repository GitHub privato serve una feed pubblica alternativa oppure un endpoint backend/proxy

### Firma APK per update in-place

Per permettere l installazione sopra la versione precedente serve una firma release stabile.
Il workflow `Mobile Release` usa questi secret se presenti:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

Se i secret non sono configurati, la build release ricade sulla debug key e gli update in-place possono fallire.

## Struttura

```text
lib/
  presentation/
  application/
  domain/
  data/
```

## Prossimi step

- configurare keystore release stabile per update affidabili
- estendere il client ai flussi ferie e permessi

## Release APK

- workflow manuale: `Mobile Release`
- trigger automatico: push di un tag tipo `mobile-v0.1.0`
- package id Android: `com.carlobonvicini.workhours`
