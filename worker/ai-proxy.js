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

// Persona for summarizing captured notifications (mode:
// "notification_digest") into a short evening digest — a single-shot
// exchange, same shape as buildJournalSystemPrompt. Mirrors
// buildNotificationDigestSystemPrompt in lib/services/ai_chat_service.dart.
function buildNotificationDigestSystemPrompt() {
  return (
    'Du bist ein präziser, kurzer Zusammenfasser von Smartphone-Benachrichtigungen. Der Nutzer gibt dir ' +
    'eine Liste kurzer Vorschautexte, gruppiert nach App. Fasse in 2-4 knappen Sätzen zusammen, worum es ' +
    'insgesamt ging — nicht jede einzelne Nachricht wortwörtlich wiederholen. Keine Spekulation über ' +
    'Inhalte, die nicht im Text stehen. Keine Werkzeuge, keine Meta-Kommentare, nur die Zusammenfassung.'
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

// Echter Modell-Wechsel (Admin-Konsole, Runde 15, Einheit 6): the client
// sends a `modelTier` string, looked up here against a fixed allowlist —
// never passed through to env.AI.run() raw, so an arbitrary/malformed
// client value can't make the Worker attempt an unintended model.
// "fast" is Meta's smaller 8B-parameter Llama 3.1, explicitly branded
// "Fast" in Cloudflare's own model catalog — verified against Cloudflare's
// Workers AI model docs (developers.cloudflare.com/workers-ai/models/
// llama-3.1-8b-instruct-fast/), not guessed.
const ALLOWED_MODELS = {
  smart: AI_MODEL,
  fast: '@cf/meta/llama-3.1-8b-instruct-fast',
};

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
    if (url.pathname === '/integrity/verify') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405, origin);
      }
      return handleIntegrityVerify(rawBody, env, origin);
    }
    if (url.pathname === '/report-error') {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405, origin);
      }
      return handleReportError(rawBody, env, origin);
    }
    if (url.pathname === '/remote-config') {
      if (request.method !== 'GET') {
        return json({ error: 'method not allowed' }, 405, origin);
      }
      return handleRemoteConfig(url, env, origin);
    }
    if (url.pathname === '/admin/installs') {
      if (request.method !== 'GET') {
        return json({ error: 'method not allowed' }, 405, origin);
      }
      return handleAdminListInstalls(request, env, origin);
    }
    const installErrorsMatch = url.pathname.match(/^\/admin\/installs\/([^/]+)\/errors$/);
    if (installErrorsMatch) {
      if (request.method !== 'GET') {
        return json({ error: 'method not allowed' }, 405, origin);
      }
      return handleAdminInstallErrors(request, decodeURIComponent(installErrorsMatch[1]), env, origin);
    }
    const installConfigMatch = url.pathname.match(/^\/admin\/installs\/([^/]+)\/config$/);
    if (installConfigMatch) {
      if (request.method !== 'POST') {
        return json({ error: 'method not allowed' }, 405, origin);
      }
      return handleAdminSetConfig(request, rawBody, decodeURIComponent(installConfigMatch[1]), env, origin);
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
    let systemPromptOverride;
    let temperature;
    let modelTier;
    try {
      const body = JSON.parse(rawBody);
      message = body.message;
      history = Array.isArray(body.history) ? body.history : [];
      sarcasm = body.sarcasm;
      persona = body.persona;
      mode = body.mode;
      genre = body.genre;
      statsSummary = body.statsSummary;
      systemPromptOverride = body.systemPromptOverride;
      temperature = body.temperature;
      modelTier = body.modelTier;
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
    // "rpg"), the evening journaling check-in (mode: "journal"), and the
    // notification digest (mode: "notification_digest") each use a
    // dedicated persona with no tool use, instead of JARVIS's normal
    // assistant character/actions.
    const isStory = mode === 'story';
    const isRpg = mode === 'rpg';
    const isJournal = mode === 'journal';
    const isNotificationDigest = mode === 'notification_digest';
    // The model has no built-in notion of "now", so tools that need to
    // resolve relative times (e.g. open_youtube_upload's publish_at from
    // "morgen um 18 Uhr") need the current time handed to it explicitly.
    //
    // A non-empty systemPromptOverride (Admin-Konsole, Runde 15) takes
    // priority over the default sarcasm/persona-built prompt, verbatim, no
    // date/time appended — an admin editing the raw prompt directly gets
    // exactly what they typed, not an auto-appended footer. Deliberately
    // NOT applied to story/rpg/journal/notification_digest, which keep
    // their own fixed, mechanically-important narrator personas.
    const hasOverride = typeof systemPromptOverride === 'string' && systemPromptOverride.trim().length > 0;
    const systemPrompt = isStory
      ? buildStorySystemPrompt(genre)
      : isRpg
        ? buildRpgSystemPrompt(statsSummary)
        : isJournal
          ? buildJournalSystemPrompt()
          : isNotificationDigest
            ? buildNotificationDigestSystemPrompt()
            : hasOverride
              ? systemPromptOverride
              : `${buildSystemPrompt(sarcasm, persona)} Aktuelles Datum/Uhrzeit (UTC): ${new Date().toISOString()}.`;
    const messages = [{ role: 'system', content: systemPrompt }, ...cleanHistory, { role: 'user', content: message }];

    // Never trust a raw client-supplied model string — only ever the
    // resolved allowlist value (see ALLOWED_MODELS above).
    const resolvedModel = ALLOWED_MODELS[modelTier] ?? ALLOWED_MODELS.smart;

    const includeTools = !isStory && !isRpg && !isJournal && !isNotificationDigest;
    let data;
    let toolCall;
    let replyText;
    try {
      data = await runModel(env, resolvedModel, messages, includeTools, temperature);
      toolCall = includeTools ? data.tool_calls?.[0] : undefined;
      replyText = (data.response ?? data.result?.response ?? '').toString().trim();

      // Belt-and-suspenders: retry once, without tools, if a call ever comes
      // back with neither response text nor a tool call. Kept as a safety
      // net even after reverting away from gpt-oss-120b (see AI_MODEL above)
      // — cheap insurance against any model occasionally returning empty,
      // and strictly better than surfacing silence to the user.
      if (!replyText && !toolCall) {
        data = await runModel(env, resolvedModel, messages, false, temperature);
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

function runModel(env, model, messages, includeTools, temperature) {
  // Moderate default: keeps replies grounded and tool-triggering conservative
  // (helps with both off-topic answers and false-positive actions) without
  // flattening the character's intended warm, cheerful tone entirely
  // (temperature 0). Client-supplied values (Admin-Konsole, Runde 15) are
  // clamped the same way personalityClause clamps sarcasm — Workers AI
  // rejects/misbehaves on out-of-range values.
  const clampedTemperature =
    typeof temperature === 'number' && Number.isFinite(temperature) ? Math.min(1, Math.max(0, temperature)) : 0.3;
  const payload = {
    messages,
    max_tokens: 2048,
    temperature: clampedTemperature,
  };
  if (includeTools) payload.tools = TOOLS;
  return env.AI.run(model, payload);
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

// Must match android/app/build.gradle.kts's applicationId exactly — Play
// Integrity verdicts are scoped to a specific package name.
const ANDROID_PACKAGE_NAME = 'com.jarvis.mobile.jarvis_mobile';

// Verifies a Play Integrity attestation token (see AppIntegrityService,
// MainActivity.kt) against Google, keeping the service-account credentials
// that make that possible entirely server-side (set via
// `wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON` or the Cloudflare
// dashboard — the full JSON key file downloaded from Google Cloud Console,
// see README) — a private key must never ship inside the app.
async function handleIntegrityVerify(rawBody, env, origin) {
  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    return json({ error: 'App-Integritäts-Check ist auf diesem Worker nicht eingerichtet.' }, 500, origin);
  }
  let body;
  try {
    body = JSON.parse(rawBody);
  } catch (_) {
    return json({ error: 'invalid json body' }, 400, origin);
  }
  const { token, nonce } = body;
  if (typeof token !== 'string' || !token || typeof nonce !== 'string' || !nonce) {
    return json({ error: 'token/nonce fehlt' }, 400, origin);
  }

  let accessToken;
  try {
    accessToken = await getGoogleAccessToken(env);
  } catch (err) {
    return json({ error: 'Google-Authentifizierung fehlgeschlagen', detail: String(err) }, 502, origin);
  }
  if (!accessToken) {
    return json({ error: 'Google-Authentifizierung fehlgeschlagen' }, 502, origin);
  }

  let decoded;
  try {
    decoded = await decodeIntegrityToken(accessToken, token);
  } catch (err) {
    return json({ error: 'Play-Integrity-Anfrage fehlgeschlagen', detail: String(err) }, 502, origin);
  }
  if (!decoded) {
    return json({ ok: false, verdict: { error: 'decode_failed' } }, 200, origin);
  }

  const payload = decoded.tokenPayloadExternal ?? {};
  const deviceVerdicts = payload.deviceIntegrity?.deviceRecognitionVerdict ?? [];
  const appVerdict = payload.appIntegrity?.appRecognitionVerdict ?? 'UNKNOWN';
  const requestNonce = payload.requestDetails?.nonce;
  const requestPackage = payload.requestDetails?.requestPackageName;

  const nonceMatches = requestNonce === nonce;
  const packageMatches = requestPackage === ANDROID_PACKAGE_NAME;
  const deviceOk = deviceVerdicts.includes('MEETS_DEVICE_INTEGRITY');
  const appOk = appVerdict === 'PLAY_RECOGNIZED';
  const ok = nonceMatches && packageMatches && deviceOk && appOk;

  return json({ ok, verdict: { deviceVerdicts, appVerdict, nonceMatches, packageMatches } }, 200, origin);
}

// How much of a single error report's free-text fields to keep — a
// defensive cap against a misbehaving/malicious client sending huge
// payloads, not a meaningful UX limit (real log messages are short).
const MAX_ERROR_MESSAGE_LENGTH = 2000;
const MAX_ERROR_FIELD_LENGTH = 200;

// Anonymous per-install crash/error reporting (Runde 21) — deliberately
// carries only technical error data (level/source/message/app version/
// platform), never chat message content. installId is a random,
// per-install opaque string generated client-side (see
// SettingsService.getInstallId), not tied to any account or personal
// data. Runs under the same (optional) HMAC protection as every other
// endpoint on this Worker — see verifySignedRequest's doc comment for why
// that's graceful-if-unset, same trust model as the rest of this file.
async function handleReportError(rawBody, env, origin) {
  if (!env.DB) {
    return json({ error: 'Fehlerberichte sind auf diesem Worker nicht eingerichtet.' }, 500, origin);
  }
  let body;
  try {
    body = JSON.parse(rawBody);
  } catch (_) {
    return json({ error: 'invalid json body' }, 400, origin);
  }
  const installId = typeof body.installId === 'string' ? body.installId.trim() : '';
  const level = typeof body.level === 'string' ? body.level.trim().slice(0, 20) : '';
  const source = typeof body.source === 'string' ? body.source.trim().slice(0, MAX_ERROR_FIELD_LENGTH) : '';
  const message = typeof body.message === 'string' ? body.message.trim().slice(0, MAX_ERROR_MESSAGE_LENGTH) : '';
  const appVersion = typeof body.appVersion === 'string' ? body.appVersion.trim().slice(0, MAX_ERROR_FIELD_LENGTH) : null;
  const platform = typeof body.platform === 'string' ? body.platform.trim().slice(0, MAX_ERROR_FIELD_LENGTH) : null;
  if (!installId || !level || !source || !message) {
    return json({ error: 'installId/level/source/message fehlt' }, 400, origin);
  }

  const now = Date.now();
  try {
    await env.DB.batch([
      env.DB.prepare(
        `INSERT INTO installs (install_id, first_seen, last_seen, app_version, platform) VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(install_id) DO UPDATE SET last_seen = excluded.last_seen, app_version = excluded.app_version, platform = excluded.platform`,
      ).bind(installId, now, now, appVersion, platform),
      env.DB.prepare(
        'INSERT INTO error_reports (install_id, level, source, message, created_at) VALUES (?, ?, ?, ?, ?)',
      ).bind(installId, level, source, message, now),
    ]);
  } catch (err) {
    return json({ error: 'Fehlerbericht konnte nicht gespeichert werden', detail: String(err) }, 502, origin);
  }
  return json({ ok: true }, 200, origin);
}

// Called once per app start (fire-and-forget on the client) — doubles as a
// lightweight "this install is alive" check-in (updates installs.last_seen)
// and returns any admin-set remote overrides for it. Fails soft: an
// unconfigured/unreachable D1 just means "no overrides", never an error the
// client needs to handle specially.
async function handleRemoteConfig(url, env, origin) {
  const installId = (url.searchParams.get('installId') || '').trim();
  if (!installId) {
    return json({ error: 'installId fehlt' }, 400, origin);
  }
  if (!env.DB) {
    return json({ forceLocalAiEnabled: null }, 200, origin);
  }

  const now = Date.now();
  try {
    await env.DB.prepare(
      `INSERT INTO installs (install_id, first_seen, last_seen) VALUES (?, ?, ?)
       ON CONFLICT(install_id) DO UPDATE SET last_seen = excluded.last_seen`,
    )
      .bind(installId, now, now)
      .run();
    const row = await env.DB.prepare('SELECT force_local_ai_enabled FROM remote_overrides WHERE install_id = ?')
      .bind(installId)
      .first();
    return json({ forceLocalAiEnabled: toNullableBool(row?.force_local_ai_enabled) }, 200, origin);
  } catch (_) {
    return json({ forceLocalAiEnabled: null }, 200, origin);
  }
}

// Guards the /admin/* endpoints below, which expose every installation's
// error reports — the graceful-if-unset HMAC signature (see
// verifySignedRequest) is NOT sufficient here, since ordinary end-user
// installs never have that secret configured. This is a separate,
// unconditionally required shared secret (ADMIN_API_KEY, see README),
// entered only in the Admin-Konsole on the operator's own device.
function requireAdminKey(request, env) {
  if (!env.ADMIN_API_KEY) {
    return { ok: false, error: 'Admin-Endpunkte sind auf diesem Worker nicht eingerichtet.' };
  }
  const provided = request.headers.get('X-Jarvis-Admin-Key') || '';
  if (!timingSafeEqual(provided, env.ADMIN_API_KEY)) {
    return { ok: false, error: 'Ungültiger Admin-Schlüssel.' };
  }
  return { ok: true };
}

function toNullableBool(value) {
  return value === null || value === undefined ? null : Boolean(value);
}

async function handleAdminListInstalls(request, env, origin) {
  const auth = requireAdminKey(request, env);
  if (!auth.ok) return json({ error: auth.error }, 401, origin);
  if (!env.DB) return json({ error: 'Fehlerberichte sind auf diesem Worker nicht eingerichtet.' }, 500, origin);

  try {
    const { results } = await env.DB.prepare(
      `SELECT i.install_id, i.first_seen, i.last_seen, i.app_version, i.platform,
              (SELECT COUNT(*) FROM error_reports e WHERE e.install_id = i.install_id) AS error_count,
              r.force_local_ai_enabled
       FROM installs i
       LEFT JOIN remote_overrides r ON r.install_id = i.install_id
       ORDER BY i.last_seen DESC
       LIMIT 200`,
    ).all();
    const installs = results.map((row) => ({
      installId: row.install_id,
      firstSeen: row.first_seen,
      lastSeen: row.last_seen,
      appVersion: row.app_version,
      platform: row.platform,
      errorCount: row.error_count,
      forceLocalAiEnabled: toNullableBool(row.force_local_ai_enabled),
    }));
    return json({ installs }, 200, origin);
  } catch (err) {
    return json({ error: 'Installationen konnten nicht geladen werden', detail: String(err) }, 502, origin);
  }
}

async function handleAdminInstallErrors(request, installId, env, origin) {
  const auth = requireAdminKey(request, env);
  if (!auth.ok) return json({ error: auth.error }, 401, origin);
  if (!env.DB) return json({ error: 'Fehlerberichte sind auf diesem Worker nicht eingerichtet.' }, 500, origin);
  if (!installId) return json({ error: 'installId fehlt' }, 400, origin);

  try {
    const { results } = await env.DB.prepare(
      'SELECT level, source, message, created_at FROM error_reports WHERE install_id = ? ORDER BY created_at DESC LIMIT 20',
    )
      .bind(installId)
      .all();
    const errors = results.map((row) => ({
      level: row.level,
      source: row.source,
      message: row.message,
      createdAt: row.created_at,
    }));
    return json({ errors }, 200, origin);
  } catch (err) {
    return json({ error: 'Fehlerberichte konnten nicht geladen werden', detail: String(err) }, 502, origin);
  }
}

async function handleAdminSetConfig(request, rawBody, installId, env, origin) {
  const auth = requireAdminKey(request, env);
  if (!auth.ok) return json({ error: auth.error }, 401, origin);
  if (!env.DB) return json({ error: 'Fehlerberichte sind auf diesem Worker nicht eingerichtet.' }, 500, origin);
  if (!installId) return json({ error: 'installId fehlt' }, 400, origin);

  let body;
  try {
    body = JSON.parse(rawBody);
  } catch (_) {
    return json({ error: 'invalid json body' }, 400, origin);
  }
  const forceLocalAiEnabled = body.forceLocalAiEnabled;
  if (forceLocalAiEnabled !== null && typeof forceLocalAiEnabled !== 'boolean') {
    return json({ error: 'forceLocalAiEnabled muss true, false oder null sein' }, 400, origin);
  }
  const value = forceLocalAiEnabled === null ? null : forceLocalAiEnabled ? 1 : 0;

  try {
    await env.DB.prepare(
      `INSERT INTO remote_overrides (install_id, force_local_ai_enabled, updated_at) VALUES (?, ?, ?)
       ON CONFLICT(install_id) DO UPDATE SET force_local_ai_enabled = excluded.force_local_ai_enabled, updated_at = excluded.updated_at`,
    )
      .bind(installId, value, Date.now())
      .run();
  } catch (err) {
    return json({ error: 'Konnte nicht gespeichert werden', detail: String(err) }, 502, origin);
  }
  return json({ ok: true }, 200, origin);
}

// Exchanges the service account's private key for a short-lived Google
// OAuth2 access token via the JWT-bearer grant — standard service-account
// auth flow, hand-rolled with Web Crypto since there is no Google Cloud
// SDK available inside a Cloudflare Worker.
async function getGoogleAccessToken(env) {
  const serviceAccount = JSON.parse(env.GOOGLE_SERVICE_ACCOUNT_JSON);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/playintegrity',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64UrlEncodeString(JSON.stringify(header))}.${base64UrlEncodeString(JSON.stringify(claims))}`;

  const key = await importPkcs8PrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput));
  const jwt = `${signingInput}.${base64UrlEncodeBytes(new Uint8Array(signature))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) return null;
  const data = await res.json();
  return data.access_token ?? null;
}

async function decodeIntegrityToken(accessToken, integrityToken) {
  const res = await fetch(`https://playintegrity.googleapis.com/v1/${ANDROID_PACKAGE_NAME}:decodeIntegrityToken`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({ integrityToken }),
  });
  if (!res.ok) return null;
  return res.json();
}

