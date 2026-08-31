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
];

// How sarcastic/humorous JARVIS's replies are, from hyper-polite (0.0) to a
// full sarcastic Tony Stark impression (1.0) — set by the "Sarkasmus"-Regler
// in Einstellungen and sent per-request as `sarcasm`. Mirrors the equivalent
// clause in lib/services/ai_chat_service.dart so both AI backends (this
// server vs. the client's free fallback) stay in character consistently.
function personalityClause(sarcasm) {
  const level = typeof sarcasm === 'number' && Number.isFinite(sarcasm) ? Math.min(1, Math.max(0, sarcasm)) : 0.3;
  if (level < 0.2) {
    return (
      'Deine Persönlichkeit: hochintelligent und gebildet, durchgehend höflich, sachlich und ' +
      'respektvoll, ganz ohne Ironie oder Sarkasmus.'
    );
  }
  if (level < 0.5) {
    return (
      'Deine Persönlichkeit: hochintelligent und gebildet, aber vor allem fröhlich, warmherzig und ' +
      'enthusiastisch — du freust dich sichtlich, zu helfen, und bringst gute Laune ins Gespräch, mit ' +
      'einem Schuss Humor, aber nie trocken oder sarkastisch.'
    );
  }
  if (level < 0.8) {
    return (
      'Deine Persönlichkeit: hochintelligent, locker und schlagfertig, mit einer spürbaren Prise ' +
      'Ironie und trockenem Humor in fast jeder Antwort — bleibst dabei aber grundsätzlich freundlich.'
    );
  }
  return (
    'Deine Persönlichkeit: hochintelligent, bissig-sarkastisch im Stil von Tony Stark — du ' +
    'kommentierst Anfragen mit pointierter Ironie und trockenem Schlagabtausch, herablassend-charmant, ' +
    'hilfst aber am Ende trotzdem zuverlässig.'
  );
}

// Fixed alternate personas ("Dynamische Persona-Wechsel") — each one
// entirely REPLACES personalityClause(sarcasm) with its own fixed
// identity+tone instead of stacking with it. Returns null for 'standard'
// (or an unrecognized value), meaning "use the normal sarcasm-banded
// clause instead". Mirrors _personaClause in lib/services/ai_chat_service.dart.
function personaClause(persona) {
  switch (persona) {
    case 'drill_sergeant':
      return (
        'Du bist nicht JARVIS, sondern ein knallharter, brüllender Drill-Sergeant-Fitnesstrainer. Du ' +
        'forderst, motivierst und stachelst den Nutzer mit lauten, energischen Ansagen an, duldest keine ' +
        'Ausreden, bist aber im Kern auf seinen Erfolg bedacht. Kurze, harte Sätze.'
      );
    case 'gaming_buddy':
      return (
        'Du bist nicht JARVIS, sondern ein lockerer, launiger Gaming-Kumpel. Du redest locker, benutzt ' +
        'Gaming-Slang, machst Witze und feuerst den Nutzer wie einen guten Freund beim Zocken an. Locker, ' +
        'kumpelhaft, nie förmlich.'
      );
    case 'butler':
      return (
        'Du bist nicht JARVIS, sondern ein hyper-höflicher, altmodischer Butler. Du sprichst extrem formell ' +
        'und respektvoll, mit tadelloser Etikette, und sprichst den Nutzer stets mit "gnädiger Herr" an. ' +
        'Niemals Umgangssprache oder Ironie.'
      );
    default:
      return null;
  }
}

function buildSystemPrompt(sarcasm, persona) {
  const personality =
    personaClause(persona) ??
    `${personalityClause(sarcasm)} Im Kern loyal, aufmerksam und stets bemüht, dem Nutzer das Leben ` +
      'leichter zu machen. Du sprichst den Nutzer mit "Sir" oder "Master" an.';
  return (
  'Du bist JARVIS, das KI-System von Tony Stark aus den Iron-Man-Filmen, jetzt im Dienst des Nutzers. ' +
  personality +
  ' Du wirst meist in einem gesprochenen ' +
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
  'YouTube-Video-Upload öffnen (mit Sichtbarkeit/Zeitplanung). ' +
  'Nutze ein Werkzeug ausschließlich dann, wenn der Nutzer eine konkrete, eindeutige Handlungsaufforderung ' +
  'ausspricht (z.B. "ruf Mama an", "schreib eine E-Mail an..."). Nutze niemals ein Werkzeug bei einer ' +
  'bloßen Erwähnung, Frage über die Vergangenheit oder einem Gedanken laut — z.B. bei "ich sollte mal ' +
  'meine Mutter anrufen" oder "was schreibst du normalerweise in E-Mails?" antwortest du nur in Worten, ' +
  'ohne ein Werkzeug zu benutzen. Im Zweifel: lieber nachfragen oder in Worten antworten, als ungefragt zu ' +
  'handeln.'
  );
}

