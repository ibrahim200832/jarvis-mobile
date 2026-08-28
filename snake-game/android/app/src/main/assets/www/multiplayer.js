(() => {
  "use strict";

  // Filled in once the snake-multiplayer worker is deployed (only happens on
  // merge to main — see .github/workflows/deploy-snake-multiplayer.yml).
  // Cloudflare Worker subdomains are per-account, and the account subdomain
  // is already known from the existing jarvis-ai worker
  // (lib/services/settings_service.dart), so this URL is correct in advance.
  const WS_BASE = "wss://snake-multiplayer.ibrahimcool2818.workers.dev";
  const CELL = 26;
  const FOOD_COLOR = "#f6f2ec";

  const openBtn = document.getElementById("mp-open-btn");
  const showCreateBtn = document.getElementById("mp-show-create-btn");
  const showJoinBtn = document.getElementById("mp-show-join-btn");
  const backToLobbyBtns = document.querySelectorAll(".back-to-lobby");
  const backToMenuBtns = document.querySelectorAll(".back-to-mp-menu");

  const createNameInput = document.getElementById("mp-create-name");
  const maxMinusBtn = document.getElementById("mp-max-minus");
  const maxPlusBtn = document.getElementById("mp-max-plus");
  const maxValueEl = document.getElementById("mp-max-value");
  const createBtn = document.getElementById("mp-create-btn");
  const createErrorEl = document.getElementById("mp-create-error");

  const joinNameInput = document.getElementById("mp-join-name");
  const joinCodeInput = document.getElementById("mp-join-code");
  const joinBtn = document.getElementById("mp-join-btn");
  const joinErrorEl = document.getElementById("mp-join-error");

  const roomCodeEl = document.getElementById("mp-room-code");
  const playerCountEl = document.getElementById("mp-player-count");
  const playerListEl = document.getElementById("mp-player-list");
  const hostControlsEl = document.getElementById("mp-host-controls");
  const startRoomBtn = document.getElementById("mp-start-btn");
  const waitingTextEl = document.getElementById("mp-waiting-text");
  const leaveRoomBtn = document.getElementById("mp-leave-btn");

  const scoreboardEl = document.getElementById("mp-scoreboard");
  const canvas = document.getElementById("mp-board");
  const ctx = canvas.getContext("2d");
  const statusEl = document.getElementById("mp-status");
  const mpOverlay = document.getElementById("mp-overlay");
  const resultsListEl = document.getElementById("mp-results");
  const rematchBtn = document.getElementById("mp-rematch-btn");
  const leaveGameBtn = document.getElementById("mp-leave-game-btn");
  const dpadButtons = document.querySelectorAll("#mp-game .dpad-btn");

  let ws = null;
  let hasWelcomed = false;
  let isHost = false;
  let desiredMax = 4;
  let roomMaxPlayers = 4;
  let mpPlaying = false;
  let latestState = null; // { cols, rows, food }

  function sendMsg(obj) {
    if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
  }

  function setDesiredMax(n) {
    desiredMax = Math.min(8, Math.max(2, n));
    maxValueEl.textContent = String(desiredMax);
  }
  setDesiredMax(4);

  function resetErrors() {
    createErrorEl.classList.add("hidden");
    joinErrorEl.classList.add("hidden");
  }

  openBtn.addEventListener("click", () => {
    resetErrors();
    SnakeUI.showScreen("mp-menu");
  });
  showCreateBtn.addEventListener("click", () => SnakeUI.showScreen("mp-create"));
  showJoinBtn.addEventListener("click", () => SnakeUI.showScreen("mp-join"));
  backToLobbyBtns.forEach((b) => b.addEventListener("click", () => SnakeUI.showScreen("lobby")));
  backToMenuBtns.forEach((b) => b.addEventListener("click", () => SnakeUI.showScreen("mp-menu")));

  maxMinusBtn.addEventListener("click", () => setDesiredMax(desiredMax - 1));
  maxPlusBtn.addEventListener("click", () => setDesiredMax(desiredMax + 1));

  joinCodeInput.addEventListener("input", () => {
    joinCodeInput.value = joinCodeInput.value.toUpperCase().replace(/[^A-Z0-9]/g, "");
  });

  createBtn.addEventListener("click", () => {
    const name = encodeURIComponent(createNameInput.value.trim() || "Spieler");
    connect(`${WS_BASE}/create?name=${name}&max=${desiredMax}`, createErrorEl, "Raum konnte nicht erstellt werden.");
  });

  joinBtn.addEventListener("click", () => {
    const name = encodeURIComponent(joinNameInput.value.trim() || "Spieler");
    const code = joinCodeInput.value.trim();
    if (!code) {
      joinErrorEl.textContent = "Bitte einen Code eingeben.";
      joinErrorEl.classList.remove("hidden");
      return;
    }
    connect(`${WS_BASE}/join/${code}?name=${name}`, joinErrorEl, "Raum nicht gefunden oder schon voll/gestartet.");
  });

  function connect(url, errorEl, failMessage) {
    errorEl.classList.add("hidden");
    if (ws) {
      try {
        ws.close();
      } catch {
        // already closed
      }
    }

    let socket;
    try {
      socket = new WebSocket(url);
    } catch {
      errorEl.textContent = "Verbindung nicht möglich.";
      errorEl.classList.remove("hidden");
      return;
    }

    ws = socket;
    hasWelcomed = false;

    socket.addEventListener("message", handleMessage);

    socket.addEventListener("close", () => {
      if (!hasWelcomed) {
        errorEl.textContent = failMessage;
        errorEl.classList.remove("hidden");
      } else {
        statusEl.textContent = "Verbindung getrennt.";
        statusEl.classList.remove("hidden");
      }
      mpPlaying = false;
      hasWelcomed = false;
      ws = null;
    });
  }

  function handleMessage(evt) {
    let msg;
    try {
      msg = JSON.parse(evt.data);
    } catch {
      return;
    }

    if (msg.type === "welcome") {
      hasWelcomed = true;
      isHost = msg.isHost;
      roomMaxPlayers = msg.maxPlayers;
      roomCodeEl.textContent = msg.code;
      SnakeUI.showScreen("mp-room");
    } else if (msg.type === "lobby") {
      roomMaxPlayers = msg.maxPlayers;
      renderPlayerList(msg.players);
    } else if (msg.type === "start") {
      latestState = { cols: msg.cols, rows: msg.rows, food: null };
      canvas.width = msg.cols * CELL;
      canvas.height = msg.rows * CELL;
      canvas.style.aspectRatio = `${msg.cols} / ${msg.rows}`;
      mpOverlay.classList.add("hidden");
      statusEl.classList.add("hidden");
      mpPlaying = true;
      SnakeUI.showScreen("mp-game");
    } else if (msg.type === "state") {
      if (!latestState) return;
      latestState.food = msg.food;
      drawMultiplayer(msg.snakes);
      renderScoreboard(msg.snakes);
    } else if (msg.type === "gameover") {
      mpPlaying = false;
      renderResults(msg.results);
      rematchBtn.classList.toggle("hidden", !isHost);
      mpOverlay.classList.remove("hidden");
    }
  }

  function renderPlayerList(players) {
    playerListEl.innerHTML = "";
    players.forEach((p) => {
      const li = document.createElement("li");
      li.className = "player-item";
      const dot = document.createElement("span");
      dot.className = "player-dot";
      dot.style.background = p.color;
      li.appendChild(dot);
      li.appendChild(document.createTextNode(p.name + (p.isHost ? " (Host)" : "")));
      playerListEl.appendChild(li);
    });

    playerCountEl.textContent = `Spieler ${players.length}/${roomMaxPlayers}`;
    hostControlsEl.classList.toggle("hidden", !isHost);
    waitingTextEl.classList.toggle("hidden", isHost);
    startRoomBtn.disabled = players.length < 2;
  }

  function renderScoreboard(snakes) {
    scoreboardEl.innerHTML = "";
    [...snakes]
      .sort((a, b) => b.score - a.score)
      .forEach((s) => {
        const chip = document.createElement("div");
        chip.className = "score-chip" + (s.alive ? "" : " dead");
        const dot = document.createElement("span");
        dot.className = "player-dot";
        dot.style.background = s.color;
        chip.appendChild(dot);
        chip.appendChild(document.createTextNode(`${s.name}: ${s.score}`));
        scoreboardEl.appendChild(chip);
      });
  }

  function renderResults(results) {
    resultsListEl.innerHTML = "";
    results.forEach((r, i) => {
      const li = document.createElement("li");
      li.textContent = `${i + 1}. ${r.name} — ${r.score} Punkte`;
      li.style.color = r.color;
      resultsListEl.appendChild(li);
    });
  }

  function drawMultiplayer(snakes) {
    const { cols, rows, food } = latestState;
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = "rgba(255,255,255,0.04)";
    ctx.lineWidth = 1;
    for (let x = 0; x <= cols; x++) {
      ctx.beginPath();
      ctx.moveTo(x * CELL, 0);
      ctx.lineTo(x * CELL, rows * CELL);
      ctx.stroke();
    }
    for (let y = 0; y <= rows; y++) {
      ctx.beginPath();
      ctx.moveTo(0, y * CELL);
      ctx.lineTo(cols * CELL, y * CELL);
      ctx.stroke();
    }

    if (food) {
      ctx.fillStyle = FOOD_COLOR;
      roundedCellAt(food.x, food.y);
    }

    snakes.forEach((s) => {
      ctx.globalAlpha = s.alive ? 1 : 0.25;
      ctx.fillStyle = s.color;
      s.segments.forEach((seg) => roundedCellAt(seg.x, seg.y));
      if (s.segments.length) {
        const head = s.segments[0];
        const pad = 2;
        ctx.strokeStyle = "rgba(255,255,255,0.6)";
        ctx.lineWidth = 2;
        ctx.strokeRect(head.x * CELL + pad, head.y * CELL + pad, CELL - pad * 2, CELL - pad * 2);
      }
      ctx.globalAlpha = 1;
    });

    function roundedCellAt(cx, cy) {
      const pad = 2;
      const x = cx * CELL + pad;
      const y = cy * CELL + pad;
      const size = CELL - pad * 2;
      if (ctx.roundRect) {
        ctx.beginPath();
        ctx.roundRect(x, y, size, size, 4);
        ctx.fill();
      } else {
        ctx.fillRect(x, y, size, size);
      }
    }
  }

  function leaveRoom() {
    if (ws) {
      try {
        ws.close(1000);
      } catch {
        // ignore
      }
      ws = null;
    }
    hasWelcomed = false;
    mpPlaying = false;
    SnakeUI.showScreen("lobby");
  }

  startRoomBtn.addEventListener("click", () => sendMsg({ type: "start" }));
  rematchBtn.addEventListener("click", () => sendMsg({ type: "rematch" }));
  leaveRoomBtn.addEventListener("click", leaveRoom);
  leaveGameBtn.addEventListener("click", leaveRoom);

  function setMpDirection(dir) {
    if (mpPlaying) sendMsg({ type: "dir", value: dir });
  }

  window.addEventListener("keydown", (e) => {
    const map = {
      ArrowUp: "up", w: "up", W: "up",
      ArrowDown: "down", s: "down", S: "down",
      ArrowLeft: "left", a: "left", A: "left",
      ArrowRight: "right", d: "right", D: "right",
    };
    const dir = map[e.key];
    if (dir && mpPlaying) {
      e.preventDefault();
      setMpDirection(dir);
    }
  });

  let touchStart = null;
  canvas.addEventListener("touchstart", (e) => {
    const t = e.changedTouches[0];
    touchStart = { x: t.clientX, y: t.clientY };
  }, { passive: true });

  canvas.addEventListener("touchend", (e) => {
    if (!touchStart) return;
    const t = e.changedTouches[0];
    const dx = t.clientX - touchStart.x;
    const dy = t.clientY - touchStart.y;
    touchStart = null;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 20) return;
    if (Math.abs(dx) > Math.abs(dy)) setMpDirection(dx > 0 ? "right" : "left");
    else setMpDirection(dy > 0 ? "down" : "up");
  }, { passive: true });

  dpadButtons.forEach((btn) => {
    btn.addEventListener("click", () => setMpDirection(btn.dataset.dir));
  });
})();
