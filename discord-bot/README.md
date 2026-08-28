# JARVIS Discord-Bot

Lässt JARVIS einem Discord-Sprachkanal beitreten und Antworten laut
vorlesen, wenn man ihn per Slash-Befehl etwas fragt. Läuft als
eigenständiger Node.js-Dienst — nicht auf Cloudflare Workers, weil
Discord-Sprachverbindungen eine dauerhafte, zustandsbehaftete Verbindung
brauchen, die eine zustandslose Request/Response-Umgebung wie Workers
technisch nicht leisten kann. Der Bot nutzt für die eigentliche
KI-Antwort denselben Cloudflare Worker (`worker/ai-proxy.js`), den auch
die JARVIS-App verwendet.

Für die Sprachausgabe kommt [Piper](https://github.com/rhasspy/piper) zum
Einsatz — eine lokale, kostenlose Text-zu-Sprache-Engine mit guten
deutschen Stimmen. Kein API-Schlüssel, keine laufenden Kosten.

**Umfang dieser ersten Version:** JARVIS spricht (liest Antworten vor),
hört aber nicht mit — es gibt keine Spracherkennung. Jede Frage ist
zustandslos, es gibt keinen Gesprächsverlauf zwischen Aufrufen.

## Einrichtung

1. **Discord-Anwendung anlegen**: [discord.com/developers/applications](https://discord.com/developers/applications) → „New Application" → unter „Bot" den **Bot Token** kopieren (für `DISCORD_BOT_TOKEN`), unter „General Information" die **Application ID** kopieren (für `DISCORD_CLIENT_ID`).
2. **Bot einladen**: „OAuth2 → URL Generator" → Scopes `bot` + `applications.commands` auswählen → Bot-Permissions `Connect`, `Speak`, `View Channels`, `Send Messages` → generierte URL öffnen und einem eigenen Server hinzufügen.
3. **Piper installieren**: Release für die eigene Plattform von [github.com/rhasspy/piper/releases](https://github.com/rhasspy/piper/releases) auf den Server laden und entpacken. Ein deutsches Stimmmodell (z. B. `de_DE-thorsten-medium`) von [huggingface.co/rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices/tree/main/de/de_DE) laden — beide Dateien (`.onnx` und `.onnx.json`) werden gebraucht.
4. **Repo auf den Server klonen** (Node.js ≥18 muss installiert sein), dann in diesem Ordner:
   ```bash
   npm install
   cp .env.example .env
   ```
   `.env` ausfüllen: `DISCORD_BOT_TOKEN`, `DISCORD_CLIENT_ID` aus Schritt 1, `PIPER_BIN`/`PIPER_MODEL` mit den Pfaden aus Schritt 3, `AI_BACKEND_URL` mit der eigenen Worker-URL (siehe Haupt-README).
5. **Slash-Befehle registrieren** (einmalig, oder erneut nach Änderungen an `deploy-commands.js`):
   ```bash
   npm run deploy-commands
   ```
6. **Dauerhaft starten**, damit der Bot Neustarts/Abstürze übersteht:
   ```bash
   sudo cp jarvis-discord-bot.service /etc/systemd/system/
   # Pfade in der Datei ggf. an den eigenen Installationsort anpassen
   sudo systemctl enable --now jarvis-discord-bot
   ```
   Zum Testen ohne systemd reicht auch `npm start`.

## Verwenden

In einem Sprachkanal sein, dann irgendwo auf dem Server:

- `/frag text:<Frage> stimme:<Auswahl>` — JARVIS tritt dem Sprachkanal bei (falls noch nicht dort) und liest die Antwort vor. `stimme` ist optional (Discord bietet dabei eine Auswahl an) — ohne Angabe wird die Standardstimme (Thorsten) verwendet.
- `/verlasse` — JARVIS verlässt den Sprachkanal.

Der Bot verlässt einen Sprachkanal auch automatisch nach 5 Minuten
Inaktivität.

## Weitere Stimmen hinzufügen

`/frag` bietet standardmäßig vier deutsche Stimmen zur Auswahl (definiert in `voices.js`): **Thorsten** (männlich, Standard), **Kerstin**, **Eva K** und **Ramona** (alle weiblich). Nur die Stimme, die schon bei der Einrichtung heruntergeladen wurde, funktioniert sofort — wählt man im Dropdown eine noch nicht heruntergeladene Stimme, zeigt der Bot eine Anleitung dafür an.

Zum Nachladen: die passende `.onnx`- und `.onnx.json`-Datei von [huggingface.co/rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices/tree/main/de/de_DE) (den jeweiligen Stimmnamen-Unterordner öffnen) in denselben Ordner legen wie die bereits vorhandene Stimme (also z. B. neben `PIPER_MODEL` aus der `.env`-Datei) — keine weitere Konfiguration nötig.

Um eine fünfte oder andere Stimme zur Auswahl hinzuzufügen: in `voices.js` einen neuen Eintrag ergänzen (Anzeigename, Dateiname, sowie die native Sample-Rate der Stimme — 16000 für `low`/`x_low`-Modelle, 22050 für `medium`/`high`-Modelle, steht auch in der jeweiligen `.onnx.json`) und danach `npm run deploy-commands` erneut ausführen, damit Discord die neue Auswahl anzeigt.
