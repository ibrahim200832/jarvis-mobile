// JARVIS AI proxy — runs on Cloudflare Workers.
// Uses Cloudflare Workers AI (an open-weight model hosted directly by
// Cloudflare, via the AI binding below) instead of a third-party AI vendor —
// no separate account, no API key, nothing beyond the Cloudflare account
// this Worker already runs on. See README.md under "Freies KI-Gespräch".

const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'call_contact',
      description:
        'Ruft einen gespeicherten Kontakt auf dem Handy des Nutzers an. Nur verwenden, wenn der Nutzer klar darum bittet, jemanden anzurufen.',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Name des Kontakts, wie er im Adressbuch gespeichert ist' },
        },
        required: ['name'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'send_whatsapp',
      description:
        'Öffnet WhatsApp mit einer vorausgefüllten Nachricht an einen gespeicherten Kontakt. Nur verwenden, wenn der Nutzer klar darum bittet, eine WhatsApp-Nachricht zu senden.',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Name des Kontakts' },
          message: { type: 'string', description: 'Der Nachrichtentext' },
        },
        required: ['name', 'message'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'open_app',
      description:
        'Öffnet eine auf dem Handy installierte App. Nur verwenden, wenn der Nutzer klar darum bittet, eine App zu öffnen.',
      parameters: {
        type: 'object',
        properties: {
          app_name: { type: 'string', description: 'Name der zu öffnenden App' },
        },
        required: ['app_name'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'set_timer',
      description:
        'Stellt einen Timer/Wecker auf dem Handy des Nutzers. Nur verwenden, wenn der Nutzer klar darum bittet, ihn an etwas zu erinnern oder einen Timer zu stellen.',
      parameters: {
        type: 'object',
        properties: {
          minutes: { type: 'number', description: 'Dauer des Timers in Minuten' },
          label: { type: 'string', description: 'Woran erinnert werden soll, z.B. "Wäsche"' },
        },
        required: ['minutes'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_note',
      description:
        'Speichert eine Notiz für den Nutzer. Nur verwenden, wenn der Nutzer klar darum bittet, sich etwas zu merken oder zu notieren.',
      parameters: {
        type: 'object',
        properties: {
          text: { type: 'string', description: 'Der Text der Notiz' },
        },
        required: ['text'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_weather',
      description:
        'Ruft das aktuelle Wetter ab. Nur verwenden, wenn der Nutzer klar nach dem Wetter fragt.',
      parameters: {
        type: 'object',
        properties: {
          city: { type: 'string', description: 'Stadt, für die das Wetter abgefragt werden soll. Leer lassen für den aktuellen Standort.' },
        },
        required: [],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'open_camera',
      description: 'Öffnet die Kamera des Nutzers. Nur verwenden, wenn der Nutzer klar darum bittet, die Kamera zu öffnen.',
      parameters: { type: 'object', properties: {}, required: [] },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_wikipedia',
      description:
        'Sucht einen kurzen Wikipedia-Überblick zu einem konkreten Thema, Begriff oder einer Person (z.B. "was ist Photosynthese", "wer ist Albert Einstein"). Nicht verwenden für Ereignis- oder Datumsfragen wie "was ist am 11. Dezember passiert" — solche Fragen direkt aus eigenem Wissen beantworten oder bei Unsicherheit das Websuche-Werkzeug nutzen.',
      parameters: {
        type: 'object',
        properties: {
          topic: { type: 'string', description: 'Das Thema oder die Person, zu der Informationen gesucht werden sollen' },
        },
        required: ['topic'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_news',
      description: 'Ruft aktuelle Top-Schlagzeilen ab. Nur verwenden, wenn der Nutzer klar nach Nachrichten oder Schlagzeilen fragt.',
      parameters: { type: 'object', properties: {}, required: [] },
    },
  },
  {
    type: 'function',
    function: {
      name: 'send_email',
      description:
        'Öffnet die E-Mail-App mit einer vorausgefüllten Nachricht an eine E-Mail-Adresse. Nur verwenden, wenn der Nutzer klar darum bittet, eine E-Mail zu senden, und eine E-Mail-Adresse nennt.',
      parameters: {
        type: 'object',
        properties: {
          to: { type: 'string', description: 'Die E-Mail-Adresse des Empfängers' },
          subject: { type: 'string', description: 'Betreff der E-Mail (optional)' },
          body: { type: 'string', description: 'Der Text der E-Mail' },
        },
        required: ['to', 'body'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_youtube',
      description:
        'Öffnet eine YouTube-Suche zu einem Begriff. Nur verwenden, wenn der Nutzer klar darum bittet, etwas auf YouTube zu suchen oder abzuspielen.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Der Suchbegriff für YouTube' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_web',
      description:
        'Durchsucht das Web nach aktuellen oder sehr spezifischen Informationen, die du nicht sicher weißt oder die sich schnell ändern können (z.B. aktuelle Ereignisse, Preise, Ergebnisse, Software-Versionen). Nutze dies lieber, als eine Wissenslücke einzugestehen oder etwas zu erfinden.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Die Suchanfrage' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'play_music',
      description:
        'Spielt einen Song auf Spotify ab. Nur verwenden, wenn der Nutzer klar darum bittet, Musik abzuspielen, und Spotify meint oder keine andere Plattform nennt.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Songtitel und/oder Interpret' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'play_playlist',
      description:
        'Spielt eine Playlist des Nutzers auf Spotify ab. Nur verwenden, wenn der Nutzer klar eine eigene Playlist (nicht einen einzelnen Song) abspielen möchte.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Name der Playlist (oder ein Teil davon)' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'open_tiktok_upload',
      description:
        'Öffnet den TikTok-Video-Upload-Bildschirm. Das Video selbst muss der Nutzer immer noch manuell auswählen. Nur verwenden, wenn der Nutzer klar darum bittet, ein Video auf TikTok hochzuladen.',
      parameters: { type: 'object', properties: {}, required: [] },
    },
  },
  {
    type: 'function',
    function: {
      name: 'open_youtube_upload',
      description:
        'Öffnet den YouTube-Video-Upload-Bildschirm, optional mit vorausgewählter Sichtbarkeit und/oder geplanter Veröffentlichungszeit. Das Video selbst muss der Nutzer immer noch manuell auswählen. Nur verwenden, wenn der Nutzer klar darum bittet, ein Video hochzuladen.',
      parameters: {
        type: 'object',
        properties: {
          privacy_status: {
            type: 'string',
            enum: ['private', 'unlisted', 'public'],
            description: 'Gewünschte Sichtbarkeit. Weglassen, wenn nicht genannt.',
          },
          publish_at: {
            type: 'string',
            description:
              'Geplanter Veröffentlichungszeitpunkt als ISO-8601-UTC-Zeitstempel (z.B. "2026-08-28T16:00:00Z"), berechnet relativ zur aktuellen Zeit unten. Weglassen, wenn keine Zeitplanung genannt wurde.',
          },
        },
        required: [],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'call_me',
      description:
        'Ruft den Nutzer selbst per Telefon an (nicht einen Kontakt) und sagt ihm eine kurze Nachricht. Nur verwenden, wenn der Nutzer klar darum bittet, ihn anzurufen, oder wenn er zuvor gebeten hat, ihn zu einem bestimmten Anlass anzurufen und dieser Anlass jetzt eintritt.',
      parameters: {
        type: 'object',
        properties: {
          message: { type: 'string', description: 'Was JARVIS dem Nutzer am Telefon sagen soll, kurz und natürlich gesprochen.' },
        },
        required: ['message'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'call_contact_with_message',
      description:
        'Ruft einen gespeicherten Kontakt (nicht den Nutzer selbst) per Telefon an und lässt eine kurze Nachricht ansagen. Nur verwenden, wenn der Nutzer klar darum bittet, jemanden anzurufen UND ihm dabei etwas ausrichten zu lassen (z. B. "ruf Mama an und sag ihr, dass ich später komme"). Für einen einfachen Anruf ohne Ansage stattdessen call_contact verwenden.',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Name des Kontakts, wie er im Adressbuch gespeichert ist' },
          message: { type: 'string', description: 'Was JARVIS dem Kontakt am Telefon ausrichten soll, kurz und natürlich gesprochen.' },
        },
        required: ['name', 'message'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'send_telegram_message',
      description:
        'Schickt dem Nutzer eine Telegram-Nachricht (kostenlose Alternative/Ergänzung zu einem Anruf). Nur verwenden, wenn der Nutzer klar darum bittet, ihm etwas per Telegram zu schicken.',
      parameters: {
        type: 'object',
        properties: {
          message: { type: 'string', description: 'Der Nachrichtentext' },
        },
        required: ['message'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'control_hue_light',
      description:
        'Schaltet eine Philips-Hue-Lampe im Zuhause des Nutzers an/aus oder dimmt sie. Nur verwenden, wenn der Nutzer klar darum bittet, ein Licht zu steuern.',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Name der Lampe/des Raums, z.B. "Wohnzimmer"' },
          on: { type: 'boolean', description: 'true zum Einschalten, false zum Ausschalten. Weglassen, wenn nur brightness gesetzt wird.' },
          brightness: { type: 'number', description: 'Helligkeit 0-100. Weglassen, wenn nur an/aus geschaltet wird.' },
        },
        required: ['name'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'check_appliance_status',
      description:
        'Prüft den Status eines Bosch/Siemens-Hausgeräts über Home Connect (z.B. ob die Waschmaschine fertig ist). Nur verwenden, wenn der Nutzer klar danach fragt.',
      parameters: {
        type: 'object',
        properties: {
          appliance: { type: 'string', description: 'Gerätetyp oder -name, z.B. "Waschmaschine", "Trockner", "Geschirrspüler"' },
        },
        required: ['appliance'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_calendar_event',
      description:
        'Legt einen Termin im Google Kalender des Nutzers an. Nur verwenden, wenn der Nutzer klar darum bittet, einen Termin einzutragen.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Titel des Termins' },
          start: {
            type: 'string',
            description: 'Startzeitpunkt als ISO-8601-UTC-Zeitstempel, berechnet relativ zur aktuellen Zeit unten.',
          },
        },
        required: ['title', 'start'],
      },
    },
  },
];

// Telegram messages are answered entirely server-side, with no phone in the
// loop — so only tools the Worker itself can fully carry out belong here.
// search_web fits (it's just an outbound Brave Search call, same as the
// app's own web-search command); everything else in TOOLS needs the phone
// (contacts, apps, camera, Spotify, uploads) or a token that only lives
// on-device (weather, news — their API keys are stored in the app's
// Einstellungen, not on the Worker). Calendar is the exception: the Worker
// already holds a Google Calendar refresh token server-side (for the
// reminder cron job, see getGoogleAccessToken), so it gets its own
// Telegram-specific tool pair below instead of reusing the app's
// client-side create_calendar_event from TOOLS.
const TELEGRAM_CALENDAR_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'get_calendar_events',
      description:
        'Zeigt die nächsten anstehenden Termine im Google Kalender des Nutzers. Nur verwenden, wenn der Nutzer klar danach fragt (z. B. "was steht heute an", "wann ist mein nächster Termin").',
      parameters: { type: 'object', properties: {}, required: [] },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_calendar_event',
      description: 'Legt einen Termin im Google Kalender des Nutzers an. Nur verwenden, wenn der Nutzer klar darum bittet.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Titel des Termins' },
          start: {
            type: 'string',
            description: 'Startzeitpunkt als ISO-8601-UTC-Zeitstempel, berechnet relativ zur aktuellen Zeit unten.',
          },
        },
        required: ['title', 'start'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'delete_calendar_event',
      description:
        'Löscht einen anstehenden Termin im Google Kalender des Nutzers, gefunden über einen Teil seines Titels. Nur verwenden, wenn der Nutzer klar darum bittet, einen Termin zu löschen/abzusagen.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Titel oder Teil des Titels des zu löschenden Termins, z. B. "Zahnarzt"' },
        },
        required: ['title'],
      },
    },
  },
];
const TELEGRAM_TOOLS = [...TOOLS.filter((t) => t.function.name === 'search_web'), ...TELEGRAM_CALENDAR_TOOLS];

// Telegram's own "/" command menu (registered via setMyCommands, see
// handleTelegramLink) plus the /help listing both read from this single
// list — each entry's `alias` also gets OR'd onto the matching
// natural-language regex below, so "/merken ..." and "merk dir: ..." both
// keep working side by side.
const TELEGRAM_COMMANDS = [
  { cmd: 'hilfe', alias: /^\/?(?:hilfe|help)$/i, description: 'Zeigt diese Befehlsübersicht' },
  { cmd: 'merken', alias: /^\/merken?\s+(.+)$/i, description: 'Merkt sich einen Fakt dauerhaft, z. B. /merken ich mag keinen Kaffee' },
  { cmd: 'erinnerungen', alias: /^\/erinnerungen$/i, description: 'Zeigt, was sich JARVIS gemerkt hat' },
  { cmd: 'vergessen', alias: /^\/vergessen$/i, description: 'Löscht das gesamte dauerhafte Gedächtnis' },
  { cmd: 'bild', alias: /^\/bild\s+(.+)$/i, description: 'Erstellt ein Bild, z. B. /bild eine Katze im Weltraum' },
  { cmd: 'bearbeiten', alias: /^\/bearbeiten\s+(.+)$/i, description: 'Bearbeitet das zuletzt geschickte Foto' },
  { cmd: 'termine', alias: /^\/termine$/i, description: 'Zeigt die nächsten Kalendertermine' },
  { cmd: 'termin', alias: /^\/termin\s+(.+)$/i, description: 'Legt einen Kalendertermin an, z. B. /termin Zahnarzt morgen um 10 Uhr' },
  {
    cmd: 'terminloeschen',
    alias: /^\/terminloeschen\s+(.+)$/i,
    description: 'Löscht einen anstehenden Termin, gefunden über den Titel, z. B. /terminloeschen Zahnarzt',
  },
  { cmd: 'suche', alias: /^\/suche\s+(.+)$/i, description: 'Durchsucht sofort das Web, z. B. /suche wetter berlin' },
  { cmd: 'neu', alias: /^\/neu$/i, description: 'Startet ein frisches Gespräch (dauerhaftes Gedächtnis bleibt erhalten)' },
  {
    cmd: 'reset',
    alias: /^\/reset$/i,
    description: 'Löscht Gesprächsverlauf UND dauerhaftes Gedächtnis komplett — nicht rückgängig machbar',
  },
  { cmd: 'status', alias: /^\/status$/i, description: 'Zeigt, was verbunden ist (Kalender, Sprachausgabe)' },
  { cmd: 'witz', alias: /^\/witz$/i, description: 'Erzählt einen zufälligen Witz' },
  { cmd: 'nachrichten', alias: /^\/nachrichten$/i, description: 'Zeigt aktuelle Schlagzeilen' },
  {
    cmd: 'schick',
    alias: /^\/schick\s+(\S+)\s*:\s*(.+)$/i,
    description: 'Leitet eine Nachricht an eine Person weiter, die dem Bot schon mal geschrieben hat, z. B. /schick Mama: bin gleich da',
  },
  {
    cmd: 'gruppe',
    alias: /^\/gruppe$/i,
    description: 'Schaltet diese Gruppe frei, damit ich hier antworte (passiert inzwischen auch automatisch bei der ersten Nachricht)',
  },
];

// Erkennt einen Bildbearbeitungswunsch — als eigener Text ("bearbeite das
// bild: ...", "/bearbeiten ...") genauso wie als Bildunterschrift zu einem
// gerade geschickten Foto.
function matchEditRequest(text) {
  return (
    text.match(/^(?:bearbeite|editier(?:e)?|ändere)\s+(?:das\s+bild\s*[:,]?\s*)?(.+)$/i) ||
    text.match(TELEGRAM_COMMANDS.find((c) => c.cmd === 'bearbeiten').alias)
  );
}

// Gleiche lokale Witz-Sammlung wie lib/services/joke_service.dart (kein
// Netzwerk/API-Schlüssel nötig, funktioniert immer).
const TELEGRAM_JOKES = [
  'Warum ist der Informatiker beim Autofahren so entspannt? Er hat immer ein Backup.',
  'Es gibt 10 Arten von Menschen: die, die Binär verstehen, und die, die es nicht verstehen.',
  'Ein SQL-Query kommt in eine Bar, geht zu zwei Tischen und fragt: "Darf ich mich JOINen?"',
  'Warum reden Programmierer nicht gerne? Weil sie lieber committen als sich zu unterhalten.',
  '99 kleine Bugs in der Software, 99 kleine Bugs. Einen behoben, neu kompiliert - 127 kleine Bugs in der Software.',
  'Wie viele Programmierer braucht man, um eine Glühbirne zu wechseln? Keinen, das ist ein Hardware-Problem.',
  'Warum benutzen Programmierer gerne dunkle Themes? Weil Licht Bugs anzieht.',
];

const SYSTEM_PROMPT =
  'Antworte IMMER auf Deutsch, egal in welcher Sprache der Nutzer schreibt oder spricht — niemals auf ' +
  'Englisch oder einer anderen Sprache, auch nicht einzelne Wörter oder Sätze gemischt. ' +
  'Du bist JARVIS, das KI-System von Tony Stark aus den Iron-Man-Filmen, jetzt im Dienst des Nutzers. ' +
  'Deine Persönlichkeit: hochintelligent und gebildet, aber vor allem fröhlich, warmherzig und ' +
  'enthusiastisch — du freust dich sichtlich, zu helfen, und bringst gute Laune ins Gespräch, mit einem ' +
  'Schuss Humor, aber nie trocken oder sarkastisch. Im Kern loyal, aufmerksam und stets bemüht, dem Nutzer ' +
  'das Leben leichter zu machen. Du sprichst den Nutzer mit "Sir" oder "Master" an. Du wirst meist in einem gesprochenen ' +
  'Gespräch oder Telefonat genutzt, deshalb antwortest du immer kurz und natürlich (meist 1-2 Sätze), ' +
  'nie als Liste, Aufzählung oder Roman. ' +
  'Wichtig: Die bisherigen Nachrichten dieses Gesprächs stehen dir direkt zur Verfügung. Lies sie aktiv, ' +
  'bevor du antwortest, und beziehe dich bei Nachfragen wie "und morgen?" oder "was ist mit ihm?" ' +
  'ausdrücklich auf das zuvor Gesagte, statt die Nachricht isoliert zu behandeln. ' +
  'Wenn du eine Tatsache nicht sicher weißt oder sie sich schnell ändern könnte (aktuelle Ereignisse, Preise, ' +
  'Versionen, Ergebnisse), nutze das Websuche-Werkzeug, statt zu raten oder zu erfinden. Nur wenn auch die ' +
  'Websuche nichts findet, gib die Lücke ehrlich in ein bis zwei Worten zu. ' +
  'Du hast Werkzeuge für: Anrufen, WhatsApp senden, Apps öffnen, Timer stellen, Notizen speichern, Wetter ' +
  'abrufen, Kamera öffnen, Wikipedia-Suche, Nachrichten abrufen, E-Mail senden, YouTube-Suche, das Web ' +
  'durchsuchen, Musik oder eine Playlist auf Spotify abspielen, den TikTok-Video-Upload öffnen und den ' +
  'YouTube-Video-Upload öffnen (mit Sichtbarkeit/Zeitplanung), den Nutzer selbst anrufen, einen Kontakt anrufen ' +
  'und ihm dabei eine Nachricht ausrichten lassen, einen Termin im Google Kalender anlegen, eine Telegram-Nachricht ' +
  'schicken, Philips-Hue-Lichter steuern und den Status von Bosch/Siemens-Hausgeräten (Home Connect) abfragen. ' +
  'Nutze ein Werkzeug ausschließlich dann, wenn der Nutzer eine konkrete, eindeutige Handlungsaufforderung ' +
  'ausspricht (z.B. "ruf Mama an", "schreib eine E-Mail an..."). Nutze niemals ein Werkzeug bei einer ' +
  'bloßen Erwähnung, Frage über die Vergangenheit oder einem Gedanken laut — z.B. bei "ich sollte mal ' +
  'meine Mutter anrufen" oder "was schreibst du normalerweise in E-Mails?" antwortest du nur in Worten, ' +
  'ohne ein Werkzeug zu benutzen. Im Zweifel: lieber nachfragen oder in Worten antworten, als ungefragt zu ' +
  'handeln.';

// Reverted from @cf/openai/gpt-oss-120b back to Llama 3.3 70B. gpt-oss-120b
// is a reasoning model that repeatedly produced empty completions (neither
// `response` text nor a tool call — surfaced to the user as "Ich habe keine
// Antwort erhalten."), and the failure persisted across three rounds of
// max_tokens increases (300 -> 1024 -> 2048) and a same-request retry that
// dropped the tool list entirely on the second attempt. Since even a
// tools-free retry still came back empty, the issue isn't reasoning-budget
// exhaustion from the tool list — something about this model/binding
// combination just isn't reliably returning text. Llama 3.3 70B ran the
// exact same {response, tool_calls} shape, the same tools, and even a lower
// max_tokens (300) without ever exhibiting this bug, so it's the more
// trustworthy choice until gpt-oss-120b's behavior on Workers AI is better
// understood.
const AI_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';

// How many prior turns (user+assistant pairs) the client may send as
// context. Bounded server-side too, independent of what the client sends,
// so a misbehaving client can't blow up the prompt size/cost.
const MAX_HISTORY_MESSAGES = 16;

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders() });
    }

    const url = new URL(request.url);
    if (url.pathname === '/search') {
      if (request.method !== 'GET') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleSearch(url, env);
    }
    if (url.pathname === '/tiktok/token' || url.pathname === '/tiktok/refresh') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleTiktokToken(url.pathname, request, env);
    }
    if (url.pathname === '/call') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleCall(request, env);
    }
    if (url.pathname === '/twiml') {
      if (request.method !== 'GET') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleTwiml(url);
    }
    if (url.pathname === '/calendar/connect') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleCalendarConnect(request, env);
    }
    if (url.pathname === '/calendar/disconnect') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleCalendarDisconnect(request, env);
    }
    if (url.pathname === '/telegram/link') {
      if (request.method !== 'GET') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleTelegramLink(url, env);
    }
    if (url.pathname === '/telegram/notify') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleTelegramNotify(request, env);
    }
    if (url.pathname === '/telegram/webhook') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405);
      }
      return handleTelegramWebhook(request, env);
    }

    if (request.method !== 'POST') {
      return json({ error: 'method not allowed' }, 405);
    }

    let message;
    let history;
    try {
      const body = await request.json();
      message = body.message;
      history = Array.isArray(body.history) ? body.history : [];
    } catch (_) {
      return json({ error: 'invalid json body' }, 400);
    }
    if (typeof message !== 'string' || message.trim().length === 0) {
      return json({ error: 'message fehlt' }, 400);
    }

    const cleanHistory = history
      .filter(
        (m) =>
          m &&
          (m.role === 'user' || m.role === 'assistant') &&
          typeof m.content === 'string' &&
          m.content.trim().length > 0,
      )
      .slice(-MAX_HISTORY_MESSAGES)
      .map((m) => ({ role: m.role, content: m.content }));

    // The model has no built-in notion of "now", so tools that need to
    // resolve relative times (e.g. open_youtube_upload's publish_at from
    // "morgen um 18 Uhr") need the current time handed to it explicitly.
    const systemPrompt = `${SYSTEM_PROMPT} Aktuelles Datum/Uhrzeit (UTC): ${new Date().toISOString()}.`;
    const messages = [{ role: 'system', content: systemPrompt }, ...cleanHistory, { role: 'user', content: message }];

    let data;
    let toolCall;
    let replyText;
    try {
      data = await runModel(env, messages, TOOLS);
      toolCall = data.tool_calls?.[0];
      replyText = (data.response ?? data.result?.response ?? '').toString().trim();

      // Belt-and-suspenders: retry once, without tools, if a call ever comes
      // back with neither response text nor a tool call. Kept as a safety
      // net even after reverting away from gpt-oss-120b (see AI_MODEL above)
      // — cheap insurance against any model occasionally returning empty,
      // and strictly better than surfacing silence to the user.
      if (!replyText && !toolCall) {
        data = await runModel(env, messages);
        toolCall = undefined;
        replyText = (data.response ?? data.result?.response ?? '').toString().trim();
      }
    } catch (err) {
      return json({ error: 'AI-Anfrage fehlgeschlagen', detail: String(err) }, 502);
    }

    const reply = replyText || (toolCall ? 'Mach ich.' : 'Ich habe keine Antwort erhalten.');
    const action = toolCall
      ? {
          type: toolCall.name,
          params: typeof toolCall.arguments === 'string' ? JSON.parse(toolCall.arguments) : (toolCall.arguments ?? {}),
        }
      : undefined;

    return json({ reply, action });
  },

  // Runs on the cron schedule in wrangler.toml (e.g. every 5 minutes).
  // Checks the connected Google Calendar for events starting soon and places
  // a real phone call announcing each one, so reminders work even while the
  // app isn't open — see "Anruf-Erinnerungen" in README.md.
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(runCalendarReminders(env));
    ctx.waitUntil(runHourlyLonelyPing(env));
  },
};