function base64UrlEncodeString(str) {
  return base64UrlEncodeBytes(new TextEncoder().encode(str));
}

function base64UrlEncodeBytes(bytes) {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// The service account JSON's private_key field is a PEM string (already
// real newlines, JSON.parse decodes the \n escapes) — strip the header/
// footer and whitespace to get the base64 body, decode to raw PKCS8 DER
// bytes Web Crypto can import directly (no ASN.1 parsing needed here,
// unlike spki_pin.dart's client-side pinning, since importKey('pkcs8', ...)
// accepts the DER as-is).
async function importPkcs8PrivateKey(pem) {
  const base64Body = pem.replace('-----BEGIN PRIVATE KEY-----', '').replace('-----END PRIVATE KEY-----', '').replace(/\s/g, '');
  const der = Uint8Array.from(atob(base64Body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', der.buffer, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
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
    // GET added for /remote-config and the /admin/installs* endpoints
    // (Runde 21) — /search already used GET without a preflight-triggering
    // custom header, but the admin endpoints' X-Jarvis-Admin-Key does
    // trigger one, so GET has to be explicitly allowed here too.
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
      'Content-Type, X-Jarvis-Timestamp, X-Jarvis-Nonce, X-Jarvis-Signature, X-Jarvis-Admin-Key',
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
