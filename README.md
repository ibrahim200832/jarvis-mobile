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
| — | Echter Telefonanruf: „ruf mich an" lässt JARVIS dich tatsächlich anrufen und etwas ansagen (optional, siehe unten) |
| — | Google-Kalender: Termine ansagen/anlegen per Sprache, plus automatischer Erinnerungsanruf kurz vor einem Termin (optional, siehe unten) |
| — | Echter Telefonanruf an einen Kontakt mit Ansage: „ruf Mama an und sag ihr: bin gleich da" (optional, siehe oben) |
| — | Kostenlose Telegram-Benachrichtigungen statt/zusätzlich zu Anrufen (optional, siehe unten) |
| — | Philips-Hue-Lichter steuern (an/aus/dimmen) — komplett lokal, keine Cloud (optional, siehe unten) |
| — | Status von Bosch/Siemens-Hausgeräten abfragen, z. B. „ist die waschmaschine fertig" (optional, siehe unten) |

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
- „ruf mich an" / „ruf Mama an und sag ihr: bin gleich da" (siehe „Telefonanrufe" unten)
- „was steht heute an" / „leg einen termin an: Zahnarzt um 15 Uhr" (siehe „Telefonanrufe & Kalender-Erinnerungen" unten)
- „schick mir eine telegram nachricht: Test" (siehe „Telegram-Benachrichtigungen" unten)
- „hue Wohnzimmer an" / „licht Küche auf 40 prozent" (siehe „Philips-Hue-Lichtsteuerung" unten)
- „ist die waschmaschine fertig" (siehe „Bosch/Siemens Home Connect" unten)
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

## Telefonanrufe & Kalender-Erinnerungen einrichten (optional)

Sag „ruf mich an", und JARVIS ruft dich tatsächlich am Telefon an (nicht nur ein Wähldialog wie bei „rufe Mama an" — ein echter eingehender Anruf, bei dem eine Stimme spricht). Verbindest du zusätzlich deinen Google Kalender, ruft JARVIS dich auch automatisch an, kurz bevor ein Termin beginnt — auch wenn die App gerade nicht geöffnet ist, weil das im Hintergrund über deinen eigenen Worker läuft (Cloudflare Cron, alle 5 Minuten). Im Gespräch kann JARVIS beides auch selbst auslösen („ruf mich in 10 Minuten nochmal an" während eines laufenden Gesprächs, „leg einen Termin für morgen 15 Uhr Zahnarzt an").

Weil ein echter Telefonanruf über einen Telefonie-Anbieter läuft und dessen Zugangsdaten niemals in der App landen dürfen, läuft das komplett über deinen eigenen Worker — Kosten für Anrufe trägt dein eigenes Twilio-Konto (siehe Twilios Preisliste; ein paar Cent pro Anruf).

