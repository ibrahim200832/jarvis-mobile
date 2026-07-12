// JARVIS AI proxy — runs on Cloudflare Workers.
// Keeps the real Anthropic API key on the server, never inside the app.
// Deployment steps are documented in README.md under "Freies KI-Gespräch".

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
        max_tokens: 500,
        system:
          'Du bist JARVIS, ein hilfreicher deutschsprachiger Sprachassistent auf dem Handy. ' +
          'Antworte kurz, natürlich und im Gesprächston, wie ein echtes Gespräch, nicht wie ein Roman.',
        messages: [{ role: 'user', content: message }],
      }),
    });

    if (!anthropicRes.ok) {
      const detail = await anthropicRes.text();
      return json({ error: 'AI-Anfrage fehlgeschlagen', detail }, 502);
    }

    const data = await anthropicRes.json();
    const reply = data.content?.[0]?.text ?? 'Ich habe keine Antwort erhalten.';
    return json({ reply });
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
