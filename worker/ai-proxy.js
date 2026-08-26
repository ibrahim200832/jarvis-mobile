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
];

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
  'durchsuchen und Musik oder eine Playlist auf Spotify abspielen. ' +
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

    const messages = [{ role: 'system', content: SYSTEM_PROMPT }, ...cleanHistory, { role: 'user', content: message }];

    let data;
    let toolCall;
    let replyText;
    try {
      data = await runModel(env, messages, true);
      toolCall = data.tool_calls?.[0];
      replyText = (data.response ?? data.result?.response ?? '').toString().trim();

      // Belt-and-suspenders: retry once, without tools, if a call ever comes
      // back with neither response text nor a tool call. Kept as a safety
      // net even after reverting away from gpt-oss-120b (see AI_MODEL above)
      // — cheap insurance against any model occasionally returning empty,
      // and strictly better than surfacing silence to the user.
      if (!replyText && !toolCall) {
        data = await runModel(env, messages, false);
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
};

function runModel(env, messages, includeTools) {
  const payload = {
    messages,
    max_tokens: 2048,
    // Moderate value: keeps replies grounded and tool-triggering conservative
    // (helps with both off-topic answers and false-positive actions) without
    // flattening the character's intended warm, cheerful tone entirely (temperature 0).
    temperature: 0.3,
  };
  if (includeTools) payload.tools = TOOLS;
  return env.AI.run(AI_MODEL, payload);
}

// Proxies web-search requests through Brave Search, keeping BRAVE_API_KEY a
// server-side secret (set via `wrangler secret put BRAVE_API_KEY` or the
// Cloudflare dashboard) instead of shipping it inside the app, where anyone
// could extract it from the APK/web bundle and drain the quota.
async function handleSearch(url, env) {
  const query = (url.searchParams.get('q') || '').trim();
  if (!query) {
    return json({ error: 'q fehlt' }, 400);
  }
  if (!env.BRAVE_API_KEY) {
    return json({ error: 'Kein Brave-Schlüssel auf dem Server hinterlegt.' }, 500);
  }

  const braveUrl = new URL('https://api.search.brave.com/res/v1/web/search');
  braveUrl.searchParams.set('q', query);
  braveUrl.searchParams.set('count', '3');

  let res;
  try {
    res = await fetch(braveUrl, {
      headers: { Accept: 'application/json', 'X-Subscription-Token': env.BRAVE_API_KEY },
    });
  } catch (err) {
    return json({ error: 'Websuche fehlgeschlagen', detail: String(err) }, 502);
  }
  if (!res.ok) {
    return json({ error: `Websuche fehlgeschlagen (${res.status})` }, 502);
  }

  const data = await res.json();
  const results = (data.web?.results ?? []).slice(0, 3).map((r) => ({
    title: r.title ?? '',
    description: (r.description ?? '').replace(/<[^>]*>/g, ''), // Brave highlights matches with <strong> tags
  }));
  return json({ results });
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
