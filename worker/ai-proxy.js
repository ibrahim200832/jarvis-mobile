// JARVIS AI proxy — runs on Cloudflare Workers.
// Keeps the real Anthropic API key on the server, never inside the app.
// Deployment steps are documented in README.md under "Freies KI-Gespräch".

const TOOLS = [
  {
    name: 'call_contact',
    description:
      'Ruft einen gespeicherten Kontakt auf dem Handy des Nutzers an. Nur verwenden, wenn der Nutzer klar darum bittet, jemanden anzurufen.',
    input_schema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Name des Kontakts, wie er im Adressbuch gespeichert ist' },
      },
      required: ['name'],
    },
  },
  {
    name: 'send_whatsapp',
    description:
      'Öffnet WhatsApp mit einer vorausgefüllten Nachricht an einen gespeicherten Kontakt. Nur verwenden, wenn der Nutzer klar darum bittet, eine WhatsApp-Nachricht zu senden.',
    input_schema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Name des Kontakts' },
        message: { type: 'string', description: 'Der Nachrichtentext' },
      },
      required: ['name', 'message'],
    },
  },
  {
    name: 'open_app',
    description:
      'Öffnet eine auf dem Handy installierte App. Nur verwenden, wenn der Nutzer klar darum bittet, eine App zu öffnen.',
    input_schema: {
      type: 'object',
      properties: {
        app_name: { type: 'string', description: 'Name der zu öffnenden App' },
      },
      required: ['app_name'],
    },
  },
];

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

    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 300,
        system:
          'Du bist JARVIS, ein hilfreicher deutschsprachiger Sprachassistent auf dem Handy, der oft in ' +
          'einem gesprochenen Telefonat genutzt wird. Antworte immer kurz (meist 1-2 Sätze), natürlich und im ' +
          'Gesprächston, nie wie ein Roman oder eine Liste. Wenn der Nutzer klar darum bittet, jemanden ' +
          'anzurufen, eine WhatsApp-Nachricht zu senden oder eine App zu öffnen, nutze das passende Werkzeug ' +
          'dafür, statt es nur zu beschreiben. Nutze Werkzeuge nur bei einer eindeutigen Bitte, nicht bei ' +
          'vagen Erwähnungen.',
        tools: TOOLS,
        messages: [{ role: 'user', content: message }],
      }),
    });

    if (!anthropicRes.ok) {
      const detail = await anthropicRes.text();
      return json({ error: 'AI-Anfrage fehlgeschlagen', detail }, 502);
    }

    const data = await anthropicRes.json();
    const textBlock = data.content?.find((b) => b.type === 'text');
    const toolBlock = data.content?.find((b) => b.type === 'tool_use');

    const reply = textBlock?.text ?? (toolBlock ? 'Mach ich.' : 'Ich habe keine Antwort erhalten.');
    const action = toolBlock ? { type: toolBlock.name, params: toolBlock.input } : undefined;

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
