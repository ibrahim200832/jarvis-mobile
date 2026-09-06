(() => {
  "use strict";

  const BEST_NIGHT_KEY = "nightshift-game-best-night";
  const WALK_SPEED = 1.8;
  const RUN_SPEED = 3.6;
  const CAMERA_FOLLOW_DIST = 4.2;
  const PITCH_MIN = -0.5;
  const PITCH_MAX = 0.6;
  const LOOK_RECENTER_DELAY_MS = 1200;
  const JOYSTICK_RADIUS = 42;

  const lobbySection = document.getElementById("lobby");
  const gameSection = document.getElementById("game");
  const continueBtn = document.getElementById("continue-btn");
  const newgameBtn = document.getElementById("newgame-btn");
  const lobbyBestEl = document.getElementById("lobby-best");

  const stageCanvas = document.getElementById("stage");
  const hudNightEl = document.getElementById("hud-night");
  const hudQuestEl = document.getElementById("hud-quest");
  const fadeEl = document.getElementById("fade");
  const toastEl = document.getElementById("toast");
  const inventoryBar = document.getElementById("inventory-bar");

  const dialoguePanel = document.getElementById("dialogue-panel");
  const dialogueName = document.getElementById("dialogue-name");
  const dialoguePortrait = document.getElementById("dialogue-portrait");
  const dialogueText = document.getElementById("dialogue-text");
  const dialogueNext = document.getElementById("dialogue-next");

  const overlayEl = document.getElementById("overlay");
  const overlayTitleEl = document.getElementById("overlay-title");
  const overlayTextEl = document.getElementById("overlay-text");
  const overlayPrimaryBtn = document.getElementById("overlay-primary-btn");
  const overlaySecondaryBtn = document.getElementById("overlay-secondary-btn");

  const lookZone = document.getElementById("look-zone");
  const joystickZone = document.getElementById("joystick-zone");
  const joystickKnob = document.getElementById("joystick-knob");
  const flashlightBtn = document.getElementById("flashlight-btn");
  const interactBtn = document.getElementById("interact-btn");

  let renderer, scene, camera;
  let playerRefs;
  let playerX = 0;
  let playerZ = 0;
  let playerYaw = 0;
  let cameraYaw = Math.PI;
  let cameraPitch = 0.15;
  let flashlightLight, ambientLight, fixtureLight;
  let flashlightOn = false;

  let currentNightIndex = 0;
  let nightElapsed = 0;
  let npcRuntimeList = [];
  let itemRuntimeList = [];
  let placementZoneList = [];
  let currentInteractTarget = null;
  let overlayMode = "caught";

  let running = false;
  let rafId = null;
  let lastTime = 0;
  let lastFootstepPhase = 0;
  let toastTimer = null;

  const keys = {};
  let joystickPointerId = null;
  const joystickVector = { x: 0, y: 0 };
  let lookPointerId = null;
  let lastLookX = 0;
  let lastLookY = 0;
  let lastLookInputTime = 0;

  function clamp(v, min, max) {
    return Math.max(min, Math.min(max, v));
  }

  function lerpAngle(a, b, t) {
    let diff = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
    if (diff < -Math.PI) diff += Math.PI * 2;
    return a + diff * t;
  }

  function loadBestNight() {
    return Number(localStorage.getItem(BEST_NIGHT_KEY) || 0);
  }

  function saveBestNight(value) {
    const current = loadBestNight();
    if (value > current) localStorage.setItem(BEST_NIGHT_KEY, String(value));
  }

  function showToast(text) {
    if (!text) return;
    toastEl.textContent = text;
    toastEl.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove("show"), 2200);
  }

  function showLobby() {
    lobbySection.classList.remove("hidden");
    gameSection.classList.add("hidden");
    const best = loadBestNight();
    continueBtn.classList.toggle("hidden", best <= 0);
    lobbyBestEl.textContent = best <= 0 ? "Noch keine Nacht geschafft" : "Nacht " + best + " erreicht";
  }

  function showGameScreen() {
    lobbySection.classList.add("hidden");
    gameSection.classList.remove("hidden");
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

  function buildItemMesh(itemId) {
    const group = new THREE.Group();
    let core;
    if (itemId === "cleaning_spray") {
      core = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 0.28, 10), new THREE.MeshLambertMaterial({ color: 0x6bbf59 }));
    } else if (itemId === "snack_box") {
      core = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.16, 0.14), new THREE.MeshLambertMaterial({ color: 0xf2c94c }));
    } else {
      core = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.22, 10), new THREE.MeshLambertMaterial({ color: 0xe6544c }));
    }
    core.position.y = 0.4;
    group.add(core);
    group.userData.baseY = 0.4;
    return group;
  }

  function buildZoneMarker() {
    const ringTex = NS.Textures.buildRingTexture("#3ecbe0");
    const mat = new THREE.MeshBasicMaterial({ map: ringTex, transparent: true, side: THREE.DoubleSide });
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 1.4), mat);
    mesh.rotation.x = -Math.PI / 2;
    return mesh;
  }

  function initSceneOnce() {
    if (renderer) return;

    renderer = new THREE.WebGLRenderer({ canvas: stageCanvas, antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x05060a);

    camera = new THREE.PerspectiveCamera(65, 1, 0.1, 80);

    ambientLight = new THREE.AmbientLight(0xaabbff, 0.2);
    scene.add(ambientLight);

    fixtureLight = new THREE.PointLight(0xffdca0, 1.0, 9);
    fixtureLight.position.set(-3.5, 2.6, 2);
    scene.add(fixtureLight);

    const fridgeLight = new THREE.PointLight(0x3aa0e0, 0.6, 4);
    fridgeLight.position.set(5, 1.4, -1);
    scene.add(fridgeLight);

    flashlightLight = new THREE.SpotLight(0xffffff, 1.6, 15, Math.PI / 7, 0.4);
    flashlightLight.visible = false;
    scene.add(flashlightLight);
    scene.add(flashlightLight.target);

    NS.Environment.build(scene);

    playerRefs = NS.Character.buildHumanoid({ uniformColor: 0x3a4a5a, facePreset: "default" });
    scene.add(playerRefs.group);

    NS.NPC.init({ panel: dialoguePanel, name: dialogueName, portrait: dialoguePortrait, text: dialogueText, nextBtn: dialogueNext });

    window.addEventListener("resize", resizeRenderer);
  }

  function clearNightEntities() {
    NS.NPC.clear(scene, npcRuntimeList);
    npcRuntimeList = [];
    itemRuntimeList.forEach((it) => scene.remove(it.mesh));
    itemRuntimeList = [];
    placementZoneList.forEach((z) => scene.remove(z.ring));
    placementZoneList = [];
    NS.Threat.dispose(scene);
  }

  function loadNight(index) {
    currentNightIndex = index;
    const nightData = NS.NIGHTS[index];

    clearNightEntities();

    const envRefs = NS.Environment.getRefs();
    playerX = envRefs.spawnPosition.x;
    playerZ = envRefs.spawnPosition.z;
    playerYaw = Math.PI;
    cameraYaw = Math.PI;
    cameraPitch = 0.15;

    ambientLight.intensity = nightData.environment.ambientIntensity;
    scene.fog = new THREE.Fog(0x05060a, nightData.environment.fogNear, nightData.environment.fogFar);

    NS.Inventory.init(inventoryBar);
    NS.Quests.load(nightData.quests);

    npcRuntimeList = NS.NPC.spawn(scene, nightData.npcs);

    itemRuntimeList = (nightData.itemsToSpawn || []).map((def) => {
      const mesh = buildItemMesh(def.itemId);
      mesh.position.set(def.position[0], def.position[1], def.position[2]);
      scene.add(mesh);
      return { def, mesh, collected: false };
    });

    placementZoneList = (nightData.placementZones || []).map((def) => {
      const ring = buildZoneMarker();
      ring.position.set(def.position[0], 0.05, def.position[2]);
      scene.add(ring);
      return { def, ring, radius: def.radius || 1.0 };
    });

    NS.Threat.init(scene, nightData.threat, onPlayerCaught);

    nightElapsed = 0;
    hudNightEl.textContent = nightData.label;
    showToast(nightData.introLine);
    updateQuestBanner();
  }

  function npcNameForQuest(q) {
    const npc = npcRuntimeList.find((n) => n.def.id === q.giverId);
    return npc ? npc.def.name : "?";
  }

  function updateQuestBanner() {
    const q = NS.Quests.activeBannerQuest();
    if (!q) {
      hudQuestEl.textContent = "Quest: alles erledigt";
      return;
    }
    let suffix = "";
    if (q.state === "locked") suffix = " (sprich mit " + npcNameForQuest(q) + ")";
    else if (q.state === "readyToTurnIn") suffix = " – zurück zu " + npcNameForQuest(q) + "!";
    hudQuestEl.textContent = "Quest: " + q.title + suffix;
  }

  function updateItems() {
    itemRuntimeList.forEach((it) => {
      if (it.collected) return;
      it.mesh.rotation.y += 0.02;
      it.mesh.children[0].position.y = it.mesh.userData.baseY + Math.sin(performance.now() * 0.003 + it.mesh.id) * 0.05;
    });
  }

  function updateZones() {
    placementZoneList.forEach((z) => {
      if (z.def.autoTrigger) {
        const d = Math.hypot(z.def.position[0] - playerX, z.def.position[2] - playerZ);
        if (d < z.radius) NS.Quests.notifyZoneEnter(z.def.id);
      }
    });
  }

  function findInteractable() {
    const candidates = [];
    const envRefs = NS.Environment.getRefs();

    const busDist = Math.hypot(envRefs.busStopPosition.x - playerX, envRefs.busStopPosition.z - playerZ);
    if (busDist < 1.6) candidates.push({ dist: busDist, type: "bus" });

    const checkoutDist = Math.hypot(envRefs.checkoutPosition.x - playerX, envRefs.checkoutPosition.z - playerZ);
    if (checkoutDist < 1.4) candidates.push({ dist: checkoutDist, type: "checkout" });

    const npc = NS.NPC.nearestInRange(npcRuntimeList, { x: playerX, z: playerZ });
    if (npc) candidates.push({ dist: 0.5, type: "npc", npc });

    itemRuntimeList.forEach((it) => {
      if (it.collected) return;
      const d = Math.hypot(it.mesh.position.x - playerX, it.mesh.position.z - playerZ);
      if (d < 1.2) candidates.push({ dist: d, type: "item", item: it });
    });

    placementZoneList.forEach((z) => {
      if (z.def.autoTrigger) return;
      const d = Math.hypot(z.def.position[0] - playerX, z.def.position[2] - playerZ);
      if (d < z.radius && NS.Inventory.has(z.def.itemId)) candidates.push({ dist: d, type: "zone", zone: z });
    });

    if (candidates.length === 0) return null;
    candidates.sort((a, b) => a.dist - b.dist);
    return candidates[0];
  }

  function updateInteractPrompt() {
    if (NS.NPC.isOpen()) {
      interactBtn.classList.add("hidden");
      currentInteractTarget = null;
      return;
    }
    const target = findInteractable();
    currentInteractTarget = target;
    if (!target) {
      interactBtn.classList.add("hidden");
      return;
    }
    interactBtn.classList.remove("hidden");
    if (target.type === "bus") interactBtn.textContent = NS.Quests.allComplete() ? "Einsteigen" : "Noch nicht fertig";
    else if (target.type === "checkout") interactBtn.textContent = "Kasse benutzen";
    else if (target.type === "npc") interactBtn.textContent = "Reden";
    else if (target.type === "item") interactBtn.textContent = "Aufheben";
    else if (target.type === "zone") interactBtn.textContent = "Ablegen: " + (NS.ITEM_LABELS[target.zone.def.itemId] || target.zone.def.itemId);
  }

  function doInteract() {
    if (!running || NS.NPC.isOpen() || !currentInteractTarget) return;
    const target = currentInteractTarget;

    if (target.type === "bus") {
      if (NS.Quests.allComplete()) boardBus();
      else showToast("Noch nicht alles erledigt.");
    } else if (target.type === "checkout") {
      NS.Quests.notifyCheckoutUse();
      NS.Audio.playBlip();
      showToast("Kasse benutzt");
    } else if (target.type === "npc") {
      NS.NPC.talkTo(target.npc, () => {});
    } else if (target.type === "item") {
      target.item.collected = true;
      scene.remove(target.item.mesh);
      NS.Inventory.add(target.item.def.itemId, 1);
      showToast("+1 " + (NS.ITEM_LABELS[target.item.def.itemId] || target.item.def.itemId));
    } else if (target.type === "zone") {
      NS.Inventory.remove(target.zone.def.itemId, 1);
      NS.Environment.registerPlacement(target.zone.def.id);
      scene.remove(target.zone.ring);
      showToast((NS.ITEM_LABELS[target.zone.def.itemId] || "") + " abgelegt");
    }
  }

  function toggleFlashlight() {
    flashlightOn = !flashlightOn;
    flashlightBtn.classList.toggle("active", flashlightOn);
    flashlightLight.visible = flashlightOn;
  }

  function onPlayerCaught() {
    running = false;
    overlayMode = "caught";
    overlayTitleEl.textContent = "Erwischt!";
    overlayTextEl.textContent = "Irgendwas hat dich gekriegt. " + NS.NIGHTS[currentNightIndex].label + " von vorn?";
    overlayPrimaryBtn.textContent = "Nochmal versuchen";
    overlayEl.classList.remove("hidden");
  }

  function showEndingScreen() {
    overlayMode = "ending";
    overlayTitleEl.textContent = "Alle Nächte geschafft!";
    overlayTextEl.textContent = "Du hast die Woche überlebt.";
    overlayPrimaryBtn.textContent = "Neu starten";
    overlayEl.classList.remove("hidden");
  }

  function boardBus() {
    running = false;
    fadeEl.classList.add("show");
    setTimeout(() => {
      const nextIndex = currentNightIndex + 1;
      if (nextIndex >= NS.NIGHTS.length) {
        saveBestNight(NS.NIGHTS.length);
        fadeEl.classList.remove("show");
        showEndingScreen();
      } else {
        saveBestNight(nextIndex);
        loadNight(nextIndex);
        fadeEl.classList.remove("show");
        running = true;
      }
    }, 550);
  }

  function getInputState() {
    let x = joystickVector.x;
    let y = joystickVector.y;
    if (keys.KeyW || keys.ArrowUp) y += 1;
    if (keys.KeyS || keys.ArrowDown) y -= 1;
    if (keys.KeyA || keys.ArrowLeft) x -= 1;
    if (keys.KeyD || keys.ArrowRight) x += 1;
    const len = Math.hypot(x, y);
    if (len > 1) {
      x /= len;
      y /= len;
    }
    const magnitude = Math.min(1, len);
    const running2 = magnitude > 0.85 || !!keys.ShiftLeft || !!keys.ShiftRight;
    return { x, y, magnitude, running: running2 };
  }

  function loop(now) {
    rafId = requestAnimationFrame(loop);
    let dt = (now - lastTime) / 1000;
    lastTime = now;
    dt = Math.min(dt, 0.05);

    if (!running || !renderer) {
      if (renderer) renderer.render(scene, camera);
      return;
    }

    nightElapsed += dt;

    const input = getInputState();
    const isMoving = input.magnitude > 0.05 && !NS.NPC.isOpen();
    if (isMoving) {
      const forwardX = Math.sin(cameraYaw);
      const forwardZ = Math.cos(cameraYaw);
      const rightX = Math.cos(cameraYaw);
      const rightZ = -Math.sin(cameraYaw);
      let dx = forwardX * input.y + rightX * input.x;
      let dz = forwardZ * input.y + rightZ * input.x;
      const dlen = Math.hypot(dx, dz);
      if (dlen > 0.001) {
        dx /= dlen;
        dz /= dlen;
      }
      const speed = input.running ? RUN_SPEED : WALK_SPEED;
      const nx = playerX + dx * speed * dt;
      const nz = playerZ + dz * speed * dt;
      const resolved = NS.Environment.resolveMove(playerX, playerZ, nx, nz, 0.35);
      playerX = resolved.x;
      playerZ = resolved.z;
      const desiredYaw = Math.atan2(dx, dz);
      playerYaw = lerpAngle(playerYaw, desiredYaw, Math.min(1, dt * 10));
    }

    playerRefs.group.position.set(playerX, 0, playerZ);
    playerRefs.group.rotation.y = playerYaw;
    NS.Character.updateWalkCycle(playerRefs, dt, isMoving);

    const phase = Math.floor(playerRefs.walkCycleT / Math.PI);
    if (isMoving && phase !== lastFootstepPhase) {
      lastFootstepPhase = phase;
      NS.Audio.playFootstep();
    }

    if (lookPointerId === null && isMoving && performance.now() - lastLookInputTime > LOOK_RECENTER_DELAY_MS) {
      cameraYaw = lerpAngle(cameraYaw, playerYaw, Math.min(1, dt * 1.5));
    }

    const camX = playerX - Math.sin(cameraYaw) * CAMERA_FOLLOW_DIST;
    const camZ = playerZ - Math.cos(cameraYaw) * CAMERA_FOLLOW_DIST;
    const camY = 2.0 + Math.sin(cameraPitch) * 2.2;
    camera.position.set(camX, camY, camZ);
    camera.lookAt(playerX, 1.1 + Math.sin(cameraPitch) * 1.0, playerZ);

    flashlightLight.position.copy(camera.position);
    flashlightLight.target.position.set(playerX + Math.sin(cameraYaw) * 4, 1, playerZ + Math.cos(cameraYaw) * 4);

    const awareness01 = NS.Threat.getAwareness() / 100;
    fixtureLight.intensity = 0.85 + Math.sin(now * 0.01) * 0.05 - (Math.random() < 0.02 + awareness01 * 0.12 ? 0.5 : 0);

    NS.Threat.update(dt, new THREE.Vector3(playerX, 0, playerZ), isMoving, input.running, flashlightOn);

    updateItems();
    updateZones();
    NS.Quests.update(nightElapsed);
    updateInteractPrompt();
    updateQuestBanner();

    renderer.render(scene, camera);
  }

  function startGame(startIndex) {
    NS.Audio.init();
    initSceneOnce();
    showGameScreen();
    resizeRenderer();
    loadNight(startIndex);
    running = true;
    lastTime = performance.now();
    if (!rafId) rafId = requestAnimationFrame(loop);
  }

  continueBtn.addEventListener("click", () => {
    const best = loadBestNight();
    startGame(Math.min(best, NS.NIGHTS.length - 1));
  });
  newgameBtn.addEventListener("click", () => startGame(0));

  overlayPrimaryBtn.addEventListener("click", () => {
    overlayEl.classList.add("hidden");
    if (overlayMode === "caught") loadNight(currentNightIndex);
    else loadNight(0);
    running = true;
  });
  overlaySecondaryBtn.addEventListener("click", () => {
    overlayEl.classList.add("hidden");
    running = false;
    showLobby();
  });

  interactBtn.addEventListener("click", doInteract);
  flashlightBtn.addEventListener("click", toggleFlashlight);

  function updateJoystick(e) {
    const rect = joystickZone.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const dx = e.clientX - cx;
    const dy = e.clientY - cy;
    const dist = Math.hypot(dx, dy);
    const clamped = Math.min(dist, JOYSTICK_RADIUS);
    const angle = Math.atan2(dy, dx);
    const kx = Math.cos(angle) * clamped;
    const ky = Math.sin(angle) * clamped;
    joystickKnob.style.transform = "translate(" + kx + "px, " + ky + "px)";
    joystickVector.x = kx / JOYSTICK_RADIUS;
    joystickVector.y = -ky / JOYSTICK_RADIUS;
  }

  function endJoystick(e) {
    if (e.pointerId !== joystickPointerId) return;
    joystickPointerId = null;
    joystickVector.x = 0;
    joystickVector.y = 0;
    joystickKnob.style.transform = "translate(0px, 0px)";
  }

  joystickZone.addEventListener("pointerdown", (e) => {
    if (joystickPointerId !== null) return;
    joystickPointerId = e.pointerId;
    joystickZone.setPointerCapture(e.pointerId);
    updateJoystick(e);
  });
  joystickZone.addEventListener("pointermove", (e) => {
    if (e.pointerId !== joystickPointerId) return;
    updateJoystick(e);
  });
  joystickZone.addEventListener("pointerup", endJoystick);
  joystickZone.addEventListener("pointercancel", endJoystick);

  lookZone.addEventListener("pointerdown", (e) => {
    if (lookPointerId !== null || NS.NPC.isOpen()) return;
    lookPointerId = e.pointerId;
    lastLookX = e.clientX;
    lastLookY = e.clientY;
    lookZone.setPointerCapture(e.pointerId);
  });
  lookZone.addEventListener("pointermove", (e) => {
    if (e.pointerId !== lookPointerId) return;
    const dx = e.clientX - lastLookX;
    const dy = e.clientY - lastLookY;
    lastLookX = e.clientX;
    lastLookY = e.clientY;
    cameraYaw -= dx * 0.006;
    cameraPitch = clamp(cameraPitch - dy * 0.005, PITCH_MIN, PITCH_MAX);
    lastLookInputTime = performance.now();
  });
  function endLook(e) {
    if (e.pointerId !== lookPointerId) return;
    lookPointerId = null;
  }
  lookZone.addEventListener("pointerup", endLook);
  lookZone.addEventListener("pointercancel", endLook);

  window.addEventListener("keydown", (e) => {
    keys[e.code] = true;
    if (e.code === "KeyE") doInteract();
    if (e.code === "KeyF") toggleFlashlight();
  });
  window.addEventListener("keyup", (e) => {
    keys[e.code] = false;
  });

  showLobby();
})();
