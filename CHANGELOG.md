# Changelog

Kurze, nutzerfreundliche Stichpunkte zu jedem Release. Der oberste Abschnitt
wird beim Deploy automatisch in den "Update verfügbar"-Dialog der App
übernommen (siehe `.github/workflows/deploy-web.yml`).

## Aktuell
- Fix: Schickte ein bereits freigeschalteter Nutzer erneut `/start` (z. B. weil Telegram das automatisch anzeigt), landete das ungefiltert in der KI-Konversation und führte zu unpassenden Antworten (z. B. eine zufällige Websuche) — `/start` wird jetzt immer mit der normalen Begrüßung beantwortet.
- Verbessert: Eine Telegram-Gruppe schaltet sich jetzt automatisch frei, sobald der Bot dort die erste Nachricht sieht (egal von wem) — der Besitzer muss nicht mehr selbst `/gruppe` schicken, das funktioniert aber weiterhin zusätzlich.
- Neu: JARVIS schickt jetzt einmal pro Stunde automatisch eine Nachricht ("Bitte schreibt mich an, ich fühle mich allein.") an dich und alle freigeschalteten Telegram-Nutzer.
- Verbessert: Sprachantworten werden jetzt bei ca. 300 Zeichen (am Satzende) gekürzt gesprochen, statt die volle Antwort vorzulesen — spart ElevenLabs-Kontingent, das sich alle Nutzer teilen. Die Textantwort bleibt immer vollständig.
- Verbessert: Schlägt die Sprachantwort (ElevenLabs) bei einem anderen Nutzer fehl, bekommst du als Besitzer jetzt eine Warnung mit dem genauen Grund, statt dass es nur wie ein unerklärlicher Fehler bei "den anderen" wirkt (z. B. wenn das monatliche ElevenLabs-Kontingent aufgebraucht ist, das sich alle Nutzer teilen).
- Neu: Bringt ein anderer freigeschalteter Telegram-Nutzer JARVIS über "merk dir: ..." etwas bei, bekommst du als Besitzer jetzt eine kurze Meldung darüber (Beleidigungen werden dabei weder gespeichert noch gemeldet, sondern herausgefiltert).
- Fix: Websuche-Ergebnisse zeigten manchmal rohe HTML-Codes wie `&#x27;` statt eines Apostrophs in JARVIS' Antwort — wird jetzt korrekt umgewandelt.
- Verbessert: Die volle Freischaltung für neue Telegram-Nutzer greift jetzt schon bei der allerersten Nachricht (egal ob `/start`, Text oder direkt eine Sprachnachricht), nicht mehr nur bei `/start` — inklusive Sprachnachrichten senden/empfangen mit derselben vollen Funktion wie beim Besitzer.
- Neu: Schreibt jemand den Telegram-Bot zum ersten Mal an, ist er ab sofort vollständig freigeschaltet — genau wie der Besitzer, inklusive Kalender, Anrufen und Smart Home. ⚠️ Wichtig: Das gibt jedem, der deinen Bot findet, vollen Zugriff, siehe README.
- Fix: Schreibt eine neue Person den Telegram-Bot zum ersten Mal an (`/start`), bekommt sie jetzt eine kurze Begrüßung statt gar keiner Antwort.
- Neu: Schreibt ein bekannter Kontakt dem Telegram-Bot zurück (nachdem du ihm über `/schick` etwas geschickt hast), bekommst du diese Antwort jetzt automatisch als Telegram-Nachricht weitergeleitet.
- Neu: JARVIS' Telegram-Bot kann jetzt auch in einer Gruppe mitschreiben — Bot zur Gruppe hinzufügen, bei BotFather `/setprivacy` auf "Disable" stellen, dann als Besitzer `/gruppe` in der Gruppe schicken (siehe README).
- Fix: Schickte man ein Foto zusammen mit einem Bearbeitungswunsch als Bildunterschrift (statt in zwei Nachrichten), wertete der Bot das fälschlich nur als Frage zum Bild aus, statt es zu bearbeiten — funktioniert jetzt in einer Nachricht.
- Neu: JARVIS' Telegram-Bot kann jetzt auch Kalendertermine löschen ("lösch den termin zahnarzt" oder `/terminloeschen zahnarzt`), gefunden über einen Teil des Titels.
- Fix: JARVIS antwortete gelegentlich auf Englisch statt Deutsch — die Anweisung, immer Deutsch zu sprechen, fehlte im System-Prompt komplett und ist jetzt ergänzt.
- Verbessert: `/reset` in Telegram löscht jetzt zusätzlich JARVIS' eigene Nachrichten der letzten 48h aus dem sichtbaren Chat (Telegram erlaubt Bots keine weitergehende Löschung — auch nicht der eigenen Nachrichten des Nutzers).
- Neu: `/reset` in Telegram löscht Gesprächsverlauf und dauerhaftes Gedächtnis komplett auf einen Schlag (nicht rückgängig machbar).
- Neu: JARVIS' Telegram-Bot kann jetzt Nachrichten an andere Personen weiterleiten ("schick Mama: bin gleich da"), sobald diese dem Bot selbst schon mal geschrieben haben — echtes Kaltanschreiben ist bei Telegram-Bots aus Anti-Spam-Gründen nicht möglich.
- Neu: JARVIS' Telegram-Bot antwortet jetzt automatisch mit einem passenden GIF, wenn man ihm einen Sticker oder ein GIF schickt (optional, kostenloser Tenor-API-Key nötig, siehe README).
- Neu: Weckwort "Jarvis" (nur Android) — sag einfach "Jarvis", auch bei geschlossener App, und JARVIS hört automatisch zu, wie "Ok Google". Braucht einen kostenlosen Picovoice-AccessKey, siehe README.
- Neu: Zwei weitere Telegram-Slash-Befehle: `/witz` erzählt einen Witz, `/nachrichten` zeigt aktuelle Schlagzeilen.
- Fix: Telegram-Befehle, die eine fehlende Einrichtung brauchen (z. B. Kalender oder Websuche), geben jetzt eine klare Anleitung statt zu schweigen oder eine technische Fehlermeldung zu zeigen — und jeder Befehl bekommt garantiert eine Antwort, auch bei unerwarteten Fehlern.
- Neu: Zwei weitere Telegram-Slash-Befehle: `/neu` startet ein frisches Gespräch, `/status` zeigt, was verbunden ist (Kalender, Sprachausgabe, Websuche).
- Neu: Zwei weitere Telegram-Slash-Befehle: `/termin` legt direkt einen Kalendertermin an, `/suche` durchsucht sofort das Web.
- Neu: JARVIS' Telegram-Bot hat jetzt echte Slash-Befehle ("/" tippen zeigt ein Menü, `/hilfe` listet alle Befehle) — die bisherigen natürlichsprachlichen Formulierungen funktionieren weiterhin zusätzlich.
- Neu: JARVIS' Telegram-Bot kann jetzt direkt auf den Google Kalender zugreifen — Termine ansehen und anlegen, ganz ohne die App zu öffnen.
- Neu: JARVIS' Telegram-Bot kann jetzt zusätzlich zur Textantwort auch mit einer eigenen Sprachnachricht antworten (optional, kleine Zusatzkosten über ElevenLabs, siehe README).
- Neu: JARVIS' Telegram-Bot kann jetzt auch ein zuvor geschicktes Foto bearbeiten ("bearbeite das bild: mach den himmel rot") — komplett über Cloudflare-KI, keine Weitergabe an Dritte.
- Fix: "Mit Telegram verbinden" schlug nach dem ersten erfolgreichen Verbinden immer fehl ("Telegram-Anfrage fehlgeschlagen") — funktioniert jetzt auch beim erneuten Verbinden zuverlässig.
- Neu: JARVIS' Telegram-Bot kann jetzt Fotos ansehen und beschreiben, und auf Zuruf eigene Bilder erstellen ("erstelle mir ein bild von ...") — komplett über Cloudflare-KI, keine Weitergabe an Dritte.
- Neu: JARVIS' Telegram-Bot reagiert jetzt zusätzlich mit einem passenden Emoji auf jede Nachricht (wie eine Emoji-Reaktion in WhatsApp/Slack).
- Neu: JARVIS' Telegram-Bot hat jetzt ein dauerhaftes Gedächtnis — "merk dir: ..." speichert Fakten für immer, "meine erinnerungen" zeigt sie, "vergiss alles" löscht sie.
- Neu: JARVIS' Telegram-Bot merkt sich jetzt den Gesprächsverlauf (Anschlussfragen funktionieren) und kann bei aktuellen Fragen selbst das Web durchsuchen.
- Neu: JARVIS' Telegram-Bot versteht jetzt auch Sprachnachrichten (automatische Spracherkennung, kostenlos über Cloudflare).
- Neu: JARVIS' Telegram-Bot antwortet jetzt auch direkt auf Nachrichten, die man ihm in Telegram schreibt — ganz ohne die App zu öffnen.
- Neu: JARVIS kann jetzt auch Kontakte per echtem Telefonanruf erreichen und ihnen etwas ausrichten: "ruf Mama an und sag ihr: bin gleich da".
- Neu: Kostenlose Telegram-Benachrichtigungen als Alternative/Ergänzung zu Anrufen — auch für Kalender-Erinnerungen.
- Neu: Philips-Hue-Lichtsteuerung ("hue Wohnzimmer an", "licht Küche auf 40 prozent") — komplett lokal, keine Cloud.
- Neu: Bosch/Siemens-Hausgerätestatus per Home Connect abfragen ("ist die waschmaschine fertig").
- Neu: "ruf mich an" lässt JARVIS dich tatsächlich anrufen (echter Telefonanruf mit Ansage) — eigenes Twilio-Konto nötig, siehe README.
- Neu: Google-Kalender-Anbindung — Termine per Sprache ansagen lassen oder anlegen ("was steht heute an", "leg einen termin an: ..."), plus automatischer Erinnerungsanruf kurz vor Terminbeginn, auch ohne geöffnete App.
- Neu: Videos lassen sich jetzt auch auf TikTok hochladen ("video auf tiktok hochladen"), mit wählbarer Sichtbarkeit — eigene TikTok-Entwickler-App nötig, siehe README. Wichtig: Ohne bestandenes TikTok-Audit landet jeder Upload automatisch als "Nur ich" (privat), unabhängig von der Auswahl.

