(() => {
  "use strict";

  const CELL = 30;
  const HIGHSCORE_KEY = "snake-game-highscore";
  const POINTS_PER_LEVEL = 5;
  const LEVEL_TOAST_DURATION_MS = 1200;

  // All presets keep a 3:4 aspect ratio so the canvas CSS never has to change.
  const SIZE_PRESETS = {
    small: { cols: 9, rows: 12 },
    medium: { cols: 15, rows: 20 },
    large: { cols: 21, rows: 28 },
  };

  const DIFFICULTY_PRESETS = {
    easy: { startTick: 260, decrement: 3, minTick: 100, levelBonus: 6 },
    normal: { startTick: 220, decrement: 4, minTick: 80, levelBonus: 10 },
    hard: { startTick: 180, decrement: 6, minTick: 60, levelBonus: 14 },
  };

  const lobby = document.getElementById("lobby");
  const gameSection = document.getElementById("game");
  const startBtn = document.getElementById("start-btn");
  const lobbyHighscoreEl = document.getElementById("lobby-highscore");
  const optionGroups = document.querySelectorAll(".option-buttons");

  const canvas = document.getElementById("board");
  const ctx = canvas.getContext("2d");
  const scoreEl = document.getElementById("score");
  const levelEl = document.getElementById("level");
  const highscoreEl = document.getElementById("highscore");
  const levelToast = document.getElementById("level-toast");
  const overlay = document.getElementById("overlay");
  const overlayTitle = document.getElementById("overlay-title");
  const overlayScore = document.getElementById("overlay-score");
  const restartBtn = document.getElementById("restart-btn");
  const lobbyBtn = document.getElementById("lobby-btn");
  const dpadButtons = document.querySelectorAll(".dpad-btn");

  const colors = {
    body: "#e3a552",
    head: "#f0c674",
    food: "#d6533a",
    grid: "rgba(255,255,255,0.04)",
  };

  const DIRS = {
    up: { x: 0, y: -1 },
    down: { x: 0, y: 1 },
    left: { x: -1, y: 0 },
    right: { x: 1, y: 0 },
  };
  const OPPOSITE = { up: "down", down: "up", left: "right", right: "left" };

  let selectedSize = "medium";
  let selectedDifficulty = "normal";
  let COLS, ROWS, difficulty;
  let snake, direction, pendingDirection, food, score, level, tickMs, gameOver;
  let rafId = null;
  let lastFrameTime = 0;
  let accumulator = 0;
  let levelToastTimer = null;

  function loadHighscore() {
    return Number(localStorage.getItem(HIGHSCORE_KEY) || 0);
  }

  function updateHighscoreDisplays(value) {
    highscoreEl.textContent = String(value);
    lobbyHighscoreEl.textContent = String(value);
  }

  function saveHighscoreIfBetter(value) {
    const current = loadHighscore();
    if (value > current) {
      localStorage.setItem(HIGHSCORE_KEY, String(value));
    }
    updateHighscoreDisplays(Math.max(current, value));
  }

  function randomFreeCell() {
    let cell;
    do {
      cell = { x: Math.floor(Math.random() * COLS), y: Math.floor(Math.random() * ROWS) };
    } while (snake.some((s) => s.x === cell.x && s.y === cell.y));
    return cell;
  }

  function applySelectedSettings() {
    const size = SIZE_PRESETS[selectedSize];
    COLS = size.cols;
    ROWS = size.rows;
    canvas.width = COLS * CELL;
    canvas.height = ROWS * CELL;
    difficulty = DIFFICULTY_PRESETS[selectedDifficulty];
  }

  function startGame() {
    applySelectedSettings();
    const startY = Math.floor(ROWS / 2);
    const startX = Math.min(7, COLS - 3);
    snake = [
      { x: startX, y: startY },
      { x: startX - 1, y: startY },
      { x: startX - 2, y: startY },
    ];
    direction = "right";
    pendingDirection = "right";
    score = 0;
    level = 1;
    tickMs = difficulty.startTick;
    gameOver = false;
    food = randomFreeCell();
    scoreEl.textContent = "0";
    levelEl.textContent = "1";
    updateHighscoreDisplays(loadHighscore());
    overlay.classList.add("hidden");
    levelToast.classList.remove("show");
    if (levelToastTimer) clearTimeout(levelToastTimer);
    draw();
    startLoop();
  }

  // A requestAnimationFrame accumulator instead of setInterval: changing
  // tickMs (food eaten / level up) takes effect on the next check without
  // restarting the timer's phase, which used to cause a visible stutter
  // right at the moment of eating.
  function startLoop() {
    if (rafId) cancelAnimationFrame(rafId);
    lastFrameTime = 0;
    accumulator = 0;
    rafId = requestAnimationFrame(gameLoop);
  }

  function stopLoop() {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = null;
  }

  function gameLoop(timestamp) {
    if (!lastFrameTime) lastFrameTime = timestamp;
    const delta = timestamp - lastFrameTime;
    lastFrameTime = timestamp;

    if (gameOver) return;

    accumulator += delta;
    while (accumulator >= tickMs) {
      tick();
      accumulator -= tickMs;
      if (gameOver) {
        accumulator = 0;
        break;
      }
    }
    rafId = requestAnimationFrame(gameLoop);
  }

  function showLevelUpToast(newLevel) {
    levelToast.textContent = `Level ${newLevel}!`;
    levelToast.classList.add("show");
    if (levelToastTimer) clearTimeout(levelToastTimer);
    levelToastTimer = setTimeout(() => levelToast.classList.remove("show"), LEVEL_TOAST_DURATION_MS);
  }

  function setDirection(dir) {
    if (gameOver || OPPOSITE[dir] === direction) return;
    pendingDirection = dir;
  }

  function tick() {
    direction = pendingDirection;
    const offset = DIRS[direction];
    const head = snake[0];
    const newHead = { x: head.x + offset.x, y: head.y + offset.y };

    const hitWall = newHead.x < 0 || newHead.x >= COLS || newHead.y < 0 || newHead.y >= ROWS;
    // Exclude the tail cell: it vacates this tick unless the snake is growing,
    // and food never spawns there, so moving onto it is always legal.
    const body = snake.slice(0, -1);
    const hitSelf = body.some((s) => s.x === newHead.x && s.y === newHead.y);

    if (hitWall || hitSelf) {
      endGame();
      return;
    }

    snake.unshift(newHead);
    if (newHead.x === food.x && newHead.y === food.y) {
      score++;
      scoreEl.textContent = String(score);
      food = randomFreeCell();
      tickMs = Math.max(difficulty.minTick, tickMs - difficulty.decrement);

      const newLevel = Math.floor(score / POINTS_PER_LEVEL) + 1;
      if (newLevel !== level) {
        level = newLevel;
        levelEl.textContent = String(level);
        showLevelUpToast(level);
        tickMs = Math.max(difficulty.minTick, tickMs - difficulty.levelBonus);
      }
    } else {
      snake.pop();
    }

    draw();
  }

  function endGame() {
    gameOver = true;
    saveHighscoreIfBetter(score);
    overlayTitle.textContent = "Game Over";
    overlayScore.textContent = `Punkte: ${score}`;
    overlay.classList.remove("hidden");
  }

  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = colors.grid;
    ctx.lineWidth = 1;
    for (let x = 0; x <= COLS; x++) {
      ctx.beginPath();
      ctx.moveTo(x * CELL, 0);
      ctx.lineTo(x * CELL, ROWS * CELL);
      ctx.stroke();
    }
    for (let y = 0; y <= ROWS; y++) {
      ctx.beginPath();
      ctx.moveTo(0, y * CELL);
      ctx.lineTo(COLS * CELL, y * CELL);
      ctx.stroke();
    }

    ctx.fillStyle = colors.food;
    roundedCell(food.x, food.y);

    snake.forEach((segment, index) => {
      ctx.fillStyle = index === 0 ? colors.head : colors.body;
      roundedCell(segment.x, segment.y);
    });
  }

  function roundedCell(cx, cy) {
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

  // Lobby option selectors (difficulty / board size)
  optionGroups.forEach((group) => {
    const option = group.dataset.option;
    group.querySelectorAll(".option-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        group.querySelectorAll(".option-btn").forEach((b) => b.classList.remove("selected"));
        btn.classList.add("selected");
        if (option === "difficulty") selectedDifficulty = btn.dataset.value;
        if (option === "size") selectedSize = btn.dataset.value;
      });
    });
  });

  function showLobby() {
    stopLoop();
    gameSection.classList.add("hidden");
    lobby.classList.remove("hidden");
    updateHighscoreDisplays(loadHighscore());
  }

  function showGame() {
    lobby.classList.add("hidden");
    gameSection.classList.remove("hidden");
  }

  startBtn.addEventListener("click", () => {
    showGame();
    startGame();
  });

  lobbyBtn.addEventListener("click", showLobby);
  restartBtn.addEventListener("click", startGame);

  // Keyboard controls
  window.addEventListener("keydown", (e) => {
    const map = {
      ArrowUp: "up", w: "up", W: "up",
      ArrowDown: "down", s: "down", S: "down",
      ArrowLeft: "left", a: "left", A: "left",
      ArrowRight: "right", d: "right", D: "right",
    };
    const dir = map[e.key];
    if (dir) {
      e.preventDefault();
      setDirection(dir);
    }
  });

  // Touch/swipe controls
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
    if (Math.abs(dx) > Math.abs(dy)) {
      setDirection(dx > 0 ? "right" : "left");
    } else {
      setDirection(dy > 0 ? "down" : "up");
    }
  }, { passive: true });

  // On-screen d-pad
  dpadButtons.forEach((btn) => {
    btn.addEventListener("click", () => setDirection(btn.dataset.dir));
  });

  updateHighscoreDisplays(loadHighscore());
})();