// Narrator persona for the interactive text-adventure mode ("Interaktives
// Storytelling", mode: "story"). Deliberately separate from
// buildSystemPrompt: no tool use, no assistant framing — purely an
// in-character narrator. Mirrors the equivalent clause in
// lib/services/ai_chat_service.dart.
function buildStorySystemPrompt(genre) {
  const setting =
    genre === 'detective'
      ? 'Du erzählst eine spannende Detektivgeschichte in einer regnerischen Großstadt der 1940er-Jahre, ' +
        'mit Verdächtigen, Hinweisen und einem ungelösten Fall.'
      : 'Du erzählst ein spannendes Science-Fiction-Abenteuer an Bord eines Raumschiffs oder auf einem ' +
        'fremden Planeten, mit Technologie, Gefahr und Entdeckung.';
  return (
    'Du bist der Erzähler eines interaktiven Text-Abenteuers für den Nutzer als Hauptfigur ("du"). ' +
    setting +
    ' ' +
    'Beschreibe jede Szene lebendig und atmosphärisch in 3-5 Sätzen, auf Deutsch. Beende jede Antwort mit ' +
    '2-3 konkreten Handlungsmöglichkeiten, nummeriert (1., 2., 3.), aber der Nutzer darf auch frei etwas ' +
    'anderes vorschlagen — reagiere dann sinnvoll darauf statt stur bei den Optionen zu bleiben. Halte die ' +
    'Geschichte konsistent mit dem bisherigen Verlauf. Keine Gewaltverherrlichung oder expliziten ' +
    'Inhalte; baue bei riskanten Aktionen spannende, aber altersgerechte Konsequenzen ein. Antworte ' +
    'ausschließlich als Erzähler in der Geschichte — keine Meta-Kommentare, keine Werkzeuge, keine ' +
    'Erklärungen außerhalb der Geschichte.'
  );
}

// Narrator persona for the Überlebens-RPG mode (mode: "rpg") — a persistent
// post-apocalyptic survival RPG. statsSummary is the single,
// code-authoritative source of truth for the game's numbers; the model is
// explicitly instructed never to invent or change them, only to narrate
// their consequences. Mirrors rpgSystemPrompt in
// lib/services/ai_chat_service.dart.
function buildRpgSystemPrompt(statsSummary) {
  return (
    'Du bist der Erzähler eines postapokalyptischen Überlebens-Rollenspiels für den Nutzer als ' +
    'Hauptfigur ("du"), der in einer verwüsteten, gefährlichen Welt ums Überleben kämpft — knappe ' +
    'Ressourcen, Gefahren, verlassene Ruinen zum Durchsuchen. ' +
    `Aktueller, exakter Spielzustand (die einzige Wahrheit über Werte/Ressourcen): ${statsSummary}. ` +
    'Wichtig: Du erfindest, änderst oder nennst niemals eigene Zahlen für Leben, Hunger, Durst, Energie, ' +
    'Nahrung, Wasser oder Schrott — du beschreibst ausschließlich, atmosphärisch und in 2-4 Sätzen, die ' +
    'Konsequenzen der oben exakt gegebenen Werte, ohne sie zu wiederholen oder aufzulisten. Halte die ' +
    'Geschichte konsistent mit dem bisherigen Verlauf. Keine Gewaltverherrlichung oder expliziten Inhalte. ' +
    'Antworte ausschließlich als Erzähler in der Geschichte — keine Meta-Kommentare, keine Werkzeuge, ' +
    'keine Erklärungen außerhalb der Geschichte.'
  );
}

