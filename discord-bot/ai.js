/**
 * Sends `text` to the existing JARVIS Cloudflare Worker (worker/ai-proxy.js)
 * and returns its reply, stripped of markdown so Piper doesn't read out
 * stray asterisks/underscores. Stateless by design — no per-user/channel
 * conversation history in this first version, each question stands alone.
 */
export async function askJarvis(text) {
  const res = await fetch(process.env.AI_BACKEND_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ message: text, history: [] }),
  });
  if (!res.ok) {
    throw new Error(`AI-Anfrage fehlgeschlagen (${res.status})`);
  }
  const data = await res.json();
  return (data.reply ?? '').replace(/[*_#`]/g, '');
}