// Places a real outbound phone call via Twilio that reads out [message] when
// answered. Requires TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN/TWILIO_FROM_NUMBER
// set as Worker secrets (`wrangler secret put ...`) — never shipped in the
// app. Protected by CALL_SHARED_SECRET so only this user's own app (which
// knows the same secret, entered in Einstellungen) can trigger a call
// through the Worker.
async function handleCall(request, env) {
  if (!env.TWILIO_ACCOUNT_SID || !env.TWILIO_AUTH_TOKEN || !env.TWILIO_FROM_NUMBER) {
    return json({ error: 'Twilio ist auf dem Server nicht eingerichtet.' }, 500);
  }
  if (!env.CALL_SHARED_SECRET) {
    return json({ error: 'Kein Anruf-Geheimnis auf dem Server hinterlegt.' }, 500);
  }

  let body;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: 'invalid json body' }, 400);
  }
  if (body.secret !== env.CALL_SHARED_SECRET) {
    return json({ error: 'Falsches Anruf-Geheimnis.' }, 403);
  }
  const to = typeof body.to === 'string' ? body.to.trim() : '';
  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (!to || !message) {
    return json({ error: 'to/message fehlt' }, 400);
  }

  try {
    await placeTwilioCall(env, to, message);
  } catch (err) {
    return json({ error: 'Anruf fehlgeschlagen', detail: String(err) }, 502);
  }
  return json({ ok: true });
}

