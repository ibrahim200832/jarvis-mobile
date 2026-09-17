# Changelog

Kurze, nutzerfreundliche Stichpunkte zu jedem Release. Der oberste Abschnitt
wird beim Deploy automatisch in den "Update verfügbar"-Dialog der App
übernommen (siehe `.github/workflows/deploy-web.yml`).

## Aktuell
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
