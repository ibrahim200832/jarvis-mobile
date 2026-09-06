(() => {
  "use strict";

  const HIGHSCORE_KEY = "racing-game-highscore";

  // accel = how many m/s the top speed grows per second, capped at maxSpeed.
  const DIFFICULTY_PRESETS = {
    easy: { startSpeed: 14, maxSpeed: 32, accel: 0.35, obstacleGap: 55, obstacleJitter: 20 },
    normal: { startSpeed: 18, maxSpeed: 42, accel: 0.45, obstacleGap: 45, obstacleJitter: 16 },
    hard: { startSpeed: 22, maxSpeed: 54, accel: 0.6, obstacleGap: 34, obstacleJitter: 12 },
  };

  const LANE_WIDTH = 3.2;
  const LANE_X = [-LANE_WIDTH, 0, LANE_WIDTH];
  const OBSTACLE_POOL_SIZE = 14;
  const COLLISION_Z = 2.3;
  const COLLISION_X = 1.9;
  const ROAD_LENGTH = 200000;
  const CAMERA_HEIGHT = 4.2;
  const CAMERA_BACK = 7.5;
  const LOOKAHEAD = 14;
  const LANE_LERP_RATE = 8;
  const OBSTACLE_COLORS = [0xe6544c, 0xf2c94c, 0x9b59e6, 0x6bbf59, 0xe67e22];

  const lobbySection = document.getElementById("lobby");
  const gameSection = document.getElementById("game");
  const startBtn = document.getElementById("start-btn");
  const lobbyHighscoreEl = document.getElementById("lobby-highscore");
  const optionGroups = document.querySelectorAll(".option-buttons");

  const stageCanvas = document.getElementById("stage");
  const scoreEl = document.getElementById("score");
  const speedEl = document.getElementById("speed");
  const highscoreEl = document.getElementById("highscore");
  const overlay = document.getElementById("overlay");
  const overlayScoreEl = document.getElementById("overlay-score");
  const restartBtn = document.getElementById("restart-btn");
  const lobbyBtn = document.getElementById("lobby-btn");
  const steerLeftBtn = document.getElementById("steer-left");
  const steerRightBtn = document.getElementById("steer-right");

  let selectedDifficulty = "normal";
  let difficulty = DIFFICULTY_PRESETS[selectedDifficulty];

  let renderer, scene, camera, playerCar;
  const obstacles = [];
  let furthestObstacleZ = 0;

  let laneIndex = 1;
  let carX = LANE_X[1];
  let carZ = 0;
  let speed = 0;
  let distance = 0;
  let running = false;
  let gameOver = false;
  let rafId = null;
  let lastTime = 0;

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

  function buildRoadTexture() {
    const canvas = document.createElement("canvas");
    canvas.width = 128;
    canvas.height = 128;
    const g = canvas.getContext("2d");

    g.fillStyle = "#2a2f36";
    g.fillRect(0, 0, canvas.width, canvas.height);

    const roadWidth = LANE_WIDTH * LANE_X.length + 2;
    const toPixelX = (x) => ((x + roadWidth / 2) / roadWidth) * canvas.width;
    const edgeThickness = 4;
    const dashThickness = 4;

    g.fillStyle = "#e7e2d6";
    g.fillRect(0, 0, edgeThickness, canvas.height);
    g.fillRect(canvas.width - edgeThickness, 0, edgeThickness, canvas.height);

    g.fillStyle = "#e7c25a";
    for (let i = 0; i < LANE_X.length - 1; i++) {
      const boundaryX = (LANE_X[i] + LANE_X[i + 1]) / 2;
      const px = toPixelX(boundaryX);
      // Only painting the top half of the tile (and repeating the texture
      // along the road's length) is what turns this into a dash-gap pattern.
      g.fillRect(px - dashThickness / 2, 0, dashThickness, canvas.height / 2);
    }

    return new THREE.CanvasTexture(canvas);
  }

  function buildCarMesh(bodyColor, cabinColor) {
    const group = new THREE.Group();
    const wheelRadius = 0.34;

    const body = new THREE.Mesh(
      new THREE.BoxGeometry(1.7, 0.5, 3.3),
      new THREE.MeshLambertMaterial({ color: bodyColor })
    );
    body.position.y = wheelRadius + 0.25;
    group.add(body);

    const cabin = new THREE.Mesh(
      new THREE.BoxGeometry(1.2, 0.45, 1.6),
      new THREE.MeshLambertMaterial({ color: cabinColor })
    );
    cabin.position.set(0, wheelRadius + 0.725, -0.2);
    group.add(cabin);

    const wheelGeo = new THREE.CylinderGeometry(wheelRadius, wheelRadius, 0.32, 14);
    const wheelMat = new THREE.MeshLambertMaterial({ color: 0x101214 });
    [
      [-0.85, 1.15],
      [0.85, 1.15],
      [-0.85, -1.15],
      [0.85, -1.15],
    ].forEach(([x, z]) => {
      const wheel = new THREE.Mesh(wheelGeo, wheelMat);
      wheel.rotation.z = Math.PI / 2;
      wheel.position.set(x, wheelRadius, z);
      group.add(wheel);
    });

    return group;
  }

  function randomObstacleColor() {
    return OBSTACLE_COLORS[Math.floor(Math.random() * OBSTACLE_COLORS.length)];
  }

  function initSceneOnce() {
    if (renderer) return;

    renderer = new THREE.WebGLRenderer({ canvas: stageCanvas, antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));

    const skyColor = 0x0a121c;
    scene = new THREE.Scene();
    scene.background = new THREE.Color(skyColor);
    scene.fog = new THREE.Fog(skyColor, 40, 140);

    camera = new THREE.PerspectiveCamera(62, 1, 0.1, 300);

    scene.add(new THREE.AmbientLight(0xffffff, 0.55));
    const sun = new THREE.DirectionalLight(0xffffff, 0.85);
    sun.position.set(-30, 60, 20);
    scene.add(sun);

    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(400, ROAD_LENGTH),
      new THREE.MeshLambertMaterial({ color: 0x1c3324 })
    );
    ground.rotation.x = -Math.PI / 2;
    ground.position.set(0, -0.02, -ROAD_LENGTH / 2 + 50);
    scene.add(ground);

    const roadWidth = LANE_WIDTH * LANE_X.length + 2;
    const roadTexture = buildRoadTexture();
    roadTexture.wrapS = THREE.ClampToEdgeWrapping;
    roadTexture.wrapT = THREE.RepeatWrapping;
    roadTexture.repeat.set(1, ROAD_LENGTH / 8);
    const road = new THREE.Mesh(
      new THREE.PlaneGeometry(roadWidth, ROAD_LENGTH),
      new THREE.MeshLambertMaterial({ map: roadTexture })
    );
    road.rotation.x = -Math.PI / 2;
    road.position.set(0, 0, -ROAD_LENGTH / 2 + 50);
    scene.add(road);

    playerCar = buildCarMesh(0x3ecbe0, 0x0d2630);
    scene.add(playerCar);

    for (let i = 0; i < OBSTACLE_POOL_SIZE; i++) {
      const mesh = buildCarMesh(randomObstacleColor(), 0x14181d);
      scene.add(mesh);
      obstacles.push({ mesh, z: 0, laneIndex: 0 });
    }

    window.addEventListener("resize", resizeRenderer);
  }

  function resizeRenderer() {
    if (!renderer) return;
    const width = stageCanvas.clientWidth;
    const height = stageCanvas.clientHeight;
    if (!width || !height) return;
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
  }

  function placeObstacle(ob, z) {
    ob.z = z;
    ob.laneIndex = Math.floor(Math.random() * LANE_X.length);
    ob.mesh.position.set(LANE_X[ob.laneIndex], 0, ob.z);
  }

  function resetObstacles() {
    furthestObstacleZ = -20;
    obstacles.forEach((ob) => {
      placeObstacle(ob, furthestObstacleZ);
      furthestObstacleZ -= difficulty.obstacleGap;
    });
  }

  function updateObstacles() {
    obstacles.forEach((ob) => {
      if (ob.z > carZ + 6) {
        furthestObstacleZ -= difficulty.obstacleGap + (Math.random() * 2 - 1) * difficulty.obstacleJitter;
        placeObstacle(ob, furthestObstacleZ);
      }
    });
  }

  function checkCollision() {
    return obstacles.some(
      (ob) => Math.abs(ob.z - carZ) < COLLISION_Z && Math.abs(ob.mesh.position.x - carX) < COLLISION_X
    );
  }

  function changeLane(delta) {
    if (!running || gameOver) return;
    laneIndex = Math.min(LANE_X.length - 1, Math.max(0, laneIndex + delta));
  }

  function showLobby() {
    lobbySection.classList.remove("hidden");
    gameSection.classList.add("hidden");
  }

  function showGameScreen() {
    lobbySection.classList.add("hidden");
    gameSection.classList.remove("hidden");
  }

  function startGame() {
    initSceneOnce();
    difficulty = DIFFICULTY_PRESETS[selectedDifficulty];

    laneIndex = 1;
    carX = LANE_X[1];
    carZ = 0;
    speed = difficulty.startSpeed;
    distance = 0;
    gameOver = false;
    running = true;

    playerCar.position.set(carX, 0, carZ);
    playerCar.rotation.z = 0;
    resetObstacles();

    overlay.classList.add("hidden");
    scoreEl.textContent = "0";
    speedEl.textContent = String(Math.round(speed * 3.6));

    showGameScreen();
    resizeRenderer();

    if (rafId) cancelAnimationFrame(rafId);
    lastTime = performance.now();
    rafId = requestAnimationFrame(loop);
  }

  function endGame() {
    gameOver = true;
    running = false;
    if (rafId) cancelAnimationFrame(rafId);

    const finalDistance = Math.floor(distance);
    saveHighscoreIfBetter(finalDistance);
    overlayScoreEl.textContent = `Distanz: ${finalDistance} m · Tempo: ${Math.round(speed * 3.6)} km/h`;
    overlay.classList.remove("hidden");
  }

  function loop(now) {
    rafId = requestAnimationFrame(loop);
    let dt = (now - lastTime) / 1000;
    lastTime = now;
    dt = Math.min(dt, 0.05);

    speed = Math.min(difficulty.maxSpeed, speed + difficulty.accel * dt);
    const moveZ = speed * dt;
    carZ -= moveZ;
    distance += moveZ;

    const targetX = LANE_X[laneIndex];
    carX += (targetX - carX) * Math.min(1, LANE_LERP_RATE * dt);
    playerCar.position.set(carX, 0, carZ);
    playerCar.rotation.z = THREE.MathUtils.clamp((targetX - carX) * 0.12, -0.25, 0.25);

    updateObstacles();

    if (checkCollision()) {
      endGame();
      return;
    }

    camera.position.set(carX, CAMERA_HEIGHT, carZ + CAMERA_BACK);
    camera.lookAt(carX, 1.2, carZ - LOOKAHEAD);

    scoreEl.textContent = String(Math.floor(distance));
    speedEl.textContent = String(Math.round(speed * 3.6));

    renderer.render(scene, camera);
  }

  optionGroups.forEach((group) => {
    group.querySelectorAll(".option-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        group.querySelectorAll(".option-btn").forEach((b) => b.classList.remove("selected"));
        btn.classList.add("selected");
        if (group.dataset.option === "difficulty") {
          selectedDifficulty = btn.dataset.value;
        }
      });
    });
  });

  startBtn.addEventListener("click", startGame);
  restartBtn.addEventListener("click", startGame);
  lobbyBtn.addEventListener("click", () => {
    running = false;
    if (rafId) cancelAnimationFrame(rafId);
    showLobby();
  });

  steerLeftBtn.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    changeLane(-1);
  });
  steerRightBtn.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    changeLane(1);
  });

  window.addEventListener("keydown", (e) => {
    if (e.repeat) return;
    if (e.key === "ArrowLeft" || e.key === "a" || e.key === "A") changeLane(-1);
    if (e.key === "ArrowRight" || e.key === "d" || e.key === "D") changeLane(1);
  });

  updateHighscoreDisplays(loadHighscore());
})();