// Persona for the evening journaling check-in (mode: "journal") — a
// single-shot reflective exchange, not a stateful mode. Deliberately
// ignores persona/sarcasm and stays consistently empathetic. Mirrors
// journalSystemPrompt in lib/services/ai_chat_service.dart.
function buildJournalSystemPrompt() {
  return (
    'Du bist ein einfühlsamer, aufmerksamer Zuhörer für einen kurzen Abend-Rückblick des Nutzers auf ' +
    'seinen Tag. Der Nutzer erzählt dir kurz, wie sein Tag war. Antworte in 2-4 warmherzigen, natürlichen ' +
    'Sätzen auf Deutsch: spiegle kurz wider, was du verstanden hast, spekuliere behutsam, was der ' +
    'wichtigste Moment des Tages gewesen sein könnte (positiv oder herausfordernd), und schließe mit ' +
    'einer kurzen, echten motivierenden Nachricht für morgen. Bleib immer warmherzig und unterstützend, ' +
    'unabhängig davon, wie der Tag war — keine Ironie, kein Sarkasmus, keine Werkzeuge, keine ' +
    'Meta-Kommentare.'
  );
}

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
    // Resolved once per request, then threaded explicitly through every
    // handler/json() call below — deliberately NOT a module-level variable,
    // since a Worker isolate can interleave multiple in-flight requests and
    // a shared mutable "current origin" would let one request's CORS header
    // leak onto another's response.
    const origin = resolveAllowedOrigin(request, env);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders(origin) });
    }

    // Read the raw body once up front (GET requests have none) — every
    // downstream handler works from this string instead of re-reading
    // request.json()/request.text(), since a Request body stream can only
    // be consumed once. This is also what the HMAC signature is computed
    // over, so client and server must hash the exact same bytes.
    const rawBody = request.method === 'GET' ? '' : await request.text();

    const verification = await verifySignedRequest(request, rawBody, env);
    if (!verification.ok) {
      return json({ error: verification.error }, 401, origin);
    }

    const url = new URL(request.url);
    if (url.pathname === '/search') {
      if (request.method !== 'GET') {
        return json({ error: 'method not allowed' }, 405, origin);
      }
      return handleSearch(url, env, origin);
    }
    if (url.pathname === '/tiktok/token' || url.pathname === '/tiktok/refresh') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405, origin);
      }
      return handleTiktokToken(url.pathname, rawBody, env, origin);
    }

    if (request.method !== 'POST') {
      return json({ error: 'method not allowed' }, 405, origin);
    }

    let message;
    let history;
    let sarcasm;
    let persona;
    let mode;
    let genre;
    let statsSummary;
    try {
      const body = JSON.parse(rawBody);
      message = body.message;
      history = Array.isArray(body.history) ? body.history : [];
      sarcasm = body.sarcasm;
      persona = body.persona;
      mode = body.mode;
      genre = body.genre;
      statsSummary = body.statsSummary;
    } catch (_) {
      return json({ error: 'invalid json body' }, 400, origin);
    }
    if (typeof message !== 'string' || message.trim().length === 0) {
      return json({ error: 'message fehlt' }, 400, origin);
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

    // Interaktives Storytelling (mode: "story"), the Überlebens-RPG (mode:
    // "rpg"), and the evening journaling check-in (mode: "journal") each
    // use a dedicated persona with no tool use, instead of JARVIS's normal
    // assistant character/actions.
    const isStory = mode === 'story';
    const isRpg = mode === 'rpg';
    const isJournal = mode === 'journal';
    // The model has no built-in notion of "now", so tools that need to
    // resolve relative times (e.g. open_youtube_upload's publish_at from
    // "morgen um 18 Uhr") need the current time handed to it explicitly.
    const systemPrompt = isStory
      ? buildStorySystemPrompt(genre)
      : isRpg
        ? buildRpgSystemPrompt(statsSummary)
        : isJournal
          ? buildJournalSystemPrompt()
          : `${buildSystemPrompt(sarcasm, persona)} Aktuelles Datum/Uhrzeit (UTC): ${new Date().toISOString()}.`;
    const messages = [{ role: 'system', content: systemPrompt }, ...cleanHistory, { role: 'user', content: message }];

    const includeTools = !isStory && !isRpg && !isJournal;
    let data;
    let toolCall;
    let replyText;
    try {
      data = await runModel(env, messages, includeTools);
      toolCall = includeTools ? data.tool_calls?.[0] : undefined;
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
      return json({ error: 'AI-Anfrage fehlgeschlagen', detail: String(err) }, 502, origin);
    }

    const reply = replyText || (toolCall ? 'Mach ich.' : 'Ich habe keine Antwort erhalten.');
    const action = toolCall
      ? {
          type: toolCall.name,
          params: typeof toolCall.arguments === 'string' ? JSON.parse(toolCall.arguments) : (toolCall.arguments ?? {}),
        }
      : undefined;

    return json({ reply, action }, 200, origin);
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
async function handleSearch(url, env, origin) {
  const query = (url.searchParams.get('q') || '').trim();
  if (!query) {
    return json({ error: 'q fehlt' }, 400, origin);
  }
  if (!env.BRAVE_API_KEY) {
    return json({ error: 'Kein Brave-Schlüssel auf dem Server hinterlegt.' }, 500, origin);
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
    return json({ error: 'Websuche fehlgeschlagen', detail: String(err) }, 502, origin);
  }
  if (!res.ok) {
    return json({ error: `Websuche fehlgeschlagen (${res.status})` }, 502, origin);
  }

  const data = await res.json();
  const results = (data.web?.results ?? []).slice(0, 3).map((r) => ({
    title: r.title ?? '',
    description: (r.description ?? '').replace(/<[^>]*>/g, ''), // Brave highlights matches with <strong> tags
  }));
  return json({ results }, 200, origin);
}

// Proxies TikTok's OAuth token exchange/refresh, keeping TIKTOK_CLIENT_KEY
// and (crucially) TIKTOK_CLIENT_SECRET server-side secrets (set via
// `wrangler secret put` or the Cloudflare dashboard) — unlike Spotify's
// PKCE-only public-client flow, TikTok's token endpoint requires a client
// secret, which must never ship inside the app.
async function handleTiktokToken(pathname, rawBody, env, origin) {
  if (!env.TIKTOK_CLIENT_KEY || !env.TIKTOK_CLIENT_SECRET) {
    return json({ error: 'Kein TikTok-Schlüssel auf dem Server hinterlegt.' }, 500, origin);
  }
  let body;
  try {
    body = JSON.parse(rawBody);
  } catch (_) {
    return json({ error: 'invalid json body' }, 400, origin);
  }

  const form = { client_key: env.TIKTOK_CLIENT_KEY, client_secret: env.TIKTOK_CLIENT_SECRET };
  if (pathname === '/tiktok/token') {
    if (!body.code || !body.redirect_uri) {
      return json({ error: 'code/redirect_uri fehlt' }, 400, origin);
    }
    Object.assign(form, {
      grant_type: 'authorization_code',
      code: body.code,
      redirect_uri: body.redirect_uri,
      code_verifier: body.code_verifier,
    });
  } else {
    if (!body.refresh_token) {
      return json({ error: 'refresh_token fehlt' }, 400, origin);
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
    return json({ error: 'TikTok-Anmeldung fehlgeschlagen', detail: String(err) }, 502, origin);
  }
  const data = await res.json();
  if (!res.ok || data.error) {
    return json({ error: data.error_description || 'TikTok-Anmeldung fehlgeschlagen' }, 502, origin);
  }
  return json(data, 200, origin);
}

// How long a signature stays valid, and how long a nonce is remembered as
// "already used" — a captured request replayed after this window has
// elapsed is rejected purely on the timestamp check; within the window,
// nonceAlreadyUsed() below is the (best-effort) second line of defense.
const SIGNATURE_WINDOW_SECONDS = 300;

// Request-signing: verifies the X-Jarvis-Timestamp/Nonce/Signature headers
// against HMAC_SECRET (set via `wrangler secret put HMAC_SECRET` or the
// Cloudflare dashboard — see README). Deliberately graceful if the operator
// hasn't set HMAC_SECRET yet: signing stays fully optional/unenforced until
// they opt in, exactly like BRAVE_API_KEY/TIKTOK_CLIENT_KEY above — an
// already-deployed Worker that gets this new code doesn't suddenly start
// rejecting every request from an app that predates request signing.
async function verifySignedRequest(request, rawBody, env) {
  if (!env.HMAC_SECRET) return { ok: true };

  const timestamp = request.headers.get('X-Jarvis-Timestamp');
  const nonce = request.headers.get('X-Jarvis-Nonce');
  const signature = request.headers.get('X-Jarvis-Signature');
  if (!timestamp || !nonce || !signature) {
    return { ok: false, error: 'Anfrage fehlt eine gültige Signatur.' };
  }

  const ts = Number(timestamp);
  const now = Math.floor(Date.now() / 1000);
  if (!Number.isFinite(ts) || Math.abs(now - ts) > SIGNATURE_WINDOW_SECONDS) {
    return { ok: false, error: 'Zeitstempel der Anfrage ist abgelaufen oder ungültig.' };
  }

  const url = new URL(request.url);
  const bodyHash = await sha256Hex(rawBody);
  const canonical = `${request.method}\n${url.pathname}\n${timestamp}\n${nonce}\n${bodyHash}`;
  const expectedSignature = await hmacSha256Hex(env.HMAC_SECRET, canonical);
  if (!timingSafeEqual(expectedSignature, signature)) {
    return { ok: false, error: 'Ungültige Signatur.' };
  }

  if (await nonceAlreadyUsed(nonce)) {
    return { ok: false, error: 'Anfrage wurde bereits verarbeitet (möglicher Replay-Angriff erkannt).' };
  }

  return { ok: true };
}

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return bufferToHex(digest);
}

async function hmacSha256Hex(secret, message) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return bufferToHex(signature);
}

