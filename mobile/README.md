# Mobile App (Flutter)

Questa cartella ospita il client Flutter di Work Hours Platform.

## Stato

Il bootstrap del progetto e pronto. La prima distribuzione prevista e un APK scaricabile da GitHub Releases.

## Comandi utili

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Struttura

```text
lib/
  presentation/
  application/
  domain/
  data/
```

## Prossimi step

- collegare i dati reali del backend
- sostituire i dati in-memory con repository applicativi
- configurare workflow release APK su GitHub

## Release APK

- workflow manuale: `Mobile Release`
- trigger automatico: push di un tag tipo `mobile-v0.1.0`
- package id Android: `com.carlobonvicini.workhours`
