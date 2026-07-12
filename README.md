# J.A.R.V.I.S. Mobile

Eine Flutter-Neuentwicklung des [J.A.R.V.I.S. Sprachassistenten](https://github.com/BolisettySujith/J.A.R.V.I.S) für **Android, iOS und den Browser**.

Das Original war ein reines Windows-Desktop-Programm (PyQt5, `win32api`, `msvcrt`, PC-Shutdown/-Steuerung usw.). Diese Funktionen gibt es auf einem Handy nicht — deshalb ist das hier keine 1:1-Portierung, sondern eine komplette Neuentwicklung mit vergleichbaren Funktionen, die auf einem Smartphone bzw. im Browser tatsächlich Sinn ergeben.

## 🌐 Live-Demo (Web)

Jeder Push auf `main` baut die App automatisch als Website und veröffentlicht sie über GitHub Pages:

**https://ibrahim200832.github.io/jarvis-mobile/**

(Erster Aufruf kann etwas dauern, bis GitHub Pages im Repo aktiviert ist — siehe unten.)

## Funktionen

| Original (Desktop) | Mobile/Web-Umsetzung |
|---|---|
| Sprachein-/-ausgabe | `speech_to_text` + `flutter_tts` (Deutsch) |
| Wikipedia-Suche | Wikipedia-REST-API |
| Programmierer-Witze | Lokale Witz-Datenbank |
| Nachrichten | NewsAPI.org (eigener API-Key nötig) |
| Wetter | OpenWeatherMap (eigener API-Key nötig) |
| Standort über Handynummer (Schätzung) | Echte GPS-Position (`geolocator` + `geocoding`) |
| PC-Apps öffnen/schließen | Installierte Android-Apps öffnen (`installed_apps`, nur Android – iOS/Web erlauben das aus Sicherheitsgründen nicht) |
| Webcam-Zugriff | Echte Kamera (`camera`, auch im Browser) |
| WhatsApp-Nachrichten senden | Öffnet WhatsApp mit vorausgefüllter Nachricht |
| Gmail senden | Öffnet die Mail-App mit vorausgefülltem Entwurf |
| Telefon-Adressbuch (`Contacts.txt`) | Eingebautes Mini-Adressbuch in den Einstellungen |
| Anrufe | Öffnet die Wählscheibe |
| YouTube abspielen | Öffnet YouTube-Suchergebnisse |
| QR-Code erzeugen | `qr_flutter`, direkt in der App |
| IP-Adresse anzeigen | Öffentliche IP via ipify.org |

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
- „meine ip"
- „hilfe" — zeigt die vollständige Befehlsliste

Kontakte werden unter **Einstellungen → Kontakte** angelegt, damit „rufe X an" und „whatsapp an X" funktionieren.

## API-Schlüssel

- News: https://newsapi.org (kostenloser Free-Plan)
- Wetter: https://openweathermap.org/api (kostenloser Free-Plan)

## Projekt bauen

```bash
flutter pub get
flutter run                       # lokal starten (Android/iOS/Web)
flutter build apk --release       # Android-APK
flutter build web --release       # Browser-Version
```

Zwei GitHub Actions laufen automatisch bei jedem Push auf `main`:

- `.github/workflows/build-apk.yml` baut eine Release-APK (Download über Reiter „Actions“ → Lauf auswählen → „Artifacts“).
- `.github/workflows/deploy-web.yml` baut die Web-Version und veröffentlicht sie über GitHub Pages.

**Damit GitHub Pages funktioniert**, muss einmalig in den Repo-Einstellungen aktiviert werden: **Settings → Pages → Build and deployment → Source: „GitHub Actions“** (die Action versucht das automatisch zu setzen, ein manueller Check schadet aber nicht).

## Berechtigungen

Mikrofon, Kamera, Standort werden zur Laufzeit angefragt. `QUERY_ALL_PACKAGES` erlaubt das Auflisten installierter Apps (nur Android).

## Projektstruktur

```
lib/
  core/command_router.dart   Erkennt Befehle aus Text/Sprache und ruft die passenden Services
  services/                  Ein Service pro Fähigkeit
  screens/                   Home-Chat-Screen, Kamera-Screen, Einstellungen
  widgets/chat_bubble.dart   Chat-Bubble-Widget
```