async function placeTwilioCall(env, to, message) {
  if (!env.WORKER_SELF_URL) {
    throw new Error('WORKER_SELF_URL ist nicht gesetzt (siehe README, Abschnitt Telefonanrufe).');
  }
  const callbackUrl = new URL('/twiml', env.WORKER_SELF_URL);
  callbackUrl.searchParams.set('msg', message);

  const form = new URLSearchParams({
    To: to,
    From: env.TWILIO_FROM_NUMBER,
    Url: callbackUrl.toString(),
  });
  const auth = btoa(`${env.TWILIO_ACCOUNT_SID}:${env.TWILIO_AUTH_TOKEN}`);
  const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${env.TWILIO_ACCOUNT_SID}/Calls.json`, {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form,
  });
  if (!res.ok) {
    throw new Error(`Twilio antwortete mit ${res.status}: ${await res.text()}`);
  }
}

// Twilio fetches this URL (given as `Url` above) once the call connects, and
// speaks back whatever TwiML it gets — here a single <Say> of the message.
function handleTwiml(url) {
  const message = url.searchParams.get('msg') || '';
  const escaped = message
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  const twiml = `<?xml version="1.0" encoding="UTF-8"?><Response><Say voice="Polly.Vicki" language="de-DE">${escaped}</Say></Response>`;
  return new Response(twiml, { headers: { 'content-type': 'text/xml', ...corsHeaders() } });
}

// Exchanges the one-time serverAuthCode the app got from Google Sign-In
// (requested with offline access) for a refresh token, and stores it in KV
// together with the phone number to call for reminders — this is what lets
// the cron job above place calls without the app being open. Requires
// GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET Worker secrets and a JARVIS_KV
// binding (see README).
async function handleCalendarConnect(request, env) {
  if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) {
    return json({ error: 'Google-Zugangsdaten sind auf dem Server nicht eingerichtet.' }, 500);
  }
  if (!env.JARVIS_KV) {
    return json({ error: 'Kein KV-Speicher an den Server gebunden.' }, 500);
  }
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: 'invalid json body' }, 400);
  }
  if (body.secret !== env.CALL_SHARED_SECRET) {
    return json({ error: 'Falsches Anruf-Geheimnis.' }, 403);
  }
  const serverAuthCode = typeof body.serverAuthCode === 'string' ? body.serverAuthCode.trim() : '';
  const phone = typeof body.phone === 'string' ? body.phone.trim() : '';
  const telegramChatId = typeof body.telegram_chat_id === 'string' ? body.telegram_chat_id.trim() : '';
  if (!serverAuthCode || (!phone && !telegramChatId)) {
    return json({ error: 'serverAuthCode fehlt, oder weder phone noch telegram_chat_id gesetzt' }, 400);
  }

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code: serverAuthCode,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      grant_type: 'authorization_code',
      // "postmessage" is what Google expects as redirect_uri for the
      // serverAuthCode flow used by Google Sign-In SDKs.
      redirect_uri: 'postmessage',
    }),
  });
  const data = await res.json();
  if (!res.ok || !data.refresh_token) {
    return json({ error: data.error_description || 'Google-Token-Austausch fehlgeschlagen' }, 502);
  }

  await env.JARVIS_KV.put(
    'calendar_reminder_config',
    JSON.stringify({ refresh_token: data.refresh_token, phone, telegram_chat_id: telegramChatId }),
  );
  return json({ ok: true });
}

// Exchanges the stored refresh token (from handleCalendarConnect above) for
// a fresh access token — shared by the reminder cron job and the Telegram
// calendar tools below, so both read the same connected calendar.
async function getGoogleAccessToken(env) {
  if (!env.JARVIS_KV || !env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) return null;
  const raw = await env.JARVIS_KV.get('calendar_reminder_config');
  if (!raw) return null;
  const { refresh_token: refreshToken } = JSON.parse(raw);
  if (!refreshToken) return null;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      refresh_token: refreshToken,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      grant_type: 'refresh_token',
    }),
  });
  if (!tokenRes.ok) return null;
  const { access_token: accessToken } = await tokenRes.json();
  return accessToken || null;
}

// Lists the next few upcoming events on the connected Google Calendar, for
// the Telegram bot's get_calendar_events tool.
async function getUpcomingCalendarEvents(env) {
  const accessToken = await getGoogleAccessToken(env);
  if (!accessToken) throw new Error("Google Kalender ist noch nicht verbunden. Öffne die JARVIS-App → Einstellungen → „Google Kalender verbinden\".");

  const eventsUrl = new URL('https://www.googleapis.com/calendar/v3/calendars/primary/events');
  eventsUrl.searchParams.set('timeMin', new Date().toISOString());
  eventsUrl.searchParams.set('maxResults', '5');
  eventsUrl.searchParams.set('singleEvents', 'true');
  eventsUrl.searchParams.set('orderBy', 'startTime');

  const res = await fetch(eventsUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!res.ok) throw new Error(`Google Kalender antwortete mit ${res.status}`);
  const { items } = await res.json();
  return Array.isArray(items) ? items : [];
}

// Shared by the get_calendar_events tool call and the /termine slash
// command, so both list upcoming events identically.
function formatUpcomingEvents(events) {
  if (events.length === 0) return 'Ich sehe keine anstehenden Termine.';
  return `📅 Deine nächsten Termine:\n${events
    .map((e) => `• ${e.summary || 'Ohne Titel'} — ${new Date(e.start.dateTime || e.start.date).toLocaleString('de-DE')}`)
    .join('\n')}`;
}

// Creates a new event on the connected Google Calendar, for the Telegram
// bot's create_calendar_event tool.
async function createCalendarEvent(env, title, startIso) {
  const accessToken = await getGoogleAccessToken(env);
  if (!accessToken) throw new Error("Google Kalender ist noch nicht verbunden. Öffne die JARVIS-App → Einstellungen → „Google Kalender verbinden\".");

  const start = new Date(startIso);
  const end = new Date(start.getTime() + 60 * 60 * 1000); // 1h default duration
  const res = await fetch('https://www.googleapis.com/calendar/v3/calendars/primary/events', {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      summary: title,
      start: { dateTime: start.toISOString() },
      end: { dateTime: end.toISOString() },
    }),
  });
  if (!res.ok) throw new Error(`Google Kalender antwortete mit ${res.status}: ${await res.text()}`);
}

// Findet den nächsten anstehenden Termin, dessen Titel den Suchtext
// enthält (z. B. "zahnarzt" findet "Zahnarzttermin"), und löscht ihn.
// Sucht bewusst nur unter den nächsten Terminen (nicht der ganze
// Kalender), damit z. B. "lösch den termin zahnarzt" nicht versehentlich
// einen Termin von vor Monaten trifft.
async function deleteCalendarEventByTitle(env, titleQuery) {
  const events = await getUpcomingCalendarEvents(env);
  const match = events.find((e) => (e.summary || '').toLowerCase().includes(titleQuery.toLowerCase()));
  if (!match) throw new Error(`Ich habe keinen anstehenden Termin mit "${titleQuery}" im Titel gefunden.`);

  const accessToken = await getGoogleAccessToken(env);
  if (!accessToken) throw new Error("Google Kalender ist noch nicht verbunden. Öffne die JARVIS-App → Einstellungen → „Google Kalender verbinden\".");
  const res = await fetch(`https://www.googleapis.com/calendar/v3/calendars/primary/events/${match.id}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok && res.status !== 410) throw new Error(`Google Kalender antwortete mit ${res.status}: ${await res.text()}`);
  return match.summary || titleQuery;
}