1. **Worker-URL kennen**: Deine Worker-URL steht unter Einstellungen → „KI-Server-Adresse" bzw. im Cloudflare-Dashboard (z. B. `https://jarvis-ai.<dein-name>.workers.dev`).
2. **WORKER_SELF_URL setzen**: Im [Cloudflare-Dashboard](https://dash.cloudflare.com) → Workers & Pages → deinen Worker öffnen → **Settings → Variables and Secrets → Add** → Name `WORKER_SELF_URL`, Wert = genau diese Worker-URL (ohne Slash am Ende) → Typ **Text** reicht.
3. **Anruf-Geheimnis festlegen**: Denk dir einen beliebigen langen Zufallstext aus (z. B. mit einem Passwort-Generator) und trage ihn zweimal ein:
   - Im Worker als Secret `CALL_SHARED_SECRET` (gleicher Weg wie oben, Typ **Secret**).
   - In der JARVIS-App unter **Einstellungen → „Anruf-Geheimnis"**.

   Das verhindert, dass jemand anderes über deine Worker-URL auf deine Kosten Anrufe auslöst.
4. **Twilio-Konto einrichten**: Kostenloses Konto unter [twilio.com](https://www.twilio.com) anlegen → eine Telefonnummer kaufen/mieten (mit Sprachfunktion) → **Account SID**, **Auth Token** (beide auf der Twilio-Console-Startseite) und die gekaufte **Telefonnummer** (im E.164-Format, z. B. `+491701234567`) notieren.
5. **Twilio-Zugangsdaten im Worker hinterlegen**: Im Worker als Secrets `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` und `TWILIO_FROM_NUMBER` (deine Twilio-Nummer) eintragen → **Deploy**.
6. **Deine eigene Handynummer eintragen**: In der JARVIS-App unter **Einstellungen → „Telefonnummer für Anrufe"** deine echte Handynummer im E.164-Format eintragen (die JARVIS anruft) → speichern.
7. **Testen**: „ruf mich an" sagen — dein Telefon sollte innerhalb weniger Sekunden klingeln, mit einer gesprochenen Nachricht von JARVIS.

### Kalender-Erinnerungsanrufe (zusätzlich, optional)

Damit JARVIS automatisch vor Terminen anruft, auch ohne geöffnete App, braucht der Worker dauerhaften Zugriff auf deinen Google Kalender:

1. **Google-Client-ID einrichten**, falls noch nicht geschehen (siehe „YouTube-Video-Upload einrichten" oben) — dieselbe Client-ID wird hier mitbenutzt, nur mit einem zusätzlichen Scope. Unter „OAuth consent screen → Scopes" zusätzlich `.../auth/calendar` hinzufügen.
2. **Client Secret erzeugen**: „APIs & Services → Credentials" → deinen bestehenden **Web application**-OAuth-Client öffnen (oder neu anlegen) → das dort angezeigte **Client Secret** notieren (nur bei „Web application"-Clients vorhanden).
3. **KV-Speicher anlegen**: Lokal mit installiertem [Wrangler](https://developers.cloudflare.com/workers/wrangler/) im Projektordner `wrangler kv namespace create JARVIS_KV` ausführen → den auskommentierten `[[kv_namespaces]]`-Block in `wrangler.toml` einkommentieren und die zurückgegebene `id` eintragen (ersetzt `REPLACE_WITH_YOUR_KV_NAMESPACE_ID`) → Worker neu deployen (`wrangler deploy`). Der Block ist standardmäßig auskommentiert, damit ein Deploy ohne diesen Schritt nicht an einer nicht existierenden Platzhalter-ID scheitert.
4. **Google-Zugangsdaten im Worker hinterlegen**: Als Secrets `GOOGLE_CLIENT_ID` (deine Web-Client-ID) und `GOOGLE_CLIENT_SECRET` (aus Schritt 2) eintragen.
5. **Verbinden**: In der JARVIS-App unter Einstellungen zuerst Telefonnummer und Anruf-Geheimnis eintragen/speichern (siehe oben), dann auf „Google Kalender verbinden" tippen und die Google-Anmeldung bestätigen (auch hier zeigt Google ggf. „App nicht überprüft" — unbedenklich für dein eigenes Test-Projekt, siehe oben).

Ab jetzt prüft der Worker automatisch alle 5 Minuten, ob ein Termin in den nächsten 15 Minuten beginnt, und ruft dich dann einmalig pro Termin an.

## Telegram-Benachrichtigungen einrichten (optional)

Kostenlose Alternative bzw. Ergänzung zu den Anrufen oben: „schick mir eine telegram nachricht: \<Text\>" schickt dir eine Telegram-Nachricht statt eines Anrufs. Ist zusätzlich zum Telefon-Setup oben auch ein Telegram-Chat verbunden, schickt der Kalender-Erinnerungs-Cronjob **zusätzlich** eine Telegram-Nachricht (auch ohne Twilio nutzbar, wenn dir Nachrichten statt Anrufen reichen).

1. **Bot anlegen**: In Telegram mit [@BotFather](https://t.me/BotFather) chatten → `/newbot` → Namen vergeben → den angezeigten **Bot-Token** notieren.
2. **Bot-Token im Worker hinterlegen**: Als Secret `TELEGRAM_BOT_TOKEN` eintragen (gleicher Weg wie bei den anderen Secrets oben).
3. **Anruf-Geheimnis eintragen**, falls noch nicht geschehen (siehe „Telefonanrufe" oben) — wird hier mitbenutzt, damit nicht jeder über deine Worker-URL Nachrichten in deinem Namen verschicken kann.
4. **Bot anschreiben**: In Telegram eine beliebige Nachricht an deinen neuen Bot schicken (z. B. „hi").
5. **Verbinden**: In der JARVIS-App unter Einstellungen auf „Mit Telegram verbinden" tippen — die App findet deine Chat-ID automatisch über die zuletzt an den Bot geschickte Nachricht (kein manuelles Heraussuchen der Chat-ID nötig).
6. **Testen**: „schick mir eine telegram nachricht: Test" sagen.

### Direkt mit dem Bot chatten (zusätzlich, optional)

Zusätzlich zum "schick mir eine telegram nachricht"-Befehl aus der App kannst du deinem Bot auch **direkt in Telegram schreiben** und bekommst eine echte KI-Antwort zurück — ganz ohne die JARVIS-App zu öffnen. Anrufe/WhatsApp/Apps-Öffnen funktionieren darüber nicht (die brauchen das Handy selbst), aber normale Fragen und Gespräche schon.

Das braucht zwei zusätzliche Dinge, die teils schon aus anderen Abschnitten oben bekannt sind:

1. **`WORKER_SELF_URL` setzen**, falls noch nicht geschehen (siehe „Telefonanrufe" oben) — der Worker muss seine eigene URL kennen, um sich bei Telegram als Webhook zu registrieren.
2. **KV-Speicher einrichten**, falls noch nicht geschehen (siehe „Kalender-Erinnerungsanrufe" oben, Schritt „KV-Speicher anlegen") — dort wird gespeichert, welche Chat-ID dein eigener Bot beantworten darf (jede andere Nachricht wird stillschweigend ignoriert, damit niemand sonst auf deine Kosten mit deinem Bot chatten kann).

Danach einmal (erneut) in der App auf **„Mit Telegram verbinden"** tippen — das registriert automatisch den Webhook bei Telegram. Ab dann antwortet der Bot auf jede Nachricht, die du ihm direkt in Telegram schickst — auch auf **Sprachnachrichten**: der Bot erkennt gesprochenen Text automatisch (über dieselbe kostenlose Cloudflare-KI, ohne extra Einrichtung), schickt den erkannten Text als Bestätigung zurück und antwortet direkt darauf.

Der Bot merkt sich außerdem den Gesprächsverlauf (die letzten Nachrichten, ca. 6 Stunden lang) — Anschlussfragen wie „und morgen?" funktionieren also. Und er kann bei aktuellen/unsicheren Fakten selbst das Web durchsuchen (braucht einen `BRAVE_API_KEY`, siehe „Websuche einrichten" oben) — alles andere, was das Handy selbst braucht (Anrufe, Hue, Home Connect, Wetter, Nachrichten), bleibt der App vorbehalten.

Der **Google Kalender** ist eine Ausnahme: Ist er über die App verbunden (siehe „Kalender-Erinnerungsanrufe" oben), kann der Bot ihn auch direkt in Telegram nutzen — „was steht heute an" zeigt die nächsten Termine, „leg einen Termin an: Zahnarzt morgen um 10 Uhr" trägt einen neuen ein, „lösch den termin zahnarzt" (oder `/terminloeschen zahnarzt`) entfernt ihn wieder — gefunden über einen Teil des Titels. Keine zusätzliche Einrichtung nötig, das läuft über dieselbe Verbindung wie die Erinnerungsanrufe.

Der Bot hat außerdem richtige Telegram-**Slash-Befehle**: Tippst du in Telegram ein "/" ein, erscheint ein Menü mit allen Befehlen (`/hilfe`, `/merken`, `/erinnerungen`, `/vergessen`, `/bild`, `/bearbeiten`, `/termine`, `/termin`, `/suche`, `/neu`, `/status`, `/witz`, `/nachrichten`, `/schick`, `/reset`, `/terminloeschen`, `/gruppe`) samt Beschreibung. `/hilfe` listet sie auch jederzeit direkt im Chat auf. Die natürlichsprachlichen Formulierungen ("merk dir: ...", "erstelle mir ein bild von ...") funktionieren weiterhin genauso, die Slash-Befehle sind nur eine zusätzliche, schnellere Variante.

**In einer Gruppe nutzen**: Standardmäßig antwortet der Bot nur im privaten Chat mit dir. Damit er auch in einer **Telegram-Gruppe** mitschreiben kann: (1) Bot zur Gruppe hinzufügen, (2) bei [@BotFather](https://t.me/BotFather) `/setprivacy` → deinen Bot auswählen → **Disable** wählen (ohne diesen Schritt sieht der Bot in Gruppen nur direkte Befehle, keine normalen Nachrichten — eine feste Telegram-Einschränkung), (3) als Besitzer `/gruppe` direkt in der Gruppe schicken. Danach antwortet der Bot dort jedem Gruppenmitglied ganz normal, so wie im privaten Chat mit dir.

**Nachrichten an andere Personen weiterleiten**: Sag „schick Mama: bin gleich da" (oder `/schick Mama: bin gleich da`), und der Bot schickt diese Nachricht an Mama weiter — vorausgesetzt, Mama hat dem Bot selbst schon mal irgendetwas geschrieben (der Bot merkt sich dann automatisch ihren Namen). Ein echtes "Kaltanschreiben" fremder Personen ist bei Telegram-Bots technisch nicht möglich (feste Anti-Spam-Regel von Telegram) — der Bot darf nur Chats antworten, die zuerst selbst geschrieben haben. Schreibt Mama dem Bot danach etwas zurück, bekommst du das automatisch als Telegram-Nachricht weitergeleitet — Mama selbst bekommt dabei keine KI-Antwort vom Bot, nur du erfährst von ihrer Antwort.

**Alles zurücksetzen**: `/reset` löscht den Gesprächsverlauf, das komplette dauerhafte Gedächtnis **und** JARVIS' eigene Nachrichten der letzten 48h im Chat — nicht rückgängig machbar. Deine eigenen geschickten Nachrichten bleiben dabei stehen: Telegram erlaubt Bots grundsätzlich nicht, fremde (also deine eigenen) Nachrichten zu löschen, das ist eine feste Plattform-Regel ohne Ausnahme.

Zusätzlich gibt es ein **dauerhaftes Gedächtnis** (kein Zeitlimit, anders als der Gesprächsverlauf oben): Sag „merk dir: \<Fakt\>" (z. B. „merk dir: ich mag keinen Kaffee"), und der Bot berücksichtigt das ab sofort bei jeder künftigen Antwort — auch nach Tagen oder Wochen noch. „meine erinnerungen" zeigt alles Gemerkte an, „vergiss alles" löscht es wieder.

Der Bot kann außerdem mit **Bildern** umgehen, komplett über die gleiche kostenlose Cloudflare-KI (keine Weitergabe an Drittanbieter wie die Websuche):
- **Fotos ansehen**: Schick dem Bot ein Foto (mit oder ohne Bildunterschrift/Frage dazu) — er beschreibt bzw. beantwortet es auf Deutsch.
- **Bilder erstellen**: Sag z. B. „erstelle mir ein bild von einer katze im weltraum" oder „mal mir einen sonnenuntergang" — der Bot generiert ein passendes Bild und schickt es zurück.
- **Bilder bearbeiten**: Entweder ein Foto schicken und danach separat „bearbeite das bild: mach den himmel rot" sagen (der Bot merkt sich das zuletzt geschickte Foto eine Stunde lang), oder gleich **in einer Nachricht** ein Foto mit „bearbeite das bild: ..." als Bildunterschrift schicken — beides funktioniert.

#### GIF-Antworten einrichten (optional)

Schickst du dem Bot einen **Sticker** oder ein **GIF** (mit oder ohne Text dazu), sucht er automatisch ein passendes GIF (über [Tenor](https://tenor.com/gifapi), gehört Google) und schickt es zurück — als Suchbegriff nutzt er deinen Text, sonst das Emoji des Stickers. Eine echte Sticker-Suche ist über die Telegram-Bot-API technisch nicht möglich (keine öffentliche Schnittstelle dafür), ein passendes GIF sieht im Chat aber sehr ähnlich aus.

1. Auf [tenor.com/developer/keys](https://tenor.com/developer/keys) ein kostenloses API-Konto anlegen (keine Kreditkarte nötig) und den **API Key** kopieren.
2. In Cloudflare bei `jarvis-ai` → Settings → Variables and Secrets einen neuen Eintrag **`TENOR_API_KEY`** mit diesem Wert anlegen — Typ **Secret** → **Deploy**.

Ohne diesen Secret ignoriert der Bot Sticker/GIFs einfach weiter wie bisher.

#### Sprachnachrichten von JARVIS (optional, kostenpflichtig)

Der Bot kann auf jede Nachricht (egal ob du tippst oder eine Sprachnachricht schickst) zusätzlich zur Textantwort auch mit einer **eigenen Sprachnachricht** antworten. Das braucht einen kleinen kostenpflichtigen Zusatzdienst (ElevenLabs), weil die kostenlose Cloudflare-KI leider kein Deutsch spricht — die Kosten sind aber sehr gering (Bruchteile eines Cents pro Antwort).

1. Auf [elevenlabs.io](https://elevenlabs.io) ein kostenloses Konto anlegen, dann unter „Profile" (oben rechts) den **API Key** kopieren.
2. In Cloudflare bei `jarvis-ai` → Settings → Variables and Secrets einen neuen Eintrag **`ELEVENLABS_API_KEY`** mit diesem Wert anlegen — unbedingt Typ **Secret** wählen, nicht „Text"/„Variable" (sonst geht der Wert beim nächsten automatischen Deploy wieder verloren) → **Deploy**.

Ohne diesen Secret antwortet der Bot einfach weiter nur in Text, wie bisher — kein Fehler, kein Zwang, das einzurichten.

Der Bot reagiert außerdem auf jede Nachricht zusätzlich mit einem passenden Emoji (z. B. ❤ bei „danke", 🤔 bei einer Frage, 🎉 wenn du „geschafft" sagst) — wie eine Emoji-Reaktion in WhatsApp/Slack, direkt an deiner eigenen Nachricht.

## Philips-Hue-Lichtsteuerung einrichten (optional)

Sag „hue Wohnzimmer an", „licht Küche aus" oder „hue Wohnzimmer auf 40 prozent", und JARVIS steuert deine Philips-Hue-Lampen — komplett lokal über deine Hue Bridge im selben WLAN wie dein Handy, ohne Cloud oder Philips-Account. Portiert vom Original-Desktop-Tool (`hue.py`).

> **Wichtig:** Dein Handy muss dafür im selben WLAN wie die Hue Bridge sein. Im Browser (Web-Version) funktioniert das nicht — Browser lassen sich nicht dazu bringen, dem selbstsignierten Zertifikat der Bridge zu vertrauen; nur die App (Android/iOS) kann das.

1. **Bridge-IP finden**: In der offiziellen Hue-App unter „Einstellungen → Mein Hue-System" nachschauen, oder [discovery.meethue.com](https://discovery.meethue.com) öffnen.
2. **IP eintragen**: In der JARVIS-App unter **Einstellungen → „Philips-Hue-Bridge-IP"** eintragen und speichern.
3. **Koppeln**: Den runden Knopf auf der Hue Bridge drücken, und **innerhalb von 30 Sekunden** in den Einstellungen auf „Hue Bridge koppeln" tippen.
4. **Testen**: „hue \<Lampenname\> an" sagen, mit dem Namen, den die Lampe in der Hue-App trägt.

## Weckwort "Jarvis" einrichten (optional, nur Android)

Sag einfach "Jarvis", egal ob die App gerade offen ist oder nicht — JARVIS hört automatisch zu und startet die Sprachaufnahme, genau wie "Ok Google" oder "Hey Siri". Das läuft über [Picovoice Porcupine](https://picovoice.ai/), eine spezialisierte, sparsame Weckwort-Erkennung (kein Dauer-Streaming, anders als normale Spracherkennung) — "Jarvis" ist eines ihrer fertigen Weckwörter, du musst nichts trainieren.

Damit das auch bei geschlossener App funktioniert, läuft im Hintergrund ein dauerhafter Dienst mit eigener Benachrichtigung ("JARVIS hört zu") — das ist eine Voraussetzung von Android für jede App, die im Hintergrund das Mikrofon offen hält, keine Fehlfunktion. Auf iOS ist das nicht möglich (Apple erlaubt keinen dauerhaften Mikrofonzugriff im Hintergrund für Drittanbieter-Apps).

1. **Kostenloses Picovoice-Konto erstellen**: Auf [console.picovoice.ai](https://console.picovoice.ai) registrieren.
2. **AccessKey kopieren**: Steht direkt auf der Startseite der Console nach dem Login.
3. **In der App eintragen**: JARVIS-App → Einstellungen → Feld **"Picovoice-AccessKey"** → einfügen → **Speichern**.
4. **Aktivieren**: Den Schalter **"Weckwort 'Jarvis'"** umlegen. Die App fragt dabei nach der Benachrichtigungs-Erlaubnis und bittet darum, JARVIS von der Akku-Optimierung auszunehmen (sonst würde Android den Hintergrunddienst nach einiger Zeit selbst beenden) — beides bitte zulassen.

> **Hinweis:** Das kostenlose Picovoice-Kontingent reicht für den persönlichen Gebrauch (ein Nutzer, eine App) völlig aus.

## Bosch/Siemens Home Connect einrichten (optional)

Sag „ist die waschmaschine fertig", „ist der trockner fertig" oder „ist der geschirrspüler fertig", und JARVIS prüft den Status deines Bosch/Siemens-Hausgeräts über die Home-Connect-Cloud-API. Portiert vom Original-Desktop-Tool (`bosch.py`).

1. **Home-Connect-Entwickler-App anlegen**: Kostenloses Konto unter [developer.home-connect.com](https://developer.home-connect.com) anlegen → neue Anwendung erstellen → als **Authorization Flow** unbedingt **„Device Flow"** wählen (nicht „Authorization Code Grant Flow" — Device Flow braucht keinen Client Secret und keine Redirect-URI, was auf dem Handy viel einfacher ist).
2. **Client-ID kopieren**: Die angezeigte **Client-ID** in der JARVIS-App unter **Einstellungen → „Home-Connect-Client-ID"** eintragen und speichern.
3. **Verbinden**: In den Einstellungen auf „Mit Home Connect verbinden" tippen — es öffnet sich eine Home-Connect-Seite im Browser mit einem Code, den die App automatisch schon eingetragen hat; dort mit deinem Home-Connect-Konto anmelden und bestätigen. Die App wartet im Hintergrund, bis das erledigt ist (bis zu ein paar Minuten Zeit).
4. **Testen**: „ist die waschmaschine fertig" sagen (auch ohne aktives Programm antwortet JARVIS, z. B. mit „läuft gerade nicht").

Falls du kein echtes Gerät zum Testen hast: Home Connect bietet einen [Simulator](https://developer.home-connect.com/simulator) mit virtuellen Geräten für genau diesen Zweck.

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

Mikrofon, Kamera, Standort, Kontakte und Benachrichtigungen werden zur Laufzeit angefragt. `QUERY_ALL_PACKAGES` erlaubt das Auflisten installierter Apps (nur Android).

## Projektstruktur

```
lib/
  core/command_router.dart   Erkennt Befehle aus Text/Sprache, ruft Services auf oder leitet an die KI weiter
  services/                  Ein Service pro Fähigkeit (inkl. ai_chat_service.dart für das KI-Gespräch)
  screens/                   Home-Chat-Screen, Kamera-Screen, Einstellungen
  widgets/                   Chat-Bubble und Anruf-Orb-Overlay
worker/ai-proxy.js           Optionaler Cloudflare-Worker-Proxy für den eigenen KI-Server (siehe oben)
```
