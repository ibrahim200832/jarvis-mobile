(() => {
  "use strict";

  // The packaged Android app loads this page from local file:// assets, so
  // it must call the worker's real origin absolutely; the web version is
  // served from that same worker, so relative paths (same-origin) suffice.
  const isPackagedApp = location.protocol === "file:";
  const AUTH_BASE = isPackagedApp ? "https://snake-multiplayer.ibrahimcool2818.workers.dev" : "";
  const TOKEN_KEY = "snake-game-auth-token";
  const HIGHSCORE_KEY = "snake-game-highscore";

  const openBtn = document.getElementById("account-open-btn");
  const logoutBtn = document.getElementById("account-logout-btn");
  const statusEl = document.getElementById("account-status");

  const tabButtons = document.querySelectorAll('.option-buttons[data-option="auth-tab"] .option-btn');
  const loginForm = document.getElementById("auth-login");
  const signupForm = document.getElementById("auth-signup");
  const loginEmail = document.getElementById("login-email");
  const loginPassword = document.getElementById("login-password");
  const loginBtn = document.getElementById("login-btn");
  const signupName = document.getElementById("signup-name");
  const signupEmail = document.getElementById("signup-email");
  const signupPassword = document.getElementById("signup-password");
  const signupBtn = document.getElementById("signup-btn");
  const errorEl = document.getElementById("auth-error");
  const infoEl = document.getElementById("auth-info");
  const googleBtn = document.getElementById("google-login-btn");
  const googleApkHint = document.getElementById("google-apk-hint");

  function apiUrl(path) {
    return AUTH_BASE + path;
  }

  function getToken() {
    return localStorage.getItem(TOKEN_KEY);
  }
  function setToken(token) {
    localStorage.setItem(TOKEN_KEY, token);
  }
  function clearToken() {
    localStorage.removeItem(TOKEN_KEY);
  }

  function resetMessages() {
    errorEl.classList.add("hidden");
    infoEl.classList.add("hidden");
  }
  function showError(msg) {
    errorEl.textContent = msg;
    errorEl.classList.remove("hidden");
  }
  function showInfo(msg) {
    infoEl.textContent = msg;
    infoEl.classList.remove("hidden");
  }

  function updateAccountBar(user) {
    if (user) {
      statusEl.textContent = `Angemeldet als ${user.displayName}`;
      statusEl.classList.remove("hidden");
      openBtn.classList.add("hidden");
      logoutBtn.classList.remove("hidden");
    } else {
      statusEl.classList.add("hidden");
      openBtn.classList.remove("hidden");
      logoutBtn.classList.add("hidden");
    }
  }

  function refreshHighscoreDisplays(value) {
    ["highscore", "lobby-highscore"].forEach((id) => {
      const el = document.getElementById(id);
      if (el) el.textContent = String(value);
    });
  }

  function prefillMultiplayerNames(displayName) {
    const createName = document.getElementById("mp-create-name");
    const joinName = document.getElementById("mp-join-name");
    if (createName && !createName.value) createName.value = displayName;
    if (joinName && !joinName.value) joinName.value = displayName;
  }

  // Whichever highscore (local device vs. account) is higher wins and both
  // ends get updated with it, so switching devices never loses progress.
  async function syncHighscore(serverHighscore) {
    const localHighscore = Number(localStorage.getItem(HIGHSCORE_KEY) || 0);
    const best = Math.max(localHighscore, serverHighscore || 0);
    if (best > localHighscore) localStorage.setItem(HIGHSCORE_KEY, String(best));
    refreshHighscoreDisplays(best);

    if (best > (serverHighscore || 0)) {
      try {
        await fetch(apiUrl("/me/highscore"), {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${getToken()}` },
          body: JSON.stringify({ score: best }),
        });
      } catch {
        // best-effort only - single-player keeps working fully offline either way
      }
    }
  }

  function onLoggedIn(user) {
    updateAccountBar(user);
    prefillMultiplayerNames(user.displayName);
    syncHighscore(user.highscore);
  }

  openBtn.addEventListener("click", () => {
    resetMessages();
    SnakeUI.showScreen("auth");
  });

  logoutBtn.addEventListener("click", () => {
    clearToken();
    updateAccountBar(null);
  });

  tabButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      tabButtons.forEach((b) => b.classList.remove("selected"));
      btn.classList.add("selected");
      const tab = btn.dataset.value;
      loginForm.classList.toggle("hidden", tab !== "login");
      signupForm.classList.toggle("hidden", tab !== "signup");
      resetMessages();
    });
  });

  loginBtn.addEventListener("click", async () => {
    resetMessages();
    try {
      const res = await fetch(apiUrl("/auth/login"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: loginEmail.value.trim(), password: loginPassword.value }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Anmeldung fehlgeschlagen");
      setToken(data.token);
      onLoggedIn(data.user);
      SnakeUI.showScreen("lobby");
    } catch (e) {
      showError(e.message || "Verbindung fehlgeschlagen");
    }
  });

  signupBtn.addEventListener("click", async () => {
    resetMessages();
    try {
      const res = await fetch(apiUrl("/auth/signup"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: signupEmail.value.trim(),
          password: signupPassword.value,
          displayName: signupName.value.trim(),
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Registrierung fehlgeschlagen");
      showInfo(data.message || "Bitte bestätige deine E-Mail-Adresse.");
    } catch (e) {
      showError(e.message || "Verbindung fehlgeschlagen");
    }
  });

  if (isPackagedApp) {
    googleBtn.classList.add("hidden");
    googleApkHint.classList.remove("hidden");
  } else {
    googleBtn.addEventListener("click", () => {
      location.href = apiUrl("/auth/google/start");
    });
  }

  async function restoreSession() {
    const token = getToken();
    if (!token) return;
    try {
      const res = await fetch(apiUrl("/me"), { headers: { Authorization: `Bearer ${token}` } });
      if (!res.ok) {
        clearToken();
        return;
      }
      onLoggedIn(await res.json());
    } catch {
      // offline / server unreachable - stay logged out client-side, single-player unaffected
    }
  }

  // The Google OAuth callback redirects back here with #authToken=... .
  function consumeGoogleRedirect() {
    const match = location.hash.match(/authToken=([^&]+)/);
    if (!match) return;
    setToken(decodeURIComponent(match[1]));
    history.replaceState(null, "", location.pathname + location.search);
  }

  consumeGoogleRedirect();
  restoreSession();
})();