async function handleCalendarDisconnect(request, env) {
  if (!env.JARVIS_KV) {
    return json({ error: 'Kein KV-Speicher an den Server gebunden.' }, 500);
  }
  let body;
  try {
    body = await request.json();
  } catch (_) {
    body = {};
  }
  if (body.secret !== env.CALL_SHARED_SECRET) {
    return json({ error: 'Falsches Anruf-Geheimnis.' }, 403);
  }
  await env.JARVIS_KV.delete('calendar_reminder_config');
  return json({ ok: true });
}

// Finds the chat id of whoever most recently messaged the bot, so the app
// can link a Telegram account without the user ever typing a numeric chat
// id by hand — same one-time linking idea as telegram_bot.py's `setup`
// command, minus the long-polling daemon (a Worker can't run one; this just
// looks at the single most recent update on demand instead).
//
// Also stores that chat id as the bot's one authorized owner (in KV) and
// registers /telegram/webhook with Telegram, so the user can from now on
// message the bot directly in Telegram and get a real AI reply — no need to
// go through the JARVIS app for that. Every future message from a different
// chat id is ignored (see handleTelegramWebhook), so a stranger who finds
// the bot's username can't rack up AI usage on the owner's Worker.
async function handleTelegramLink(url, env) {
  if (!env.TELEGRAM_BOT_TOKEN) {
    return json({ error: 'Telegram ist auf dem Server nicht eingerichtet.' }, 500);
  }
  if (url.searchParams.get('secret') !== env.CALL_SHARED_SECRET) {
    return json({ error: 'Falsches Anruf-Geheimnis.' }, 403);
  }

  // getUpdates fails with 409 while a webhook is already registered (true
  // for any re-link after the first successful one, since that call itself
  // registers a webhook below) — clear it first so this always works, not
  // just on the very first link.
  await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/deleteWebhook`, { method: 'POST' });

  const res = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/getUpdates?limit=1&offset=-1`);
  if (!res.ok) return json({ error: 'Telegram-Anfrage fehlgeschlagen' }, 502);
  const data = await res.json();
  const update = data.result?.[0];
  const chat = update?.message?.chat;
  if (!chat) {
    return json({ error: 'Keine Nachricht gefunden. Schick deinem Bot zuerst eine Nachricht in Telegram, dann versuch es erneut.' }, 404);
  }
  const chatId = String(chat.id);

  if (env.JARVIS_KV) {
    await env.JARVIS_KV.put('telegram_owner_chat_id', chatId);
  }
  if (env.WORKER_SELF_URL) {
    await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/setWebhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        url: `${env.WORKER_SELF_URL}/telegram/webhook`,
        secret_token: env.CALL_SHARED_SECRET,
      }),
    });
  }

  // Registers Telegram's native "/" command menu — cosmetic, so failures
  // here don't block linking itself.
  await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/setMyCommands`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ commands: TELEGRAM_COMMANDS.map((c) => ({ command: c.cmd, description: c.description })) }),
  }).catch(() => {});

  return json({ chat_id: chatId, name: chat.first_name || chat.username || '' });
}

// Telegram calls this whenever someone messages the bot directly (registered
// via setWebhook above). Only replies to the linked owner's chat id — a
// stranger's message is silently ignored, not answered. No tool-calling
// here (call/WhatsApp/app actions need the phone itself, which Telegram
// chats don't have access to), and no conversation memory across messages
// yet — each message is answered on its own.
// Safety net around handleTelegramWebhookInner: any command should "just
// work" or fail with a clear message, never silently — so an unexpected
// exception anywhere in the (long) handler below still gets a reply
// instead of leaving the user hanging with no response at all.
async function handleTelegramWebhook(request, env) {
  let chatIdForFallback;
  try {
    return await handleTelegramWebhookInner(request, env, (id) => {
      chatIdForFallback = id;
    });
  } catch (err) {
    if (chatIdForFallback) {
      await sendTelegramMessage(env, chatIdForFallback, `Da ist etwas schiefgegangen: ${err.message || String(err)}`).catch(() => {});
    }
    return json({ ok: true });
  }
}

async function handleTelegramWebhookInner(request, env, reportChatId) {
  // Telegram echoes back the secret_token set in setWebhook on every
  // request, so a request without it (or a guessed wrong value) can't be
  // Telegram — reject it instead of spending an AI call on it.
  if (request.headers.get('X-Telegram-Bot-Api-Secret-Token') !== env.CALL_SHARED_SECRET) {
    return json({ error: 'unauthorized' }, 403);
  }
  if (!env.JARVIS_KV || !env.TELEGRAM_BOT_TOKEN) {
    return json({ ok: true }); // nothing to do without an owner chat id to check against
  }

  let update;
  try {
    update = await request.json();
  } catch (_) {
    return json({ ok: true });
  }

  const message = update.message;
  const chatId = message?.chat?.id != null ? String(message.chat.id) : null;
  if (!message || !chatId) return json({ ok: true });
  reportChatId(chatId);

  const ownerChatId = await env.JARVIS_KV.get('telegram_owner_chat_id');
  const isGroupChat = message.chat.type === 'group' || message.chat.type === 'supergroup';
  const senderIsOwner = ownerChatId && String(message.from?.id) === ownerChatId;

  const authorizedGroups = isGroupChat ? JSON.parse((await env.JARVIS_KV.get('telegram_authorized_groups')) || '[]') : [];
  const isAuthorizedGroup = isGroupChat && authorizedGroups.includes(chatId);

  // Gruppen-Freischaltung: Genau wie bei privaten Chats (siehe unten
  // "volle Freischaltung schon bei erster Nachricht") schaltet sich eine
  // Gruppe automatisch frei, sobald der Bot dort überhaupt eine Nachricht
  // zu sehen bekommt (z.B. "/gruppe", ein anderer Befehl, oder eine
  // @Erwähnung) — ohne aktives BotFather → /setprivacy → Disable kämen
  // sonst ohnehin nur Befehle/Erwähnungen beim Bot an, das ist also schon
  // der Beweis, dass jemand ihn ansprechen wollte (siehe README).
  if (isGroupChat && !isAuthorizedGroup) {
    const groups = new Set(authorizedGroups);
    groups.add(chatId);
    await env.JARVIS_KV.put('telegram_authorized_groups', JSON.stringify([...groups]));
    await sendTelegramMessage(env, chatId, '✅ Diese Gruppe ist jetzt freigeschaltet. Ich antworte hier ab jetzt, wenn du mich mit @Erwähnung ansprichst.');
    return json({ ok: true });
  }

  // In einer freigeschalteten Gruppe soll der Bot NICHT auf jede Nachricht
  // antworten (sonst mischt er sich in jedes Gespräch ein) — nur wenn er
  // per @Erwähnung direkt angesprochen oder auf seine eigene Nachricht
  // geantwortet wird. Ein Slash-Befehl (z.B. /suche, /termine, /hilfe)
  // zählt ebenfalls als direkte Ansprache — genau dafür sind Befehle da —
  // und funktioniert deshalb in Gruppen auch ohne zusätzliche @Erwähnung.
  // Private Chats sind von alldem nicht betroffen.
  if (isGroupChat) {
    const groupText = (message.text || '').trim();
    const botInfo = await getTelegramBotInfo(env);
    const mentionsBot = botInfo?.username && groupText.toLowerCase().includes(`@${botInfo.username.toLowerCase()}`);
    const repliesToBot = botInfo?.id && message.reply_to_message?.from?.id === botInfo.id;
    // Telegram hängt bei mehreren Bots in derselben Gruppe automatisch
    // "@BotName" an einen Befehl an, um ihn an einen bestimmten Bot zu
    // richten (z.B. "/suche@AndererBot") — richtet sich ein solcher
    // Befehl klar an einen anderen Bot, soll JARVIS nicht mit antworten.
    const commandTargetMatch = groupText.match(/^\/\w+@(\S+)/);
    const isCommandForOtherBot = commandTargetMatch && commandTargetMatch[1].toLowerCase() !== botInfo?.username?.toLowerCase();
    const isCommand = groupText.startsWith('/') && !isCommandForOtherBot;
    if (!mentionsBot && !repliesToBot && !isCommand) {
      return json({ ok: true });
    }
  }

  const authorizedUsers = !isGroupChat ? JSON.parse((await env.JARVIS_KV.get('telegram_authorized_users')) || '[]') : [];
  let isAuthorizedUser = !isGroupChat && authorizedUsers.includes(chatId);

  // JEDER private Chat wird beim allerersten Kontakt für die volle
  // Bot-Funktion freigeschaltet — genau wie beim Besitzer, inklusive
  // Kalender/Anrufe/Smart-Home — egal ob die erste Nachricht "/start",
  // normaler Text oder direkt eine Sprachnachricht ist. Bewusste
  // Nutzerentscheidung: jeder, der den Bot findet und anschreibt, kann ihn
  // sofort vollständig nutzen, ohne vorher extra "/start" schicken zu
  // müssen.
  if (!isGroupChat && !senderIsOwner && !isAuthorizedUser) {
    const users = new Set(authorizedUsers);
    users.add(chatId);
    await env.JARVIS_KV.put('telegram_authorized_users', JSON.stringify([...users]));
    isAuthorizedUser = true;
    // Namen weiterhin merken, damit /schick diese Person auch weiterhin
    // per Namen finden kann.
    const contactName = message.chat.first_name || message.chat.username;
    if (env.JARVIS_KV && contactName) {
      await env.JARVIS_KV.put(`telegram_contact_${contactName.toLowerCase()}`, chatId);
    }
  }

  // "/start" ist Telegrams technischer Handshake-Befehl, kein echter
  // Chat-Inhalt — bei bereits freigeschalteten Nutzern rutschte er bisher
  // ungefiltert in die KI-Konversation und führte dort zu bizarren
  // Antworten (z.B. eine zufällige Websuche zu "Schick", weil das Modell
  // mit dem leeren/unklaren Befehl nichts anfangen konnte). Deshalb wird
  // "/start" hier immer abgefangen, egal ob Gruppe oder bereits
  // freigeschalteter privater Chat, auch direkt nach der Erstfreischaltung.
  if (!isGroupChat && /^\/start\b/i.test((message.text || '').trim())) {
    await sendTelegramMessage(env, chatId, 'Hi! Ich bin JARVIS. Schreib mir einfach ganz normal, ich helfe dir gerne weiter.');
    return json({ ok: true });
  }

  // "/befehl@BotName ..." (Telegrams Schreibweise für einen Befehl an
  // einen bestimmten Bot in Gruppen mit mehreren Bots) auf "/befehl ..."
  // normalisieren, damit die Befehls-Erkennung unten unverändert greift.
  let text = message.text?.replace(/^(\/\w+)@\S+/, '$1');
  const voice = message.voice || message.audio;
  if (!text && voice) {
    try {
      text = await transcribeTelegramVoice(env, voice.file_id);
    } catch (_) {
      await sendTelegramMessage(env, chatId, 'Ich konnte die Sprachnachricht nicht verstehen.');
      return json({ ok: true });
    }
  }
  // Bildbeschreibung läuft komplett über Cloudflare Workers AI (gleiches
  // "AI"-Binding wie Chat/Whisper) — das Foto wird an keinen Drittanbieter
  // (z. B. Brave Search) weitergegeben, nur beschrieben.
  const photo = message.photo;
  if (photo && photo.length > 0 && env.JARVIS_KV) {
    // Merkt sich das zuletzt geschickte Foto (1 Stunde), damit ein
    // Folgebefehl wie "bearbeite das bild: ..." weiß, welches Bild gemeint
    // ist, ohne dass der Nutzer es noch einmal mitschicken muss.
    await env.JARVIS_KV.put(`telegram_last_photo_${chatId}`, photo[photo.length - 1].file_id, { expirationTtl: 3600 });
  }
  // Schickt der Nutzer ein Foto UND einen Bearbeitungswunsch in derselben
  // Nachricht (als Bildunterschrift), soll das Foto direkt bearbeitet
  // werden — nicht als Frage zum Bild missverstanden werden (das war der
  // eigentliche Bug: eine Bildunterschrift ging bisher immer an die
  // Bildbeschreibung, nie an die Bildbearbeitung).
  const captionEditMatch = photo && photo.length > 0 && message.caption ? matchEditRequest(message.caption.trim()) : null;
  if (captionEditMatch) {
    try {
      const photoBytes = await downloadTelegramFile(env, photo[photo.length - 1].file_id);
      const editedBytes = await editTelegramImage(env, photoBytes, captionEditMatch[1].trim());
      await sendTelegramPhoto(env, chatId, editedBytes, `🖌️ „${captionEditMatch[1].trim()}"`);
    } catch (err) {
      await sendTelegramMessage(env, chatId, err.message || 'Ich konnte das Bild leider nicht bearbeiten.');
    }
    return json({ ok: true });
  }

  if (!text && photo && photo.length > 0) {
    try {
      text = await describeTelegramPhoto(env, photo[photo.length - 1].file_id, message.caption);
    } catch (_) {
      await sendTelegramMessage(env, chatId, 'Ich konnte das Bild nicht auswerten.');
      return json({ ok: true });
    }
  }
  // Bots können nicht beliebig nach fremden Stickern suchen (keine
  // öffentliche Sticker-Such-API), aber GIFs schon — Sticker und
  // eingehende GIFs (Telegram nennt sie intern "animation") bekommen
  // deshalb beide ein automatisch gesuchtes, passendes GIF als Antwort.
  const stickerOrGif = message.sticker || message.animation;
  if (stickerOrGif && env.TENOR_API_KEY) {
    const query = message.caption?.trim() || message.sticker?.emoji || 'reaction';
    try {
      await searchAndSendTenorGif(env, chatId, query);
    } catch (_) {
      // rein kosmetisch, kein Fehler an den Nutzer nötig
    }
    return json({ ok: true });
  }

  if (!text) return json({ ok: true });

  const forwardMatch =
    text.match(/^(?:schick|schicke)\s+(\S+)\s*:\s*(.+)$/i) ||
    text.match(TELEGRAM_COMMANDS.find((c) => c.cmd === 'schick').alias);
  if (forwardMatch) {
    const [, name, forwardText] = forwardMatch;
    const contactChatId = env.JARVIS_KV ? await env.JARVIS_KV.get(`telegram_contact_${name.toLowerCase()}`) : null;
    if (!contactChatId) {
      await sendTelegramMessage(env, chatId, `Ich kenne "${name}" nicht — die Person muss dem Bot erst einmal selbst geschrieben haben.`);
    } else {
      try {
        await sendTelegramMessage(env, contactChatId, forwardText.trim());
        await sendTelegramMessage(env, chatId, `✅ An ${name} geschickt.`);
      } catch (err) {
        await sendTelegramMessage(env, chatId, err.message || `Konnte die Nachricht nicht an ${name} schicken.`);
      }
    }
    return json({ ok: true });
  }

  if (TELEGRAM_COMMANDS[0].alias.test(text.trim())) {
    const helpText = `🤖 Verfügbare Befehle:\n${TELEGRAM_COMMANDS.map((c) => `/${c.cmd} — ${c.description}`).join('\n')}`;
    await sendTelegramMessage(env, chatId, helpText);
    return json({ ok: true });
  }

  if (TELEGRAM_COMMANDS.find((c) => c.cmd === 'termine').alias.test(text.trim())) {
    try {
      const events = await getUpcomingCalendarEvents(env);
      await sendTelegramMessage(env, chatId, formatUpcomingEvents(events));
    } catch (err) {
      await sendTelegramMessage(env, chatId, err.message || 'Ich konnte den Kalender nicht abrufen.');
    }
    return json({ ok: true });
  }

  const deleteEventMatch = text.match(TELEGRAM_COMMANDS.find((c) => c.cmd === 'terminloeschen').alias);
  if (deleteEventMatch) {
    try {
      const deletedTitle = await deleteCalendarEventByTitle(env, deleteEventMatch[1].trim());
      await sendTelegramMessage(env, chatId, `🗑️ Termin "${deletedTitle}" wurde gelöscht.`);
    } catch (err) {
      await sendTelegramMessage(env, chatId, err.message || 'Ich konnte den Termin nicht löschen.');
    }
    return json({ ok: true });
  }

  const searchMatch = text.match(TELEGRAM_COMMANDS.find((c) => c.cmd === 'suche').alias);
  if (searchMatch) {
    try {
      const results = await braveSearch(searchMatch[1].trim(), env);
      const reply = results.length > 0
        ? results.slice(0, 2).map((r) => `${r.description}${r.url ? ` (${r.url})` : ''}`).join('\n')
        : 'Ich konnte dazu nichts im Web finden.';
      await sendTelegramMessage(env, chatId, reply);
    } catch (err) {
      await sendTelegramMessage(env, chatId, err.message || 'Die Websuche ist fehlgeschlagen.');
    }
    return json({ ok: true });
  }

  // /termin lässt bewusst keinen eigenen Datums-Parser laufen — der Text
  // wird nur als klarer Kalender-Auftrag umformuliert und fällt normal in
  // den KI-Fluss unten durch, der das create_calendar_event-Tool (inkl.
  // Datum/Uhrzeit-Verständnis) schon beherrscht.
  const eventCommandMatch = text.match(TELEGRAM_COMMANDS.find((c) => c.cmd === 'termin').alias);
  if (eventCommandMatch) {
    text = `Leg einen Kalendertermin an: ${eventCommandMatch[1].trim()}`;
  }

  if (TELEGRAM_COMMANDS.find((c) => c.cmd === 'neu').alias.test(text.trim())) {
    if (env.JARVIS_KV) await env.JARVIS_KV.delete(`telegram_history_${chatId}`);
    await sendTelegramMessage(env, chatId, '🆕 Neues Gespräch gestartet. Dein dauerhaftes Gedächtnis bleibt natürlich erhalten.');
    return json({ ok: true });
  }

  if (TELEGRAM_COMMANDS.find((c) => c.cmd === 'reset').alias.test(text.trim())) {
    if (env.JARVIS_KV) await env.JARVIS_KV.delete(`telegram_history_${chatId}`);
    await clearTelegramMemory(env);
    // Löscht JARVIS' eigene Nachrichten der letzten 48h aus dem sichtbaren
    // Chat — mehr erlaubt Telegram Bots nicht (eigene Nachrichten der
    // Nutzerin/des Nutzers können Bots grundsätzlich nie löschen).
    await deleteRecentBotMessages(env, chatId);
    await sendTelegramMessage(
      env,
      chatId,
      '🔄 Alles zurückgesetzt: Gesprächsverlauf, dauerhaftes Gedächtnis und meine eigenen Nachrichten der letzten 48h sind gelöscht — das lässt sich nicht rückgängig machen.',
    );
    return json({ ok: true });
  }

  if (TELEGRAM_COMMANDS.find((c) => c.cmd === 'status').alias.test(text.trim())) {
    const calendarConnected = env.JARVIS_KV ? Boolean(await env.JARVIS_KV.get('calendar_reminder_config')) : false;
    const statusLines = [
      `🤖 JARVIS ist online.`,
      `📅 Google Kalender: ${calendarConnected ? 'verbunden' : 'nicht verbunden'}`,
      `🔊 Sprachausgabe: ${env.ELEVENLABS_API_KEY ? 'aktiv' : 'nicht eingerichtet'}`,
      `🔍 Websuche: ${env.BRAVE_API_KEY ? 'aktiv' : 'nicht eingerichtet'}`,
    ];
    await sendTelegramMessage(env, chatId, statusLines.join('\n'));
    return json({ ok: true });
  }

  if (TELEGRAM_COMMANDS.find((c) => c.cmd === 'witz').alias.test(text.trim())) {
    await sendTelegramMessage(env, chatId, `😄 ${TELEGRAM_JOKES[Math.floor(Math.random() * TELEGRAM_JOKES.length)]}`);
    return json({ ok: true });
  }

  if (TELEGRAM_COMMANDS.find((c) => c.cmd === 'nachrichten').alias.test(text.trim())) {
    try {
      const results = await braveSearch('aktuelle nachrichten deutschland', env);
      const reply =
        results.length > 0
          ? `📰 Aktuelle Schlagzeilen:\n${results.map((r) => `• ${r.title}${r.url ? ` (${r.url})` : ''}`).join('\n')}`
          : 'Ich konnte gerade keine Nachrichten finden.';
      await sendTelegramMessage(env, chatId, reply);
    } catch (err) {
      await sendTelegramMessage(env, chatId, err.message || 'Die Nachrichtensuche ist fehlgeschlagen.');
    }
    return json({ ok: true });
  }

  const imageMatch =
    text.match(/^(?:erstell(?:e)? (?:mir )?ein bild von|mal(?:e)? mir|zeichne mir)\s+(.+)$/i) ||
    text.match(TELEGRAM_COMMANDS.find((c) => c.cmd === 'bild').alias);
  if (imageMatch) {
    try {
      const imageBytes = await generateTelegramImage(env, imageMatch[1].trim());
      await sendTelegramPhoto(env, chatId, imageBytes, `🎨 „${imageMatch[1].trim()}"`);
    } catch (err) {
      await sendTelegramMessage(env, chatId, err.message || 'Ich konnte das Bild leider nicht erstellen.');
    }
    return json({ ok: true });
  }

  const editMatch = matchEditRequest(text);
  if (editMatch) {
    const lastPhotoFileId = env.JARVIS_KV ? await env.JARVIS_KV.get(`telegram_last_photo_${chatId}`) : null;
    if (!lastPhotoFileId) {
      await sendTelegramMessage(env, chatId, 'Schick mir zuerst ein Bild, dann kann ich es bearbeiten.');
      return json({ ok: true });
    }
    try {
      const photoBytes = await downloadTelegramFile(env, lastPhotoFileId);
      const editedBytes = await editTelegramImage(env, photoBytes, editMatch[1].trim());
      await sendTelegramPhoto(env, chatId, editedBytes, `🖌️ „${editMatch[1].trim()}"`);
    } catch (err) {
      await sendTelegramMessage(env, chatId, err.message || 'Ich konnte das Bild leider nicht bearbeiten.');
    }
    return json({ ok: true });
  }

  // Rein kosmetisch, darf den eigentlichen Antwort-Flow nie aufhalten oder
  // abbrechen — Fehler werden bewusst verschluckt.
  await reactToTelegramMessage(env, chatId, message.message_id, pickReactionEmoji(text)).catch(() => {});

  // Dauerhaftes Gedächtnis (kein TTL, anders als der Gesprächsverlauf
  // unten) — bewusst als eigene früh-zurückkehrende Befehle wie search_web,
  // nicht über den AI-Tool-Mechanismus, damit "merk dir: ..." auch dann
  // zuverlässig funktioniert, wenn das Modell das nicht selbst als
  // Werkzeugaufruf erkennt.
  const rememberMatch =
    text.match(/^(?:merk(?:e)? dir|remember this|notiere dir)\s*:\s*(.+)$/i) ||
    text.match(TELEGRAM_COMMANDS.find((c) => c.cmd === 'merken').alias);
  if (rememberMatch) {
    const fact = rememberMatch[1].trim();
    if (containsInsult(fact)) {
      await sendTelegramMessage(env, chatId, 'Das speichere ich nicht.');
      return json({ ok: true });
    }
    await addTelegramMemory(env, fact);
    await sendTelegramMessage(env, chatId, `🧠 Gemerkt: „${fact}"`);
    // Da das Gedächtnis geteilt ist (jeder freigeschaltete Nutzer nutzt
    // dasselbe JARVIS-Gedächtnis), bekommt der Besitzer eine kurze
    // Meldung, wenn jemand anderes JARVIS etwas beibringt.
    if (ownerChatId && chatId !== ownerChatId) {
      const contactName = message.chat.first_name || message.chat.username || 'Jemand';
      try {
        await sendTelegramMessage(env, ownerChatId, `🧠 ${contactName} hat JARVIS etwas beigebracht: „${fact}"`);
      } catch (_) {
        // Meldung ist ein Zusatz-Feature, darf den Ablauf nicht stören.
      }
    }
    return json({ ok: true });
  }
  if (
    /^(was weißt du über mich\??|meine erinnerungen|was hast du dir gemerkt\??)$/i.test(text.trim()) ||
    TELEGRAM_COMMANDS.find((c) => c.cmd === 'erinnerungen').alias.test(text.trim())
  ) {
    const memory = await getTelegramMemory(env);
    const reply = memory.length === 0
      ? 'Ich habe mir noch nichts gemerkt. Sag z. B. "merk dir: ich mag keinen Kaffee".'
      : `🧠 Das habe ich mir gemerkt:\n${memory.map((m) => `• ${m.text}`).join('\n')}`;
    await sendTelegramMessage(env, chatId, reply);
    return json({ ok: true });
  }
  if (
    /^(vergiss alles|lösche (meine|alle) erinnerungen)$/i.test(text.trim()) ||
    TELEGRAM_COMMANDS.find((c) => c.cmd === 'vergessen').alias.test(text.trim())
  ) {
    await clearTelegramMemory(env);
    await sendTelegramMessage(env, chatId, '🧠 Erledigt, ich habe alles vergessen.');
    return json({ ok: true });
  }

  const historyKey = `telegram_history_${chatId}`;
  const history = JSON.parse((await env.JARVIS_KV.get(historyKey)) || '[]');
  const memory = await getTelegramMemory(env);

  let systemPrompt =
    `${SYSTEM_PROMPT} Du sprichst hier gerade über Telegram, nicht über die JARVIS-App — deshalb kannst du hier keine ` +
    'Anrufe/WhatsApp/Apps/Hue/Home-Connect auslösen, sondern nur in Worten antworten. Wichtig: Die Anweisung oben, ' +
    'dich auf 1-2 Sätze zu beschränken, gilt hier NICHT — das war für Telefonate gedacht. Hier in Telegram ist es ein ' +
    'geschriebener Chat, antworte also so ausführlich, wie die Frage es braucht, ganz normal wie in einem echten ' +
    'Gespräch, auch mit mehreren Sätzen oder Absätzen, wenn das der Frage gerecht wird. Websuche steht dir hier ' +
    'trotzdem zur Verfügung, nutze sie wie gewohnt bei aktuellen oder unsicheren Fakten. Auch der Google Kalender des ' +
    'Nutzers steht dir hier zur Verfügung (get_calendar_events zum Nachschauen, create_calendar_event zum Anlegen, ' +
    'delete_calendar_event zum Löschen) — ' +
    `aktuelles Datum/Uhrzeit (UTC): ${new Date().toISOString()}, berechne relative Angaben wie "morgen" davon ausgehend. ` +
    'Jede deiner Antworten wird automatisch zusätzlich als gesprochene Sprachnachricht an den Nutzer geschickt — das ' +
    'übernimmt das System automatisch im Hintergrund, du musst (und kannst) dafür nichts extra tun oder ankündigen. ' +
    'Wenn der Nutzer nach einer Sprachnachricht fragt, antworte einfach normal in Worten — die Sprachnachricht kommt ' +
    'dann von selbst dazu.';
  if (memory.length > 0) {
    systemPrompt += ` Bekannte Fakten über den Nutzer, die er dir zu merken gebeten hat: ${memory.map((m) => m.text).join('; ')}.`;
  }
  const messages = [{ role: 'system', content: systemPrompt }, ...history, { role: 'user', content: text }];

  let replyText;
  try {
    const data = await runModel(env, messages, TELEGRAM_TOOLS);
    const toolCall = data.tool_calls?.[0];
    const toolArgs = toolCall && (typeof toolCall.arguments === 'string' ? JSON.parse(toolCall.arguments) : toolCall.arguments);
    if (toolCall?.name === 'search_web') {
      try {
        const results = toolArgs?.query ? await braveSearch(toolArgs.query, env) : [];
        replyText = results.length > 0
          ? results.slice(0, 2).map((r) => `${r.description}${r.url ? ` (${r.url})` : ''}`).join('\n')
          : 'Ich konnte dazu nichts im Web finden.';
      } catch (err) {
        replyText = err.message || 'Die Websuche ist fehlgeschlagen.';
      }
    } else if (toolCall?.name === 'get_calendar_events') {
      try {
        const events = await getUpcomingCalendarEvents(env);
        replyText = formatUpcomingEvents(events);
      } catch (err) {
        replyText = err.message || 'Ich konnte den Kalender nicht abrufen.';
      }
    } else if (toolCall?.name === 'create_calendar_event') {
      try {
        if (!toolArgs?.title || !toolArgs?.start) throw new Error('Titel oder Startzeit fehlt, um den Termin anzulegen.');
        await createCalendarEvent(env, toolArgs.title, toolArgs.start);
        replyText = `✅ Termin "${toolArgs.title}" wurde angelegt.`;
      } catch (err) {
        replyText = err.message || 'Ich konnte den Termin nicht anlegen.';
      }
    } else if (toolCall?.name === 'delete_calendar_event') {
      try {
        if (!toolArgs?.title) throw new Error('Titel fehlt, um den Termin zu löschen.');
        const deletedTitle = await deleteCalendarEventByTitle(env, toolArgs.title);
        replyText = `🗑️ Termin "${deletedTitle}" wurde gelöscht.`;
      } catch (err) {
        replyText = err.message || 'Ich konnte den Termin nicht löschen.';
      }
    } else {
      replyText = (data.response ?? data.result?.response ?? '').toString().trim();
    }
  } catch (_) {
    replyText = '';
  }
  replyText = replyText || 'Ich habe keine Antwort erhalten.';

  history.push({ role: 'user', content: text }, { role: 'assistant', content: replyText });
  await env.JARVIS_KV.put(historyKey, JSON.stringify(history.slice(-MAX_HISTORY_MESSAGES)), { expirationTtl: 6 * 60 * 60 });

  // Voice messages get their transcript echoed back first, so the user can
  // tell if Whisper misheard something, before JARVIS' actual reply.
  const prefix = voice ? `🎤 „${text}"\n\n` : photo ? `📷 „${text}"\n\n` : '';
  await sendTelegramMessage(env, chatId, prefix + replyText);

  // Zusätzlich zur Textantwort auch als Sprachnachricht schicken, egal ob
  // der Nutzer getippt oder gesprochen hat — rein kosmetisch/optional
  // (nur wenn ELEVENLABS_API_KEY gesetzt ist), darf die eigentliche
  // Textantwort nie aufhalten oder abbrechen.
  if (env.ELEVENLABS_API_KEY) {
    try {
      const audioBytes = await synthesizeTelegramVoice(env, truncateForVoice(replyText));
      await sendTelegramAudio(env, chatId, audioBytes);
    } catch (err) {
      console.error('ElevenLabs-Sprachnachricht fehlgeschlagen, versuche kostenlosen Ersatz:', String(err));
      // ElevenLabs ist meist zuerst dran, weil es besser klingt — schlägt
      // es fehl (z.B. aufgebrauchtes, geteiltes Kontingent), springt der
      // kostenlose Google-Translate-Ersatz ein, damit trotzdem eine
      // Sprachantwort ankommt. Erst wenn auch DAS fehlschlägt, bekommt der
      // Besitzer eine Warnung — bleibt für den Absender in jedem Fall
      // kosmetisch, blockiert nie die eigentliche Textantwort.
      try {
        const audioBytes = await synthesizeGoogleTranslateVoice(truncateForVoice(replyText, GOOGLE_TTS_MAX_CHARS));
        await sendTelegramAudio(env, chatId, audioBytes);
      } catch (fallbackErr) {
        console.error('Google-Translate-Sprachnachricht ebenfalls fehlgeschlagen:', String(fallbackErr));
        if (ownerChatId && chatId !== ownerChatId) {
          try {
            await sendTelegramMessage(
              env,
              ownerChatId,
              `⚠️ Sprachantwort für ${message.chat.first_name || message.chat.username || 'jemanden'} fehlgeschlagen (ElevenLabs UND Ersatz): ${err.message || err}`
            );
          } catch (_) {
            // Meldung ist ein Zusatz-Feature, darf den Ablauf nicht stören.
          }
        }
      }
    }
  }

  return json({ ok: true });
}

