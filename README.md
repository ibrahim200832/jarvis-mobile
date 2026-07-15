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
| Akkustand | „akkustand" fragt den aktuellen Akku-Prozentwert ab (`battery_plus`) |
| — | Freies KI-Gespräch für alles, was kein fester Befehl ist (siehe unten) |
| — | Anruf-Modus: durchgehendes Sprachgespräch statt Einzelbefehle (siehe unten) |
| — | Die KI kann im Gespräch selbst Anrufe/WhatsApp/Apps auslösen (Tool-Use, siehe unten) |

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
- „akkustand" / „wie ist der akku"
- „hilfe" — zeigt die vollständige Befehlsliste
- alles andere — wird an eine echte KI weitergegeben (siehe „Freies KI-Gespräch einrichten")

Kontakte werden unter **Einstellungen → Kontakte** angelegt, damit „rufe X an" und „whatsapp an X" funktionieren.

## Anruf-Modus

Statt jede Nachricht einzeln per Mikrofon-Knopf aufzunehmen, startet das Telefonhörer-Symbol neben dem Mikrofon ein durchgehendes Gespräch: JARVIS hört zu, antwortet per Sprache, und hört danach automatisch wieder zu — wie ein Telefonat. Auf „Auflegen" tippen beendet das Gespräch wieder.

## Automatische Update-Benachrichtigung (Android)

Da die App nicht über den Play Store läuft, prüft sie beim Start selbst, ob eine neuere Version auf der Website liegt (`downloads/version.json`, wird bei jedem `Deploy Web`-Lauf automatisch mit hochgezählt). Ist eine neuere Version verfügbar, erscheint ein Dialog mit „Jetzt herunterladen“ — das lädt die neue APK über den Browser, danach einmal antippen zum Installieren (wie beim ersten Sideload). Web und iOS zeigen den Dialog nicht, da dort Updates automatisch beim Neuladen der Seite bzw. über TestFlight/App Store passieren würden.

## API-Schlüssel

- News: https://newsapi.org (kostenloser Free-Plan)
- Wetter: https://openweathermap.org/api (kostenloser Free-Plan)

## Freies KI-Gespräch einrichten

Alles, was JARVIS nicht als festen Befehl erkennt (z. B. „wikipedia …“, „wetter …“), wird an eine echte KI weitergegeben, statt einfach „nicht verstanden“ zu antworten. Die KI kann dabei auch direkt handeln: bittet man sie im Gespräch klar darum, jemanden anzurufen, eine WhatsApp-Nachricht zu senden oder eine App zu öffnen, löst sie das selbst aus (Function-Calling), statt es nur zu beschreiben.

Der API-Schlüssel darf dafür **nicht** in der App selbst liegen (sonst könnte ihn jeder aus der APK/Website extrahieren) — deshalb läuft ein kleiner, kostenloser Proxy-Server dazwischen (`worker/ai-proxy.js`, für [Cloudflare Workers](https://workers.cloudflare.com)).

Als KI kommt **Google Gemini** zum Einsatz, weil der kostenlose Plan ganz ohne Kreditkarte funktioniert (anders als bei den meisten anderen KI-Anbietern).

**Einmalige Einrichtung (kein Terminal nötig, alles über den Browser):**

1. **Gemini-API-Schlüssel besorgen**: [aistudio.google.com/apikey](https://aistudio.google.com/apikey) → mit einem Google-Konto anmelden → **Create API key**. Kostenlos, es wird keine Kreditkarte verlangt.
2. **Cloudflare-Account erstellen**: [dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up) (kostenlos, keine Kreditkarte nötig).
3. Im Cloudflare-Dashboard: **Workers & Pages → Create → Create Worker** → einen Namen vergeben (z. B. `jarvis-ai`) → **Deploy**.
4. Auf **Edit code** klicken, den kompletten Inhalt der Datei [`worker/ai-proxy.js`](worker/ai-proxy.js) aus diesem Repo hineinkopieren (vorhandenen Beispielcode überschreiben) → **Deploy**.
5. Zurück auf der Worker-Übersichtsseite: **Settings → Variables and Secrets → Add** → Name `GEMINI_API_KEY`, Typ **Secret**, Wert = der Schlüssel aus Schritt 1 → **Save**.
6. Die Worker-URL steht oben auf der Seite (z. B. `https://jarvis-ai.<dein-name>.workers.dev`) — die in der JARVIS-App unter **Einstellungen → „KI-Server-Adresse"** eintragen und speichern.

Wird `worker/ai-proxy.js` später im Repo geändert (z. B. um neue Tools), muss der aktualisierte Code auch im bestehenden Worker per **Edit code** eingefügt und neu deployt werden — das passiert nicht automatisch.

Danach beantwortet JARVIS beliebige Fragen mit einer echten KI (Gemini), zusätzlich zu den festen Befehlen.

## Projekt bauen

```bash
flutter pub get
flutter run                       # lokal starten (Android/iOS/Web)
flutter build apk --release       # Android-APK
flutter build web --release       # Browser-Version
flutter build ipa --release       # iOS (nur auf macOS, braucht Signing s.u.)
```

Drei GitHub Actions laufen automatisch bei jedem Push auf `main`:

- `.github/workflows/build-apk.yml` baut eine Android-Release-APK (Download über Reiter „Actions“ → Lauf auswählen → „Artifacts“).
- `.github/workflows/deploy-web.yml` baut die Web-Version **und** die Android-APK, veröffentlicht beides über GitHub Pages (inkl. `downloads/version.json` für die Update-Prüfung).
- `.github/workflows/build-ios.yml` baut eine signierte Ad-Hoc-`.ipa` für iOS (braucht einmalige Einrichtung, siehe unten).

**Damit GitHub Pages funktioniert**, muss einmalig in den Repo-Einstellungen aktiviert werden: **Settings → Pages → Build and deployment → Source: „GitHub Actions“** (die Action versucht das automatisch zu setzen, ein manueller Check schadet aber nicht).

## iPhone-Installation ohne Zertifikat (empfohlen)

Der einfachste Weg für iPhone-Nutzer: Auf der Website den Apple-Button antippen — er zeigt eine Anleitung, JARVIS über Safari (Teilen → „Zum Home-Bildschirm") als Web-App zu installieren. Das funktioniert sofort, ganz ohne Apple-Entwicklerkonto, Zertifikat oder Warten auf einen Build.

## iOS Ad-Hoc-Signing einrichten (optional, native App)

Wer stattdessen eine echte native iOS-App (`.ipa`) bauen will, braucht einmalig vier Geheimnisse als **GitHub Actions Secrets** (Repo → Settings → Secrets and variables → Actions → New repository secret). Diese Zertifikate/Schlüssel niemals im Chat oder Code teilen, nur direkt auf GitHub eintragen:

1. **App ID registrieren** (falls noch nicht geschehen): [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers) → „+“ → App IDs → Bundle ID exakt `com.jarvis.mobile.jarvisMobile` eintragen.
2. **Geräte registrieren**: Devices → „+“ → UDID jedes iPhones eintragen, auf dem die App laufen soll (Ad Hoc erlaubt max. 100 Geräte/Jahr). UDID findet man z. B. über Xcode → Window → Devices and Simulators, wenn das iPhone angeschlossen ist.
3. **Distribution-Zertifikat erstellen**: In Xcode (Settings → Accounts → Manage Certificates → „+“ → Apple Distribution) oder über das Developer-Portal. Danach in Keychain Access das Zertifikat **inkl. privatem Schlüssel** als `.p12`-Datei exportieren (mit einem selbstgewählten Passwort).
4. **Ad-Hoc-Provisioning-Profil erstellen**: Profiles → „+“ → „Ad Hoc“ → die App ID, das Zertifikat aus Schritt 3 und die Geräte aus Schritt 2 auswählen → herunterladen (`.mobileprovision`).
5. **Base64-kodieren** (im Terminal):
   ```bash
   base64 -i DistCert.p12 | pbcopy        # → Secret IOS_DIST_CERT_BASE64
   base64 -i AdHocProfile.mobileprovision | pbcopy   # → Secret IOS_PROVISION_PROFILE_BASE64
   ```
6. **Vier Secrets im Repo anlegen**:
   - `IOS_DIST_CERT_BASE64` — Inhalt aus Schritt 5 (Zertifikat)
   - `IOS_DIST_CERT_PASSWORD` — das Passwort aus Schritt 3
   - `IOS_PROVISION_PROFILE_BASE64` — Inhalt aus Schritt 5 (Profil)
   - `IOS_TEAM_ID` — deine 10-stellige Team-ID (developer.apple.com/account → Membership)
7. Push auf `main` (oder „Run workflow“ im Actions-Tab) startet den Build. Die fertige `.ipa` liegt danach als Artifact `jarvis-mobile-ipa` bereit.
8. **Installation aufs iPhone**: Eine `.ipa` lässt sich nicht wie eine APK antippen. Nutze z. B. [AltStore](https://altstore.io), [Sideloadly](https://sideloadly.io) oder Apple Configurator, um sie auf ein registriertes Gerät zu übertragen.

## Berechtigungen

Mikrofon, Kamera, Standort werden zur Laufzeit angefragt. `QUERY_ALL_PACKAGES` erlaubt das Auflisten installierter Apps (nur Android).

## Projektstruktur

```
lib/
  core/command_router.dart   Erkennt Befehle aus Text/Sprache, ruft Services auf oder leitet an die KI weiter
  services/                  Ein Service pro Fähigkeit (inkl. ai_chat_service.dart für das KI-Gespräch)
  screens/                   Home-Chat-Screen, Kamera-Screen, Einstellungen
  widgets/chat_bubble.dart   Chat-Bubble-Widget
worker/ai-proxy.js           Cloudflare-Worker-Proxy für das freie KI-Gespräch (siehe oben)
```
