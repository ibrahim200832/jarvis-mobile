// Cloudflare Worker + Durable Object backend for snake-game online multiplayer.
// One SnakeRoom Durable Object instance per room code — it holds the
// authoritative game state and pushes it to every connected player over
// WebSocket, so clients stay a "dumb" renderer with no local physics.
//
// This Worker also serves the game's static files (via the Assets binding)
// and the account system (auth.js), all on one origin — needed so "Sign in
// with Google" has an actual browser page to redirect back to (Google
// blocks its sign-in flow inside the packaged app's embedded WebView, so
// that flow only makes sense from a real page, not local APK assets).

import {
  handleCorsPreflight,
  handleGoogleCallback,
  handleGoogleStart,
  handleLogin,
  handleMe,
  handleSignup,
  handleUpdateHighscore,
  handleVerify,
} from "./auth.js";

const DIRS = {
  up: { x: 0, y: -1 },
  down: { x: 0, y: 1 },
  left: { x: -1, y: 0 },
  right: { x: 1, y: 0 },
};
const OPPOSITE = { up: "down", down: "up", left: "right", right: "left" };

const PLAYER_COLORS = [
  "#e3a552", // gold (host)
  "#5db3e0", // blue
  "#7fd88f", // green
  "#c58af0", // violet
  "#f06fa8", // pink
  "#4fd6c4", // teal
  "#f0955f", // orange
  "#c9e05d", // lime
];

const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"; // no 0/O/1/I/L
const TICK_MS = 220;

function generateCode() {
  let out = "";
  for (let i = 0; i < 5; i++) {
    out += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return out;
}

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const method = request.method;

    if (method === "OPTIONS" && url.pathname.startsWith("/auth/")) return handleCorsPreflight();
    if (method === "POST" && url.pathname === "/auth/signup") return handleSignup(request, env);
    if (method === "GET" && url.pathname === "/auth/verify") return handleVerify(request, env);
    if (method === "POST" && url.pathname === "/auth/login") return handleLogin(request, env);
    if (method === "GET" && url.pathname === "/auth/google/start") return handleGoogleStart(request, env);
    if (method === "GET" && url.pathname === "/auth/google/callback") return handleGoogleCallback(request, env);
    if (method === "OPTIONS" && url.pathname === "/me") return handleCorsPreflight();
    if (method === "GET" && url.pathname === "/me") return handleMe(request, env);
    if (method === "POST" && url.pathname === "/me/highscore") return handleUpdateHighscore(request, env);

    const isRoomRoute = url.pathname === "/create" || /^\/join\/[A-Z0-9]{4,8}$/i.test(url.pathname);
    if (!isRoomRoute) {
      // Not one of our API routes - serve the game's static files.
      return env.ASSETS.fetch(request);
    }

    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket upgrade", { status: 426 });
    }

    let code;
    let isCreator = false;

    if (url.pathname === "/create") {
      code = generateCode();
      isCreator = true;
    } else {
      const match = url.pathname.match(/^\/join\/([A-Z0-9]{4,8})$/i);
      code = match[1].toUpperCase();
    }

    const id = env.SNAKE_ROOM.idFromName(code);
    const stub = env.SNAKE_ROOM.get(id);

    const forwardUrl = new URL(request.url);
    forwardUrl.searchParams.set("code", code);
    forwardUrl.searchParams.set("isCreator", String(isCreator));

    return stub.fetch(new Request(forwardUrl.toString(), request));
  },
};

