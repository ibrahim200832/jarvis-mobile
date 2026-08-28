// Account system for snake-game: email/password (with email verification via
// Resend) and Google Sign-In. Lives alongside the multiplayer Durable Object
// in the same Worker so player identity and rooms share one backend.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function htmlResponse(message, status = 200, ok = false) {
  const color = ok ? "#7fd88f" : "#d6533a";
  const html = `<!DOCTYPE html>
<html lang="de"><head><meta charset="UTF-8"><title>Snake</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
    background:#120f0c; color:#f6f2ec; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; padding:24px; }
  .card { max-width:360px; text-align:center; background:#211c17; border:1px solid rgba(255,255,255,0.08);
    border-radius:16px; padding:28px; }
  p { color:${color}; font-weight:600; }
  a { color:#e3a552; }
</style></head>
<body><div class="card"><p>${message}</p><a href="/">Zurück zum Spiel</a></div></body></html>`;
  return new Response(html, { status, headers: { "Content-Type": "text/html; charset=utf-8" } });
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// --- base64url helpers (loop-based, safe for arbitrary-length buffers) ---

function bytesToB64url(bytes) {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlToBytes(str) {
  str = str.replace(/-/g, "+").replace(/_/g, "/");
  while (str.length % 4) str += "=";
  const bin = atob(str);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function stringToB64url(str) {
  return bytesToB64url(new TextEncoder().encode(str));
}

function bytesToHex(bytes) {
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function hexToBytes(hex) {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  return bytes;
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// --- Password hashing (PBKDF2 via Web Crypto, no external dependency) ---

const PBKDF2_ITERATIONS = 100000;

async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const keyMaterial = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const derived = await crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations: PBKDF2_ITERATIONS, hash: "SHA-256" }, keyMaterial, 256);
  return `pbkdf2:${PBKDF2_ITERATIONS}:${bytesToHex(salt)}:${bytesToHex(new Uint8Array(derived))}`;
}

async function verifyPassword(password, stored) {
  const parts = String(stored).split(":");
  if (parts.length !== 4 || parts[0] !== "pbkdf2") return false;
  const iterations = parseInt(parts[1], 10);
  const salt = hexToBytes(parts[2]);
  const keyMaterial = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const derived = await crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations, hash: "SHA-256" }, keyMaterial, 256);
  return timingSafeEqual(bytesToHex(new Uint8Array(derived)), parts[3]);
}

// --- Sessions (HS256 JWT via Web Crypto) ---

async function importHmacKey(secret) {
  return crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}

async function signJWT(payload, secret, expiresInSeconds = 60 * 60 * 24 * 30) {
  const now = Math.floor(Date.now() / 1000);
  const encHeader = stringToB64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const encPayload = stringToB64url(JSON.stringify({ ...payload, iat: now, exp: now + expiresInSeconds }));
  const data = `${encHeader}.${encPayload}`;
  const key = await importHmacKey(secret);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return `${data}.${bytesToB64url(new Uint8Array(sig))}`;
}

async function verifyJWT(token, secret) {
  if (!token) return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [encHeader, encPayload, encSig] = parts;
  const key = await importHmacKey(secret);
  const valid = await crypto.subtle.verify("HMAC", key, b64urlToBytes(encSig), new TextEncoder().encode(`${encHeader}.${encPayload}`));
  if (!valid) return null;
  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(encPayload)));
  if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) return null;
  return payload;
}

async function requireAuth(request, env) {
  const authHeader = request.headers.get("Authorization") || "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  return verifyJWT(token, env.AUTH_JWT_SECRET);
}

// --- Verification email (Resend, with a local-dev fallback that just logs
// the link instead of requiring a real API key while testing) ---