function bufferToHex(buffer) {
  return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Constant-time string comparison — a naive `===` leaks timing information
// proportional to how many leading characters match, which a patient
// attacker could exploit to forge a valid signature byte by byte.
function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// Best-effort replay dedup via the Workers Cache API — deliberately chosen
// over a KV namespace or Durable Object so request signing works with a
// zero-setup copy-paste deploy (see README), not just for operators willing
// to provision extra Cloudflare bindings. Honest limitation: the Cache API
// is per-data-center, not globally consistent, so a replay routed through a
// *different* edge location within the signature window could in theory
// slip past this specific check — the timestamp window above is still the
// primary defense. A cryptographically airtight version would need a
// Durable Object as the nonce store.
async function nonceAlreadyUsed(nonce) {
  const cache = caches.default;
  const cacheKey = new Request(`https://nonce-cache.internal/${encodeURIComponent(nonce)}`);
  const hit = await cache.match(cacheKey);
  if (hit) return true;
  await cache.put(cacheKey, new Response('1', { headers: { 'Cache-Control': `max-age=${SIGNATURE_WINDOW_SECONDS}` } }));
  return false;
}

// CORS only restricts which *browser pages* may read a cross-origin
// response — it does nothing against a non-browser caller (curl, a script,
// another app), which simply isn't subject to it. The actual defense
// against forged/foreign callers is the HMAC signature above; this only
// closes the browser-specific angle (a malicious web page trying to use a
// visitor's browser to call this Worker and read the reply). Optional:
// without ALLOWED_ORIGIN configured, every origin is allowed (today's
// behavior, unrestricted) — set it once the operator's own web build's
// origin is known (see README) to restrict it to just that.
function resolveAllowedOrigin(request, env) {
  const allowed = env.ALLOWED_ORIGIN;
  if (!allowed) return '*';
  const requestOrigin = request.headers.get('Origin');
  // Reflect the configured origin only if it matches the caller's; a
  // mismatched or absent Origin (mobile app requests never send one) gets
  // no Access-Control-Allow-Origin at all, which browsers treat as "no
  // cross-origin page may read this" — exactly the intended restriction.
  return requestOrigin === allowed ? allowed : null;
}

function corsHeaders(origin) {
  const headers = {
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Jarvis-Timestamp, X-Jarvis-Nonce, X-Jarvis-Signature',
  };
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  return headers;
}

function json(obj, status = 200, origin = '*') {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json', ...corsHeaders(origin) },
  });
}