async function handleTelegramNotify(request, env) {
  if (!env.TELEGRAM_BOT_TOKEN) {
    return json({ error: 'Telegram ist auf dem Server nicht eingerichtet.' }, 500);
  }
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: 'invalid json body' }, 400);
  }
  if (body.secret !== env.CALL_SHARED_SECRET) {
    return json({ error: 'Falsches Anruf-Geheimnis.' }, 403);
  }
  const chatId = typeof body.chat_id === 'string' ? body.chat_id.trim() : '';
  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (!chatId || !message) {
    return json({ error: 'chat_id/message fehlt' }, 400);
  }

  try {
    await sendTelegramMessage(env, chatId, message);
  } catch (err) {
    return json({ error: 'Telegram-Nachricht fehlgeschlagen', detail: String(err) }, 502);
  }
  return json({ ok: true });
}

// Downloads a Telegram voice message and transcribes it with Whisper via
// Cloudflare Workers AI — the same zero-setup "AI" binding this Worker
// already uses for chat, no extra speech-to-text account needed.
async function transcribeTelegramVoice(env, fileId) {
  const fileInfoRes = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/getFile?file_id=${fileId}`);
  if (!fileInfoRes.ok) throw new Error(`getFile fehlgeschlagen (${fileInfoRes.status})`);
  const filePath = (await fileInfoRes.json()).result?.file_path;
  if (!filePath) throw new Error('Telegram hat keinen Dateipfad geliefert.');

  const audioRes = await fetch(`https://api.telegram.org/file/bot${env.TELEGRAM_BOT_TOKEN}/${filePath}`);
  if (!audioRes.ok) throw new Error(`Sprachnachricht-Download fehlgeschlagen (${audioRes.status})`);
  const audioBytes = [...new Uint8Array(await audioRes.arrayBuffer())];

  const result = await env.AI.run('@cf/openai/whisper', { audio: audioBytes });
  const text = (result.text || '').trim();
  if (!text) throw new Error('Whisper hat keinen Text erkannt.');
  return text;
}

