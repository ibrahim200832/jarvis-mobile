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
];

const SYSTEM_PROMPT =
  'Du bist JARVIS, mit der Persönlichkeit von Tony Starks JARVIS aus den Iron-Man-Filmen: ' +
  'gebildet, trocken-witzig, leicht sarkastisch, aber immer loyal und hilfsbereit. Du sprichst den ' +
  'Nutzer mit "Master" an. Du wirst oft in einem gesprochenen Telefonat genutzt. Antworte immer kurz ' +
  '(meist 1-2 Sätze), natürlich und im Gesprächston, nie wie ein Roman oder eine Liste. Wenn der ' +
  'Nutzer klar darum bittet, jemanden anzurufen, eine WhatsApp-Nachricht zu senden oder eine App zu ' +
  'öffnen, nutze das passende Werkzeug dafür, statt es nur zu beschreiben. Nutze Werkzeuge nur bei ' +
  'einer eindeutigen Bitte, nicht bei vagen Erwähnungen.';

const AI_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders() });
    }
    if (request.method !== 'POST') {
      return json({ error: 'method not allowed' }, 405);
    }

    let message;
    try {
      const body = await request.json();
      message = body.message;
    } catch (_) {
      return json({ error: 'invalid json body' }, 400);
    }
    if (typeof message !== 'string' || message.trim().length === 0) {
      return json({ error: 'message fehlt' }, 400);
    }

    let data;
    try {
      data = await env.AI.run(AI_MODEL, {
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: message },
        ],
        tools: TOOLS,
        max_tokens: 300,
      });
    } catch (err) {
      return json({ error: 'AI-Anfrage fehlgeschlagen', detail: String(err) }, 502);
    }

    const toolCall = data.tool_calls?.[0];
    const reply = data.response?.trim() || (toolCall ? 'Mach ich.' : 'Ich habe keine Antwort erhalten.');
    const action = toolCall
      ? {
          type: toolCall.name,
          params: typeof toolCall.arguments === 'string' ? JSON.parse(toolCall.arguments) : (toolCall.arguments ?? {}),
        }
      : undefined;

    return json({ reply, action });
  },
};

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
