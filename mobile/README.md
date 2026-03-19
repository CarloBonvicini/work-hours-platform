# Mobile App (Flutter)

Questa cartella ospita il client Flutter di Work Hours Platform.

## Stato

Il bootstrap del progetto e pronto. La distribuzione Android passa da GitHub Releases, ma il canale di update in produzione vive sul backend Linux.
Il client controlla automaticamente all avvio se esiste una release piu recente e, su Android, scarica l APK e apre l installer direttamente dall app.

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
- con repository GitHub privato il percorso consigliato e usare il backend Linux come feed update pubblica
- la produzione punta a `.../mobile-updates/latest.json` e `.../mobile-updates/releases/latest`

### Sistema update produzione

Il percorso previsto in produzione e questo:

1. `Mobile Release` builda l APK e lo pubblica su GitHub Releases
2. lo stesso workflow copia l APK nel workspace del server Linux (`infra/updates/downloads/`)
3. il backend espone:
   - `/mobile-updates/latest.json`
   - `/mobile-updates/releases/latest`
   - `/mobile-updates/downloads/<apk>`
4. il client legge quella feed e avvia il download/installazione Android

Per attivarlo servono:

- secret repository `MOBILE_API_BASE_URL`
- secret repository `MOBILE_UPDATE_BASE_URL`
- backend env `MOBILE_UPDATES_PUBLIC_BASE_URL`

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
- per le release GitHub l APK deve ricevere `API_BASE_URL` reale:
  - secret repository `MOBILE_API_BASE_URL`, oppure
  - input `api_base_url` nel workflow manuale
- se `API_BASE_URL` manca, il workflow ora fallisce invece di pubblicare un APK che punta a `10.0.2.2`
- per il canale update produzione, configura:
  - secret `MOBILE_UPDATE_BASE_URL`
  - opzionalmente `MOBILE_UPDATE_FEED_URL` e `MOBILE_UPDATE_PAGE_URL` solo per override non standard

### Esempio feed update pubblica

Il client accetta anche una feed JSON pubblica con questo schema:

```json
{
  "tag_name": "mobile-v0.1.4",
  "html_url": "https://auth.autocaptionservices.work/work-hours/releases/mobile-v0.1.4",
  "assets": [
    {
      "browser_download_url": "https://auth.autocaptionservices.work/work-hours/downloads/app-release-0.1.4.apk"
    }
  ]
}
```