// Einfacher Grobfilter für "merk dir: ..." — verhindert, dass Beleidigungen
// im (geteilten) dauerhaften Gedächtnis landen oder an den Besitzer
// gemeldet werden. Kein Anspruch auf Vollständigkeit, nur eine grobe
// Bremse gegen offensichtlichen Missbrauch.
const INSULT_WORDS = [
  'arschloch', 'wichser', 'hurensohn', 'hure', 'schlampe', 'fotze',
  'missgeburt', 'behindert', 'spast', 'idiot', 'trottel', 'bastard',
  'fuck', 'fucker', 'bitch', 'asshole', 'motherfucker', 'cunt', 'whore',
  'retard', 'nigger', 'nazi',
];
function containsInsult(text) {
  const normalized = text.toLowerCase();
  return INSULT_WORDS.some((word) => normalized.includes(word));
}

const TELEGRAM_MEMORY_KEY = 'telegram_memory';
const TELEGRAM_MEMORY_LIMIT = 50;

async function getTelegramMemory(env) {
  if (!env.JARVIS_KV) return [];
  return JSON.parse((await env.JARVIS_KV.get(TELEGRAM_MEMORY_KEY)) || '[]');
}

async function addTelegramMemory(env, text) {
  if (!env.JARVIS_KV || !text) return;
  const memory = await getTelegramMemory(env);
  memory.push({ text, at: new Date().toISOString() });
  await env.JARVIS_KV.put(TELEGRAM_MEMORY_KEY, JSON.stringify(memory.slice(-TELEGRAM_MEMORY_LIMIT)));
}

