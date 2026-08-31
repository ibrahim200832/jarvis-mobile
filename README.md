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
| Websuche (aktuelle/spezifische Fakten) | Brave Search API, läuft server-seitig über den eigenen Worker (siehe unten) |
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
| — | Taschenrechner: versteht Symbole (`+ - * / ^ ()`) und gesprochene Wörter (plus, minus, mal, durch, hoch) |
| — | Timer/Erinnerungen: "timer für 5 minuten", live im Gerät, mit Sprachansage bei Ablauf |
| — | Notizen: kleine, dauerhaft gespeicherte Notizliste direkt im Chat |
| — | Münzwurf, Würfel (auch mit anderer Seitenzahl), Zufallszahl in einem Bereich |
| — | Freies KI-Gespräch, funktioniert sofort ohne jede Einrichtung (siehe unten) |
| — | Anruf-Modus: Vollbild-Gespräch mit animiertem Orb statt Einzelbefehle (siehe unten) |
| — | Die KI kann im Gespräch selbst Anrufe/WhatsApp/Apps auslösen (optional, siehe unten) |
| — | Video vom Handy auf dein eigenes YouTube-Konto hochladen — Sichtbarkeit (privat/nicht gelistet/öffentlich) wählbar, optional zeitgesteuerte Veröffentlichung (optional, siehe unten) |
| — | Video vom Handy auf dein eigenes TikTok-Konto hochladen — Sichtbarkeit wählbar (optional, siehe unten; Einschränkungen beachten) |

## Sprachbefehle (Beispiele)