async function sendVerificationEmail(env, email, displayName, verifyUrl) {
  if (!env.RESEND_API_KEY) {
    console.log(`[dev] Verifizierungslink für ${email}: ${verifyUrl}`);
    return;
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: env.RESEND_FROM_EMAIL,
      to: email,
      subject: "Bestätige deine E-Mail für Snake",
      html: `<p>Hallo ${displayName},</p><p>Bitte bestätige deine E-Mail-Adresse:</p><p><a href="${verifyUrl}">${verifyUrl}</a></p>`,
    }),
  });
  if (!res.ok) {
    console.error("Resend-Fehler:", await res.text());
  }
}

// --- Route handlers ---

export function handleCorsPreflight() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function handleSignup(request, env) {
  const body = await request.json().catch(() => null);
  if (!body || !body.email || !body.password || !body.displayName) {
    return jsonResponse({ error: "email, password und displayName erforderlich" }, 400);
  }
  const email = String(body.email).trim().toLowerCase();
  const password = String(body.password);
  const displayName = String(body.displayName).trim().slice(0, 32) || "Spieler";

  if (!isValidEmail(email)) return jsonResponse({ error: "Ungültige E-Mail-Adresse" }, 400);
  if (password.length < 8) return jsonResponse({ error: "Passwort muss mindestens 8 Zeichen haben" }, 400);

  const existing = await env.DB.prepare("SELECT id FROM users WHERE email = ?").bind(email).first();
  if (existing) return jsonResponse({ error: "Diese E-Mail ist bereits registriert" }, 409);

  const id = crypto.randomUUID();
  const passwordHash = await hashPassword(password);
  await env.DB.prepare(
    "INSERT INTO users (id, email, password_hash, display_name, email_verified, highscore, created_at) VALUES (?, ?, ?, ?, 0, 0, ?)"
  ).bind(id, email, passwordHash, displayName, Date.now()).run();

  const token = crypto.randomUUID();
  await env.DB.prepare("INSERT INTO email_verification_tokens (token, user_id, expires_at) VALUES (?, ?, ?)")
    .bind(token, id, Date.now() + 24 * 60 * 60 * 1000)
    .run();

  const verifyUrl = `${new URL(request.url).origin}/auth/verify?token=${token}`;
  await sendVerificationEmail(env, email, displayName, verifyUrl);

  return jsonResponse({ ok: true, message: "Bitte bestätige deine E-Mail-Adresse (Link wurde verschickt)." });
}

export async function handleVerify(request, env) {
  const token = new URL(request.url).searchParams.get("token");
  if (!token) return htmlResponse("Fehlender Bestätigungs-Code.", 400);

  const row = await env.DB.prepare("SELECT user_id, expires_at FROM email_verification_tokens WHERE token = ?").bind(token).first();
  if (!row) return htmlResponse("Dieser Link ist ungültig oder wurde bereits verwendet.", 400);
  if (row.expires_at < Date.now()) return htmlResponse("Dieser Link ist abgelaufen. Bitte registriere dich erneut.", 400);

  await env.DB.prepare("UPDATE users SET email_verified = 1 WHERE id = ?").bind(row.user_id).run();
  await env.DB.prepare("DELETE FROM email_verification_tokens WHERE token = ?").bind(token).run();

  return htmlResponse("E-Mail bestätigt! Du kannst dich jetzt im Spiel anmelden.", 200, true);
}

export async function handleLogin(request, env) {
  const body = await request.json().catch(() => null);
  if (!body || !body.email || !body.password) return jsonResponse({ error: "email und password erforderlich" }, 400);

  const email = String(body.email).trim().toLowerCase();
  const user = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(email).first();
  if (!user || !user.password_hash || !(await verifyPassword(String(body.password), user.password_hash))) {
    return jsonResponse({ error: "E-Mail oder Passwort falsch" }, 401);
  }
  if (!user.email_verified) return jsonResponse({ error: "Bitte bestätige zuerst deine E-Mail-Adresse." }, 403);

  const token = await signJWT({ sub: user.id, name: user.display_name, email: user.email }, env.AUTH_JWT_SECRET);
  return jsonResponse({ token, user: { id: user.id, displayName: user.display_name, email: user.email, highscore: user.highscore } });
}