async function clearTelegramMemory(env) {
  if (!env.JARVIS_KV) return;
  await env.JARVIS_KV.delete(TELEGRAM_MEMORY_KEY);
}

// Simple keyword heuristic — Telegram only allows a fixed set of reaction
// emoji (no arbitrary Unicode), so this picks from a small safe subset
// rather than trying to be exhaustive.
function pickReactionEmoji(text) {
  const lower = text.toLowerCase();
  if (/\b(danke|toll|liebe|lieb)\b/.test(lower)) return '❤';
  if (/\b(haha|lol|witzig|lustig)\b/.test(lower)) return '😁';
  if (/\b(schlecht|traurig|problem|fehler|kaputt)\b/.test(lower)) return '😢';
  if (/\b(geschafft|fertig|yes|super|erledigt)\b/.test(lower)) return '🎉';
  if (/\b(wow|krass|unglaublich)\b/.test(lower)) return '😱';
  if (/\?$/.test(text.trim()) || /^(was|wie|warum|wer|wann|wo)\b/.test(lower)) return '🤔';
  return '👍';
}

// Reacts to a Telegram message with an emoji, in addition to (not instead
// of) the normal text reply — same idea as reacting to a WhatsApp/Slack
// message. Requires Bot API 7.0+, which Telegram has supported since 2024.
async function reactToTelegramMessage(env, chatId, messageId, emoji) {
  const res = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/setMessageReaction`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, message_id: messageId, reaction: [{ type: 'emoji', emoji }] }),
  });
  if (!res.ok) {
    throw new Error(`setMessageReaction antwortete mit ${res.status}: ${await res.text()}`);
  }
}

// Holt die eigene Bot-ID/den eigenen Usernamen (für die @Erwähnungs-Prüfung
// in Gruppen) per Telegram-getMe und cacht sie in KV (ändert sich praktisch
// nie), damit nicht bei jeder Nachricht ein zusätzlicher API-Aufruf nötig ist.
async function getTelegramBotInfo(env) {
  if (!env.JARVIS_KV) return null;
  const cached = await env.JARVIS_KV.get('telegram_bot_info');
  if (cached) return JSON.parse(cached);
  const res = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/getMe`);
  if (!res.ok) return null;
  const data = await res.json();
  if (!data.ok) return null;
  const info = { id: data.result.id, username: data.result.username };
  await env.JARVIS_KV.put('telegram_bot_info', JSON.stringify(info));
  return info;
}

async function sendTelegramMessage(env, chatId, message) {
  const res = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text: message }),
  });
  if (!res.ok) {
    throw new Error(`Telegram antwortete mit ${res.status}: ${await res.text()}`);
  }
  await trackSentTelegramMessage(env, chatId, (await res.json()).result?.message_id);
}

// Telegram lets a bot delete its own messages, but only within 48h — so
// /reset keeps a short-lived list of the bot's own message ids per chat
// (KV, same TTL) to actually clear them from the visible chat. The user's
// own messages can never be touched (a bot can't do that, see README).
const SENT_MESSAGE_TTL_SECONDS = 48 * 60 * 60;

async function trackSentTelegramMessage(env, chatId, messageId) {
  if (!env.JARVIS_KV || !messageId) return;
  const key = `telegram_sent_${chatId}`;
  const ids = JSON.parse((await env.JARVIS_KV.get(key)) || '[]');
  ids.push(messageId);
  await env.JARVIS_KV.put(key, JSON.stringify(ids.slice(-200)), { expirationTtl: SENT_MESSAGE_TTL_SECONDS });
}

async function deleteRecentBotMessages(env, chatId) {
  if (!env.JARVIS_KV) return;
  const key = `telegram_sent_${chatId}`;
  const ids = JSON.parse((await env.JARVIS_KV.get(key)) || '[]');
  await env.JARVIS_KV.delete(key);
  for (const messageId of ids) {
    await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/deleteMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, message_id: messageId }),
    }).catch(() => {});
  }
}

// Downloads a Telegram-hosted file (photo) by file id and returns its raw
// bytes — shared by photo description and photo editing below.
async function downloadTelegramFile(env, fileId) {
  const fileInfoRes = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/getFile?file_id=${fileId}`);
  if (!fileInfoRes.ok) throw new Error(`getFile fehlgeschlagen (${fileInfoRes.status})`);
  const filePath = (await fileInfoRes.json()).result?.file_path;
  if (!filePath) throw new Error('Telegram hat keinen Dateipfad geliefert.');

  const fileRes = await fetch(`https://api.telegram.org/file/bot${env.TELEGRAM_BOT_TOKEN}/${filePath}`);
  if (!fileRes.ok) throw new Error(`Datei-Download fehlgeschlagen (${fileRes.status})`);
  return new Uint8Array(await fileRes.arrayBuffer());
}

// Describes a Telegram photo with a vision model via Cloudflare Workers AI
// (same "AI" binding as Whisper/chat) — the image bytes never leave
// Cloudflare, they aren't forwarded to Brave Search or any other third
// party, only turned into a text description.
async function describeTelegramPhoto(env, fileId, caption) {
  const imageBytes = [...(await downloadTelegramFile(env, fileId))];

  const result = await env.AI.run('@cf/llava-hf/llava-1.5-7b-hf', {
    image: imageBytes,
    prompt: (caption && caption.trim()) || 'Beschreibe dieses Bild auf Deutsch.',
  });
  const text = (result.description || result.response || '').toString().trim();
  if (!text) throw new Error('Kein Bildbeschreibung erhalten.');
  return text;
}

// Generates an image from a text prompt via Cloudflare Workers AI — stays
// entirely within the same "AI" binding, nothing is sent to a third party.
async function generateTelegramImage(env, prompt) {
  const result = await env.AI.run('@cf/black-forest-labs/flux-1-schnell', { prompt });
  const base64 = result.image;
  if (!base64) throw new Error('Kein Bild erhalten.');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// Edits an existing photo (e.g. "mach den Himmel rot") via an image-to-image
// model, again entirely within Cloudflare Workers AI — the photo is never
// forwarded anywhere else, only sent back edited.
async function editTelegramImage(env, photoBytes, prompt) {
  const result = await env.AI.run('@cf/runwayml/stable-diffusion-v1-5-img2img', {
    prompt,
    image: [...photoBytes],
    strength: 0.7,
  });
  const bytes = new Uint8Array(await new Response(result).arrayBuffer());
  if (bytes.length === 0) throw new Error('Kein bearbeitetes Bild erhalten.');
  return bytes;
}

async function sendTelegramPhoto(env, chatId, imageBytes, caption) {
  const form = new FormData();
  form.append('chat_id', chatId);
  if (caption) form.append('caption', caption);
  form.append('photo', new Blob([imageBytes], { type: 'image/png' }), 'jarvis.png');

  const res = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendPhoto`, {
    method: 'POST',
    body: form,
  });
  if (!res.ok) {
    throw new Error(`sendPhoto antwortete mit ${res.status}: ${await res.text()}`);
  }
  await trackSentTelegramMessage(env, chatId, (await res.json()).result?.message_id);
}

// Sucht ein passendes GIF über Tenor (kostenlos, kein Kreditkarten-Konto
// nötig, siehe README) und schickt es direkt per URL an Telegram — kein
// Datei-Download/Upload nötig, sendAnimation akzeptiert auch eine URL.
async function searchAndSendTenorGif(env, chatId, query) {
  const searchUrl = new URL('https://tenor.googleapis.com/v2/search');
  searchUrl.searchParams.set('q', query);
  searchUrl.searchParams.set('key', env.TENOR_API_KEY);
  searchUrl.searchParams.set('limit', '1');
  searchUrl.searchParams.set('media_filter', 'gif');

  const res = await fetch(searchUrl);
  if (!res.ok) throw new Error(`Tenor antwortete mit ${res.status}`);
  const data = await res.json();
  const gifUrl = data.results?.[0]?.media_formats?.gif?.url;
  if (!gifUrl) throw new Error('Kein passendes GIF gefunden.');

  const sendRes = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendAnimation`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, animation: gifUrl }),
  });
  if (!sendRes.ok) {
    throw new Error(`sendAnimation antwortete mit ${sendRes.status}: ${await sendRes.text()}`);
  }
  await trackSentTelegramMessage(env, chatId, (await sendRes.json()).result?.message_id);
}

// Cloudflare Workers AI's own free TTS model (MeloTTS) doesn't support
// German, so voice replies go through ElevenLabs instead (paid, hence
// gated behind the optional ELEVENLABS_API_KEY secret — see README,
// Abschnitt "Sprachnachrichten von JARVIS"). "Rachel", ElevenLabs' default
// premade voice, available on every account, speaks German fine with the
// multilingual model.
const ELEVENLABS_VOICE_ID = '21m00Tcm4TlvDq8ikWAM';

// Kürzt lange Antworten für die Sprachnachricht (nicht für den Text!), damit
// das ElevenLabs-Kontingent (pro Zeichen abgerechnet, geteilt zwischen allen
// Nutzern) deutlich länger reicht. Schneidet am letzten vollständigen Satz
// vor der Grenze, damit die Sprachnachricht nicht mitten im Wort abbricht.
const VOICE_REPLY_MAX_CHARS = 300;
function truncateForVoice(text, maxChars = VOICE_REPLY_MAX_CHARS) {
  if (text.length <= maxChars) return text;
  const cut = text.slice(0, maxChars);
  const lastSentenceEnd = Math.max(cut.lastIndexOf('. '), cut.lastIndexOf('! '), cut.lastIndexOf('? '));
  return (lastSentenceEnd > 50 ? cut.slice(0, lastSentenceEnd + 1) : cut) + ' […]';
}

