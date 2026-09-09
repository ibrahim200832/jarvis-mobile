/* ============================================================================
   RELIC ISLAND — 3D Open-World-Abenteuer
   Reines Vanilla-JS + Three.js (r15x UMD-Build), keine externen Assets außer
   dem vendored three.min.js. Läuft als Web-Seite und im Android-WebView-Wrapper.
   ========================================================================== */
(function () {
  'use strict';

  /* ------------------------------------------------------------------------
     Konstanten
     ------------------------------------------------------------------------ */
  const SAVE_KEY = 'relic-island-save-v2';
  const WORLD_RADIUS = 100; // unsichtbare Wand weit hinter dem letzten Eiland
  const ISLANDS = [
    { id: 'home', name: 'Hafen-Eiland', cx: -38, cz: -34, r: 28 },
    { id: 'mountain', name: 'Berg-Eiland', cx: -42, cz: 30, r: 30 },
    { id: 'village', name: 'Dorf-Eiland', cx: 40, cz: 34, r: 28 },
    { id: 'castle', name: 'Burg-Eiland', cx: 46, cz: -32, r: 30 },
  ];
  const BRIDGE_LINKS = [['home', 'mountain'], ['mountain', 'village'], ['village', 'castle'], ['castle', 'home']];
  const SPAWN = { x: -30, z: -26 };
  const MOUNTAIN_POS = { x: -42, z: 30 };
  const PATH_SEGMENTS = []; // wird in buildWorld() aus den Brücken-Ankern gefüllt
  const PATH_WIDTH = 3.2;
  const GRAVITY = 18;
  const JUMP_SPEED = 6.4;
  const WATER_LEVEL = 0;
  const SWIM_GRAVITY = GRAVITY * 0.18;
  const SWIM_UP_SPEED = 3.4;
  const SWIM_BUOYANCY = 1.1;
  const SUBMERGE_DEPTH = 0.35; // wie tief die Wasseroberflaeche ueber der Spielerposition sein muss, um als "untergetaucht" zu gelten
  const OXYGEN_DRAIN = 9;
  const OXYGEN_REGEN = 34;
  const DROWN_TICK_DAMAGE = 6;
  const DROWN_TICK_INTERVAL = 0.6;
  const PLAYER_RADIUS = 0.35;
  const TREE_COLLIDE_R = 0.55;
  const ROCK_COLLIDE_R = 0.85;
  const WALL_COLLIDE_R = 1.25;
  const ATTACK_RANGE = 2.3;
  const ATTACK_COOLDOWN = 0.45;
  const INTERACT_RANGE = 2.4;
  const STAMINA_DRAIN = 22;
  const STAMINA_REGEN = 14;
  const HEALTH_REGEN = 0.6;
  const DAY_LENGTH = 260; // Sekunden pro voller Tag/Nacht-Zyklus
  const MIN_PITCH = 0.12;
  const MAX_PITCH = 1.25;
  const MIN_DIST = 3.5;
  const MAX_DIST = 12;

  const BUILD_OPTIONS = [
    { id: 'campfire', name: 'Lagerfeuer', icon: '🔥', cost: { wood: 3, stone: 2 }, footprint: 1.3 },
    { id: 'wall', name: 'Holzwand', icon: '🧱', cost: { wood: 5, stone: 0 }, footprint: 1.6 },
    { id: 'platform', name: 'Plattform', icon: '▬', cost: { wood: 4, stone: 1 }, footprint: 1.8 },
  ];

  const QUESTS = [
    { id: 'wood', title: 'Der erste Schritt', desc: 'Sammle 5 Holz', target: 5, get: () => counters.woodTotal, reward: { coin: 10, xp: 20 } },
    { id: 'stone', title: 'Steinbruch', desc: 'Sammle 5 Stein', target: 5, get: () => counters.stoneTotal, reward: { coin: 12, xp: 25 } },
    { id: 'fire', title: 'Lagerfeuer', desc: 'Baue ein Lagerfeuer', target: 1, get: () => counters.campfiresBuilt, reward: { coin: 15, xp: 30 } },
    { id: 'fight', title: 'Schädlingsbekämpfung', desc: 'Besiege 3 Schleime', target: 3, get: () => counters.enemiesDefeated, reward: { coin: 25, xp: 50 } },
    { id: 'chest', title: 'Schatzsucher', desc: 'Öffne 2 Truhen', target: 2, get: () => counters.chestsOpened, reward: { coin: 30, xp: 60 } },
    { id: 'peak', title: 'Gipfelsturm', desc: 'Erreiche den Gipfel des Berges', target: 1, get: () => (counters.peakReached ? 1 : 0), reward: { coin: 50, xp: 100 } },
  ];

  /* ------------------------------------------------------------------------
     Utility
     ------------------------------------------------------------------------ */
  function clamp(v, min, max) { return v < min ? min : v > max ? max : v; }
  function clamp01(v) { return clamp(v, 0, 1); }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function lerpAngle(a, b, t) {
    let diff = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
    if (diff < -Math.PI) diff += Math.PI * 2;
    return a + diff * t;
  }
  function flatDistXZ(x1, z1, x2, z2) { return Math.hypot(x1 - x2, z1 - z2); }
  function flatDist(a, b) { return Math.hypot(a.x - b.x, a.z - b.z); }
  function mulberry32(seed) {
    return function () {
      seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const worldRand = mulberry32(1337);

  /* ------------------------------------------------------------------------
     Terrain-Höhenfunktion: mehrere Eiland-Kuppeln (deterministisch, kein
     Perlin nötig) + ein See dazwischen, da wo keine Kuppel hinreicht.
     ------------------------------------------------------------------------ */
  function heightAt(x, z) {
    let h = -3; // Seeboden zwischen den Eilanden
    for (let i = 0; i < ISLANDS.length; i++) {
      const isle = ISLANDS[i];
      const dx = x - isle.cx, dz = z - isle.cz;
      const d = Math.hypot(dx, dz);
      const fall = clamp(1 - Math.pow(d / isle.r, 1.9), 0, 1);
      if (fall <= 0) continue;
      let local = fall * 8.5;
      local += Math.sin(x * 0.05 + 1.3 + i) * Math.cos(z * 0.045 - 0.6 + i) * 2.6 * fall;
      local += Math.sin(x * 0.11 - z * 0.08 + i * 2) * 1.2 * fall;
      if (local > h) h = local;
    }
    const md = Math.hypot(x - MOUNTAIN_POS.x, z - MOUNTAIN_POS.z);
    h += Math.pow(Math.max(0, 1 - md / 22), 2) * 22;
    return h;
  }
  let peakHeight = 0; // wird in buildWorld() gesetzt

  function pointInLocalBox(px, pz, cx, cz, rotY, hw, hd) {
    const dx = px - cx, dz = pz - cz;
    const cosT = Math.cos(rotY || 0), sinT = Math.sin(rotY || 0);
    const lx = dx * cosT - dz * sinT;
    const lz = dx * sinT + dz * cosT;
    return Math.abs(lx) <= hw && Math.abs(lz) <= hd;
  }
  function distToSegment(px, pz, ax, az, bx, bz) {
    const abx = bx - ax, abz = bz - az;
    const lenSq = abx * abx + abz * abz || 1;
    const t = clamp(((px - ax) * abx + (pz - az) * abz) / lenSq, 0, 1);
    const cx = ax + abx * t, cz = az + abz * t;
    return Math.hypot(px - cx, pz - cz);
  }
  function getIsland(id) { return ISLANDS.find((i) => i.id === id); }

  /* ------------------------------------------------------------------------
     Audio (rein prozedural via WebAudio, keine Dateien nötig)
     ------------------------------------------------------------------------ */
  const SFX = {
    ctx: null, masterGain: null, ambientGain: null, volume: 0.6,
    ensure() {
      if (this.ctx) return;
      try {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        this.ctx = new Ctx();
        this.masterGain = this.ctx.createGain();
        this.masterGain.gain.value = this.volume;
        this.masterGain.connect(this.ctx.destination);
        this._startAmbient();
      } catch (e) { /* Audio nicht verfügbar - Spiel läuft trotzdem */ }
    },
    resume() { if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume(); },
    setVolume(v) { this.volume = v; if (this.masterGain) this.masterGain.gain.value = v; },
    _tone(freq, duration, type, gain, opts) {
      if (!this.ctx) return;
      opts = opts || {};
      const t0 = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      osc.type = type || 'sine';
      osc.frequency.setValueAtTime(freq, t0);
      if (opts.slideTo) osc.frequency.exponentialRampToValueAtTime(Math.max(1, opts.slideTo), t0 + duration);
      const g = this.ctx.createGain();
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.exponentialRampToValueAtTime(Math.max(0.0002, gain || 0.2), t0 + 0.015);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + duration);
      osc.connect(g); g.connect(this.masterGain);
      osc.start(t0); osc.stop(t0 + duration + 0.03);
    },
    _noise(duration, gain, filterFreq) {
      if (!this.ctx) return;
      const n = Math.max(1, Math.floor(this.ctx.sampleRate * duration));
      const buffer = this.ctx.createBuffer(1, n, this.ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < n; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / n);
      const src = this.ctx.createBufferSource(); src.buffer = buffer;
      const filt = this.ctx.createBiquadFilter(); filt.type = 'bandpass'; filt.frequency.value = filterFreq || 1200;
      const g = this.ctx.createGain(); g.gain.value = gain || 0.2;
      src.connect(filt); filt.connect(g); g.connect(this.masterGain);
      src.start();
    },
    chop() { this._noise(0.08, 0.3, 900); this._tone(220, 0.08, 'square', 0.08); },
    mine() { this._noise(0.07, 0.28, 2200); },
    pickup() { this._tone(660, 0.1, 'sine', 0.16); this._tone(880, 0.12, 'sine', 0.12); },
    swing() { this._noise(0.09, 0.15, 3500); },
    hit() { this._noise(0.07, 0.3, 600); this._tone(140, 0.08, 'square', 0.14); },
    hurt() { this._tone(180, 0.2, 'sawtooth', 0.2, { slideTo: 80 }); },
    jump() { this._tone(300, 0.12, 'sine', 0.14, { slideTo: 520 }); },
    land() { this._tone(150, 0.08, 'sine', 0.1, { slideTo: 80 }); },
    splash() { this._noise(0.22, 0.22, 1400); this._tone(220, 0.15, 'sine', 0.1, { slideTo: 90 }); },
    levelup() { [523, 659, 784, 1046].forEach((f, i) => setTimeout(() => this._tone(f, 0.25, 'triangle', 0.18), i * 90)); },
    build() { this._tone(200, 0.1, 'square', 0.14); this._noise(0.1, 0.15, 500); },
    chest() { [440, 554, 659, 880].forEach((f, i) => setTimeout(() => this._tone(f, 0.2, 'sine', 0.15), i * 70)); },
    questDone() { [523, 659, 784].forEach((f, i) => setTimeout(() => this._tone(f, 0.3, 'triangle', 0.2), i * 100)); },
    enemyDeath() { this._tone(400, 0.15, 'sawtooth', 0.14, { slideTo: 80 }); this._noise(0.1, 0.14, 700); },
    death() { this._tone(300, 0.6, 'sawtooth', 0.18, { slideTo: 40 }); },
    _startAmbient() {
      if (!this.ctx) return;
      const o1 = this.ctx.createOscillator(); o1.type = 'sine'; o1.frequency.value = 80;
      const o2 = this.ctx.createOscillator(); o2.type = 'sine'; o2.frequency.value = 120;
      const g = this.ctx.createGain(); g.gain.value = 0.028;
      o1.connect(g); o2.connect(g); g.connect(this.masterGain);
      o1.start(); o2.start();
      const lfo = this.ctx.createOscillator(); lfo.frequency.value = 0.07;
      const lfoGain = this.ctx.createGain(); lfoGain.gain.value = 0.014;
      lfo.connect(lfoGain); lfoGain.connect(g.gain);
      lfo.start();
    },
  };

  /* ------------------------------------------------------------------------
     Zustand
     ------------------------------------------------------------------------ */
  let renderer, scene, camera, terrainMesh, waterMesh, waterMat;
  let hemiLight, sunLight, sunMesh, moonMesh, starsMat, relicMarker, relicBaseY = 0;
  let worldBuilt = false, worldReady = false, onGameScreen = false, paused = false, loopStarted = false;
  let gameTime = 0, dayTime = 0.28, lastTime = 0, frameCount = 0, lastAutosave = 0;
  let sensitivity = 1;
  let camDist = 7;
  const camState = { yaw: Math.PI, pitch: 0.5 };
  let cameraShake = 0;
  let isNight = false;

  const trees = [], rocks = [], bushes = [], chests = [], enemies = [];
  const structures = [], walls = [], structureColliders = [], campfires = [];
  const bridgeColliders = []; // dauerhafte begehbare Brücken, unabhängig vom Bau-System
  const landmarkColliders = [], minimapLandmarks = [];
  let castleFootprint = null;
  const particlePool = [];
  const tweens = [];

  const resources = { wood: 0, stone: 0, berry: 0, coin: 0 };
  const counters = { woodTotal: 0, stoneTotal: 0, campfiresBuilt: 0, enemiesDefeated: 0, chestsOpened: 0, peakReached: false };
  const openedChestIds = new Set();
  let questIndex = 0;

  const player = {
    pos: new THREE.Vector3(SPAWN.x, 0, SPAWN.z),
    vel: new THREE.Vector3(),
    yaw: Math.PI,
    grounded: false,
    health: 100, maxHealth: 100,
    stamina: 100, maxStamina: 100,
    oxygen: 100, maxOxygen: 100,
    level: 1, xp: 0,
    attackDamage: 12,
    attackCooldownTimer: 0,
    isAttacking: false,
    isDead: false,
    inWater: false,
    submerged: false,
    speed: 4.3, sprintMult: 1.8,
    rig: null,
  };

  const keys = Object.create(null);
  const input = { move: { x: 0, y: 0 }, jumpPressed: false, jumpHeld: false, sprint: false };
  const joystick = { active: false, x: 0, y: 0, pointerId: null };
  let touchSprintActive = false;
  let isTouchDevice = false;

  let placementMode = false, placementGhost = null, placementValid = false, selectedBuildType = null;

  /* ------------------------------------------------------------------------
     DOM-Referenzen
     ------------------------------------------------------------------------ */
  let dom = {};
  function cacheDom() {
    const ids = [
      'start-screen', 'game-screen', 'new-game-btn', 'continue-btn', 'wipe-save-btn',
      'stage', 'damage-flash', 'water-overlay', 'loading-overlay', 'loading-text', 'hud',
      'bar-health', 'bar-stamina', 'bar-oxygen', 'oxygen-row', 'bar-xp', 'level-badge',
      'res-wood', 'res-stone', 'res-berry', 'res-coin',
      'daytime-icon', 'daytime-text', 'minimap', 'pause-btn',
      'quest-tracker', 'quest-title', 'quest-desc', 'quest-progress-fill',
      'toast-stack', 'interact-prompt',
      'mobile-controls', 'joystick-zone', 'joystick-base', 'joystick-stick',
      'btn-build', 'btn-interact', 'btn-jump', 'btn-attack', 'btn-sprint',
      'build-menu', 'build-options', 'build-cancel-btn',
      'pause-menu', 'resume-btn', 'sens-slider', 'vol-slider', 'save-btn', 'quit-btn',
      'death-menu', 'death-info', 'respawn-btn',
    ];
    ids.forEach((id) => { dom[id] = document.getElementById(id); });
  }

  /* ------------------------------------------------------------------------
     Three.js Aufbau
     ------------------------------------------------------------------------ */
  function initThree() {
    renderer = new THREE.WebGLRenderer({ canvas: dom.stage, antialias: true, powerPreference: 'high-performance' });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    if ('outputColorSpace' in renderer) renderer.outputColorSpace = THREE.SRGBColorSpace;
    scene = new THREE.Scene();
    scene.fog = new THREE.Fog(0x6ec3e8, 60, 235);
    camera = new THREE.PerspectiveCamera(62, window.innerWidth / window.innerHeight, 0.1, 400);
    initParticlePool();
    buildLightsAndSky();
    window.addEventListener('resize', onResize);
    window.addEventListener('orientationchange', onResize);
  }

  function onResize() {
    if (!renderer || !camera) return;
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }

  function buildLightsAndSky() {
    hemiLight = new THREE.HemisphereLight(0x6ec3e8, 0x3a2e1a, 0.6);
    scene.add(hemiLight);
    sunLight = new THREE.DirectionalLight(0xffffff, 1);
    sunLight.castShadow = true;
    sunLight.shadow.mapSize.set(1024, 1024);
    const d = 110;
    sunLight.shadow.camera.left = -d; sunLight.shadow.camera.right = d;
    sunLight.shadow.camera.top = d; sunLight.shadow.camera.bottom = -d;
    sunLight.shadow.camera.near = 5; sunLight.shadow.camera.far = 300;
    sunLight.shadow.bias = -0.0018;
    scene.add(sunLight);
    scene.add(sunLight.target);
    sunMesh = new THREE.Mesh(new THREE.SphereGeometry(6, 10, 8), new THREE.MeshBasicMaterial({ color: 0xfff3c4 }));
    moonMesh = new THREE.Mesh(new THREE.SphereGeometry(4, 10, 8), new THREE.MeshBasicMaterial({ color: 0xdfe6f0 }));
    scene.add(sunMesh, moonMesh);
  }

  function buildTerrain() {
    const size = 220, seg = 90;
    const geo = new THREE.PlaneGeometry(size, size, seg, seg);
    geo.rotateX(-Math.PI / 2);
    const pos = geo.attributes.position;
    const colors = new Float32Array(pos.count * 3);
    const sand = new THREE.Color(0xd9c48a);
    const grassLo = new THREE.Color(0x4f9e3a);
    const grassHi = new THREE.Color(0x8bd15a);
    const rock = new THREE.Color(0x8a8f97);
    const snow = new THREE.Color(0xf3f6f8);
    const pathColor = new THREE.Color(0xcbb27a);
    const tmp = new THREE.Color();
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), z = pos.getZ(i);
      const h = heightAt(x, z);
      pos.setY(i, h);
      let c;
      if (h < 0.4) c = sand;
      else if (h < 15) c = tmp.copy(grassLo).lerp(grassHi, clamp01((h - 0.4) / 14.6));
      else if (h < 24) c = tmp.copy(grassHi).lerp(rock, clamp01((h - 15) / 9));
      else c = tmp.copy(rock).lerp(snow, clamp01((h - 24) / 8));
      if (h > 0.35) {
        for (let p = 0; p < PATH_SEGMENTS.length; p++) {
          const seg2 = PATH_SEGMENTS[p];
          if (distToSegment(x, z, seg2.ax, seg2.az, seg2.bx, seg2.bz) < seg2.width / 2) { c = pathColor; break; }
        }
      }
      colors[i * 3] = c.r; colors[i * 3 + 1] = c.g; colors[i * 3 + 2] = c.b;
    }
    geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    geo.computeVertexNormals();
    const mat = new THREE.MeshStandardMaterial({ vertexColors: true, flatShading: true, roughness: 1, metalness: 0 });
    terrainMesh = new THREE.Mesh(geo, mat);
    terrainMesh.receiveShadow = true;
    scene.add(terrainMesh);
  }

  function buildWater() {
    const geo = new THREE.PlaneGeometry(700, 700, 1, 1);
    geo.rotateX(-Math.PI / 2);
    waterMat = new THREE.MeshStandardMaterial({ color: 0x1b6f96, transparent: true, opacity: 0.8, roughness: 0.35, metalness: 0.1, side: THREE.DoubleSide });
    waterMesh = new THREE.Mesh(geo, waterMat);
    waterMesh.position.y = 0;
    scene.add(waterMesh);
  }

  function buildStars() {
    const count = 400;
    const positions = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      const r = 280 + Math.random() * 60;
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(Math.random() * 0.9);
      positions[i * 3] = r * Math.sin(phi) * Math.cos(theta);
      positions[i * 3 + 1] = Math.abs(r * Math.cos(phi)) + 20;
      positions[i * 3 + 2] = r * Math.sin(phi) * Math.sin(theta);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    starsMat = new THREE.PointsMaterial({ color: 0xffffff, size: 1.6, transparent: true, opacity: 0, depthWrite: false });
    scene.add(new THREE.Points(geo, starsMat));
  }

  function buildRelicMarker() {
    const group = new THREE.Group();
    const mat = new THREE.MeshStandardMaterial({ color: 0x8a5cff, emissive: 0x4a2ea8, emissiveIntensity: 0.6, flatShading: true, roughness: 0.3 });
    for (let i = 0; i < 3; i++) {
      const c = new THREE.Mesh(new THREE.OctahedronGeometry(0.45 - i * 0.08, 0), mat);
      c.position.y = 1.6 + i * 0.7;
      c.rotation.y = i * 0.7;
      c.castShadow = true;
      group.add(c);
    }
    const light = new THREE.PointLight(0x8a5cff, 1.2, 10);
    light.position.y = 2.2;
    group.add(light);
    const h = heightAt(MOUNTAIN_POS.x, MOUNTAIN_POS.z);
    relicBaseY = h;
    group.position.set(MOUNTAIN_POS.x, h, MOUNTAIN_POS.z);
    scene.add(group);
    relicMarker = group;
  }

  /* --- Scatter-Helfer --- */
  function scatterPositions(count, opts) {
    const centerX = opts.centerX || 0, centerZ = opts.centerZ || 0;
    const minR = opts.minR || 8, maxR = opts.maxR || 24;
    const minSpacing = opts.minSpacing || 4;
    const minHeight = opts.minHeight != null ? opts.minHeight : 0.4;
    const maxHeight = opts.maxHeight != null ? opts.maxHeight : 999;
    const existing = opts.existing || [];
    const excludeZones = opts.excludeZones || [];
    const results = [];
    let attempts = 0;
    const maxAttempts = count * 150 + 200;
    while (results.length < count && attempts < maxAttempts) {
      attempts++;
      const a = worldRand() * Math.PI * 2;
      const r = minR + worldRand() * (maxR - minR);
      const x = centerX + Math.cos(a) * r, z = centerZ + Math.sin(a) * r;
      const h = heightAt(x, z);
      if (h < minHeight || h > maxHeight) continue;
      if (flatDistXZ(x, z, SPAWN.x, SPAWN.z) < 6) continue;
      let ok = true;
      for (let i = 0; i < results.length; i++) { if (flatDistXZ(x, z, results[i].x, results[i].z) < minSpacing) { ok = false; break; } }
      if (ok) for (let i = 0; i < existing.length; i++) { if (flatDistXZ(x, z, existing[i].x, existing[i].z) < minSpacing) { ok = false; break; } }
      if (ok) for (let i = 0; i < excludeZones.length; i++) { if (flatDistXZ(x, z, excludeZones[i].x, excludeZones[i].z) < excludeZones[i].radius) { ok = false; break; } }
      if (ok) results.push({ x, z });
    }
    return results;
  }

  function makeTree(p, variant) {
    const group = new THREE.Group();
    const trunkMat = new THREE.MeshStandardMaterial({ color: 0x6b4a2b, flatShading: true });
    const trunkH = 1.6 + worldRand() * 0.6;
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.22, trunkH, 6), trunkMat);
    trunk.position.y = trunkH / 2;
    trunk.castShadow = true; trunk.receiveShadow = true;
    group.add(trunk);
    const leafMat = new THREE.MeshStandardMaterial({ color: variant === 0 ? 0x3f8f3a : 0x5aa63f, flatShading: true });
    if (variant === 0) {
      for (let i = 0; i < 3; i++) {
        const r = 0.9 - i * 0.22, h = 1.1 - i * 0.18;
        const cone = new THREE.Mesh(new THREE.ConeGeometry(r, h, 7), leafMat);
        cone.position.y = trunkH + i * 0.55 + h * 0.3;
        cone.castShadow = true;
        group.add(cone);
      }
    } else {
      const blob = new THREE.Mesh(new THREE.IcosahedronGeometry(0.95, 0), leafMat);
      blob.position.y = trunkH + 0.7; blob.scale.y = 0.85; blob.castShadow = true;
      group.add(blob);
      const blob2 = new THREE.Mesh(new THREE.IcosahedronGeometry(0.6, 0), leafMat);
      blob2.position.set(0.5, trunkH + 0.5, 0.2); blob2.castShadow = true;
      group.add(blob2);
    }
    const h = heightAt(p.x, p.z);
    group.position.set(p.x, h, p.z);
    group.rotation.y = worldRand() * Math.PI * 2;
    const s = 0.85 + worldRand() * 0.4;
    group.scale.setScalar(s);
    scene.add(group);
    return { mesh: group, hp: 3, maxHp: 3, hidden: false, respawnAt: 0, baseScale: group.scale.clone() };
  }

  function makeRock(p) {
    const rockMat = new THREE.MeshStandardMaterial({ color: 0x888d94, flatShading: true, roughness: 1 });
    const geo = new THREE.IcosahedronGeometry(0.55 + worldRand() * 0.35, 0);
    const mesh = new THREE.Mesh(geo, rockMat);
    mesh.rotation.set(worldRand() * Math.PI, worldRand() * Math.PI, worldRand() * Math.PI);
    mesh.scale.set(1 + worldRand() * 0.4, 0.6 + worldRand() * 0.3, 1 + worldRand() * 0.4);
    mesh.castShadow = true; mesh.receiveShadow = true;
    const h = heightAt(p.x, p.z);
    mesh.position.set(p.x, h + 0.15, p.z);
    scene.add(mesh);
    return { mesh, hp: 4, maxHp: 4, hidden: false, respawnAt: 0, baseScale: mesh.scale.clone() };
  }

  function makeBush(p) {
    const group = new THREE.Group();
    const leafMat = new THREE.MeshStandardMaterial({ color: 0x4a8f3f, flatShading: true });
    const berryMat = new THREE.MeshStandardMaterial({ color: 0xd23f5a, flatShading: true });
    for (let i = 0; i < 4; i++) {
      const s = new THREE.Mesh(new THREE.IcosahedronGeometry(0.28, 0), leafMat);
      s.position.set((worldRand() - 0.5) * 0.4, 0.2 + worldRand() * 0.15, (worldRand() - 0.5) * 0.4);
      group.add(s);
    }
    for (let i = 0; i < 4; i++) {
      const b = new THREE.Mesh(new THREE.SphereGeometry(0.06, 5, 4), berryMat);
      b.position.set((worldRand() - 0.5) * 0.5, 0.22 + worldRand() * 0.2, (worldRand() - 0.5) * 0.5);
      group.add(b);
    }
    const h = heightAt(p.x, p.z);
    group.position.set(p.x, h, p.z);
    scene.add(group);
    return { mesh: group, hp: 1, maxHp: 1, hidden: false, respawnAt: 0, baseScale: group.scale.clone() };
  }

  function makeChest(p, id) {
    const group = new THREE.Group();
    const baseMat = new THREE.MeshStandardMaterial({ color: 0x7a4f27, flatShading: true });
    const bandMat = new THREE.MeshStandardMaterial({ color: 0xdcb24a, metalness: 0.4, roughness: 0.4 });
    const base = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.5, 0.6), baseMat);
    base.position.y = 0.25; base.castShadow = true;
    group.add(base);
    const lid = new THREE.Mesh(new THREE.BoxGeometry(0.94, 0.22, 0.64), baseMat);
    lid.position.set(0, 0.53, -0.02);
    lid.castShadow = true;
    group.add(lid);
    const band = new THREE.Mesh(new THREE.BoxGeometry(0.94, 0.08, 0.66), bandMat);
    band.position.y = 0.4;
    group.add(band);
    group.userData.lid = lid;
    const h = heightAt(p.x, p.z);
    group.position.set(p.x, h, p.z);
    group.rotation.y = worldRand() * Math.PI * 2;
    scene.add(group);
    return { id, mesh: group, opened: false };
  }

  function makeEnemy(home) {
    const group = new THREE.Group();
    const baseColor = new THREE.Color(0x5fd18a);
    const bodyMat = new THREE.MeshStandardMaterial({ color: baseColor.clone(), flatShading: true, transparent: true, opacity: 0.88, roughness: 0.4 });
    const body = new THREE.Mesh(new THREE.SphereGeometry(0.5, 10, 8), bodyMat);
    body.scale.y = 0.75;
    body.castShadow = true;
    group.add(body);
    const eyeMat = new THREE.MeshBasicMaterial({ color: 0x0c1a12 });
    [-0.16, 0.16].forEach((sx) => {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.06, 6, 5), eyeMat);
      eye.position.set(sx, 0.15, 0.42);
      group.add(eye);
    });
    const h = heightAt(home.x, home.z);
    group.position.set(home.x, h + 0.35, home.z);
    scene.add(group);
    return {
      mesh: group, bodyMat, baseColor, baseY: 0.35,
      home: { x: home.x, z: home.z },
      hp: 26, maxHp: 26, dead: false, respawnAt: 0,
      state: 'idle', wanderTarget: { x: home.x, z: home.z }, wanderTimer: 0,
      speed: 1.6, aggroRangeBase: 9, attackRange: 1.3, attackCooldown: 1.4, attackTimer: 0,
      damage: 6, animTime: Math.random() * 10,
    };
  }

  function makeStructureMesh(type, ghost) {
    const group = new THREE.Group();
    const opacity = ghost ? 0.5 : 1;
    function mat(color) { return new THREE.MeshStandardMaterial({ color, flatShading: true, transparent: !!ghost, opacity }); }
    if (type === 'campfire') {
      const stoneMat = mat(0x777d84);
      for (let i = 0; i < 6; i++) {
        const a = (i / 6) * Math.PI * 2;
        const s = new THREE.Mesh(new THREE.IcosahedronGeometry(0.22, 0), stoneMat);
        s.position.set(Math.cos(a) * 0.55, 0.12, Math.sin(a) * 0.55);
        if (!ghost) s.castShadow = true;
        group.add(s);
      }
      const logMat = mat(0x6b4a2b);
      for (let i = 0; i < 3; i++) {
        const l = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.9, 6), logMat);
        l.rotation.z = Math.PI / 2; l.rotation.y = i * 1.2;
        l.position.y = 0.1;
        group.add(l);
      }
      const flame = new THREE.Mesh(new THREE.ConeGeometry(0.22, 0.5, 8), new THREE.MeshBasicMaterial({ color: 0xff9d3c, transparent: true, opacity: ghost ? 0.5 : 0.85 }));
      flame.position.y = 0.4;
      group.add(flame);
      group.userData.flame = flame;
      if (!ghost) {
        const light = new THREE.PointLight(0xff9a3c, 1.2, 8);
        light.position.y = 0.6;
        group.add(light);
        group.userData.light = light;
      }
    } else if (type === 'wall') {
      const w = new THREE.Mesh(new THREE.BoxGeometry(2.2, 1.4, 0.3), mat(0x8a6a3f));
      w.position.y = 0.7;
      if (!ghost) { w.castShadow = true; w.receiveShadow = true; }
      group.add(w);
    } else if (type === 'platform') {
      const woodMat = mat(0x9c7a4a);
      const p = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.3, 2.4), woodMat);
      p.position.y = 0.6;
      if (!ghost) { p.castShadow = true; p.receiveShadow = true; }
      group.add(p);
      [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([sx, sz]) => {
        const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.6, 6), woodMat);
        leg.position.set(sx * 1.0, 0.3, sz * 1.0);
        group.add(leg);
      });
    }
    return group;
  }

  function makeStructure(type, pos, yaw) {
    const mesh = makeStructureMesh(type, false);
    const groundY = heightAt(pos.x, pos.z);
    mesh.position.set(pos.x, groundY, pos.z);
    mesh.rotation.y = yaw || 0;
    scene.add(mesh);
    const rec = { type, mesh };
    structures.push(rec);
    if (type === 'wall') walls.push({ pos: mesh.position, radius: 1.25 });
    if (type === 'platform') structureColliders.push({ x: pos.x, z: pos.z, hw: 1.3, hd: 1.3, topY: groundY + 0.75 });
    if (type === 'campfire') campfires.push(rec);
    return rec;
  }

  /* --- Landmarken: Hütte, Burg, Wachturm, Leuchtturm, Brücke --- */
  function makeHut(pos, rotY) {
    const group = new THREE.Group();
    const wallMat = new THREE.MeshStandardMaterial({ color: 0xd9c48a, flatShading: true });
    const roofMat = new THREE.MeshStandardMaterial({ color: 0x8a5a3a, flatShading: true });
    const wall = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 1.2, 1.4, 8), wallMat);
    wall.position.y = 0.7; wall.castShadow = true; wall.receiveShadow = true;
    group.add(wall);
    const roof = new THREE.Mesh(new THREE.ConeGeometry(1.5, 1.3, 8), roofMat);
    roof.position.y = 1.4 + 0.65; roof.castShadow = true;
    group.add(roof);
    const door = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.8, 0.1), new THREE.MeshStandardMaterial({ color: 0x4a3320 }));
    door.position.set(0, 0.4, 1.15);
    group.add(door);
    const h = heightAt(pos.x, pos.z);
    group.position.set(pos.x, h, pos.z);
    group.rotation.y = rotY || 0;
    scene.add(group);
    landmarkColliders.push({ x: pos.x, z: pos.z, radius: 1.5 });
    minimapLandmarks.push({ pos: group.position, color: '#d9c48a' });
    return group;
  }

  function makeCastle(pos) {
    const group = new THREE.Group();
    const stoneMat = new THREE.MeshStandardMaterial({ color: 0xa8a8ad, flatShading: true, roughness: 1 });
    const roofMat = new THREE.MeshStandardMaterial({ color: 0x5a6a8a, flatShading: true });
    function tower(x, z, r, hgt, roofH) {
      const t = new THREE.Mesh(new THREE.CylinderGeometry(r, r * 1.05, hgt, 8), stoneMat);
      t.position.set(x, hgt / 2, z); t.castShadow = true; t.receiveShadow = true;
      group.add(t);
      const roof = new THREE.Mesh(new THREE.ConeGeometry(r * 1.2, roofH, 8), roofMat);
      roof.position.set(x, hgt + roofH / 2, z); roof.castShadow = true;
      group.add(roof);
    }
    tower(0, 0, 2.2, 5.5, 2.4);
    tower(-3.4, -1.6, 1.3, 3.8, 1.7);
    tower(3.4, -1.6, 1.3, 3.8, 1.7);
    const wallGeo = new THREE.BoxGeometry(3.6, 2.2, 0.6);
    const wallL = new THREE.Mesh(wallGeo, stoneMat);
    wallL.position.set(-1.9, 1.1, -1.7); wallL.rotation.y = 0.4; wallL.castShadow = true;
    group.add(wallL);
    const wallR = new THREE.Mesh(wallGeo, stoneMat);
    wallR.position.set(1.9, 1.1, -1.7); wallR.rotation.y = -0.4; wallR.castShadow = true;
    group.add(wallR);
    const h = heightAt(pos.x, pos.z);
    group.position.set(pos.x, h, pos.z);
    scene.add(group);
    landmarkColliders.push({ x: pos.x, z: pos.z, radius: 4.6 });
    minimapLandmarks.push({ pos: group.position, color: '#c94c4c' });
    return group;
  }

  /* Echtes 3D-Scan-Modell (Castle of Loarre) als Herzstück des Burg-Eilands. */
  function makeCastleModel(pos) {
    const scale = 0.1548;
    const localCenter = { x: -6.72, z: -9.39 };
    const localMinY = -13.70;
    const px = pos.x - localCenter.x * scale;
    const pz = pos.z - localCenter.z * scale;
    const footprint = { x: px, z: pz, radius: 20 };

    if (typeof THREE.GLTFLoader === 'function') {
      const loader = new THREE.GLTFLoader();
      loader.load('assets/castle-loarre.glb', (gltf) => {
        const model = gltf.scene;
        model.name = 'castle-model';
        model.scale.setScalar(scale);
        // Modell hat einen flachen Boden (Foto-Scan mit Sockel) — auf den tiefsten Punkt
        // des Terrains rund um den Fußabdruck absenken, sonst schwebt es an den Rändern.
        let minTerrainY = heightAt(px, pz);
        for (let i = 0; i < 10; i++) {
          const a = (i / 10) * Math.PI * 2;
          const sx = px + Math.cos(a) * footprint.radius * 0.9;
          const sz = pz + Math.sin(a) * footprint.radius * 0.9;
          minTerrainY = Math.min(minTerrainY, heightAt(sx, sz));
        }
        const py = minTerrainY - 1.5 + Math.abs(localMinY) * scale;
        model.position.set(px, py, pz);
        model.traverse((o) => {
          if (o.isMesh) {
            o.castShadow = true; o.receiveShadow = true;
            o.material.flatShading = true;
            o.material.roughness = 1;
            o.material.metalness = 0;
            o.material.needsUpdate = true;
          }
        });
        scene.add(model);
        landmarkColliders.push({ x: px, z: pz, radius: footprint.radius });
        minimapLandmarks.push({ pos: model.position, color: '#c94c4c' });
      }, undefined, (err) => {
        console.warn('Burg-Modell konnte nicht geladen werden, nutze Platzhalter:', err);
        makeCastle(pos);
      });
    } else {
      makeCastle(pos);
    }
    return footprint;
  }

  function makeWatchtower(pos) {
    const group = new THREE.Group();
    const mat = new THREE.MeshStandardMaterial({ color: 0x8a8f97, flatShading: true, roughness: 1 });
    const tower = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 0.9, 5.5, 7), mat);
    tower.position.y = 2.75; tower.castShadow = true; tower.receiveShadow = true;
    group.add(tower);
    const roof = new THREE.Mesh(new THREE.ConeGeometry(1.0, 1.2, 7), new THREE.MeshStandardMaterial({ color: 0x6b4a2b, flatShading: true }));
    roof.position.y = 5.5 + 0.6; roof.castShadow = true;
    group.add(roof);
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 1.4, 4), new THREE.MeshStandardMaterial({ color: 0x3a2e1a }));
    pole.position.y = 5.5 + 1.2 + 0.7;
    group.add(pole);
    const flag = new THREE.Mesh(new THREE.PlaneGeometry(0.5, 0.32), new THREE.MeshStandardMaterial({ color: 0xe6544c, side: THREE.DoubleSide }));
    flag.position.set(0.26, 5.5 + 1.2 + 1.15, 0);
    group.add(flag);
    group.userData.flag = flag;
    const h = heightAt(pos.x, pos.z);
    group.position.set(pos.x, h, pos.z);
    scene.add(group);
    landmarkColliders.push({ x: pos.x, z: pos.z, radius: 1.1 });
    minimapLandmarks.push({ pos: group.position, color: '#8a8f97' });
    return group;
  }

  function makeLighthouse(pos) {
    const group = new THREE.Group();
    const bodyMat = new THREE.MeshStandardMaterial({ color: 0xf2f6f8, flatShading: true });
    const base = new THREE.Mesh(new THREE.CylinderGeometry(1.0, 1.3, 4.5, 8), bodyMat);
    base.position.y = 2.25; base.castShadow = true; base.receiveShadow = true;
    group.add(base);
    const stripe = new THREE.Mesh(new THREE.CylinderGeometry(1.02, 1.15, 1.2, 8), new THREE.MeshStandardMaterial({ color: 0xe6544c, flatShading: true }));
    stripe.position.y = 2.6;
    group.add(stripe);
    const top = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 0.8, 1.0, 8), new THREE.MeshStandardMaterial({ color: 0x3a4a5a, flatShading: true }));
    top.position.y = 4.5 + 0.5;
    group.add(top);
    const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.35, 8, 6), new THREE.MeshBasicMaterial({ color: 0xffe27a }));
    bulb.position.y = 4.5 + 1.0 + 0.3;
    group.add(bulb);
    const light = new THREE.PointLight(0xffe27a, 1.0, 15);
    light.position.y = 4.5 + 1.0 + 0.3;
    group.add(light);
    const roof = new THREE.Mesh(new THREE.ConeGeometry(0.85, 0.7, 8), new THREE.MeshStandardMaterial({ color: 0x3a4a5a, flatShading: true }));
    roof.position.y = 4.5 + 1.0 + 0.6 + 0.35;
    group.add(roof);
    const h = heightAt(pos.x, pos.z);
    group.position.set(pos.x, h, pos.z);
    scene.add(group);
    landmarkColliders.push({ x: pos.x, z: pos.z, radius: 1.4 });
    minimapLandmarks.push({ pos: group.position, color: '#f2f6f8' });
    return group;
  }

  function makeBridge(pA, pB, topY) {
    const width = 2.6;
    const dx = pB.x - pA.x, dz = pB.z - pA.z;
    const length = Math.hypot(dx, dz);
    const angle = Math.atan2(-dz, dx);
    const cx = (pA.x + pB.x) / 2, cz = (pA.z + pB.z) / 2;
    const group = new THREE.Group();
    const deckMat = new THREE.MeshStandardMaterial({ color: 0x9c7a4a, flatShading: true });
    const deck = new THREE.Mesh(new THREE.BoxGeometry(length, 0.3, width), deckMat);
    deck.castShadow = true; deck.receiveShadow = true;
    group.add(deck);
    const postMat = new THREE.MeshStandardMaterial({ color: 0x6b4a2b, flatShading: true });
    const postCount = Math.max(2, Math.round(length / 4));
    for (let i = 0; i <= postCount; i++) {
      const t = (i / postCount - 0.5) * length;
      [-1, 1].forEach((side) => {
        const post = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 0.9, 5), postMat);
        post.position.set(t, 0.55, side * width / 2);
        group.add(post);
      });
    }
    group.position.set(cx, topY, cz);
    group.rotation.y = angle;
    scene.add(group);
    bridgeColliders.push({ x: cx, z: cz, hw: length / 2, hd: width / 2, rotY: angle, topY: topY + 0.15 });
    return group;
  }

  function isleEdgeAnchor(isle, towardX, towardZ, inset) {
    const dx = towardX - isle.cx, dz = towardZ - isle.cz;
    const d = Math.hypot(dx, dz) || 1;
    const r = isle.r - inset;
    return { x: isle.cx + (dx / d) * r, z: isle.cz + (dz / d) * r };
  }

  function buildLandmarksAndBridges() {
    const bridgeTopY = 0.85;
    BRIDGE_LINKS.forEach(([idA, idB]) => {
      const a = getIsland(idA), b = getIsland(idB);
      const anchorA = isleEdgeAnchor(a, b.cx, b.cz, 4);
      const anchorB = isleEdgeAnchor(b, a.cx, a.cz, 4);
      makeBridge(anchorA, anchorB, bridgeTopY);
      PATH_SEGMENTS.push({ ax: a.cx, az: a.cz, bx: anchorA.x, bz: anchorA.z, width: PATH_WIDTH });
      PATH_SEGMENTS.push({ ax: b.cx, az: b.cz, bx: anchorB.x, bz: anchorB.z, width: PATH_WIDTH });
    });

    const village = getIsland('village');
    const hutSpots = scatterPositions(4, { centerX: village.cx, centerZ: village.cz, minR: 3, maxR: village.r * 0.55, minSpacing: 4.5, minHeight: 0.6, maxHeight: 14 });
    hutSpots.forEach((p) => makeHut(p, worldRand() * Math.PI * 2));

    const castleIsle = getIsland('castle');
    castleFootprint = makeCastleModel({ x: castleIsle.cx, z: castleIsle.cz });
    const towerSpot = { x: castleIsle.cx + castleIsle.r * 0.67, z: castleIsle.cz - castleIsle.r * 0.49 };
    makeWatchtower(towerSpot);

    const home = getIsland('home');
    const lighthousePos = isleEdgeAnchor(home, 0, 0, 6);
    makeLighthouse(lighthousePos);

    buildRelicMarker();
    peakHeight = heightAt(MOUNTAIN_POS.x, MOUNTAIN_POS.z);
  }

  function scatterAndCreateObjects() {
    const occupied = [];
    const counts = {
      home: { trees: 9, rocks: 4, bushes: 3, chests: 2, enemies: 1 },
      mountain: { trees: 10, rocks: 6, bushes: 2, chests: 2, enemies: 2 },
      village: { trees: 5, rocks: 2, bushes: 4, chests: 2, enemies: 0 },
      castle: { trees: 4, rocks: 7, bushes: 1, chests: 2, enemies: 3 },
    };
    let chestIdCounter = 0;
    ISLANDS.forEach((isle) => {
      const c = counts[isle.id];
      const excludeZones = (isle.id === 'castle' && castleFootprint)
        ? [{ x: castleFootprint.x, z: castleFootprint.z, radius: castleFootprint.radius + 2 }]
        : [];
      const base = { centerX: isle.cx, centerZ: isle.cz, minR: 4, maxR: isle.r - 5, existing: occupied, excludeZones };

      const treePos = scatterPositions(c.trees, Object.assign({}, base, { minSpacing: 4.2, minHeight: 0.6, maxHeight: 17 }));
      treePos.forEach((p) => occupied.push(p));
      treePos.forEach((p) => trees.push(makeTree(p, worldRand() < 0.55 ? 0 : 1)));

      const rockPos = scatterPositions(c.rocks, Object.assign({}, base, { minSpacing: 4, minHeight: 0.5, maxHeight: 26 }));
      rockPos.forEach((p) => occupied.push(p));
      rockPos.forEach((p) => rocks.push(makeRock(p)));

      const bushPos = scatterPositions(c.bushes, Object.assign({}, base, { minSpacing: 4, minHeight: 0.6, maxHeight: 14 }));
      bushPos.forEach((p) => occupied.push(p));
      bushPos.forEach((p) => bushes.push(makeBush(p)));

      const chestPos = scatterPositions(c.chests, Object.assign({}, base, { maxR: isle.r - 6, minSpacing: 6, minHeight: 0.6, maxHeight: 22 }));
      chestPos.forEach((p) => { occupied.push(p); chests.push(makeChest(p, chestIdCounter++)); });

      const enemyHomes = scatterPositions(c.enemies, Object.assign({}, base, { maxR: isle.r - 6, minSpacing: 6, minHeight: 0.7, maxHeight: 16 }));
      enemyHomes.forEach((p) => { occupied.push(p); enemies.push(makeEnemy(p)); });
    });

    buildLandmarksAndBridges();
  }

  /* --- Spieler-Rig --- */
  function limb(parentGroup, radius, length, mat, x, y) {
    const pivot = new THREE.Group();
    pivot.position.set(x, y, 0);
    const mesh = new THREE.Mesh(new THREE.CapsuleGeometry(radius, length, 3, 6), mat);
    mesh.position.y = -(length / 2 + radius);
    mesh.castShadow = true;
    pivot.add(mesh);
    parentGroup.add(pivot);
    return pivot;
  }

  function buildPlayerRig() {
    const group = new THREE.Group();
    const bodyMat = new THREE.MeshStandardMaterial({ color: 0x3d6fd6, flatShading: true });
    const pantsMat = new THREE.MeshStandardMaterial({ color: 0x2b3a52, flatShading: true });
    const skinMat = new THREE.MeshStandardMaterial({ color: 0xe0a878, flatShading: true });

    const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.32, 0.55, 4, 8), bodyMat);
    torso.position.y = 1.05;
    torso.castShadow = true;
    group.add(torso);

    const head = new THREE.Mesh(new THREE.SphereGeometry(0.26, 10, 8), skinMat);
    head.position.y = 1.62;
    head.castShadow = true;
    group.add(head);

    const leftArm = limb(group, 0.09, 0.42, skinMat, -0.42, 1.35);
    const rightArm = limb(group, 0.09, 0.42, skinMat, 0.42, 1.35);
    const leftLeg = limb(group, 0.11, 0.46, pantsMat, -0.16, 0.78);
    const rightLeg = limb(group, 0.11, 0.46, pantsMat, 0.16, 0.78);

    const sword = new THREE.Group();
    const blade = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.55, 0.05), new THREE.MeshStandardMaterial({ color: 0xcfd8e3, metalness: 0.6, roughness: 0.3 }));
    blade.position.y = -0.75;
    sword.add(blade);
    const hilt = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.13, 0.11), new THREE.MeshStandardMaterial({ color: 0x6b4a2b }));
    hilt.position.y = -0.44;
    sword.add(hilt);
    sword.position.y = -0.44;
    rightArm.add(sword);

    scene.add(group);
    return { group, leftArm, rightArm, leftLeg, rightLeg };
  }

  function buildWorld() {
    buildWater();
    buildStars();
    scatterAndCreateObjects(); // füllt u.a. PATH_SEGMENTS (Brücken-Anker) für die Terrain-Einfärbung
    buildTerrain();
    player.rig = buildPlayerRig();
    worldBuilt = true;
    worldReady = true;
  }

  /* ------------------------------------------------------------------------
     Boden / Kollisionen
     ------------------------------------------------------------------------ */
  function getGroundHeight(x, z) {
    let h = heightAt(x, z);
    for (let i = 0; i < structureColliders.length; i++) {
      const s = structureColliders[i];
      if (pointInLocalBox(x, z, s.x, s.z, s.rotY, s.hw, s.hd)) h = Math.max(h, s.topY);
    }
    for (let i = 0; i < bridgeColliders.length; i++) {
      const s = bridgeColliders[i];
      if (pointInLocalBox(x, z, s.x, s.z, s.rotY, s.hw, s.hd)) h = Math.max(h, s.topY);
    }
    return h;
  }

  function pushOutCircle(pos, center, minD) {
    const dx = pos.x - center.x, dz = pos.z - center.z;
    const d = Math.hypot(dx, dz);
    if (d < minD) {
      if (d > 0.0001) { const k = (minD - d) / d; pos.x += dx * k; pos.z += dz * k; }
      else { pos.x += minD; }
    }
  }

  function resolveWorldCollisions(pos) {
    for (let i = 0; i < trees.length; i++) { const t = trees[i]; if (!t.hidden) pushOutCircle(pos, t.mesh.position, TREE_COLLIDE_R + PLAYER_RADIUS); }
    for (let i = 0; i < rocks.length; i++) { const r = rocks[i]; if (!r.hidden) pushOutCircle(pos, r.mesh.position, ROCK_COLLIDE_R + PLAYER_RADIUS); }
    for (let i = 0; i < walls.length; i++) { pushOutCircle(pos, walls[i].pos, WALL_COLLIDE_R + PLAYER_RADIUS); }
    for (let i = 0; i < landmarkColliders.length; i++) { const l = landmarkColliders[i]; pushOutCircle(pos, l, l.radius + PLAYER_RADIUS); }
  }

  /* ------------------------------------------------------------------------
     Spieler-Update
     ------------------------------------------------------------------------ */
  let animTime = 0;
  let wasInWater = false;
  function updatePlayer(dt) {
    if (player.isDead) return;
    const moveLen = Math.hypot(input.move.x, input.move.y);
    const sprinting = input.sprint && moveLen > 0.1 && player.stamina > 1 && !player.inWater;
    const swimSpeedMult = player.inWater ? 0.72 : 1;
    const moveSpeed = player.speed * (sprinting ? player.sprintMult : 1) * swimSpeedMult;
    const yaw = camState.yaw;
    const forward = { x: Math.sin(yaw), z: Math.cos(yaw) };
    const right = { x: Math.sin(yaw + Math.PI / 2), z: Math.cos(yaw + Math.PI / 2) };
    let dirX = forward.x * input.move.y + right.x * input.move.x;
    let dirZ = forward.z * input.move.y + right.z * input.move.x;
    const dirLen = Math.hypot(dirX, dirZ);
    if (dirLen > 1e-4) { dirX /= dirLen; dirZ /= dirLen; }

    player.vel.x = dirX * moveSpeed;
    player.vel.z = dirZ * moveSpeed;

    if (moveLen > 0.15) {
      const targetYaw = Math.atan2(dirX, dirZ);
      player.yaw = lerpAngle(player.yaw, targetYaw, 1 - Math.pow(0.0001, dt));
    }

    player.pos.x += player.vel.x * dt;
    player.pos.z += player.vel.z * dt;

    resolveWorldCollisions(player.pos);

    const distC = Math.hypot(player.pos.x, player.pos.z);
    if (distC > WORLD_RADIUS - 2) { const k = (WORLD_RADIUS - 2) / distC; player.pos.x *= k; player.pos.z *= k; }

    // Wasser/Schwimmen: eine Stelle zaehlt als "im Wasser", wenn der rohe
    // Meeresgrund dort unter dem Wasserspiegel liegt und keine Bruecke/
    // Plattform eine trockene Oberflaeche darueber bereitstellt.
    const seabed = heightAt(player.pos.x, player.pos.z);
    const groundY = getGroundHeight(player.pos.x, player.pos.z);
    const onSolidSurface = groundY > seabed + 0.05;
    const overWater = seabed < WATER_LEVEL - 0.05 && !onSolidSurface;
    player.inWater = overWater && player.pos.y < WATER_LEVEL + 0.3;
    player.submerged = player.inWater && (WATER_LEVEL - player.pos.y) > SUBMERGE_DEPTH;

    if (player.inWater !== wasInWater) {
      wasInWater = player.inWater;
      SFX.splash();
      spawnParticles(new THREE.Vector3(player.pos.x, WATER_LEVEL + 0.05, player.pos.z), 0xbdf3ff, 10);
    }

    if (player.inWater) {
      let targetVy;
      if (input.jumpHeld) targetVy = SWIM_UP_SPEED;
      else if (player.pos.y < WATER_LEVEL - 0.1) targetVy = SWIM_BUOYANCY;
      else targetVy = -0.6;
      player.vel.y = lerp(player.vel.y, targetVy, clamp(dt * 3, 0, 1));
    } else {
      player.vel.y -= GRAVITY * dt;
      if (input.jumpPressed && player.grounded) { player.vel.y = JUMP_SPEED; player.grounded = false; SFX.jump(); }
    }
    input.jumpPressed = false;

    player.pos.y += player.vel.y * dt;
    if (player.pos.y <= groundY) {
      if (!player.inWater && player.vel.y < -6) SFX.land();
      player.pos.y = groundY;
      player.vel.y = player.inWater ? Math.max(player.vel.y, 0) : 0;
      player.grounded = !player.inWater;
    } else if (!player.inWater) {
      player.grounded = false;
    }

    if (sprinting) player.stamina = Math.max(0, player.stamina - STAMINA_DRAIN * dt);
    else player.stamina = Math.min(player.maxStamina, player.stamina + STAMINA_REGEN * dt);

    player.health = Math.min(player.maxHealth, player.health + HEALTH_REGEN * dt);

    if (player.attackCooldownTimer > 0) player.attackCooldownTimer -= dt;

    updateBreath(dt);

    player.rig.group.position.copy(player.pos);
    player.rig.group.rotation.y = player.yaw;

    const walkFactor = moveLen * (sprinting ? 1.6 : 1);
    if (!player.isAttacking) {
      if (moveLen > 0.12) {
        animTime += dt * (player.inWater ? 6 : 3 + walkFactor * 7);
        const amp = player.inWater ? 0.5 : Math.min(0.65, 0.3 + walkFactor * 0.5);
        const swing = Math.sin(animTime) * amp;
        player.rig.leftArm.rotation.x = swing;
        player.rig.rightArm.rotation.x = -swing;
        player.rig.leftLeg.rotation.x = -swing;
        player.rig.rightLeg.rotation.x = swing;
      } else {
        const relax = 1 - Math.pow(0.0001, dt);
        player.rig.leftArm.rotation.x = lerp(player.rig.leftArm.rotation.x, 0, relax);
        player.rig.rightArm.rotation.x = lerp(player.rig.rightArm.rotation.x, 0, relax);
        player.rig.leftLeg.rotation.x = lerp(player.rig.leftLeg.rotation.x, 0, relax);
        player.rig.rightLeg.rotation.x = lerp(player.rig.rightLeg.rotation.x, 0, relax);
      }
    }
  }

  let drownTickTimer = 0;
  function updateBreath(dt) {
    if (player.submerged) {
      player.oxygen = Math.max(0, player.oxygen - OXYGEN_DRAIN * dt);
      if (player.oxygen <= 0) {
        drownTickTimer -= dt;
        if (drownTickTimer <= 0) { drownTickTimer = DROWN_TICK_INTERVAL; damagePlayer(DROWN_TICK_DAMAGE); }
      } else {
        drownTickTimer = 0;
      }
    } else {
      player.oxygen = Math.min(player.maxOxygen, player.oxygen + OXYGEN_REGEN * dt);
      drownTickTimer = 0;
    }
    if (dom['water-overlay']) {
      dom['water-overlay'].style.opacity = player.submerged ? '1' : '0';
    }
  }

  /* ------------------------------------------------------------------------
     Angriff / Sammeln
     ------------------------------------------------------------------------ */
  function tryAttack() {
    if (paused || player.isDead || placementMode || !worldReady) return;
    if (player.attackCooldownTimer > 0) return;
    player.attackCooldownTimer = ATTACK_COOLDOWN;
    player.isAttacking = true;
    SFX.swing();
    addTween(0.32, (p) => {
      const s = Math.sin(Math.min(p, 1) * Math.PI);
      player.rig.rightArm.rotation.x = -0.3 - s * 2.0;
      player.rig.rightArm.rotation.z = s * 0.4;
    }, () => { player.isAttacking = false; player.rig.rightArm.rotation.z = 0; player.rig.rightArm.rotation.x = 0; });
    performAttackHit();
  }

  function performAttackHit() {
    const forward = { x: Math.sin(player.yaw), z: Math.cos(player.yaw) };
    let best = null, bestType = null, bestDist = Infinity;
    function consider(list, type) {
      for (let i = 0; i < list.length; i++) {
        const o = list[i];
        if (o.dead || o.hidden) continue;
        const dx = o.mesh.position.x - player.pos.x, dz = o.mesh.position.z - player.pos.z;
        const dist = Math.hypot(dx, dz);
        if (dist > ATTACK_RANGE) continue;
        const nx = dist > 1e-4 ? dx / dist : 0, nz = dist > 1e-4 ? dz / dist : 1;
        const dot = nx * forward.x + nz * forward.z;
        if (dot < 0.3) continue;
        if (dist < bestDist) { bestDist = dist; best = o; bestType = type; }
      }
    }
    consider(trees, 'tree'); consider(rocks, 'rock'); consider(bushes, 'bush'); consider(enemies, 'enemy');
    if (!best) return;
    if (bestType === 'enemy') damageEnemy(best, player.attackDamage);
    else gatherNode(best, bestType);
  }

  function gatherNode(node, type) {
    node.hp -= 1;
    const color = type === 'tree' ? 0x6b4a2b : type === 'rock' ? 0x8a8f97 : 0xd23f5a;
    spawnParticles(node.mesh.position, color, 6);
    if (type === 'tree') SFX.chop(); else if (type === 'rock') SFX.mine(); else SFX.pickup();
    if (type === 'tree') {
      const amt = 1 + Math.floor(Math.random() * 2);
      resources.wood += amt; counters.woodTotal += amt;
      toast(`+${amt} 🪵 Holz`);
    } else if (type === 'rock') {
      const amt = 1 + Math.floor(Math.random() * 2);
      resources.stone += amt; counters.stoneTotal += amt;
      toast(`+${amt} 🪨 Stein`);
    } else {
      const amt = 2 + Math.floor(Math.random() * 2);
      resources.berry += amt;
      toast(`+${amt} 🍓 Beeren`);
    }
    if (node.hp <= 0) depleteNode(node, type);
  }

  function depleteNode(node, type) {
    const mesh = node.mesh;
    if (type === 'tree') {
      addTween(0.5, (p) => { mesh.rotation.z = p * 1.4; }, () => { mesh.rotation.z = 0; finalizeDeplete(node, type); });
    } else {
      addTween(0.25, (p) => { mesh.scale.copy(node.baseScale).multiplyScalar(1 - p * 0.92); }, () => finalizeDeplete(node, type));
    }
  }

  function finalizeDeplete(node, type) {
    node.mesh.visible = false;
    node.hidden = true;
    const respawnTime = type === 'bush' ? 32 : type === 'tree' ? 55 : 48;
    node.respawnAt = gameTime + respawnTime + Math.random() * 18;
  }

  function updateGatherRespawns() {
    [trees, rocks, bushes].forEach((list) => {
      for (let i = 0; i < list.length; i++) {
        const node = list[i];
        if (node.hidden && gameTime >= node.respawnAt) {
          node.hidden = false;
          node.hp = node.maxHp;
          node.mesh.visible = true;
          node.mesh.scale.copy(node.baseScale).multiplyScalar(0.05);
          addTween(0.35, (p) => { node.mesh.scale.copy(node.baseScale).multiplyScalar(0.05 + 0.95 * p); });
        }
      }
    });
  }

  /* ------------------------------------------------------------------------
     Interagieren (Truhen, Bauen bestätigen)
     ------------------------------------------------------------------------ */
  function tryInteract() {
    if (paused || player.isDead || !worldReady) return;
    if (placementMode) { confirmPlacement(); return; }
    let nearest = null, nd = INTERACT_RANGE;
    for (let i = 0; i < chests.length; i++) {
      const c = chests[i];
      if (c.opened) continue;
      const d = flatDist(player.pos, c.mesh.position);
      if (d < nd) { nd = d; nearest = c; }
    }
    if (nearest) openChest(nearest);
  }

  function updateInteractPrompt() {
    if (!worldReady) return;
    if (placementMode) { showPrompt(placementValid ? 'E / ✋ zum Platzieren' : 'Hier nicht möglich'); return; }
    for (let i = 0; i < chests.length; i++) {
      const c = chests[i];
      if (!c.opened && flatDist(player.pos, c.mesh.position) < INTERACT_RANGE) { showPrompt('E / ✋ Truhe öffnen'); return; }
    }
    hidePrompt();
  }
  function showPrompt(text) { dom['interact-prompt'].textContent = text; dom['interact-prompt'].classList.remove('hidden'); }
  function hidePrompt() { dom['interact-prompt'].classList.add('hidden'); }

  function openChest(c) {
    c.opened = true;
    openedChestIds.add(c.id);
    const lid = c.mesh.userData.lid;
    addTween(0.35, (p) => { lid.rotation.x = -p * 1.9; });
    const coinAmt = 8 + Math.floor(Math.random() * 10);
    resources.coin += coinAmt;
    addXp(15);
    counters.chestsOpened++;
    spawnParticles(c.mesh.position.clone().add(new THREE.Vector3(0, 0.5, 0)), 0xf2c94c, 10);
    SFX.chest();
    toast(`Truhe geöffnet! +${coinAmt} 🪙`, 'gold');
    saveGame();
  }

  /* ------------------------------------------------------------------------
     Gegner-KI
     ------------------------------------------------------------------------ */
  function moveToward(en, target, speed, dt) {
    const dx = target.x - en.mesh.position.x, dz = target.z - en.mesh.position.z;
    const d = Math.hypot(dx, dz);
    if (d > 0.05) {
      const nx = dx / d, nz = dz / d;
      const step = Math.min(speed * dt, d);
      en.mesh.position.x += nx * step;
      en.mesh.position.z += nz * step;
      en.mesh.rotation.y = Math.atan2(nx, nz);
    }
  }
  function faceToward(en, target) {
    const dx = target.x - en.mesh.position.x, dz = target.z - en.mesh.position.z;
    if (Math.abs(dx) > 1e-4 || Math.abs(dz) > 1e-4) en.mesh.rotation.y = Math.atan2(dx, dz);
  }
  function pickWanderTarget(home, radius) {
    for (let i = 0; i < 6; i++) {
      const a = Math.random() * Math.PI * 2, r = Math.random() * radius;
      const x = home.x + Math.cos(a) * r, z = home.z + Math.sin(a) * r;
      if (heightAt(x, z) > 0.6) return { x, z };
    }
    return { x: home.x, z: home.z };
  }

  function updateEnemies(dt) {
    const aggroMult = isNight ? 1.6 : 1;
    for (let i = 0; i < enemies.length; i++) {
      const en = enemies[i];
      if (en.dead) { if (gameTime >= en.respawnAt) respawnEnemy(en); continue; }
      const dist = flatDist(player.pos, en.mesh.position);
      switch (en.state) {
        case 'idle':
        case 'wander': {
          en.wanderTimer -= dt;
          if (en.wanderTimer <= 0) { en.wanderTarget = pickWanderTarget(en.home, 6); en.wanderTimer = 3 + Math.random() * 3; }
          moveToward(en, en.wanderTarget, en.speed * 0.4, dt);
          if (dist < en.aggroRangeBase * aggroMult && !player.isDead) en.state = 'chase';
          break;
        }
        case 'chase': {
          if (dist > en.aggroRangeBase * aggroMult * 1.6 || player.isDead) { en.state = 'wander'; break; }
          if (dist < en.attackRange) { en.state = 'attack'; break; }
          moveToward(en, player.pos, en.speed, dt);
          break;
        }
        case 'attack': {
          faceToward(en, player.pos);
          en.attackTimer -= dt;
          if (dist > en.attackRange * 1.4 || player.isDead) { en.state = 'chase'; break; }
          if (en.attackTimer <= 0) { en.attackTimer = en.attackCooldown; damagePlayer(en.damage); }
          break;
        }
      }
      en.animTime += dt * 4;
      const activity = en.state === 'idle' ? 0.3 : 1;
      const bounce = Math.abs(Math.sin(en.animTime)) * 0.12 * activity;
      en.mesh.scale.set(1 + bounce * 0.3, 1 - bounce * 0.6, 1 + bounce * 0.3);
      const gy = getGroundHeight(en.mesh.position.x, en.mesh.position.z);
      en.mesh.position.y = gy + en.baseY + bounce * 0.15;
      en.bodyMat.color.lerp(en.baseColor, Math.min(1, dt * 6));
    }
  }

  function damageEnemy(en, dmg) {
    en.hp -= dmg;
    en.bodyMat.color.set(0xff5555);
    spawnParticles(en.mesh.position, 0x5fd18a, 8);
    SFX.hit();
    if (en.state === 'idle' || en.state === 'wander') en.state = 'chase';
    if (en.hp <= 0) killEnemy(en);
  }

  function killEnemy(en) {
    en.dead = true;
    en.mesh.visible = false;
    spawnParticles(en.mesh.position, 0x5fd18a, 14);
    const coinAmt = 3 + Math.floor(Math.random() * 5);
    resources.coin += coinAmt;
    addXp(10);
    counters.enemiesDefeated++;
    toast(`Schleim besiegt! +${coinAmt} 🪙`, 'good');
    SFX.enemyDeath();
    en.respawnAt = gameTime + 25 + Math.random() * 20;
  }

  function respawnEnemy(en) {
    en.dead = false;
    en.hp = en.maxHp;
    en.state = 'idle';
    en.mesh.visible = true;
    en.mesh.position.set(en.home.x, heightAt(en.home.x, en.home.z) + en.baseY, en.home.z);
  }

  /* ------------------------------------------------------------------------
     Schaden am Spieler / Tod
     ------------------------------------------------------------------------ */
  function damagePlayer(dmg) {
    if (player.isDead) return;
    player.health -= dmg;
    flashDamage();
    SFX.hurt();
    cameraShake = 0.18;
    if (player.health <= 0) { player.health = 0; killPlayer(); }
  }
  function flashDamage() {
    dom['damage-flash'].classList.remove('flash');
    void dom['damage-flash'].offsetWidth;
    dom['damage-flash'].classList.add('flash');
  }
  function killPlayer() {
    player.isDead = true;
    dom['death-info'].textContent = 'Kehre zurück zum Lagerplatz.';
    dom['death-menu'].classList.remove('hidden');
    SFX.death();
  }
  function respawnPlayer() {
    player.pos.set(SPAWN.x, heightAt(SPAWN.x, SPAWN.z), SPAWN.z);
    player.vel.set(0, 0, 0);
    player.health = Math.max(30, Math.floor(player.maxHealth * 0.6));
    player.oxygen = player.maxOxygen;
    player.isDead = false;
    resources.coin = Math.floor(resources.coin * 0.7);
    dom['death-menu'].classList.add('hidden');
    saveGame();
  }

  /* ------------------------------------------------------------------------
     Bauen
     ------------------------------------------------------------------------ */
  function initBuildMenuUI() {
    const container = dom['build-options'];
    container.innerHTML = '';
    BUILD_OPTIONS.forEach((opt) => {
      const btn = document.createElement('button');
      btn.className = 'build-opt';
      btn.dataset.id = opt.id;
      const costText = 'Kosten: ' + [opt.cost.wood ? `${opt.cost.wood}🪵` : null, opt.cost.stone ? `${opt.cost.stone}🪨` : null].filter(Boolean).join(' + ');
      btn.innerHTML = `<span class="build-opt-icon">${opt.icon}</span><span class="build-opt-info"><span class="build-opt-name">${opt.name}</span><br><span class="build-opt-cost">${costText}</span></span>`;
      btn.addEventListener('pointerdown', (e) => { e.preventDefault(); selectBuildOption(opt.id); });
      container.appendChild(btn);
    });
  }
  function refreshBuildMenu() {
    const buttons = dom['build-options'].querySelectorAll('.build-opt');
    buttons.forEach((btn) => {
      const opt = BUILD_OPTIONS.find((o) => o.id === btn.dataset.id);
      const afford = resources.wood >= opt.cost.wood && resources.stone >= (opt.cost.stone || 0);
      btn.classList.toggle('disabled', !afford);
    });
  }
  function selectBuildOption(id) {
    const opt = BUILD_OPTIONS.find((o) => o.id === id);
    if (resources.wood < opt.cost.wood || resources.stone < (opt.cost.stone || 0)) { toast('Nicht genug Rohstoffe', 'bad'); return; }
    selectedBuildType = id;
    closeBuildMenu();
    placementMode = true;
    placementGhost = makeStructureMesh(id, true);
    scene.add(placementGhost);
  }
  function toggleBuildMenu() {
    if (paused || player.isDead || !worldReady) return;
    if (placementMode) { cancelPlacement(); return; }
    if (!dom['build-menu'].classList.contains('hidden')) { closeBuildMenu(); return; }
    refreshBuildMenu();
    dom['build-menu'].classList.remove('hidden');
  }
  function closeBuildMenu() { dom['build-menu'].classList.add('hidden'); }

  function updatePlacementGhost() {
    if (!placementMode || !placementGhost) return;
    const fx = Math.sin(player.yaw), fz = Math.cos(player.yaw);
    const px = player.pos.x + fx * 3, pz = player.pos.z + fz * 3;
    const py = heightAt(px, pz);
    placementGhost.position.set(px, py, pz);
    placementGhost.rotation.y = player.yaw;
    const opt = BUILD_OPTIONS.find((o) => o.id === selectedBuildType);
    let valid = py > 0.5 && Math.hypot(px, pz) < WORLD_RADIUS - 4;
    if (valid) for (let i = 0; i < trees.length; i++) { const t = trees[i]; if (!t.hidden && flatDistXZ(px, pz, t.mesh.position.x, t.mesh.position.z) < opt.footprint + 0.6) { valid = false; break; } }
    if (valid) for (let i = 0; i < rocks.length; i++) { const r = rocks[i]; if (!r.hidden && flatDistXZ(px, pz, r.mesh.position.x, r.mesh.position.z) < opt.footprint + 0.5) { valid = false; break; } }
    if (valid) for (let i = 0; i < structures.length; i++) { const s = structures[i]; if (flatDistXZ(px, pz, s.mesh.position.x, s.mesh.position.z) < opt.footprint + 0.8) { valid = false; break; } }
    placementValid = valid;
    const tint = valid ? 0x58c96b : 0xe6544c;
    placementGhost.traverse((o) => { if (o.material && o.material.color) o.material.color.set(tint); });
  }

  function confirmPlacement() {
    if (!placementMode) return;
    const opt = BUILD_OPTIONS.find((o) => o.id === selectedBuildType);
    if (!placementValid) { toast('Kann hier nicht bauen', 'bad'); return; }
    if (resources.wood < opt.cost.wood || resources.stone < (opt.cost.stone || 0)) { toast('Nicht genug Rohstoffe', 'bad'); cancelPlacement(); return; }
    resources.wood -= opt.cost.wood;
    resources.stone -= (opt.cost.stone || 0);
    makeStructure(opt.id, { x: placementGhost.position.x, z: placementGhost.position.z }, placementGhost.rotation.y);
    if (opt.id === 'campfire') counters.campfiresBuilt++;
    SFX.build();
    toast(`${opt.name} gebaut!`, 'good');
    cancelPlacement();
    saveGame();
  }
  function cancelPlacement() {
    placementMode = false;
    if (placementGhost) { scene.remove(placementGhost); placementGhost = null; }
  }

  function applyCampfireHeal(dt) {
    for (let i = 0; i < campfires.length; i++) {
      const c = campfires[i];
      const d = flatDist(player.pos, c.mesh.position);
      if (d < 3 && player.health < player.maxHealth) player.health = Math.min(player.maxHealth, player.health + 6 * dt);
      const flame = c.mesh.userData.flame;
      if (flame) flame.scale.setScalar(0.85 + Math.sin(gameTime * 14 + c.mesh.id) * 0.15 + Math.random() * 0.05);
      const light = c.mesh.userData.light;
      if (light) light.intensity = 1.0 + Math.sin(gameTime * 10 + c.mesh.id) * 0.25 + Math.random() * 0.1;
    }
  }

  function clearAllStructures() {
    for (let i = 0; i < structures.length; i++) scene.remove(structures[i].mesh);
    structures.length = 0; walls.length = 0; structureColliders.length = 0; campfires.length = 0;
  }

  /* ------------------------------------------------------------------------
     Partikel
     ------------------------------------------------------------------------ */
  const MAX_PARTICLES = 48;
  function initParticlePool() {
    const geo = new THREE.BoxGeometry(0.09, 0.09, 0.09);
    for (let i = 0; i < MAX_PARTICLES; i++) {
      const mat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.visible = false;
      scene.add(mesh);
      particlePool.push({ mesh, mat, vel: new THREE.Vector3(), life: 0, maxLife: 1, active: false });
    }
  }
  function spawnParticles(pos, color, count) {
    let spawned = 0;
    for (let i = 0; i < particlePool.length && spawned < count; i++) {
      const p = particlePool[i];
      if (p.active) continue;
      p.active = true; p.mesh.visible = true;
      p.mesh.position.copy(pos);
      p.mat.color.set(color); p.mat.opacity = 1;
      const ang = Math.random() * Math.PI * 2, spd = 1 + Math.random() * 2.5;
      p.vel.set(Math.cos(ang) * spd, 2 + Math.random() * 2.5, Math.sin(ang) * spd);
      p.life = 0; p.maxLife = 0.5 + Math.random() * 0.4;
      spawned++;
    }
  }
  function updateParticles(dt) {
    for (let i = 0; i < particlePool.length; i++) {
      const p = particlePool[i];
      if (!p.active) continue;
      p.life += dt;
      if (p.life >= p.maxLife) { p.active = false; p.mesh.visible = false; continue; }
      p.vel.y -= 9 * dt;
      p.mesh.position.addScaledVector(p.vel, dt);
      p.mat.opacity = 1 - p.life / p.maxLife;
    }
  }

  /* ------------------------------------------------------------------------
     Tweens
     ------------------------------------------------------------------------ */
  function addTween(duration, onUpdate, onDone) { tweens.push({ t: 0, duration, onUpdate, onDone }); }
  function updateTweens(dt) {
    for (let i = tweens.length - 1; i >= 0; i--) {
      const tw = tweens[i];
      tw.t += dt;
      const p = Math.min(tw.t / tw.duration, 1);
      tw.onUpdate(p);
      if (p >= 1) { if (tw.onDone) tw.onDone(); tweens.splice(i, 1); }
    }
  }

  /* ------------------------------------------------------------------------
     XP / Level / Ressourcen
     ------------------------------------------------------------------------ */
  function xpToNext(level) { return 40 + level * 30; }
  function applyLevelStats() {
    player.maxHealth = 100 + (player.level - 1) * 10;
    player.maxStamina = 100 + (player.level - 1) * 5;
    player.attackDamage = 12 + (player.level - 1) * 2;
  }
  function addXp(amount) {
    player.xp += amount;
    let leveled = false;
    while (player.xp >= xpToNext(player.level)) {
      player.xp -= xpToNext(player.level);
      player.level++;
      leveled = true;
    }
    if (leveled) {
      applyLevelStats();
      player.health = player.maxHealth;
      player.stamina = player.maxStamina;
      toast(`Level ${player.level}! 🎉`, 'gold');
      SFX.levelup();
    }
  }

  /* ------------------------------------------------------------------------
     Quests
     ------------------------------------------------------------------------ */
  let announcedAllDone = false;
  function updateQuests() {
    if (questIndex >= QUESTS.length) {
      updateQuestTrackerUI(null, 0);
      return;
    }
    const q = QUESTS[questIndex];
    const val = q.get();
    updateQuestTrackerUI(q, Math.min(val, q.target));
    if (val >= q.target) {
      resources.coin += q.reward.coin;
      addXp(q.reward.xp);
      toast(`Quest abgeschlossen: ${q.title} (+${q.reward.coin}🪙 +${q.reward.xp}XP)`, 'gold');
      SFX.questDone();
      questIndex++;
      if (questIndex >= QUESTS.length && !announcedAllDone) {
        announcedAllDone = true;
        setTimeout(() => toast('Alle Quests abgeschlossen! Erkunde frei weiter 🎉', 'good'), 1600);
      }
    }
  }
  function updateQuestTrackerUI(q, val) {
    if (!q) {
      dom['quest-title'].textContent = 'Freies Spiel';
      dom['quest-desc'].textContent = 'Erkunde die Insel weiter';
      dom['quest-progress-fill'].style.width = '100%';
      dom['quest-tracker'].classList.remove('hidden');
      return;
    }
    dom['quest-title'].textContent = `Quest ${questIndex + 1}/${QUESTS.length}: ${q.title}`;
    dom['quest-desc'].textContent = `${q.desc} (${val}/${q.target})`;
    dom['quest-progress-fill'].style.width = `${clamp01(val / q.target) * 100}%`;
    dom['quest-tracker'].classList.remove('hidden');
  }
  function checkPeakReached() {
    if (counters.peakReached) return;
    const d = Math.hypot(player.pos.x - MOUNTAIN_POS.x, player.pos.z - MOUNTAIN_POS.z);
    if (d < 6 && player.pos.y > peakHeight - 3) {
      counters.peakReached = true;
      toast('Du hast den Gipfel erreicht! ⛰️', 'good');
    }
  }

  /* ------------------------------------------------------------------------
     HUD
     ------------------------------------------------------------------------ */
  function toast(msg, cls) {
    const el = document.createElement('div');
    el.className = 'toast' + (cls ? ' ' + cls : '');
    el.textContent = msg;
    dom['toast-stack'].appendChild(el);
    setTimeout(() => { if (el.parentNode) el.parentNode.removeChild(el); }, 2700);
    while (dom['toast-stack'].children.length > 4) dom['toast-stack'].removeChild(dom['toast-stack'].firstChild);
  }

  function updateHud() {
    if (!worldReady) return;
    dom['bar-health'].style.width = `${clamp01(player.health / player.maxHealth) * 100}%`;
    dom['bar-stamina'].style.width = `${clamp01(player.stamina / player.maxStamina) * 100}%`;
    dom['bar-oxygen'].style.width = `${clamp01(player.oxygen / player.maxOxygen) * 100}%`;
    dom['oxygen-row'].classList.toggle('hidden', !player.inWater && player.oxygen >= player.maxOxygen);
    dom['bar-xp'].style.width = `${clamp01(player.xp / xpToNext(player.level)) * 100}%`;
    dom['level-badge'].textContent = player.level;
    dom['res-wood'].textContent = resources.wood;
    dom['res-stone'].textContent = resources.stone;
    dom['res-berry'].textContent = resources.berry;
    dom['res-coin'].textContent = resources.coin;
  }

  const minimapCtx = () => dom.minimap.getContext('2d');
  function drawMinimap() {
    if (!worldReady) return;
    const ctx = minimapCtx();
    const size = dom.minimap.width;
    const viewR = 55;
    const scale = (size / 2 - 4) / viewR;
    ctx.clearRect(0, 0, size, size);
    ctx.fillStyle = 'rgba(20,30,42,0.55)';
    ctx.beginPath(); ctx.arc(size / 2, size / 2, size / 2 - 2, 0, Math.PI * 2); ctx.fill();
    ctx.save();
    ctx.beginPath(); ctx.arc(size / 2, size / 2, size / 2 - 2, 0, Math.PI * 2); ctx.clip();

    function toMap(x, z) { return [size / 2 + (x - player.pos.x) * scale, size / 2 + (z - player.pos.z) * scale]; }
    function dot(x, z, color, r) {
      const [mx, my] = toMap(x, z);
      if (mx < -4 || mx > size + 4 || my < -4 || my > size + 4) return;
      ctx.fillStyle = color;
      ctx.beginPath(); ctx.arc(mx, my, r, 0, Math.PI * 2); ctx.fill();
    }
    chests.forEach((c) => { if (!c.opened) dot(c.mesh.position.x, c.mesh.position.z, '#f2c94c', 3); });
    enemies.forEach((en) => { if (!en.dead && flatDist(player.pos, en.mesh.position) < viewR) dot(en.mesh.position.x, en.mesh.position.z, '#e6544c', 2.6); });
    campfires.forEach((c) => dot(c.mesh.position.x, c.mesh.position.z, '#ff9d3c', 2.6));
    structures.forEach((s) => { if (s.type !== 'campfire') dot(s.mesh.position.x, s.mesh.position.z, '#9c7a4a', 2.2); });
    minimapLandmarks.forEach((l) => dot(l.pos.x, l.pos.z, l.color, 2.8));
    dot(MOUNTAIN_POS.x, MOUNTAIN_POS.z, '#8a5cff', 3.2);

    ctx.restore();
    ctx.save();
    ctx.translate(size / 2, size / 2);
    ctx.rotate(player.yaw);
    ctx.fillStyle = '#f2f6f8';
    ctx.beginPath();
    ctx.moveTo(0, -7); ctx.lineTo(5, 6); ctx.lineTo(0, 3); ctx.lineTo(-5, 6);
    ctx.closePath(); ctx.fill();
    ctx.restore();
  }

  function updateDayNight(dt) {
    dayTime = (dayTime + dt / DAY_LENGTH) % 1;
    const sunHeight = Math.sin(dayTime * Math.PI * 2);
    const sunAngle = dayTime * Math.PI * 2;
    const dist = 120;
    sunLight.position.set(Math.cos(sunAngle) * dist, Math.max(sunHeight, -0.15) * dist + 20, Math.sin(sunAngle) * dist * 0.6);
    sunMesh.position.copy(sunLight.position);
    moonMesh.position.set(-sunLight.position.x, -sunLight.position.y + 60, -sunLight.position.z);

    const t = clamp01((sunHeight + 0.25) / 0.5);
    const skyDay = new THREE.Color(0x6ec3e8), skyNight = new THREE.Color(0x0a1020);
    const sky = skyNight.clone().lerp(skyDay, t);
    scene.background = sky;
    scene.fog.color.copy(sky);
    hemiLight.intensity = 0.25 + t * 0.55;
    sunLight.intensity = 0.15 + t * 0.9;
    sunLight.color.setHSL(0.12, 0.5, 0.55 + t * 0.2);
    starsMat.opacity = 1 - t;
    sunMesh.visible = sunHeight > -0.2;
    moonMesh.visible = sunHeight < 0.3;

    isNight = t < 0.35;
    dom['daytime-icon'].textContent = t > 0.6 ? '☀️' : t > 0.25 ? '🌅' : '🌙';
    dom['daytime-text'].textContent = t > 0.6 ? 'Tag' : t > 0.25 ? 'Dämmerung' : 'Nacht';

    if (relicMarker) {
      relicMarker.rotation.y += dt * 0.4;
      relicMarker.position.y = relicBaseY + Math.sin(gameTime * 1.2) * 0.15;
    }
    if (waterMesh) waterMesh.position.y = Math.sin(gameTime * 0.6) * 0.06;
  }

  /* ------------------------------------------------------------------------
     Kamera
     ------------------------------------------------------------------------ */
  function updateCamera(dt) {
    const eyeHeight = 1.5;
    camDist = clamp(camDist, MIN_DIST, MAX_DIST);
    let cx = player.pos.x - Math.sin(camState.yaw) * camDist * Math.cos(camState.pitch);
    let cz = player.pos.z - Math.cos(camState.yaw) * camDist * Math.cos(camState.pitch);
    let cy = player.pos.y + eyeHeight + camDist * Math.sin(camState.pitch);
    const groundClamp = getGroundHeight(cx, cz) + 0.4;
    if (cy < groundClamp) cy = groundClamp;
    if (cameraShake > 0) {
      cx += (Math.random() - 0.5) * cameraShake;
      cy += (Math.random() - 0.5) * cameraShake;
      cz += (Math.random() - 0.5) * cameraShake;
      cameraShake = Math.max(0, cameraShake - dt * 1.5);
    }
    camera.position.set(cx, cy, cz);
    camera.lookAt(player.pos.x, player.pos.y + eyeHeight * 0.85, player.pos.z);
  }

  /* ------------------------------------------------------------------------
     Eingabe
     ------------------------------------------------------------------------ */
  function detectTouch() {
    isTouchDevice = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
  }

  function handleEscape() {
    if (placementMode) { cancelPlacement(); return; }
    if (!dom['build-menu'].classList.contains('hidden')) { closeBuildMenu(); return; }
    if (player.isDead) return;
    togglePause();
  }

  function togglePause() {
    paused = !paused;
    dom['pause-menu'].classList.toggle('hidden', !paused);
    if (paused) saveGameIfPlaying();
    SFX.resume();
  }

  function wireKeyboard() {
    window.addEventListener('keydown', (e) => {
      if (e.repeat) return;
      keys[e.code] = true;
      if (e.code === 'Space') { input.jumpPressed = true; input.jumpHeld = true; e.preventDefault(); }
      if (e.code === 'KeyF') tryAttack();
      if (e.code === 'KeyE') tryInteract();
      if (e.code === 'KeyB') toggleBuildMenu();
      if (e.code === 'Escape') handleEscape();
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
    });
    window.addEventListener('keyup', (e) => { keys[e.code] = false; if (e.code === 'Space') input.jumpHeld = false; });
  }

  function updateInputDerived() {
    let mx = 0, my = 0;
    if (keys.KeyW || keys.ArrowUp) my += 1;
    if (keys.KeyS || keys.ArrowDown) my -= 1;
    if (keys.KeyD || keys.ArrowRight) mx += 1;
    if (keys.KeyA || keys.ArrowLeft) mx -= 1;
    if (joystick.active) { mx = joystick.x; my = joystick.y; }
    const len = Math.hypot(mx, my);
    if (len > 1) { mx /= len; my /= len; }
    input.move.x = mx; input.move.y = my;
    input.sprint = !!keys.ShiftLeft || !!keys.ShiftRight || touchSprintActive;
  }

  let lookPointerId = null, lastLookX = 0, lastLookY = 0;
  function wireLookInput() {
    const el = dom.stage;
    el.addEventListener('pointerdown', (e) => {
      if (lookPointerId !== null) return;
      lookPointerId = e.pointerId;
      lastLookX = e.clientX; lastLookY = e.clientY;
      try { el.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
    });
    el.addEventListener('pointermove', (e) => {
      if (e.pointerId !== lookPointerId) return;
      const dx = e.clientX - lastLookX, dy = e.clientY - lastLookY;
      lastLookX = e.clientX; lastLookY = e.clientY;
      camState.yaw -= dx * 0.005 * sensitivity;
      camState.pitch = clamp(camState.pitch - dy * 0.005 * sensitivity, MIN_PITCH, MAX_PITCH);
    });
    function end(e) { if (e.pointerId === lookPointerId) lookPointerId = null; }
    el.addEventListener('pointerup', end);
    el.addEventListener('pointercancel', end);
    el.addEventListener('wheel', (e) => { camDist = clamp(camDist + e.deltaY * 0.01, MIN_DIST, MAX_DIST); e.preventDefault(); }, { passive: false });
    el.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  function wireMobileControls() {
    const zone = dom['joystick-zone'], base = dom['joystick-base'], stick = dom['joystick-stick'];
    let baseCenter = { x: 0, y: 0 };
    const maxR = 40;
    function updateJoystick(e) {
      const dx = e.clientX - baseCenter.x, dy = e.clientY - baseCenter.y;
      const dist = Math.min(Math.hypot(dx, dy), maxR);
      const ang = Math.atan2(dy, dx);
      const sx = Math.cos(ang) * dist, sy = Math.sin(ang) * dist;
      stick.style.transform = `translate(${sx}px, ${sy}px)`;
      joystick.x = sx / maxR; joystick.y = -sy / maxR;
    }
    zone.addEventListener('pointerdown', (e) => {
      if (joystick.active) return;
      joystick.active = true; joystick.pointerId = e.pointerId;
      const rect = base.getBoundingClientRect();
      baseCenter = { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
      try { zone.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
      updateJoystick(e);
    });
    zone.addEventListener('pointermove', (e) => { if (e.pointerId === joystick.pointerId) updateJoystick(e); });
    function endJoystick(e) {
      if (e.pointerId !== joystick.pointerId) return;
      joystick.active = false; joystick.x = 0; joystick.y = 0;
      stick.style.transform = 'translate(0,0)';
    }
    zone.addEventListener('pointerup', endJoystick);
    zone.addEventListener('pointercancel', endJoystick);

    dom['btn-jump'].addEventListener('pointerdown', (e) => { e.preventDefault(); input.jumpPressed = true; input.jumpHeld = true; });
    ['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) => dom['btn-jump'].addEventListener(ev, () => { input.jumpHeld = false; }));
    dom['btn-attack'].addEventListener('pointerdown', (e) => { e.preventDefault(); tryAttack(); });
    dom['btn-interact'].addEventListener('pointerdown', (e) => { e.preventDefault(); tryInteract(); });
    dom['btn-build'].addEventListener('pointerdown', (e) => { e.preventDefault(); toggleBuildMenu(); });
    const sprintBtn = dom['btn-sprint'];
    sprintBtn.addEventListener('pointerdown', (e) => { e.preventDefault(); touchSprintActive = true; sprintBtn.classList.add('active'); });
    ['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) => sprintBtn.addEventListener(ev, () => { touchSprintActive = false; sprintBtn.classList.remove('active'); }));
  }

  function wireHudButtons() {
    dom['pause-btn'].addEventListener('pointerdown', (e) => { e.preventDefault(); handleEscape(); });
  }

  function wireBuildMenu() {
    dom['build-cancel-btn'].addEventListener('pointerdown', (e) => { e.preventDefault(); closeBuildMenu(); });
  }

  function wirePauseMenu() {
    dom['resume-btn'].addEventListener('pointerdown', (e) => { e.preventDefault(); togglePause(); });
    dom['save-btn'].addEventListener('pointerdown', (e) => { e.preventDefault(); saveGame(); toast('Gespeichert.', 'good'); });
    dom['quit-btn'].addEventListener('pointerdown', (e) => {
      e.preventDefault();
      saveGameIfPlaying();
      paused = false;
      dom['pause-menu'].classList.add('hidden');
      onGameScreen = false;
      dom['game-screen'].classList.add('hidden');
      dom['start-screen'].classList.remove('hidden');
      refreshContinueButtons();
    });
    dom['sens-slider'].addEventListener('input', (e) => { sensitivity = parseFloat(e.target.value); });
    dom['vol-slider'].addEventListener('input', (e) => { SFX.setVolume(parseFloat(e.target.value)); });
  }

  function wireDeathMenu() {
    dom['respawn-btn'].addEventListener('pointerdown', (e) => { e.preventDefault(); respawnPlayer(); });
  }

  let wipeConfirmPending = false;
  function wireStartScreen() {
    dom['new-game-btn'].addEventListener('click', () => startGame(false));
    dom['continue-btn'].addEventListener('click', () => startGame(true));
    dom['wipe-save-btn'].addEventListener('click', () => {
      if (!wipeConfirmPending) {
        wipeConfirmPending = true;
        dom['wipe-save-btn'].textContent = 'Wirklich löschen? Nochmal tippen';
        setTimeout(() => { wipeConfirmPending = false; dom['wipe-save-btn'].textContent = 'Spielstand löschen'; }, 3000);
      } else {
        try { localStorage.removeItem(SAVE_KEY); } catch (e) { /* ignore */ }
        wipeConfirmPending = false;
        dom['wipe-save-btn'].textContent = 'Spielstand löschen';
        refreshContinueButtons();
      }
    });
  }

  function refreshContinueButtons() {
    let has = false;
    try { has = !!localStorage.getItem(SAVE_KEY); } catch (e) { has = false; }
    dom['continue-btn'].classList.toggle('hidden', !has);
    dom['wipe-save-btn'].classList.toggle('hidden', !has);
  }

  /* ------------------------------------------------------------------------
     Speichern / Laden
     ------------------------------------------------------------------------ */
  function loadSave() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (!raw) return null;
      const data = JSON.parse(raw);
      if (!data || typeof data !== 'object') return null;
      return data;
    } catch (e) { return null; }
  }
  function buildSaveObject() {
    return {
      v: 1,
      pos: { x: player.pos.x, y: player.pos.y, z: player.pos.z },
      yaw: player.yaw,
      level: player.level, xp: player.xp, health: player.health,
      resources: Object.assign({}, resources),
      counters: Object.assign({}, counters),
      questIndex,
      openedChests: Array.from(openedChestIds),
      structures: structures.map((s) => ({ type: s.type, x: s.mesh.position.x, z: s.mesh.position.z, yaw: s.mesh.rotation.y })),
      timeOfDay: dayTime,
      settings: { sensitivity, volume: SFX.volume },
    };
  }
  function saveGame() {
    if (!worldReady) return;
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(buildSaveObject())); } catch (e) { /* Speicher voll o.ä. - ignorieren */ }
  }
  function saveGameIfPlaying() { if (worldReady && onGameScreen && !player.isDead) saveGame(); }

  function resetWorldObjects() {
    trees.forEach((t) => { t.hidden = false; t.hp = t.maxHp; t.mesh.visible = true; t.mesh.rotation.z = 0; t.mesh.scale.copy(t.baseScale); });
    rocks.forEach((r) => { r.hidden = false; r.hp = r.maxHp; r.mesh.visible = true; r.mesh.scale.copy(r.baseScale); });
    bushes.forEach((b) => { b.hidden = false; b.hp = b.maxHp; b.mesh.visible = true; b.mesh.scale.copy(b.baseScale); });
    chests.forEach((c) => { c.opened = false; if (c.mesh.userData.lid) c.mesh.userData.lid.rotation.x = 0; });
    enemies.forEach((en) => { en.dead = false; en.hp = en.maxHp; en.state = 'idle'; en.mesh.visible = true; en.mesh.position.set(en.home.x, heightAt(en.home.x, en.home.z) + en.baseY, en.home.z); });
    clearAllStructures();
  }

  function resetState() {
    if (worldBuilt) resetWorldObjects();
    player.pos.set(SPAWN.x, worldBuilt ? heightAt(SPAWN.x, SPAWN.z) : 0, SPAWN.z);
    player.vel.set(0, 0, 0);
    player.yaw = Math.PI;
    player.level = 1; player.xp = 0;
    applyLevelStats();
    player.health = player.maxHealth; player.stamina = player.maxStamina; player.oxygen = player.maxOxygen;
    player.isDead = false; player.attackCooldownTimer = 0; player.isAttacking = false;
    player.inWater = false; player.submerged = false;
    resources.wood = 0; resources.stone = 0; resources.berry = 0; resources.coin = 0;
    counters.woodTotal = 0; counters.stoneTotal = 0; counters.campfiresBuilt = 0; counters.enemiesDefeated = 0; counters.chestsOpened = 0; counters.peakReached = false;
    questIndex = 0; announcedAllDone = false;
    openedChestIds.clear();
    dayTime = 0.28;
    camState.yaw = Math.PI; camState.pitch = 0.5; camDist = 7;
    cancelPlacement();
    dom['death-menu'].classList.add('hidden');
    dom['pause-menu'].classList.add('hidden');
    dom['build-menu'].classList.add('hidden');
    dom['toast-stack'].innerHTML = '';
    paused = false;
  }

  function applySave(data) {
    resetState();
    if (!data) return;
    try {
      if (data.pos) player.pos.set(data.pos.x, data.pos.y, data.pos.z);
      if (typeof data.yaw === 'number') player.yaw = data.yaw;
      player.level = data.level || 1;
      player.xp = data.xp || 0;
      applyLevelStats();
      player.health = clamp(data.health != null ? data.health : player.maxHealth, 1, player.maxHealth);
      if (data.resources) Object.assign(resources, data.resources);
      if (data.counters) Object.assign(counters, data.counters);
      questIndex = data.questIndex || 0;
      (data.openedChests || []).forEach((id) => openedChestIds.add(id));
      chests.forEach((c) => {
        if (openedChestIds.has(c.id)) { c.opened = true; if (c.mesh.userData.lid) c.mesh.userData.lid.rotation.x = -1.9; }
      });
      (data.structures || []).forEach((s) => makeStructure(s.type, { x: s.x, z: s.z }, s.yaw || 0));
      if (typeof data.timeOfDay === 'number') dayTime = data.timeOfDay;
      if (data.settings) {
        sensitivity = data.settings.sensitivity || 1;
        SFX.setVolume(data.settings.volume != null ? data.settings.volume : 0.6);
        dom['sens-slider'].value = sensitivity;
        dom['vol-slider'].value = SFX.volume;
      }
    } catch (e) { console.error('Spielstand konnte nicht vollständig geladen werden.', e); }
  }

  /* ------------------------------------------------------------------------
     Game Loop
     ------------------------------------------------------------------------ */
  function tick(now) {
    requestAnimationFrame(tick);
    if (!onGameScreen) return;
    let dt = (now - lastTime) / 1000;
    lastTime = now;
    if (!isFinite(dt) || dt <= 0) return;
    dt = Math.min(dt, 0.08);
    frameCount++;

    if (!paused && !player.isDead) {
      gameTime += dt;
      updateInputDerived();
      updatePlayer(dt);
      updateEnemies(dt);
      updateGatherRespawns();
      applyCampfireHeal(dt);
      updateTweens(dt);
      updateParticles(dt);
      updateDayNight(dt);
      updatePlacementGhost();
      updateInteractPrompt();
      updateQuests();
      checkPeakReached();
      if (gameTime - lastAutosave > 20) { lastAutosave = gameTime; saveGame(); }
    } else if (!paused && player.isDead) {
      updateTweens(dt);
      updateParticles(dt);
    }
    updateCamera(dt);
    updateHud();
    if (frameCount % 4 === 0) drawMinimap();
    renderer.render(scene, camera);
  }

  function ensureLoopStarted() {
    if (loopStarted) return;
    loopStarted = true;
    lastTime = performance.now();
    requestAnimationFrame(tick);
  }

  function startGame(isContinue) {
    SFX.ensure();
    SFX.resume();
    dom['start-screen'].classList.add('hidden');
    dom['game-screen'].classList.remove('hidden');
    dom['loading-overlay'].classList.remove('hidden');
    dom.hud.classList.add('hidden');
    requestAnimationFrame(() => setTimeout(() => {
      if (!worldBuilt) { initThree(); buildWorld(); }
      if (isContinue) applySave(loadSave()); else resetState();
      onGameScreen = true;
      ensureLoopStarted();
      dom['loading-overlay'].classList.add('hidden');
      dom.hud.classList.remove('hidden');
      onResize();
    }, 30));
  }

  /* ------------------------------------------------------------------------
     Boot
     ------------------------------------------------------------------------ */
  function boot() {
    cacheDom();
    detectTouch();
    initBuildMenuUI();
    wireStartScreen();
    wirePauseMenu();
    wireDeathMenu();
    wireBuildMenu();
    wireHudButtons();
    wireMobileControls();
    wireLookInput();
    wireKeyboard();
    refreshContinueButtons();
    document.addEventListener('visibilitychange', () => { if (document.hidden) saveGameIfPlaying(); });
    window.addEventListener('pagehide', () => saveGameIfPlaying());
  }

  document.addEventListener('DOMContentLoaded', boot);
})();