export class SnakeRoom {
  constructor(state, env) {
    this.state = state;
    this.sessions = new Map(); // WebSocket -> session
    this.created = false;
    this.code = null;
    this.maxPlayers = 4;
    this.phase = "lobby"; // lobby | playing | gameover
    this.cols = 15;
    this.rows = 20;
    this.food = null;
    this.timer = null;
    this.nextPlayerNum = 0;
    this.roundPlayerCount = 0;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const code = url.searchParams.get("code");
    const isCreator = url.searchParams.get("isCreator") === "true";
    const name = (url.searchParams.get("name") || "Spieler").slice(0, 16);
    const maxParam = parseInt(url.searchParams.get("max") || "4", 10);

    if (isCreator) {
      this.created = true;
      this.code = code;
      this.maxPlayers = clamp(isNaN(maxParam) ? 4 : maxParam, 2, 8);
    }

    if (!this.created) {
      return new Response("Room not found", { status: 404 });
    }
    if (this.phase !== "lobby") {
      return new Response("Room already playing", { status: 409 });
    }
    if (this.sessions.size >= this.maxPlayers) {
      return new Response("Room full", { status: 409 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();

    const isHost = this.sessions.size === 0;
    const color = PLAYER_COLORS[this.nextPlayerNum % PLAYER_COLORS.length];
    this.nextPlayerNum++;

    const session = { name, color, isHost, ws: server, snakeState: null };
    this.sessions.set(server, session);

    server.addEventListener("message", (evt) => this.handleMessage(session, evt));
    server.addEventListener("close", () => this.handleClose(server));
    server.addEventListener("error", () => this.handleClose(server));

    server.send(JSON.stringify({ type: "welcome", code: this.code, isHost, maxPlayers: this.maxPlayers }));
    this.broadcastLobby();

    return new Response(null, { status: 101, webSocket: client });
  }

  handleMessage(session, evt) {
    let msg;
    try {
      msg = JSON.parse(evt.data);
    } catch {
      return;
    }

    if (msg.type === "dir" && this.phase === "playing") {
      const s = session.snakeState;
      if (s && s.alive && DIRS[msg.value] && OPPOSITE[msg.value] !== s.direction) {
        s.pendingDirection = msg.value;
      }
    } else if (msg.type === "setMax" && session.isHost && this.phase === "lobby") {
      const n = parseInt(msg.value, 10);
      if (!isNaN(n)) {
        this.maxPlayers = clamp(n, 2, 8);
        this.broadcastLobby();
      }
    } else if (msg.type === "start" && session.isHost && this.phase === "lobby") {
      if (this.sessions.size >= 2) this.startGame();
    } else if (msg.type === "rematch" && session.isHost && this.phase === "gameover") {
      this.resetToLobby();
      this.broadcastLobby();
    }
  }

  handleClose(ws) {
    const session = this.sessions.get(ws);
    if (!session) return;
    this.sessions.delete(ws);
    if (session.snakeState) session.snakeState.alive = false;

    if (this.sessions.size === 0) {
      this.stopTimer();
      return;
    }

    if (session.isHost) {
      const next = this.sessions.values().next().value;
      if (next) next.isHost = true;
    }

    if (this.phase === "lobby") {
      this.broadcastLobby();
    } else if (this.phase === "playing") {
      this.broadcastState();
      this.checkRoundEnd();
    }
  }

  broadcast(obj) {
    const msg = JSON.stringify(obj);
    for (const session of this.sessions.values()) {
      try {
        session.ws.send(msg);
      } catch {
        // dropped connection, will be cleaned up by its own close event
      }
    }
  }

  broadcastLobby() {
    const players = [...this.sessions.values()].map((s) => ({ name: s.name, color: s.color, isHost: s.isHost }));
    this.broadcast({ type: "lobby", players, maxPlayers: this.maxPlayers });
  }

  broadcastState() {
    const snakes = [...this.sessions.values()]
      .filter((s) => s.snakeState)
      .map((s) => ({
        name: s.name,
        color: s.color,
        alive: s.snakeState.alive,
        score: s.snakeState.score,
        segments: s.snakeState.segments,
      }));
    this.broadcast({ type: "state", snakes, food: this.food });
  }

  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  resetToLobby() {
    this.phase = "lobby";
    this.stopTimer();
    for (const s of this.sessions.values()) s.snakeState = null;
  }

  startGame() {
    this.phase = "playing";
    this.cols = 15 + 3 * (this.maxPlayers - 2);
    this.rows = Math.round((this.cols * 4) / 3);

    const players = [...this.sessions.values()];
    this.roundPlayerCount = players.length;
    const cx = this.cols / 2;
    const cy = this.rows / 2;
    const radius = Math.min(this.cols, this.rows) / 2 - 2;

    players.forEach((session, i) => {
      const angle = (2 * Math.PI * i) / players.length;
      const hx = clamp(Math.round(cx + radius * Math.cos(angle)), 1, this.cols - 2);
      const hy = clamp(Math.round(cy + radius * Math.sin(angle)), 1, this.rows - 2);
      const dx = cx - hx;
      const dy = cy - hy;
      const direction = Math.abs(dx) >= Math.abs(dy) ? (dx > 0 ? "right" : "left") : dy > 0 ? "down" : "up";
      const offset = DIRS[direction];

      const segments = [0, 1, 2].map((k) => ({
        x: clamp(hx - offset.x * k, 0, this.cols - 1),
        y: clamp(hy - offset.y * k, 0, this.rows - 1),
      }));

      session.snakeState = { segments, direction, pendingDirection: direction, alive: true, score: 0 };
    });

    this.spawnFood();
    this.broadcast({ type: "start", cols: this.cols, rows: this.rows });
    this.broadcastState();
    this.timer = setInterval(() => this.tick(), TICK_MS);
  }

  spawnFood() {
    const occupied = new Set();
    for (const s of this.sessions.values()) {
      if (s.snakeState) for (const seg of s.snakeState.segments) occupied.add(`${seg.x},${seg.y}`);
    }
    let x, y;
    do {
      x = Math.floor(Math.random() * this.cols);
      y = Math.floor(Math.random() * this.rows);
    } while (occupied.has(`${x},${y}`));
    this.food = { x, y };
  }

  tick() {
    const alivePlayers = [...this.sessions.values()].filter((s) => s.snakeState && s.snakeState.alive);
    if (alivePlayers.length === 0) {
      this.checkRoundEnd();
      return;
    }

    const nextHeads = new Map();
    for (const session of alivePlayers) {
      const s = session.snakeState;
      s.direction = s.pendingDirection;
      const offset = DIRS[s.direction];
      const head = s.segments[0];
      nextHeads.set(session, { x: head.x + offset.x, y: head.y + offset.y });
    }

    // Flat occupancy snapshot from pre-move positions; each snake's own tail
    // is excluded (it vacates this tick unless growing — same simplification
    // as single-player), but other snakes' tails stay solid to avoid a
    // growth-timing paradox between two different snakes.
    const occupied = [];
    for (const session of alivePlayers) {
      const segs = session.snakeState.segments;
      segs.forEach((seg, idx) => {
        occupied.push({ owner: session, x: seg.x, y: seg.y, isTail: idx === segs.length - 1 });
      });
    }

    let foodEaten = false;
    const deaths = [];

    for (const session of alivePlayers) {
      const s = session.snakeState;
      const head = nextHeads.get(session);
      const hitWall = head.x < 0 || head.x >= this.cols || head.y < 0 || head.y >= this.rows;
      const hitBody = occupied.some((c) => c.x === head.x && c.y === head.y && !(c.owner === session && c.isTail));
      let hitOtherHead = false;
      for (const other of alivePlayers) {
        if (other === session) continue;
        const oh = nextHeads.get(other);
        if (oh.x === head.x && oh.y === head.y) {
          hitOtherHead = true;
          break;
        }
      }

      if (hitWall || hitBody || hitOtherHead) {
        deaths.push(session);
        continue;
      }

      s.segments.unshift(head);
      if (this.food && head.x === this.food.x && head.y === this.food.y) {
        s.score++;
        foodEaten = true;
      } else {
        s.segments.pop();
      }
    }

    for (const session of deaths) session.snakeState.alive = false;
    if (foodEaten) this.spawnFood();

    this.broadcastState();
    this.checkRoundEnd();
  }

  checkRoundEnd() {
    if (this.phase !== "playing") return;
    const alive = [...this.sessions.values()].filter((s) => s.snakeState && s.snakeState.alive);
    const threshold = this.roundPlayerCount >= 2 ? 1 : 0;
    if (alive.length <= threshold) {
      this.phase = "gameover";
      this.stopTimer();
      const results = [...this.sessions.values()]
        .map((s) => ({ name: s.name, color: s.color, score: s.snakeState ? s.snakeState.score : 0 }))
        .sort((a, b) => b.score - a.score);
      this.broadcast({ type: "gameover", results });
    }
  }
}