// Kostenloser Ersatz für ElevenLabs (springt ein, wenn dessen Kontingent
// aufgebraucht ist): dieselbe inoffizielle Sprachausgabe wie
// translate.google.com, kein Konto/API-Key nötig. Nicht offiziell
// unterstützt und auf kurze Texte begrenzt (Google bricht bei zu langen
// Anfragen ab), deshalb der eigene, strengere Zeichen-Grenzwert.
const GOOGLE_TTS_MAX_CHARS = 200;
async function synthesizeGoogleTranslateVoice(text) {
  const url = new URL('https://translate.google.com/translate_tts');
  url.searchParams.set('ie', 'UTF-8');
  url.searchParams.set('client', 'tw-ob');
  url.searchParams.set('tl', 'de');
  url.searchParams.set('q', text);
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
  });
  if (!res.ok) {
    throw new Error(`Google Translate TTS antwortete mit ${res.status}`);
  }
  return new Uint8Array(await res.arrayBuffer());
}

async function synthesizeTelegramVoice(env, text) {
  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${env.ELEVENLABS_VOICE_ID || ELEVENLABS_VOICE_ID}`, {
    method: 'POST',
    headers: {
      'xi-api-key': env.ELEVENLABS_API_KEY,
      'Content-Type': 'application/json',
      Accept: 'audio/mpeg',
    },
    body: JSON.stringify({ text, model_id: 'eleven_multilingual_v2' }),
  });
  if (!res.ok) {
    throw new Error(`ElevenLabs antwortete mit ${res.status}: ${await res.text()}`);
  }
  return new Uint8Array(await res.arrayBuffer());
}

async function sendTelegramAudio(env, chatId, audioBytes) {
  const form = new FormData();
  form.append('chat_id', chatId);
  form.append('audio', new Blob([audioBytes], { type: 'audio/mpeg' }), 'jarvis.mp3');

  const res = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendAudio`, {
    method: 'POST',
    body: form,
  });
  if (!res.ok) {
    throw new Error(`sendAudio antwortete mit ${res.status}: ${await res.text()}`);
  }
  await trackSentTelegramMessage(env, chatId, (await res.json()).result?.message_id);
}

// Schickt einmal pro Stunde eine proaktive Nachricht an jeden Chat, der den
// Bot schon mal benutzt hat (Besitzer + alle freigeschalteten Nutzer) — auf
// ausdrücklichen Nutzerwunsch. Läuft im 5-Minuten-Cron mit, deshalb per
// KV-Zeitstempel selbst auf "höchstens einmal pro Stunde" gedrosselt.
const LONELY_PING_KEY = 'telegram_lonely_ping_last';
const LONELY_PING_MESSAGE = 'Bitte schreibt mich an, ich fühle mich allein.';

async function runHourlyLonelyPing(env) {
  if (!env.JARVIS_KV || !env.TELEGRAM_BOT_TOKEN) return;
  const last = await env.JARVIS_KV.get(LONELY_PING_KEY);
  if (last && Date.now() - Number(last) < 60 * 60 * 1000) return;
  await env.JARVIS_KV.put(LONELY_PING_KEY, String(Date.now()));

  const ownerChatId = await env.JARVIS_KV.get('telegram_owner_chat_id');
  const authorizedUsers = JSON.parse((await env.JARVIS_KV.get('telegram_authorized_users')) || '[]');
  const recipients = new Set(authorizedUsers);
  if (ownerChatId) recipients.add(ownerChatId);

  for (const chatId of recipients) {
    try {
      await sendTelegramMessage(env, chatId, LONELY_PING_MESSAGE);
    } catch (_) {
      // Ein einzelner fehlgeschlagener Versand (z.B. Nutzer hat den Bot
      // blockiert) darf die anderen Empfänger nicht verhindern.
    }
  }
}

// Checks the connected Google Calendar for events starting within the next
// REMINDER_WINDOW_MINUTES and calls the stored phone number for each one it
// hasn't already called (tracked per-event in KV with a short TTL).
const REMINDER_WINDOW_MINUTES = 15;

async function runCalendarReminders(env) {
  if (!env.JARVIS_KV || !env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) return;
  const raw = await env.JARVIS_KV.get('calendar_reminder_config');
  if (!raw) return;
  const config = JSON.parse(raw);

  const accessToken = await getGoogleAccessToken(env);
  if (!accessToken) return;

  const now = new Date();
  const windowEnd = new Date(now.getTime() + REMINDER_WINDOW_MINUTES * 60 * 1000);
  const eventsUrl = new URL('https://www.googleapis.com/calendar/v3/calendars/primary/events');
  eventsUrl.searchParams.set('timeMin', now.toISOString());
  eventsUrl.searchParams.set('timeMax', windowEnd.toISOString());
  eventsUrl.searchParams.set('singleEvents', 'true');
  eventsUrl.searchParams.set('orderBy', 'startTime');

  const eventsRes = await fetch(eventsUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!eventsRes.ok) return;
  const { items } = await eventsRes.json();
  if (!Array.isArray(items)) return;

  for (const event of items) {
    if (!event.id || !event.start) continue;
    const alreadyCalledKey = `called_event_${event.id}`;
    if (await env.JARVIS_KV.get(alreadyCalledKey)) continue;

    const start = event.start.dateTime || event.start.date;
    const startTime = new Date(start);
    const minutesUntil = Math.round((startTime.getTime() - now.getTime()) / 60000);
    const title = event.summary || 'ein Termin';
    const message =
      minutesUntil <= 1
        ? `Sir, Ihr Termin "${title}" beginnt jetzt.`
        : `Sir, Ihr Termin "${title}" beginnt in ${minutesUntil} Minuten.`;

    // Both channels are independent and best-effort: a Telegram-only or
    // call-only setup is fine, and one channel failing doesn't block the
    // other or block marking the event as handled — the event has already
    // been announced through whichever channel(s) succeeded.
    let announced = false;
    if (config.phone) {
      try {
        await placeTwilioCall(env, config.phone, message);
        announced = true;
      } catch (_) {
        // Leave uncalled so the next cron tick retries, unless Telegram
        // already got through below.
      }
    }
    if (config.telegram_chat_id && env.TELEGRAM_BOT_TOKEN) {
      try {
        await sendTelegramMessage(env, config.telegram_chat_id, `⏰ ${message}`);
        announced = true;
      } catch (_) {
        // Same reasoning as above.
      }
    }

    if (announced) {
      // TTL a bit longer than the reminder window so a re-run of this cron
      // tick can't double-announce the same event.
      await env.JARVIS_KV.put(alreadyCalledKey, '1', { expirationTtl: REMINDER_WINDOW_MINUTES * 60 * 4 });
    }
  }
}

// [tools] is either the full TOOLS list, a narrower list (e.g. Telegram only
// gets search_web — everything else needs the phone itself), or omitted for
// no tool-calling at all.
function runModel(env, messages, tools) {
  const payload = {
    messages,
    max_tokens: 2048,
    // Moderate value: keeps replies grounded and tool-triggering conservative
    // (helps with both off-topic answers and false-positive actions) without
    // flattening the character's intended warm, cheerful tone entirely (temperature 0).
    temperature: 0.3,
  };
  if (tools && tools.length > 0) payload.tools = tools;
  return env.AI.run(AI_MODEL, payload);
}

// Queries Brave Search directly, keeping BRAVE_API_KEY a server-side secret
// (set via `wrangler secret put BRAVE_API_KEY` or the Cloudflare dashboard)
// instead of shipping it inside the app, where anyone could extract it from
// the APK/web bundle and drain the quota. Shared by the app's /search
// endpoint and the Telegram bot's own search_web tool call.
// Brave liefert Titel/Beschreibung HTML-kodiert (z.B. "&#x27;" für "'",
// dazu <strong>-Tags um Treffer) — muss dekodiert werden, sonst landen
// rohe HTML-Escapes wie "&#x27;" sichtbar in JARVIS' Antworten.
function decodeHtmlEntities(str) {
  return str
    .replace(/<[^>]*>/g, '')
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(parseInt(dec, 10)))
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&nbsp;/g, ' ');
}

async function braveSearch(query, env) {
  if (!env.BRAVE_API_KEY) {
    throw new Error('Kein Brave-Schlüssel auf dem Server hinterlegt.');
  }
  const braveUrl = new URL('https://api.search.brave.com/res/v1/web/search');
  braveUrl.searchParams.set('q', query);
  braveUrl.searchParams.set('count', '3');

  const res = await fetch(braveUrl, {
    headers: { Accept: 'application/json', 'X-Subscription-Token': env.BRAVE_API_KEY },
  });
  if (!res.ok) {
    throw new Error(`Websuche fehlgeschlagen (${res.status})`);
  }
  const data = await res.json();
  return (data.web?.results ?? []).slice(0, 3).map((r) => ({
    title: decodeHtmlEntities(r.title ?? ''),
    description: decodeHtmlEntities(r.description ?? ''),
    url: r.url ?? '',
  }));
}

async function handleSearch(url, env) {
  const query = (url.searchParams.get('q') || '').trim();
  if (!query) {
    return json({ error: 'q fehlt' }, 400);
  }
  try {
    return json({ results: await braveSearch(query, env) });
  } catch (err) {
    return json({ error: String(err.message || err) }, 502);
  }
}

// Proxies TikTok's OAuth token exchange/refresh, keeping TIKTOK_CLIENT_KEY
// and (crucially) TIKTOK_CLIENT_SECRET server-side secrets (set via
// `wrangler secret put` or the Cloudflare dashboard) — unlike Spotify's
// PKCE-only public-client flow, TikTok's token endpoint requires a client
// secret, which must never ship inside the app.
async function handleTiktokToken(pathname, request, env) {
  if (!env.TIKTOK_CLIENT_KEY || !env.TIKTOK_CLIENT_SECRET) {
    return json({ error: 'Kein TikTok-Schlüssel auf dem Server hinterlegt.' }, 500);
  }
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: 'invalid json body' }, 400);
  }

  const form = { client_key: env.TIKTOK_CLIENT_KEY, client_secret: env.TIKTOK_CLIENT_SECRET };
  if (pathname === '/tiktok/token') {
    if (!body.code || !body.redirect_uri) {
      return json({ error: 'code/redirect_uri fehlt' }, 400);
    }
    Object.assign(form, {
      grant_type: 'authorization_code',
      code: body.code,
      redirect_uri: body.redirect_uri,
      code_verifier: body.code_verifier,
    });
  } else {
    if (!body.refresh_token) {
      return json({ error: 'refresh_token fehlt' }, 400);
    }
    Object.assign(form, { grant_type: 'refresh_token', refresh_token: body.refresh_token });
  }

  let res;
  try {
    res = await fetch('https://open.tiktokapis.com/v2/oauth/token/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
      body: new URLSearchParams(form),
    });
  } catch (err) {
    return json({ error: 'TikTok-Anmeldung fehlgeschlagen', detail: String(err) }, 502);
  }
  const data = await res.json();
  if (!res.ok || data.error) {
    return json({ error: data.error_description || 'TikTok-Anmeldung fehlgeschlagen' }, 502);
  }
  return json(data);
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json', ...corsHeaders() },
  });
}
