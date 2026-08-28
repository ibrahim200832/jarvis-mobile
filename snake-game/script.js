(() => {
  "use strict";

  const COLS = 15;
  const ROWS = 20;
  const CELL = 30;
  const START_TICK_MS = 220;
  const MIN_TICK_MS = 80;
  const HIGHSCORE_KEY = "snake-game-highscore";

  const canvas = document.getElementById("board");
  const ctx = canvas.getContext("2d");
  const scoreEl = document.getElementById("score");
  const highscoreEl = document.getElementById("highscore");
  const overlay = document.getElementById("overlay");
  const overlayTitle = document.getElementById("overlay-title");
  const overlayScore = document.getElementById("overlay-score");
  const restartBtn = document.getElementById("restart-btn");
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

  let snake, direction, pendingDirection, food, score, tickMs, timer, gameOver;

  function loadHighscore() {
    return Number(localStorage.getItem(HIGHSCORE_KEY) || 0);
  }

  function saveHighscoreIfBetter(value) {
    const current = loadHighscore();
    if (value > current) {
      localStorage.setItem(HIGHSCORE_KEY, String(value));
    }
    highscoreEl.textContent = Math.max(current, value);
  }

  function randomFreeCell() {
    let cell;
    do {
      cell = { x: Math.floor(Math.random() * COLS), y: Math.floor(Math.random() * ROWS) };
    } while (snake.some((s) => s.x === cell.x && s.y === cell.y));
    return cell;
  }

  function startGame() {
    const startY = Math.floor(ROWS / 2);
    snake = [
      { x: 7, y: startY },
      { x: 6, y: startY },
      { x: 5, y: startY },
    ];
    direction = "right";
    pendingDirection = "right";
    score = 0;
    tickMs = START_TICK_MS;
    gameOver = false;
    food = randomFreeCell();
    scoreEl.textContent = "0";
    highscoreEl.textContent = loadHighscore();
    overlay.classList.add("hidden");
    restartTimer();
    draw();
  }

  function restartTimer() {
    if (timer) clearInterval(timer);
    timer = setInterval(tick, tickMs);
  }

  function setDirection(dir) {
    if (gameOver || OPPOSITE[dir] === direction) return;
    pendingDirection = dir;
  }

  function tick() {
    if (gameOver) return;
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
      tickMs = Math.max(MIN_TICK_MS, tickMs - 4);
      restartTimer();
    } else {
      snake.pop();
    }

    draw();
  }

  function endGame() {
    gameOver = true;
    clearInterval(timer);
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

  restartBtn.addEventListener("click", startGame);

  startGame();
})();