- „wie spät ist es" / „welcher Tag ist heute"
- „erzähl mir einen Witz"
- „wikipedia Albert Einstein" / „was ist Photosynthese"
- „suche im internet nach dem aktuellen bitcoin preis" / „recherchiere die neueste flutter version"
- „nachrichten"
- „wetter" oder „wetter in Berlin"
- „standort"
- „öffne Spotify"
- „kamera"
- „rufe Mama an"
- „whatsapp an Mama: Bin gleich da"
- „email an chef@firma.de: Bin heute im Homeoffice"
- „youtube lofi hip hop"
- „video hochladen" (auf dein YouTube-Konto, siehe unten)
- „lade das video öffentlich hoch" (Sichtbarkeit vorauswählen, siehe unten)
- „video auf tiktok hochladen" (auf dein TikTok-Konto, siehe unten)
- „qr code https://example.com"
- „meine ip"
- „akkustand" / „wie ist der akku"
- „rechne 12 mal 7" / „was ist 5 plus 3"
- „timer für 5 minuten" / „erinnere mich in 10 minuten an die wäsche"
- „meine timer" / „timer abbrechen"
- „notiz kaufe milch" / „meine notizen" / „lösche notiz 2"
- „wirf eine münze" / „würfle" / „würfle mit 20 seiten" / „zufallszahl zwischen 1 und 100"
- „hilfe" — zeigt die vollständige Befehlsliste
- alles andere — wird an eine echte KI weitergegeben (siehe „Freies KI-Gespräch")

Kontakte werden unter **Einstellungen → Kontakte** angelegt, damit „rufe X an" und „whatsapp an X" funktionieren.

## Anruf-Modus

Statt jede Nachricht einzeln per Mikrofon-Knopf aufzunehmen, startet das Telefonhörer-Symbol neben dem Mikrofon ein durchgehendes Gespräch im Vollbild: ein pulsierender Orb zeigt, ob JARVIS zuhört, nachdenkt oder spricht — ähnlich dem Sprachmodus bekannter KI-Apps. Zur Verfügung stehen außerdem:

- **Mikrofon-Knopf** (unten) — Mikrofon stummschalten/wieder aktivieren, ohne das Gespräch zu beenden
- **Auflegen-Knopf** (unten, rot) — beendet das Gespräch
- **Reset-Symbol** (oben) — setzt das Gespräch zurück und fängt neu an
- **Kamera-Symbol** (oben) — öffnet die Kamera, während der Anruf im Hintergrund weiterläuft

JARVIS antwortet dabei mit einer eigenen, fröhlichen und warmherzigen Persönlichkeit, angelehnt an Tony Starks JARVIS aus den Iron-Man-Filmen, aber mit guter Laune statt trockenem Sarkasmus — spricht den Nutzer mit „Master" an.

## Automatische Update-Benachrichtigung (Android)

Da die App nicht über den Play Store läuft, prüft sie beim Start selbst, ob eine neuere Version auf der Website liegt (`downloads/version.json`, wird bei jedem `Deploy Web`-Lauf automatisch mit hochgezählt). Ist eine neuere Version verfügbar, erscheint ein Dialog mit „Jetzt herunterladen“ — das lädt die neue APK über den Browser, danach einmal antippen zum Installieren (wie beim ersten Sideload). Web und iOS zeigen den Dialog nicht, da dort Updates automatisch beim Neuladen der Seite bzw. über TestFlight/App Store passieren würden.

## Android-Signierschlüssel einrichten (empfohlen, gegen Sicherheitswarnungen)

Ohne diesen Schritt signiert die Build-Pipeline die Release-APK mit dem öffentlichen Debug-Schlüssel von Flutter — dem gleichen, den jedes Flutter-Projekt weltweit standardmäßig benutzt. Android/Play Protect stuft das automatisch als besonders verdächtig ein, deshalb die harten Warnhinweise beim Installieren.

Mit einem echten, eigenen Signierschlüssel wird die App eindeutig identifizierbar und die Installation deutlich unauffälliger. **Ganz verschwinden** wird der „Unbekannte Quelle"-Hinweis von Android trotzdem nicht — der erscheint bei jeder App, die nicht aus dem Play Store kommt, das ist eine reine Android-Systemfunktion und lässt sich ohne Play-Store-Veröffentlichung nicht abschalten. Aber die zusätzliche „Diese App könnte schädlich sein"-Warnung von Play Protect wird dadurch seltener bzw. verschwindet oft ganz.

**Einmalige Einrichtung** (Repo → Settings → Secrets and variables → Actions → New repository secret):

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`

Beide Werte wurden einmalig generiert und dem Repo-Besitzer direkt mitgeteilt (nicht im Code, damit niemand sonst zukünftige Updates signieren kann). **Gut aufbewahren** — geht der Schlüssel verloren, kann keine spätere Version mehr als Update installiert werden, nur noch als komplette Neuinstallation.

Sobald beide Secrets gesetzt sind, signieren `build-apk.yml` und `deploy-web.yml` automatisch damit; ohne sie fällt der Build automatisch auf den alten Debug-Schlüssel zurück (Projekt bleibt also auch ohne diese Secrets baubar).

## API-Schlüssel

- News: https://newsapi.org (kostenloser Free-Plan)
- Wetter: https://openweathermap.org/api (kostenloser Free-Plan)

### Websuche einrichten (optional, für den eigenen Worker)

Damit JARVIS aktuelle Informationen selbst recherchieren kann ("suche im internet nach ...", "recherchiere ..."),
braucht der **Worker** (nicht die App) einen Brave-Search-Schlüssel:

1. Kostenlosen Schlüssel unter https://brave.com/search/api/ holen
2. Im [Cloudflare-Dashboard](https://dash.cloudflare.com) → **Workers & Pages** → den eigenen Worker öffnen →
   **Settings** → **Variables and Secrets** → **Add**: Name `BRAVE_API_KEY`, Typ **Secret**, Wert der Schlüssel → **Deploy**

Der Schlüssel bleibt danach dauerhaft im Worker gespeichert (übersteht auch künftige Deploys über
`deploy-worker.yml`) und wird nie an die App weitergegeben — genau wie beim KI-Modell selbst bleibt er
server-seitig geheim. Ohne diesen Schlüssel meldet die Websuche einen Fehler statt eines Ergebnisses.

## Freies KI-Gespräch

Alles, was JARVIS nicht als festen Befehl erkennt (z. B. „wikipedia …“, „wetter …“), wird an eine echte KI weitergegeben, statt einfach „nicht verstanden“ zu antworten.

**Standardmäßig braucht das keinerlei Einrichtung** — JARVIS fragt dafür automatisch einen kostenlosen, öffentlichen KI-Dienst (ohne Konto, ohne Schlüssel) direkt aus der App heraus. Das funktioniert sofort nach dem ersten Start. Als kostenloser Dienst ohne Garantie kann er gelegentlich langsamer oder mal kurz nicht erreichbar sein — dafür ist absolut kein Setup nötig.

### Optionales Upgrade: eigener KI-Server

Wer zuverlässigere Antworten möchte, oder will, dass die KI im Gespräch selbst Anrufe/WhatsApp-Nachrichten/Apps auslösen kann (Function-Calling) statt es nur zu beschreiben, kann optional einen eigenen KI-Server einrichten: ein kleiner Proxy-Worker (`worker/ai-proxy.js`, für [Cloudflare Workers](https://workers.cloudflare.com)).

Als KI kommt dabei **Cloudflare Workers AI** zum Einsatz — ein offenes Modell (Metas Llama 3.3 70B), das direkt bei Cloudflare läuft, im selben Account wie der Worker selbst. Kein Google, kein separater KI-Anbieter, kein API-Schlüssel, der irgendwo verwaltet werden müsste. JARVIS merkt sich dabei auch den bisherigen Gesprächsverlauf und kann neben Anrufen/WhatsApp/Apps auch Timer stellen, Notizen speichern, das Wetter abrufen und die Kamera öffnen.

**Einmalige Einrichtung (kein Terminal nötig, alles über den Browser):**

1. **Cloudflare-Account erstellen**: [dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up) (kostenlos, keine Kreditkarte nötig).
2. Im Cloudflare-Dashboard: **Workers & Pages → Create → Create Worker** → einen Namen vergeben (z. B. `jarvis-ai`) → **Deploy**.
3. Auf **Edit code** klicken, den kompletten Inhalt der Datei [`worker/ai-proxy.js`](worker/ai-proxy.js) aus diesem Repo hineinkopieren (vorhandenen Beispielcode überschreiben) → **Deploy**.
4. Im Worker-Dashboard: **Settings → Bindings → Add → AI** → Binding-Name `AI` eintragen → **Deploy** (macht `wrangler.toml` in diesem Repo automatisch, falls per Actions deployt — siehe unten).
5. Die Worker-URL steht oben auf der Seite (z. B. `https://jarvis-ai.<dein-name>.workers.dev`) — die in der JARVIS-App unter **Einstellungen → „KI-Server-Adresse"** eintragen und speichern. Ist das Feld leer, nutzt JARVIS automatisch den kostenlosen Standard-Dienst ohne Setup.

Wird `worker/ai-proxy.js` später im Repo geändert (z. B. um neue Tools), muss der aktualisierte Code auch im bestehenden Worker per **Edit code** eingefügt und neu deployt werden — das passiert nicht automatisch.

**Geteiltes Backend mit dem WhatsApp-Bot:** Derselbe Worker lässt sich auch vom [DARKZONE-MD](https://github.com/ibrahim200832/DARKZONE-MD) WhatsApp-Bot nutzen (`lib/aichat.js` dort, `AI_BACKEND_URL` in dessen `config.env`) — beide Apps antworten dann mit derselben JARVIS-Persönlichkeit über dieselbe KI.

**Auch als Discord-Bot verfügbar:** JARVIS kann auch einem Discord-Sprachkanal beitreten und Antworten vorlesen, wenn man ihn per Slash-Befehl fragt — nutzt denselben Worker als Backend, läuft aber als eigener Node.js-Dienst auf einem eigenen Server. Einrichtung siehe [`discord-bot/README.md`](discord-bot/README.md).

## Sicherheit (eigener KI-Server, optional)

Diese Maßnahmen betreffen ausschließlich die optionale Verbindung zum **eigenen** `worker/ai-proxy.js`
(siehe oben) — der kostenlose Standard-Dienst ohne eigenen Server ist davon nicht betroffen, da er auf
keinem selbst kontrollierten Backend läuft, das sich zusätzlich absichern ließe.

### Request-Signierung (HMAC) & Replay-Schutz

Jede Anfrage an den eigenen Worker kann mit einer HMAC-SHA256-Signatur (plus Zeitstempel und
Einmal-Nonce) versehen werden, damit der Worker Fälschungen und wiederholt gesendete (abgefangene)
Anfragen ablehnt. Einrichtung:

1. Ein zufälliges Geheimnis erzeugen, z. B. `openssl rand -hex 32`.
2. Im [Cloudflare-Dashboard](https://dash.cloudflare.com) → Worker öffnen → **Settings → Variables and
   Secrets → Add**: Name `HMAC_SECRET`, Typ **Secret**, Wert = das erzeugte Geheimnis → **Deploy**.
3. Denselben Wert in der JARVIS-App unter **Einstellungen → „KI-Server-Schlüssel"** eintragen.

Solange `HMAC_SECRET` im Worker **nicht** gesetzt ist, bleibt alles wie bisher (unsignierte Anfragen
werden akzeptiert) — erst mit gesetztem Schlüssel lehnt der Worker unsignierte oder gefälschte Anfragen
mit Fehler 401 ab. Beide Seiten (App-Einstellung und Worker-Secret) müssen exakt übereinstimmen.

### TLS-Zertifikat-Pinning (optional, Handy/Desktop)

Unter **Einstellungen → „TLS-Zertifikat-Pins"** lässt sich per Knopfdruck der aktuelle
Zertifikats-Fingerabdruck des eigenen Worker-Servers anzeigen und übernehmen. Ist mindestens ein Pin
gespeichert, verweigert die App die Verbindung, sobald ein Server ein anderes Zertifikat präsentiert —
Schutz vor Man-in-the-Middle-Angriffen im selben WLAN. **Wichtiger Kompromiss:** Cloudflare rotiert das
TLS-Zertifikat für `*.workers.dev`-Adressen automatisch von Zeit zu Zeit; danach muss hier manuell ein
neuer Fingerabdruck ergänzt werden, sonst funktioniert die Verbindung zum eigenen Server nicht mehr, bis
das passiert. Deshalb am besten zwei Pins gleichzeitig pflegen (aktueller + einer für die nächste
geplante Rotation). Nur auf Handy/Desktop wirksam — im Web-Build hat eine Seite technisch keinen Zugriff
auf das TLS-Zertifikat, das ist eine Browser-Plattformgrenze.

### Herkunfts-Einschränkung (CORS)

Standardmäßig akzeptiert der Worker Anfragen von jeder Web-Seite (`Access-Control-Allow-Origin: *`).
Optional lässt sich das auf die eigene Web-Version einschränken: Cloudflare-Secret `ALLOWED_ORIGIN`
(Typ **Text**, kein Secret nötig) auf die eigene Domain setzen, z. B.
`https://<dein-name>.github.io`. **Wichtig zu wissen:** CORS schützt ausschließlich davor, dass eine
fremde Webseite im Browser eines Besuchers die Antwort lesen kann — es blockiert keinen direkten Aufruf
von außerhalb eines Browsers (z. B. per Skript oder curl). Der eigentliche Schutz gegen gefälschte
Anfragen ist die Request-Signierung oben.

### Lokale Verschlüsselung & keine hartcodierten Geheimnisse

API-Schlüssel, OAuth-Tokens (Spotify/TikTok) und der Request-Signierungs-Schlüssel liegen auf dem Gerät
AES-256-verschlüsselt im Android Keystore / iOS Keychain statt im Klartext — automatisch, ohne
Einrichtung. Im Quellcode dieses Projekts ist bewusst kein einziger echter Schlüssel/Token hinterlegt:
jeder Nutzer trägt seine eigenen in Einstellungen bzw. als Cloudflare-Secret ein, nichts landet dadurch
versehentlich im (öffentlichen) Repository.

### App-Integritäts-Check (Play Integrity, optional, nur Android)

Prüft beim App-Start, ob Gerät und Installation vertrauenswürdig sind (nicht gerootet, App unverändert
und über Google Play erkannt) — schlägt der Check erkennbar fehl, startet JARVIS nicht weiter (siehe
Einstellungen → „App-Integritäts-Check aktivieren"). Braucht deutlich mehr Einrichtung als die übrigen
Punkte hier, da Google Play Integrity ein echtes, mit Play Console verknüpftes Google-Cloud-Projekt
voraussetzt:

1. **App bei Google Play registrieren** (mindestens als interner Test-Track): [Play Console](https://play.google.com/console)
   → App anlegen, Paketname `com.jarvis.mobile.jarvis_mobile`, mindestens einmal ein signiertes Bundle/APK
   hochladen (siehe „Android-Signierschlüssel einrichten" oben — der Play-Integrity-Check funktioniert nur
   für über Play verifizierte Installationen).
2. **Google-Cloud-Projekt mit Play Console verknüpfen**: Play Console → „Setup → API access" → verknüpftes
   Google-Cloud-Projekt anlegen/verknüpfen lassen. Die dort angezeigte **Projektnummer** in der JARVIS-App
   unter **Einstellungen → „Google-Cloud-Projektnummer"** eintragen.
3. **Play Integrity API aktivieren**: Im verknüpften Projekt unter [console.cloud.google.com](https://console.cloud.google.com)
   → „APIs & Services → Library" → „Play Integrity API" suchen → **Enable**.
4. **Service-Konto für den Worker anlegen**: „IAM & Admin → Service Accounts → Create Service Account" →
   Rolle **„Service Account User"** reicht; danach „Keys → Add Key → Create new key" → Typ **JSON** → Datei
   herunterladen (enthält den privaten Schlüssel, sorgfältig aufbewahren).
5. **JSON-Key im Worker hinterlegen**: Im [Cloudflare-Dashboard](https://dash.cloudflare.com) → Worker
   öffnen → **Settings → Variables and Secrets → Add**: Name `GOOGLE_SERVICE_ACCOUNT_JSON`, Typ **Secret**,
   Wert = kompletter Inhalt der heruntergeladenen JSON-Datei → **Deploy**.
6. In den JARVIS-Einstellungen den Schalter **„App-Integritäts-Check aktivieren"** umlegen.

Ohne diese Einrichtung bleibt der Check einfach aus (kein Fehler, keine Sperre) — er ist bewusst
Opt-in, weil er der aufwändigste Punkt in diesem Abschnitt ist. **Aus dieser Entwicklungsumgebung heraus
nicht end-to-end testbar** (kein echtes Android-Gerät, kein echtes Google-Cloud-/Play-Console-Projekt
verfügbar) — die Server-seitige Google-Authentifizierung (JWT-Signierung fürs Service-Konto) wurde
gegen einen unabhängig erzeugten Test-Schlüssel isoliert verifiziert (gültige RS256-Signatur, korrekte
Verdikt-Auswertung bei verschiedenen Antworten), die native Android-Anbindung nur so weit wie ohne
echtes Gerät möglich (Kotlin-Code + Gradle-Abhängigkeit, kompiliert über die reguläre APK-Build-Pipeline).

## Runde 13: Automatisierung, Backups & Offline-KI (optional)

### Crash-Reporting & Log-Viewer

Fehler (Flutter-Abstürze, fehlgeschlagene KI-Anfragen/Timeouts) landen automatisch mit Zeitstempel in
einer lokalen Logdatei (max. 500 Einträge) — einsehbar unter **Einstellungen → „Log-Viewer"**
(aktualisieren/kopieren/leeren). Keine Einrichtung nötig.

### API-Health-Monitor

**Einstellungen → „API-Health-Monitor"** zeigt, ob der eigene KI-Server gerade erreichbar ist und wie
hoch die Round-Trip-Latenz ist. Verbrauchte API-Quotas zeigt die App bewusst **nicht** an — Cloudflare
legt die nur im eigenen Account-Dashboard offen, nicht dem Worker selbst.

### RSS-Feed-Reader

„abonniere feed \<URL\>" akzeptiert sowohl einen direkten RSS/Atom-Feed-Link als auch eine normale
Website-Adresse (der zugehörige Feed-Link wird automatisch erkannt). „meine feeds" listet Abos,
„entferne feed \<URL\>" kündigt eins, „was gibt's neues in meinen feeds" prüft sofort auf neue
Schlagzeilen. Regelmäßige Hintergrundprüfung (alle 3 Stunden, auch bei geschlossener App) mit
Push-Benachrichtigung bei neuen Schlagzeilen: **Einstellungen → „RSS-Hintergrundprüfung"** (Standard
aus).

### Verschlüsselter Backup-Export (rein lokal)

„erstelle jetzt ein backup" sichert Notizen, Journal, XP/Erfolge, Challenges, RPG-Spielstand,
RSS-Abos und Einstellungen als AES-256-verschlüsselte Datei — der Schlüssel wird einmalig erzeugt und
sicher im Android Keystore/iOS Keychain abgelegt, kein Passwort nötig. Bleibt bewusst **rein lokal auf
dem Gerät** (kein Mail-/Bot-Versand). „backup wiederherstellen" stellt den letzten Stand wieder her,
„backup status" zeigt den Zeitpunkt des letzten Backups. Wöchentlicher automatischer Export:
**Einstellungen → „Wöchentlicher Backup-Export"** (Standard aus).

### WebDAV-Cloud-Sync (Ende-zu-Ende-verschlüsselt, optional)

Synchronisiert das verschlüsselte Backup mit einem **eigenen** WebDAV-Server (z. B. Nextcloud) —
„cloud-backup hochladen" / „cloud-backup herunterladen". Die Verschlüsselung passiert vollständig auf
dem Gerät, *bevor* etwas gesendet wird: der WebDAV-Server sieht ausschließlich Chiffretext, nie die
Klardaten. Einrichtung unter **Einstellungen → „WebDAV-Cloud-Sync"**: Server-URL, Benutzername,
Passwort eintragen, mit „Verbindung testen" prüfen.

### Offline-KI (lokales Sprachmodell, optional)

Lässt JARVIS grundlegende Fragen, Notizen und Berechnungen auch **ganz ohne Internetverbindung**
beantworten — ein Sprachmodell läuft direkt auf dem Gerät (Googles MediaPipe/LiteRT-LM-Laufzeit über
[flutter_gemma](https://pub.dev/packages/flutter_gemma)). Sobald ein Modell installiert ist, springt
JARVIS automatisch ein, wenn die Cloud-KI (eigener Server oder der kostenlose Fallback) gerade nicht
erreichbar ist — „offline-ki status" zeigt den aktuellen Stand.

Einrichtung unter **Einstellungen → „Offline-KI"**:

1. Ein Gemma-Modell im `.litertlm`-Format besorgen, z. B. von
   [huggingface.co/litert-community](https://huggingface.co/litert-community) (nach „Gemma" filtern).
   Größere Modelle (mehrere GB) antworten besser, brauchen aber mehr Speicherplatz und RAM — passend zur
   Empfehlung „größeres Modell" ruhig eines im 2–4-GB-Bereich wählen, sofern das Gerät genug freien
   Speicher hat.
2. Den direkten Download-Link zur `.litertlm`-Datei in **„Modell-Datei-URL"** eintragen.
3. **„Herunterladen"** antippen (läuft als Hintergrund-Download mit Fortschrittsanzeige, auch bei
   mehreren GB).

Es gibt bewusst **keinen** vorausgewählten Standard-Modell-Link: `huggingface.co` war aus der
Entwicklungsumgebung dieses Projekts heraus nicht erreichbar, ein konkreter Link ließ sich also nicht
vorab verifizieren — lieber selbst ein Modell wählen als einer möglicherweise falschen Adresse
vertrauen. „Modell löschen" gibt den Speicherplatz wieder frei.

## Runde 14: Widget, Reaktor-Ring, Gesten & Benachrichtigungs-Digest

### Homescreen-Widget & Lockscreen-Dashboard-Ersatz

Ein Android-Homescreen-Widget zeigt Server-Status/Latenz und die Anzahl offener Aufgaben, ohne die App
zu öffnen — antippen des „+ Blitz-Notiz"-Buttons öffnet direkt einen Notiz-Dialog. Einrichtung: lange auf
den Startbildschirm drücken → Widgets → J.A.R.V.I.S. (ein programmatisches Anheften ist erst ab Android 8
möglich; **Einstellungen → „Homescreen-Widget"** bietet dafür einen „Widget anheften"-Button, falls der
Launcher das unterstützt). Android hat seit Version 5 keine echten Sperrbildschirm-Widgets mehr (von
Google entfernt) — als Ersatz zeigt eine **dauerhafte, nicht wegwischbare Benachrichtigung** dieselben
Infos auch bei gesperrtem Handy: **Einstellungen → „Lockscreen-Dashboard"** (Standard aus). Beide
aktualisieren sich alle 30 Minuten automatisch sowie sofort nach jeder Chat-Antwort.

### Audio-reaktiver Reaktor-Ring

Der Reaktor-Ring im Anruf-Modus schlägt jetzt im Takt der echten Mikrofon-Lautstärke beim Zuhören und
einem angenäherten Sprech-Puls bei JARVIS' Antwort aus. Abschaltbar unter **Einstellungen → HUD-Optik →
„Audio-reaktiver Reaktor-Ring"**.

### Bewegungssteuerung (Face-Down & Schütteln)

Alle drei Gesten sind standardmäßig **aus** und einzeln aktivierbar unter **Einstellungen →
„Bewegungssteuerung & Notfall-Sperre"**:

- **Handy umdrehen (Face-Down)** schaltet JARVIS in einen stummen Fokus-Modus (TTS/Mikrofon pausiert,
  HUD-Banner sichtbar) — Umdrehen zurück beendet ihn automatisch.
- **Schütteln** kann wahlweise die Spracheingabe starten und/oder die Notfall-Sperre auslösen — beide
  Wirkungen sind unabhängig voneinander zu- und abschaltbar, auch gleichzeitig.

### Notfall-Sperre (PIN)

Sperrt die App komplett hinter einer PIN-Eingabe (z. B. per Sprachbefehl „sperre die app" oder per
Schütteln, falls aktiviert). Einrichtung unter **Einstellungen → „Bewegungssteuerung &
Notfall-Sperre"** (PIN + Bestätigung eingeben, „PIN speichern"). Die PIN wird **nie im Klartext
gespeichert**, nur ein gesalzener SHA-256-Hash. **Wichtig:** Es gibt bewusst **keinen
Wiederherstellungsweg** für eine vergessene PIN (wie schon beim App-Integritäts-Lockdown) — „PIN
entfernen" ist nur erreichbar, solange die App nicht gesperrt ist. Vor dem Einrichten sicherstellen, dass
die PIN nicht in Vergessenheit gerät.

### Benachrichtigungs-Zusammenfasser (Notification Hub)

Fasst abends ungelesene Push-Benachrichtigungen anderer Apps kurz zusammen. Braucht eine besondere,
manuell erteilte Systemberechtigung — **„Benachrichtigungszugriff"** — kein normaler Laufzeit-Dialog.
Einrichtung unter **Einstellungen → „Benachrichtigungs-Zusammenfasser"**:

1. „Benachrichtigungszugriff einrichten" antippen → JARVIS in der sich öffnenden Systemliste aktivieren.
2. „Benachrichtigungen erfassen" einschalten.

Standardmäßig läuft die Zusammenfassung **rein lokal und regelbasiert** (kein KI-Aufruf, keine Daten
verlassen das Gerät). Nur wenn zusätzlich „KI-Zusammenfassung erlauben" aktiviert **und** ein eigener
KI-Server eingetragen ist, werden kurze Vorschautexte an diesen eigenen Server geschickt — anders als
jede andere KI-Funktion dieser App fällt der Benachrichtigungs-Digest dabei **nie** auf den öffentlichen
Gratis-Fallback zurück. „Erfasste Benachrichtigungen jetzt löschen" entfernt alles sofort wieder.

## YouTube-Video-Upload einrichten (optional)

Der Befehl „video hochladen" lässt dich ein Video von deinem Handy/Computer auswählen und direkt auf dein eigenes YouTube-Konto hochladen — jeder Upload ist ein bewusster Tastendruck (Anmelden → Video wählen → Sichtbarkeit wählen → Titel eintippen → Hochladen), nichts passiert automatisch im Hintergrund. Beim Hochladen wählst du die Sichtbarkeit — **privat**, **nicht gelistet** oder **öffentlich** — und kannst optional eine spätere Veröffentlichungszeit festlegen; YouTube macht das Video dann automatisch zur gewählten Zeit öffentlich (bis dahin bleibt es privat, das schreibt die YouTube-API so vor). Standard bleibt „privat", damit nichts versehentlich sofort öffentlich landet. Auch JARVIS selbst kann beim Öffnen des Upload-Bildschirms schon eine Sichtbarkeit vorauswählen (z. B. „lade das video öffentlich hoch") — die eigentliche Datei wählst du danach weiterhin immer manuell aus.

Weil das Schreibrechte auf einem echten Google-Konto braucht, ist einmalig ein eigenes (kostenloses) Google-Cloud-Projekt nötig:

1. **Google-Cloud-Projekt erstellen**: [console.cloud.google.com](https://console.cloud.google.com) → neues Projekt anlegen (kostenlos, keine Kreditkarte für diesen Teil nötig).
2. **YouTube Data API v3 aktivieren**: Im Projekt unter „APIs & Services → Library" nach „YouTube Data API v3" suchen → **Enable**.
3. **OAuth-Zustimmungsbildschirm einrichten**: „APIs & Services → OAuth consent screen" → Typ **External** → App-Name/E-Mail eintragen → unter „Scopes" `.../auth/youtube.upload` hinzufügen → unter „Test users" deine eigene Google-Mail-Adresse eintragen → Status **Testing** belassen (reicht für den persönlichen Gebrauch, keine Google-Prüfung nötig, solange nur du selbst die App nutzt).
4. **Web-Client-ID erstellen**: „APIs & Services → Credentials → Create Credentials → OAuth client ID" → Typ **Web application** → als „Authorized JavaScript origin" `https://ibrahim200832.github.io` eintragen → erstellen. Die angezeigte **Client-ID** in der JARVIS-App unter **Einstellungen → „YouTube-Client-ID"** eintragen und speichern.
5. **Android-Client registrieren** (nur für die APK nötig, nicht für die Website): „Create Credentials → OAuth client ID" → Typ **Android** → Package-Name `com.jarvis.mobile.jarvis_mobile` → SHA-1-Fingerabdruck `44:E3:29:B6:3F:B2:DE:E3:59:C7:79:56:31:38:40:37:19:CE:5C:17` (das ist der Fingerabdruck des Release-Signierschlüssels aus dem Abschnitt oben) eintragen → erstellen. Hier ist keine Client-ID in der App nötig, Google erkennt die App automatisch anhand von Package-Name und Fingerabdruck.

**Beim ersten Anmelden** zeigt Google eine Warnung „Diese App wurde nicht überprüft" — das ist normal und unbedenklich, weil es dein eigenes Projekt ist und nur du selbst als Test-Nutzer eingetragen bist. Auf „Erweitert" → „Weiter zu … (unsicher)" klicken, um fortzufahren.

## Spotify-Musiksteuerung einrichten (optional)

Sag „spiele \<Song\> auf Spotify", „spiele playlist \<Name\> auf Spotify" oder frag JARVIS frei danach, etwas abzuspielen, und er startet den Song bzw. die Playlist auf deinem gerade aktiven Spotify-Gerät (dafür ist ein **Spotify-Premium-Konto** nötig — das ist eine Einschränkung von Spotify selbst, keine der App). Das funktioniert sowohl in der APK auf dem Handy als auch in der Web-Version am PC — die Anmeldung läuft in beiden Fällen über die normale Spotify-Login-Seite mit deinen normalen Zugangsdaten; die App selbst sieht dein Passwort nie. Weil dafür Zugriff auf dein eigenes Spotify-Konto nötig ist, brauchst du einmalig eine eigene (kostenlose) Spotify-Developer-App:

1. **Spotify-Developer-App anlegen**: [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) → mit deinem Spotify-Konto anmelden → „Create app" → beliebigen Namen/Beschreibung eintragen.
2. **Redirect URIs eintragen**: In den App-Einstellungen unter „Redirect URIs" **beide** folgenden Werte hinzufügen und speichern:
   - `jarvismobile://spotify-callback` (für die APK auf dem Handy)
   - `https://ibrahim200832.github.io/jarvis-mobile/spotify-callback.html` (für die Web-Version am PC)
3. **Client ID kopieren**: Auf der App-Übersichtsseite steht die **Client ID** — die in der JARVIS-App unter **Einstellungen → „Spotify-Client-ID"** eintragen und speichern (auf jedem Gerät, auf dem du dich anmeldest).
4. **Verbinden**: In den Einstellungen auf „Mit Spotify verbinden" tippen und im sich öffnenden Spotify-Login mit deinem normalen Spotify-Konto bestätigen. Dabei fragt Spotify auch nach Zugriff auf deine Playlists, damit JARVIS sie später abspielen kann.

Kein Client Secret nötig — die Anmeldung läuft über einen sicheren Code-Flow (PKCE), bei dem kein Geheimnis im Gerät gespeichert werden muss.

## TikTok-Video-Upload einrichten (optional)

Sag „video auf tiktok hochladen", und JARVIS öffnet den Upload-Bildschirm, in dem du ein Video auswählst, einen Titel eingibst und die Sichtbarkeit festlegst.

> **Wichtige Einschränkung:** Solange deine eigene TikTok-Entwickler-App kein offizielles TikTok-Audit bestanden hat, erzwingt TikTok bei **jedem** Upload die Sichtbarkeit „Nur ich" (privat) — unabhängig davon, was in JARVIS ausgewählt wird. „Öffentlich" oder „Nur Freunde" funktionieren erst, nachdem TikTok die App geprüft hat; das dauert Tage bis Wochen, verlangt ein Demo-Video der fertigen Funktion sowie eine gehostete Datenschutzerklärung/Nutzungsbedingungen, und ist für eine private Hobby-App nicht garantiert genehmigt. Verbinden und Hochladen funktionieren aber auch ohne Audit sofort — nur eben ausschließlich privat.

Weil TikToks Login sowohl einen Client Key **als auch** ein geheimes Client Secret verlangt (letzteres darf niemals in der App landen), läuft die Anmeldung über den eigenen Worker — genau wie schon die Websuche. Einmalige Einrichtung:

1. **TikTok-Entwickler-App anlegen**: [developers.tiktok.com](https://developers.tiktok.com) → mit deinem TikTok-Konto anmelden → neue App erstellen → die Produkte **„Login Kit"** und **„Content Posting API"** hinzufügen.
2. **Redirect URIs eintragen**: In den App-Einstellungen **beide** folgenden Werte als Redirect-URI hinzufügen:
   - `jarvismobile://tiktok-callback` (für die APK auf dem Handy)
   - `https://ibrahim200832.github.io/jarvis-mobile/tiktok-callback.html` (für die Web-Version am PC)

   Für die zweite URI verlangt TikTok eine Domain-Verifizierung — TikTok zeigt dafür direkt im Dashboard an, welche Datei/welches Meta-Tag nötig ist (kann sich ändern, deshalb hier nicht fest vorgeschrieben).
3. **Client Key kopieren**: Auf der App-Übersichtsseite steht der **Client Key** — den in der JARVIS-App unter **Einstellungen → „TikTok-Client-Key"** eintragen und speichern.
4. **Client Key und Client Secret im Worker hinterlegen**: Im [Cloudflare-Dashboard](https://dash.cloudflare.com) → **Workers & Pages** → den eigenen Worker öffnen → **Settings → Variables and Secrets → Add**, zweimal: Name `TIKTOK_CLIENT_KEY` (Wert = Client Key) und Name `TIKTOK_CLIENT_SECRET` (Wert = Client Secret) → jeweils Typ **Secret** → **Deploy**.
5. **Verbinden**: In den Einstellungen auf „Mit TikTok verbinden" tippen und im sich öffnenden TikTok-Login mit deinem normalen TikTok-Konto bestätigen.

Getestet ist dieser Ablauf bisher auf der APK (Handy); die Web-Version nutzt denselben Code, TikToks API ist aber primär für Server-zu-Server-Aufrufe gedacht, daher ist nicht sichergestellt, dass der eigentliche Video-Upload im Browser funktioniert.

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

Mikrofon, Kamera, Standort, Kontakte und Benachrichtigungen werden zur Laufzeit angefragt. `QUERY_ALL_PACKAGES` erlaubt das Auflisten installierter Apps (nur Android). Der Benachrichtigungs-Zusammenfasser (Runde 14) braucht zusätzlich die besondere, manuell in den Systemeinstellungen erteilte „Benachrichtigungszugriff"-Berechtigung — kein normaler Laufzeit-Dialog, siehe oben.

## Projektstruktur

```
lib/
  core/command_router.dart   Erkennt Befehle aus Text/Sprache, ruft Services auf oder leitet an die KI weiter
  services/                  Ein Service pro Fähigkeit (inkl. ai_chat_service.dart für das KI-Gespräch)
  screens/                   Home-Chat-Screen, Kamera-Screen, Einstellungen
  widgets/                   Chat-Bubble und Anruf-Orb-Overlay
worker/ai-proxy.js           Optionaler Cloudflare-Worker-Proxy für den eigenen KI-Server (siehe oben)
```
