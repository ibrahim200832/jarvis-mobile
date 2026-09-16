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
// app's own web-search command); everything else in TOOLS either needs the
// phone (contacts, apps, camera, Spotify, uploads) or a token that only
// lives on-device (calendar, weather, news — their API keys are stored in
// the app's Einstellungen, not on the Worker).
const TELEGRAM_TOOLS = TOOLS.filter((t) => t.function.name === 'search_web');

const SYSTEM_PROMPT =
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

  return json({ chat_id: chatId, name: chat.first_name || chat.username || '' });
}

// Telegram calls this whenever someone messages the bot directly (registered
// via setWebhook above). Only replies to the linked owner's chat id — a
// stranger's message is silently ignored, not answered. No tool-calling
// here (call/WhatsApp/app actions need the phone itself, which Telegram
// chats don't have access to), and no conversation memory across messages
// yet — each message is answered on its own.
async function handleTelegramWebhook(request, env) {
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

  const ownerChatId = await env.JARVIS_KV.get('telegram_owner_chat_id');
  if (!ownerChatId || chatId !== ownerChatId) return json({ ok: true });

  let text = message.text;
  const voice = message.voice || message.audio;
  if (!text && voice) {
    try {
      text = await transcribeTelegramVoice(env, voice.file_id);
    } catch (_) {
      await sendTelegramMessage(env, chatId, 'Ich konnte die Sprachnachricht nicht verstehen.');
      return json({ ok: true });
    }
  }
  if (!text) return json({ ok: true });

  const historyKey = `telegram_history_${chatId}`;
  const history = JSON.parse((await env.JARVIS_KV.get(historyKey)) || '[]');

  const systemPrompt =
    `${SYSTEM_PROMPT} Du sprichst hier gerade über Telegram, nicht über die JARVIS-App — deshalb kannst du hier keine ` +
    'Anrufe/WhatsApp/Apps/Kalender/Hue/Home-Connect auslösen, sondern nur in Worten antworten. Websuche steht dir ' +
    'hier trotzdem zur Verfügung, nutze sie wie gewohnt bei aktuellen oder unsicheren Fakten.';
  const messages = [{ role: 'system', content: systemPrompt }, ...history, { role: 'user', content: text }];

  let replyText;
  try {
    const data = await runModel(env, messages, TELEGRAM_TOOLS);
    const toolCall = data.tool_calls?.[0];
    if (toolCall?.name === 'search_web') {
      const query = (typeof toolCall.arguments === 'string' ? JSON.parse(toolCall.arguments) : toolCall.arguments)?.query;
      const results = query ? await braveSearch(query, env) : [];
      replyText = results.length > 0 ? results.slice(0, 2).map((r) => r.description).join(' ') : 'Ich konnte dazu nichts im Web finden.';
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
  const prefix = voice ? `🎤 „${text}"\n\n` : '';
  await sendTelegramMessage(env, chatId, prefix + replyText);
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

async function sendTelegramMessage(env, chatId, message) {
  const res = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text: message }),
  });
  if (!res.ok) {
    throw new Error(`Telegram antwortete mit ${res.status}: ${await res.text()}`);
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

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      refresh_token: config.refresh_token,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      grant_type: 'refresh_token',
    }),
  });
  if (!tokenRes.ok) return;
  const { access_token: accessToken } = await tokenRes.json();
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
    title: r.title ?? '',
    description: (r.description ?? '').replace(/<[^>]*>/g, ''), // Brave highlights matches with <strong> tags
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
