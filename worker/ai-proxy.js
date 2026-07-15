// JARVIS AI proxy — runs on Cloudflare Workers.
// Keeps the real Gemini API key on the server, never inside the app.
// Google AI Studio gives a free API key without a credit card — see
// README.md under "Freies KI-Gespräch einrichten".

const TOOLS = [
  {
    name: 'call_contact',
    description:
      'Ruft einen gespeicherten Kontakt auf dem Handy des Nutzers an. Nur verwenden, wenn der Nutzer klar darum bittet, jemanden anzurufen.',
    parameters: {
      type: 'OBJECT',
      properties: {
        name: { type: 'STRING', description: 'Name des Kontakts, wie er im Adressbuch gespeichert ist' },
      },
      required: ['name'],
    },
  },
  {
    name: 'send_whatsapp',
    description:
      'Öffnet WhatsApp mit einer vorausgefüllten Nachricht an einen gespeicherten Kontakt. Nur verwenden, wenn der Nutzer klar darum bittet, eine WhatsApp-Nachricht zu senden.',
    parameters: {
      type: 'OBJECT',
      properties: {
        name: { type: 'STRING', description: 'Name des Kontakts' },
        message: { type: 'STRING', description: 'Der Nachrichtentext' },
      },
      required: ['name', 'message'],
    },
  },
  {
    name: 'open_app',
    description:
      'Öffnet eine auf dem Handy installierte App. Nur verwenden, wenn der Nutzer klar darum bittet, eine App zu öffnen.',
    parameters: {
      type: 'OBJECT',
      properties: {
        app_name: { type: 'STRING', description: 'Name der zu öffnenden App' },
      },
      required: ['app_name'],
    },
  },
];

const SYSTEM_PROMPT =
  'Du bist JARVIS, ein hilfreicher deutschsprachiger Sprachassistent auf dem Handy, der oft in ' +
  'einem gesprochenen Telefonat genutzt wird. Antworte immer kurz (meist 1-2 Sätze), natürlich und im ' +
  'Gesprächston, nie wie ein Roman oder eine Liste. Wenn der Nutzer klar darum bittet, jemanden ' +
  'anzurufen, eine WhatsApp-Nachricht zu senden oder eine App zu öffnen, nutze das passende Werkzeug ' +
  'dafür, statt es nur zu beschreiben. Nutze Werkzeuge nur bei einer eindeutigen Bitte, nicht bei ' +
  'vagen Erwähnungen.';

const GEMINI_MODEL = 'gemini-2.0-flash';

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

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': env.GEMINI_API_KEY,
        },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: [{ role: 'user', parts: [{ text: message }] }],
          tools: [{ functionDeclarations: TOOLS }],
          generationConfig: { maxOutputTokens: 300 },
        }),
      },
    );

    if (!geminiRes.ok) {
      const detail = await geminiRes.text();
      return json({ error: 'AI-Anfrage fehlgeschlagen', detail }, 502);
    }

    const data = await geminiRes.json();
    const parts = data.candidates?.[0]?.content?.parts ?? [];
    const textPart = parts.find((p) => typeof p.text === 'string');
    const functionCallPart = parts.find((p) => p.functionCall);

    const reply = textPart?.text ?? (functionCallPart ? 'Mach ich.' : 'Ich habe keine Antwort erhalten.');
    const action = functionCallPart
      ? { type: functionCallPart.functionCall.name, params: functionCallPart.functionCall.args ?? {} }
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