## Vorheriges Update
- YouTube-Upload: Sichtbarkeit ist jetzt wählbar (privat/nicht gelistet/öffentlich), statt immer fest auf "privat" — und Videos können optional für eine spätere Veröffentlichungszeit geplant werden (bleibt bis dahin privat, YouTube macht es automatisch öffentlich).
- JARVIS kann den YouTube-Upload jetzt auch per Sprache mit vorausgewählter Sichtbarkeit öffnen ("lade das video öffentlich hoch") — das Video selbst wählst du weiterhin immer manuell aus.

## Ältere Änderungen
- Spotify-Anmeldung funktioniert jetzt auch am PC (Web-Version), nicht mehr nur auf dem Handy — Anmeldung mit dem normalen Spotify-Konto, kein Passwort wird von der App gesehen.
- JARVIS kann jetzt auch eigene Spotify-Playlists abspielen: "spiele playlist \<Name\> auf Spotify".
- Fix: JARVIS antwortete manchmal gar nicht ("Ich habe keine Antwort erhalten."). Ursache war das stärkere KI-Modell, das gelegentlich leer antwortete — zurückgewechselt auf das zuverlässige Vorgänger-Modell.
- JARVIS hat jetzt eine fröhlichere, warmherzigere Persönlichkeit statt trockenem Sarkasmus.
- Logo neu eingefärbt: passt jetzt zum dunklen Gold-Design statt der alten Cyan-Farben.
- Komplett neues, cleanes UI: dunkles Design mit Glas-Optik (Header, Chat-Blasen, Eingabeleiste), goldenem Akzent und neuen Schnellzugriff-Chips (Wetter, Nachrichten, Witz, Hilfe).
- JARVIS kann jetzt selbst im Web recherchieren, statt sich nur auf sein (irgendwann veraltetes) Trainingswissen zu verlassen: "suche im internet nach ..." oder "recherchiere ...". Läuft zero-setup über den eigenen Worker (kein Schlüssel in der App nötig).
- Timer/Erinnerungen kommen jetzt auch als echte Benachrichtigung, selbst wenn die App im Hintergrund oder geschlossen ist.
- Neuer Änderungsverlauf in den Einstellungen zeigt alle bisherigen Updates, nicht nur das neueste.
- Musiksteuerung über Spotify: "spiele \<Song\> auf Spotify" (eigene Spotify-App nötig, siehe README).
- KI-Antworten sind jetzt spürbar klüger dank eines stärkeren KI-Modells.
- JARVIS erinnert sich jetzt an den bisherigen Gesprächsverlauf, statt jede Frage isoliert zu beantworten.
- JARVIS kann jetzt auch per freier Sprache Timer stellen, Notizen speichern, das Wetter abrufen und die Kamera öffnen.
- Überarbeitete JARVIS-Persönlichkeit: pointierter, britischer Humor im Iron-Man-Stil.
- Der Update-Dialog zeigt jetzt an, was sich in der neuen Version geändert hat.