export function handleGoogleStart(request, env) {
  const url = new URL(request.url);
  const state = crypto.randomUUID();
  const params = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID,
    redirect_uri: `${url.origin}/auth/google/callback`,
    response_type: "code",
    scope: "openid email profile",
    state,
    prompt: "select_account",
  });
  const headers = new Headers({ Location: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}` });
  // Short-lived CSRF nonce round-tripped via cookie instead of server-side
  // storage - this handler has no Durable Object / session store of its own.
  headers.append("Set-Cookie", `oauth_state=${state}; Max-Age=600; Path=/auth/google; HttpOnly; Secure; SameSite=Lax`);
  return new Response(null, { status: 302, headers });
}

export async function handleGoogleCallback(request, env) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  const cookieMatch = (request.headers.get("Cookie") || "").match(/oauth_state=([^;]+)/);

  if (!code || !state || !cookieMatch || cookieMatch[1] !== state) {
    return htmlResponse("Google-Anmeldung fehlgeschlagen (ungültige Sitzung). Bitte erneut versuchen.", 400);
  }

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: `${url.origin}/auth/google/callback`,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenRes.ok) return htmlResponse("Google-Anmeldung fehlgeschlagen (Token-Austausch).", 400);
  const tokenData = await tokenRes.json();

  const profileRes = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
    headers: { Authorization: `Bearer ${tokenData.access_token}` },
  });
  if (!profileRes.ok) return htmlResponse("Google-Anmeldung fehlgeschlagen (Profil).", 400);
  const profile = await profileRes.json();

  let user = await env.DB.prepare("SELECT * FROM users WHERE google_id = ?").bind(profile.sub).first();
  if (!user) {
    const byEmail = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(profile.email).first();
    if (byEmail) {
      await env.DB.prepare("UPDATE users SET google_id = ?, email_verified = 1 WHERE id = ?").bind(profile.sub, byEmail.id).run();
      user = { ...byEmail, google_id: profile.sub, email_verified: 1 };
    } else {
      const id = crypto.randomUUID();
      const displayName = profile.name || profile.email;
      await env.DB.prepare(
        "INSERT INTO users (id, email, google_id, display_name, email_verified, highscore, created_at) VALUES (?, ?, ?, ?, 1, 0, ?)"
      ).bind(id, profile.email, profile.sub, displayName, Date.now()).run();
      user = { id, email: profile.email, display_name: displayName, highscore: 0 };
    }
  }

  const sessionToken = await signJWT({ sub: user.id, name: user.display_name, email: user.email }, env.AUTH_JWT_SECRET);
  const headers = new Headers({ Location: `${url.origin}/#authToken=${encodeURIComponent(sessionToken)}` });
  headers.append("Set-Cookie", "oauth_state=; Max-Age=0; Path=/auth/google");
  return new Response(null, { status: 302, headers });
}

export async function handleMe(request, env) {
  const payload = await requireAuth(request, env);
  if (!payload) return jsonResponse({ error: "Nicht angemeldet" }, 401);
  const user = await env.DB.prepare("SELECT id, email, display_name, highscore FROM users WHERE id = ?").bind(payload.sub).first();
  if (!user) return jsonResponse({ error: "Konto nicht gefunden" }, 404);
  return jsonResponse({ id: user.id, email: user.email, displayName: user.display_name, highscore: user.highscore });
}

export async function handleUpdateHighscore(request, env) {
  const payload = await requireAuth(request, env);
  if (!payload) return jsonResponse({ error: "Nicht angemeldet" }, 401);
  const body = await request.json().catch(() => null);
  const score = body && Number.isFinite(body.score) ? Math.max(0, Math.floor(body.score)) : null;
  if (score === null) return jsonResponse({ error: "score erforderlich" }, 400);

  await env.DB.prepare("UPDATE users SET highscore = MAX(highscore, ?) WHERE id = ?").bind(score, payload.sub).run();
  const user = await env.DB.prepare("SELECT highscore FROM users WHERE id = ?").bind(payload.sub).first();
  return jsonResponse({ highscore: user.highscore });
}
