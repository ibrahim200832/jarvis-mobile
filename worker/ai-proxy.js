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
];

const SYSTEM_PROMPT =
  'Du bist JARVIS, das KI-System von Tony Stark aus den Iron-Man-Filmen, jetzt im Dienst des Nutzers. ' +
  'Deine Persönlichkeit: hochintelligent, gebildet, britisch-trocken und humorvoll, leicht sarkastisch, ' +
  'aber niemals unhöflich — im Kern loyal, aufmerksam und stets bemüht, dem Nutzer das Leben leichter zu ' +
  'machen. Du sprichst den Nutzer mit "Sir" oder "Master" an. Du wirst meist in einem gesprochenen ' +
  'Gespräch oder Telefonat genutzt, deshalb antwortest du immer kurz und natürlich (meist 1-2 Sätze), ' +
  'nie als Liste, Aufzählung oder Roman. Nutze den bisherigen Gesprächsverlauf, um Bezüge und Nachfragen ' +
  'richtig zu verstehen, statt jede Nachricht isoliert zu behandeln. Wenn der Nutzer klar darum bittet, ' +
  'jemanden anzurufen, eine WhatsApp-Nachricht zu senden, eine App zu öffnen, einen Timer zu stellen, ' +
  'eine Notiz zu speichern, das Wetter abzurufen oder die Kamera zu öffnen, nutze sofort das passende ' +
  'Werkzeug dafür, statt es nur zu beschreiben. Nutze Werkzeuge nur bei einer eindeutigen Bitte, nicht ' +
  'bei vagen Erwähnungen.';

// gpt-oss-120b: OpenAI's open-weight model on Workers AI, meaningfully
// stronger reasoning than the previous Llama 3.3 70B while still going
// through the same normalized {response, tool_calls} shape below (Workers
// AI's text-generation binding output is normalized across models, so no
// other code here needs to change for the swap).
const AI_MODEL = '@cf/openai/gpt-oss-120b';

// How many prior turns (user+assistant pairs) the client may send as
// context. Bounded server-side too, independent of what the client sends,
// so a misbehaving client can't blow up the prompt size/cost.
const MAX_HISTORY_MESSAGES = 16;

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders() });
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

    let data;
    try {
      data = await env.AI.run(AI_MODEL, {
        messages: [{ role: 'system', content: SYSTEM_PROMPT }, ...cleanHistory, { role: 'user', content: message }],
        tools: TOOLS,
        max_tokens: 300,
      });
    } catch (err) {
      return json({ error: 'AI-Anfrage fehlgeschlagen', detail: String(err) }, 502);
    }

    const toolCall = data.tool_calls?.[0];
    const replyText = (data.response ?? data.result?.response ?? '').toString().trim();
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
