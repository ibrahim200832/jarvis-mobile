# J.A.R.V.I.S. Mobile

Eine Flutter-Neuentwicklung des [J.A.R.V.I.S. Sprachassistenten](https://github.com/BolisettySujith/J.A.R.V.I.S) für **Android und iOS**.

Das Original war ein reines Windows-Desktop-Programm (PyQt5, `win32api`, `msvcrt`, PC-Shutdown/-Steuerung usw.). Diese Funktionen gibt es auf einem Handy nicht — deshalb ist das hier keine 1:1-Portierung, sondern eine komplette Neuentwicklung mit vergleichbaren Funktionen, die auf einem Smartphone tatsächlich Sinn ergeben.

## Funktionen

| Original (Desktop) | Mobile-Umsetzung |
|---|---|
| Sprachein-/-ausgabe | `speech_to_text` + `flutter_tts` (Deutsch) |
| Wikipedia-Suche | Wikipedia-REST-API |
| Programmierer-Witze | Lokale Witz-Datenbank |
| Nachrichten | NewsAPI.org (eigener API-Key nötig) |
| Wetter | OpenWeatherMap (eigener API-Key nötig) |
| Standort über Handynummer (Schätzung) | Echte GPS-Position (`geolocator` + `geocoding`) |
| PC-Apps öffnen/schließen | Installierte Android-Apps öffnen (`installed_apps`, nur Android – iOS erlaubt das aus Sicherheitsgründen nicht) |
| Webcam-Zugriff | Echte Handykamera (`camera`) |
| WhatsApp-Nachrichten senden | Öffnet WhatsApp mit vorausgefüllter Nachricht |
| Gmail senden | Öffnet die Mail-App mit vorausgefülltem Entwurf |
| Telefon-Adressbuch (`Contacts.txt`) | Eingebautes Mini-Adressbuch in den Einstellungen |
| Anrufe | Öffnet die Wählscheibe |
| YouTube abspielen | Öffnet YouTube-Suchergebnisse |
| QR-Code erzeugen | `qr_flutter`, direkt in der App |

## Sprachbefehle (Beispiele)

- „wie spät ist es" / „welcher Tag ist heute"
- „erzähl mir einen Witz"
- „wikipedia Albert Einstein" / „was ist Photosynthese"
- „nachrichten"
- „wetter" oder „wetter in Berlin"
- „standort"
- „öffne Spotify"
- „kamera"
- „rufe Mama an"
- „whatsapp an Mama: Bin gleich da"
- „email an chef@firma.de: Bin heute im Homeoffice"
- „youtube lofi hip hop"
- „qr code https://example.com"
- „hilfe" — zeigt die vollständige Befehlsliste

Kontakte werden unter **Einstellungen → Kontakte** angelegt, damit „rufe X an" und „whatsapp an X" funktionieren.

## API-Schlüssel

- News: https://newsapi.org (kostenloser Free-Plan)
- Wetter: https://openweathermap.org/api (kostenloser Free-Plan)

## Projekt bauen

```bash
flutter pub get
flutter run
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

Ein Push auf `main` löst automatisch die GitHub Action `.github/workflows/build-apk.yml` aus, die eine Release-APK baut und als Artifact bereitstellt (Reiter „Actions“ im Repo).

## Berechtigungen

Mikrofon, Kamera, Standort werden zur Laufzeit angefragt. `QUERY_ALL_PACKAGES` erlaubt das Auflisten installierter Apps.

## Projektstruktur

```
lib/
  core/command_router.dart   Erkennt Befehle aus Text/Sprache und ruft die passenden Services
  services/                  Ein Service pro Fähigkeit
  screens/                   Home-Chat-Screen, Kamera-Screen, Einstellungen
  widgets/chat_bubble.dart   Chat-Bubble-Widget
```
