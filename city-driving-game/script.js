/* ============================================================================
   HEAT STREETS — offene Stadt zum Fahren, mit NPCs & Fahndungsstufe
   Reines Vanilla-JS, 2D-Top-Down-Rendering direkt auf einem <canvas> (wie
   die ersten beiden GTA-Teile) — bewusst KEINE 3D-Engine, keine externen
   Assets. Läuft als Web-Seite und im Android-WebView-Wrapper.

   Vereinfachungen (bewusst, damit das Spiel in einem Zug baubar bleibt):
   - Kein Aussteigen aus dem Auto, kein Zufußgehen.
   - Verkehrsautos fahren feste Rechteck-Umläufe um je einen Block (kein
     Pathfinding, kein Spurwechsel) und kollidieren nicht untereinander,
     sondern regeln nur Tempo über eine 1D-Abstandsregel entlang der Route.
   - Polizei verfolgt den Spieler direkt (kein Vorhalten/Interception).
   - Autos sind als Kollisionskreis modelliert, Gebäude/Weltgrenze als
     achsenparallele Rechtecke — die Kollisions-/Bewegungs-Mathematik läuft
     nach wie vor in Weltkoordinaten (x,z); die Kamera ist einfach eine
     feste Nordausrichtung, die dem Spieler folgt (kein Rotieren der Karte).
   ========================================================================== */
(function () {
  'use strict';

  /* ------------------------------------------------------------------------
     Konstanten: Stadtraster
     ------------------------------------------------------------------------ */
  const GRID_N = 7;                          // 7x7 Blocks
  const LANE_WIDTH = 3.2;
  const STREET_WIDTH = LANE_WIDTH * 2;       // 2-spurig, beide Richtungen
  const BLOCK_SIZE = 34;                     // Block-Innenfläche (Gebäude + Gehweg)
  const GRID_PERIOD = BLOCK_SIZE + STREET_WIDTH;
  const GRID_HALF = (GRID_N * GRID_PERIOD) / 2;
  const WORLD_MARGIN = 20;
  const WORLD_HALF_EXTENT = GRID_HALF + WORLD_MARGIN;
  const SIDEWALK_WIDTH = 2.4;
  const BUILDING_MIN_H = 6;
  const BUILDING_MAX_H = 32;
  const PARK_BLOCK_CHANCE = 0.15;
  const BUILDING_COLORS = [0x8a7d6b, 0x9c8f7a, 0x7d8a94, 0xa3907a, 0x6f7d89, 0x8f8574, 0x7a8a7d];

  /* ------------------------------------------------------------------------
     Konstanten: Auto-Physik (Spieler, Verkehr, Polizei teilen sich das Modell)
     ------------------------------------------------------------------------ */
  const CAR_RADIUS = 1.1;
  const MAX_SPEED_FORWARD = 26;
  const MAX_SPEED_REVERSE = -8;
  const ACCEL = 9;
  const BRAKE_DECEL = 16;
  const DRAG = 3.5;
  const STEER_MAX_RATE = 2.0;

  /* ------------------------------------------------------------------------
     Konstanten: Fußgänger
     ------------------------------------------------------------------------ */
  const PED_RADIUS = 0.4;
  const PED_WALK_SPEED = 1.3;
  const PED_FLEE_SPEED = 2.8;
  const FLEE_RADIUS = 6;
  const FLEE_DURATION = 2.5;
  const MIN_HIT_SPEED = 2.5;
  const PED_RESPAWN_DELAY = 20;
  const PED_DEATH_ANIM_TIME = 0.4;

  /* ------------------------------------------------------------------------
     Konstanten: Verkehr (Ambient-KI, feste Rechteck-Umläufe je Block)
     ------------------------------------------------------------------------ */
  const TRAFFIC_SPEED_MIN = 9;
  const TRAFFIC_SPEED_MAX = 14;
  const TRAFFIC_MAX_ACCEL = 6;

  /* ------------------------------------------------------------------------
     Konstanten: Fahndungsstufe & Polizei
     ------------------------------------------------------------------------ */
  const PED_HIT_HEAT = 1.0;
  const RECKLESS_WINDOW = 8;
  const RECKLESS_CAR_HITS_THRESHOLD = 3;
  const RECKLESS_HEAT = 1.0;
  const POLICE_HIT_HEAT = 0.4;
  const POLICE_SPAWN_MIN_DIST = 30;
  const POLICE_SPAWN_MAX_DIST = 70;
  const POLICE_MAX_SPEED = 22;
  const POLICE_PROXIMITY_DECAY_RADIUS = 25;
  const POLICE_STUCK_TIME = 4;
  const HEALTH_REGEN = 2;

  const DENSITY_PRESETS = {
    ruhig: { pedCount: 20, trafficCount: 6, policeMaxCars: 3, evadeTime: 10 },
    normal: { pedCount: 32, trafficCount: 12, policeMaxCars: 4, evadeTime: 12 },
    voll: { pedCount: 44, trafficCount: 18, policeMaxCars: 5, evadeTime: 16 },
  };

  const HIGHSCORE_KEY = 'city-driving-game-highscore';

  /* ------------------------------------------------------------------------
     Konstanten: Münzen (Sammel-Bonus, liegen direkt auf den Straßen)
     ------------------------------------------------------------------------ */
  const COIN_COUNT = 36;
  const COIN_PICKUP_RADIUS = 1.0;
  const COIN_SCORE = 20;
  const ALL_COINS_BONUS = 200;

  /* ------------------------------------------------------------------------
     Konstanten: Ampeln an Kreuzungen (rein dekorativ)
     ------------------------------------------------------------------------ */
  const TRAFFIC_LIGHT_CYCLE = 8;
  const TRAFFIC_LIGHT_GREEN = 5;

  /* ------------------------------------------------------------------------
     Konstanten: Beinahe-Unfall-Bonus (knapp an Fußgängern vorbeigefahren)
     ------------------------------------------------------------------------ */
  const NEAR_MISS_MIN_GAP = CAR_RADIUS + PED_RADIUS + 0.15;
  const NEAR_MISS_MAX_GAP = NEAR_MISS_MIN_GAP + 1.2;
  const NEAR_MISS_MIN_SPEED = 6;
  const NEAR_MISS_SCORE = 5;
  const NEAR_MISS_COOLDOWN = 3;

  /* ------------------------------------------------------------------------
     Konstanten: Tag/Nacht-Zyklus (Himmel-/Bodenfarbe, Straßenlaternen nachts)
     ------------------------------------------------------------------------ */
  const DAY_LENGTH = 220; // Sekunden pro vollem Tag/Nacht-Zyklus
  const SKY_DAY = [0x8a, 0xb7, 0xd6];
  const SKY_NIGHT = [0x07, 0x0a, 0x14];
  const GROUND_DAY = [0xc9, 0xc2, 0xae];
  const GROUND_NIGHT = [0x22, 0x24, 0x2a];

  // Auto-Farbwahl in der Lobby.
  const CAR_COLORS = [
    { body: 0xf2a93a, cabin: 0x2b1900 },
    { body: 0xe6544c, cabin: 0x2b0906 },
    { body: 0x4c9fe6, cabin: 0x0d1f2b },
    { body: 0x5fb87a, cabin: 0x0d2b17 },
  ];

  /* ------------------------------------------------------------------------
     Utility
     ------------------------------------------------------------------------ */
  function clamp(v, min, max) { return v < min ? min : v > max ? max : v; }
  function clamp01(v) { return clamp(v, 0, 1); }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function moveToward(v, target, maxDelta) {
    const d = target - v;
    if (d > maxDelta) return v + maxDelta;
    if (d < -maxDelta) return v - maxDelta;
    return target;
  }
  function angleDiff(a, b) {
    let d = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
    if (d < -Math.PI) d += Math.PI * 2;
    return d;
  }
  function dist2D(ax, az, bx, bz) { return Math.hypot(ax - bx, az - bz); }
  function pick(arr, rand) { return arr[Math.floor(rand() * arr.length) % arr.length]; }
  function css(hex) { return '#' + hex.toString(16).padStart(6, '0'); }
  function lerpRgb(a, b, t) {
    return 'rgb(' + Math.round(lerp(a[0], b[0], t)) + ',' + Math.round(lerp(a[1], b[1], t)) + ',' + Math.round(lerp(a[2], b[2], t)) + ')';
  }

  // Deterministischer PRNG (mulberry32) — sorgt dafür, dass die Stadt bei
  // jedem Start identisch generiert wird.
  function mulberry32(seed) {
    return function () {
      seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const worldRand = mulberry32(4242);

  // Kollisionshilfen (Auto = Kreis, Gebäude/Grenze = achsenparalleles Rechteck).
  function pushOutRect(pos, rect, r) {
    const insideX = pos.x > rect.minX && pos.x < rect.maxX;
    const insideZ = pos.z > rect.minZ && pos.z < rect.maxZ;
    if (insideX && insideZ) {
      const dLeft = pos.x - rect.minX, dRight = rect.maxX - pos.x;
      const dTop = pos.z - rect.minZ, dBottom = rect.maxZ - pos.z;
      const m = Math.min(dLeft, dRight, dTop, dBottom);
      if (m === dLeft) pos.x = rect.minX - r;
      else if (m === dRight) pos.x = rect.maxX + r;
      else if (m === dTop) pos.z = rect.minZ - r;
      else pos.z = rect.maxZ + r;
      return true;
    }
    const cx = clamp(pos.x, rect.minX, rect.maxX);
    const cz = clamp(pos.z, rect.minZ, rect.maxZ);
    const dx = pos.x - cx, dz = pos.z - cz;
    const d = Math.hypot(dx, dz);
    if (d >= r || d === 0) return false;
    const push = (r - d) / d;
    pos.x += dx * push;
    pos.z += dz * push;
    return true;
  }
  function pushOutCircle(pos, center, minD) {
    const dx = pos.x - center.x, dz = pos.z - center.z;
    const d = Math.hypot(dx, dz) || 0.0001;
    if (d >= minD) return false;
    const push = (minD - d) / d;
    pos.x += dx * push;
    pos.z += dz * push;
    return true;
  }
  function clampToWorldBounds(car) {
    const x = clamp(car.pos.x, -WORLD_HALF_EXTENT + CAR_RADIUS, WORLD_HALF_EXTENT - CAR_RADIUS);
    const z = clamp(car.pos.z, -WORLD_HALF_EXTENT + CAR_RADIUS, WORLD_HALF_EXTENT - CAR_RADIUS);
    const hit = (x !== car.pos.x) || (z !== car.pos.z);
    car.pos.x = x; car.pos.z = z;
    return hit;
  }

  /* ------------------------------------------------------------------------
     Highscore (localStorage)
     ------------------------------------------------------------------------ */
  function loadHighscore() { return Number(localStorage.getItem(HIGHSCORE_KEY) || 0); }
  function saveHighscoreIfBetter(value) {
    const current = loadHighscore();
    if (value > current) localStorage.setItem(HIGHSCORE_KEY, String(value));
    return Math.max(current, value);
  }

  /* ------------------------------------------------------------------------
     Prozedurales WebAudio (keine Audio-Dateien)
     ------------------------------------------------------------------------ */
  const SFX = {
    ctx: null, masterGain: null, volume: 0.6,
    ensure() {
      if (this.ctx) return;
      try {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        this.ctx = new Ctx();
        this.masterGain = this.ctx.createGain();
        this.masterGain.gain.value = this.volume;
        this.masterGain.connect(this.ctx.destination);
      } catch (e) { /* Audio nicht verfügbar - Spiel läuft trotzdem */ }
    },
    resume() { if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume(); },
    _tone(freq, duration, type, gain, slideTo) {
      if (!this.ctx) return;
      const t0 = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      osc.type = type || 'sine';
      osc.frequency.setValueAtTime(freq, t0);
      if (slideTo) osc.frequency.exponentialRampToValueAtTime(Math.max(1, slideTo), t0 + duration);
      const g = this.ctx.createGain();
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.exponentialRampToValueAtTime(Math.max(0.0002, gain || 0.2), t0 + 0.015);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + duration);
      osc.connect(g); g.connect(this.masterGain);
      osc.start(t0); osc.stop(t0 + duration + 0.02);
    },
    _noise(duration, gain) {
      if (!this.ctx) return;
      const t0 = this.ctx.currentTime;
      const bufferSize = Math.max(1, Math.floor(this.ctx.sampleRate * duration));
      const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < bufferSize; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / bufferSize);
      const src = this.ctx.createBufferSource();
      src.buffer = buffer;
      const g = this.ctx.createGain();
      g.gain.setValueAtTime(gain || 0.3, t0);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + duration);
      src.connect(g); g.connect(this.masterGain);
      src.start(t0);
    },
    crash() { this._noise(0.35, 0.5); this._tone(120, 0.25, 'sawtooth', 0.25, 60); },
    hit() { this._noise(0.15, 0.35); this._tone(300, 0.12, 'square', 0.2, 140); },
    heatUp() { this._tone(220, 0.18, 'sawtooth', 0.22, 440); },
    heatDown() { this._tone(440, 0.18, 'sine', 0.15, 220); },
    busted() { this._tone(300, 0.5, 'sawtooth', 0.25, 60); },
    coin() { this._tone(660, 0.08, 'square', 0.15, 990); this._tone(990, 0.1, 'square', 0.12, 1320); },
    nearMiss() { this._tone(500, 0.1, 'triangle', 0.12, 300); },
  };

  /* ------------------------------------------------------------------------
     DOM-Referenzen
     ------------------------------------------------------------------------ */
  let dom = {};
  function cacheDom() {
    const ids = [
      'lobby', 'game', 'start-btn', 'lobby-highscore',
      'stage', 'hud', 'wanted-row', 'bar-health', 'minimap', 'damage-flash',
      'speed', 'score', 'toast-stack',
      'daytime-icon', 'daytime-text', 'coins', 'coins-total',
      'steer-left', 'steer-right', 'pedal-gas', 'pedal-brake',
      'overlay', 'overlay-title', 'overlay-stats', 'restart-btn', 'lobby-btn',
    ];
    ids.forEach((id) => { dom[id] = document.getElementById(id); });
    dom.wantedStars = Array.prototype.slice.call(document.querySelectorAll('.wanted-star'));
    dom.optionGroups = document.querySelectorAll('.option-buttons');
  }

  /* ------------------------------------------------------------------------
     2D-Canvas-Grundgerüst (kein WebGL, reines CanvasRenderingContext2D)
     ------------------------------------------------------------------------ */
  let ctx = null;
  let viewW = 0, viewH = 0;
  let SCALE = 16; // Pixel pro Meter, an die Bildschirmbreite angepasst

  function initCanvas() {
    ctx = dom.stage.getContext('2d');
    window.addEventListener('resize', onResize);
    onResize();
  }
  function onResize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    viewW = window.innerWidth;
    viewH = window.innerHeight;
    dom.stage.width = Math.round(viewW * dpr);
    dom.stage.height = Math.round(viewH * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    SCALE = clamp(viewW / 46, 11, 22);
  }

  // Zeichenpfad für ein abgerundetes Rechteck (kein ctx.roundRect() genutzt,
  // damit es auch auf älteren Android-WebViews sicher funktioniert).
  function roundRectPath(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  /* ------------------------------------------------------------------------
     Stadt-Welt: deterministisch aus worldRand() aufgebaut. Straßen sind die
     Rasterlinien alle GRID_PERIOD Einheiten; jeder Block dazwischen ist
     entweder Park (begehbar, keine Kollision) oder Gebäude (Rechteck, um
     SIDEWALK_WIDTH von den Blockkanten eingerückt). Der verbleibende Ring
     ist der Gehweg (Fußgänger-Wegpunkte). Es entstehen nur reine Daten,
     keine Meshes — das 2D-Rendering zeichnet daraus jeden Frame neu.
     ------------------------------------------------------------------------ */
  const world = {
    buildingRects: [],   // flache Liste für Kollisionschecks
    buildings: [],       // { rect, color, height } fürs Zeichnen
    parks: [],           // { rect, trees: [{x,z}] }
    lamps: [],           // { x, z } Straßenlaternen, leuchten nachts
    blockLoops: [],      // ein Rechteck-Umlauf pro Block, für Verkehr
    pedWaypointLoops: [], // Punktlisten (im Uhrzeigersinn) je Block
  };

  function blockRange(i) {
    const min = -GRID_HALF + i * GRID_PERIOD + STREET_WIDTH;
    return { min, max: min + BLOCK_SIZE, center: min + BLOCK_SIZE / 2 };
  }

  function rectPerimeterPoints(rect) {
    return [
      { x: rect.minX, z: rect.minZ },
      { x: rect.maxX, z: rect.minZ },
      { x: rect.maxX, z: rect.maxZ },
      { x: rect.minX, z: rect.maxZ },
    ];
  }

  function buildWorld() {
    for (let i = 0; i < GRID_N; i++) {
      const bx = blockRange(i);
      for (let j = 0; j < GRID_N; j++) {
        const bz = blockRange(j);

        const isPark = worldRand() < PARK_BLOCK_CHANCE;
        if (isPark) {
          const rect = { minX: bx.min, maxX: bx.max, minZ: bz.min, maxZ: bz.max };
          const trees = [];
          const treeCount = 3 + Math.floor(worldRand() * 4);
          for (let t = 0; t < treeCount; t++) {
            trees.push({
              x: lerp(rect.minX + 2, rect.maxX - 2, worldRand()),
              z: lerp(rect.minZ + 2, rect.maxZ - 2, worldRand()),
            });
          }
          world.parks.push({ rect, trees });
        } else {
          const insetMin = { x: bx.min + SIDEWALK_WIDTH, z: bz.min + SIDEWALK_WIDTH };
          const insetMax = { x: bx.max - SIDEWALK_WIDTH, z: bz.max - SIDEWALK_WIDTH };
          const availW = insetMax.x - insetMin.x, availD = insetMax.z - insetMin.z;
          const footW = availW * lerp(0.6, 0.9, worldRand());
          const footD = availD * lerp(0.6, 0.9, worldRand());
          const offX = (availW - footW) * worldRand();
          const offZ = (availD - footD) * worldRand();
          const rect = {
            minX: insetMin.x + offX, maxX: insetMin.x + offX + footW,
            minZ: insetMin.z + offZ, maxZ: insetMin.z + offZ + footD,
          };
          const height = lerp(BUILDING_MIN_H, BUILDING_MAX_H, worldRand());
          const color = pick(BUILDING_COLORS, worldRand);
          world.buildingRects.push(rect);
          world.buildings.push({ rect, color, height });
        }

        // Gehweg-Wegpunktschleife: Ring knapp innerhalb der Blockkante.
        const wpRect = {
          minX: bx.min + SIDEWALK_WIDTH / 2, maxX: bx.max - SIDEWALK_WIDTH / 2,
          minZ: bz.min + SIDEWALK_WIDTH / 2, maxZ: bz.max - SIDEWALK_WIDTH / 2,
        };
        const loopPoints = rectPerimeterPoints(wpRect);
        world.pedWaypointLoops.push(loopPoints);
        // Zwei Straßenlaternen pro Block (gegenüberliegende Ecken), leuchten
        // nachts — ersetzt in der 2D-Draufsicht die früheren "Fenster", weil
        // man von oben ohnehin nur Dächer sieht, keine Fassaden.
        world.lamps.push(loopPoints[0], loopPoints[2]);

        // Verkehrs-Umlauf: Straßenmitte rund um diesen Block.
        const loopRect = {
          minX: bx.min - STREET_WIDTH / 2, maxX: bx.max + STREET_WIDTH / 2,
          minZ: bz.min - STREET_WIDTH / 2, maxZ: bz.max + STREET_WIDTH / 2,
        };
        world.blockLoops.push(loopRect);
      }
    }

    // Münzen: entlang der Straßen-Umläufe verstreut, damit jede beim
    // normalen Fahren erreichbar ist (kein Abstecher von der Fahrbahn nötig).
    for (let i = 0; i < COIN_COUNT; i++) {
      const loopRect = world.blockLoops[Math.floor(worldRand() * world.blockLoops.length)];
      const per = 2 * ((loopRect.maxX - loopRect.minX) + (loopRect.maxZ - loopRect.minZ));
      const p = pointOnLoop(loopRect, worldRand() * per);
      coins.push({ pos: { x: p.x, z: p.z }, collected: false });
    }

    // Ampeln an jeder Straßenkreuzung — rein dekorativ, der Verkehr hält
    // sich (wie beim ganzen Ambient-Verkehr) nicht an sie.
    for (let k = 0; k <= GRID_N; k++) {
      for (let j = 0; j <= GRID_N; j++) {
        const ix = -GRID_HALF + k * GRID_PERIOD, iz = -GRID_HALF + j * GRID_PERIOD;
        const offset = STREET_WIDTH / 2 + 0.6;
        trafficLights.push({ x: ix + offset, z: iz + offset, phase: worldRand() * TRAFFIC_LIGHT_CYCLE });
      }
    }
  }

  /* ------------------------------------------------------------------------
     Auto-Physik — gemeinsamer Integrator für Spieler & Polizei.
     ------------------------------------------------------------------------ */
  function integrateCarPhysics(car, throttle, brake, steerInput, dt) {
    if (brake) {
      if (car.speed > 0.05) car.speed = moveToward(car.speed, 0, BRAKE_DECEL * dt);
      else car.speed = moveToward(car.speed, MAX_SPEED_REVERSE, ACCEL * dt);
    } else if (throttle) {
      car.speed = moveToward(car.speed, MAX_SPEED_FORWARD, ACCEL * dt);
    } else {
      car.speed = moveToward(car.speed, 0, DRAG * dt);
    }
    car.speed = clamp(car.speed, MAX_SPEED_REVERSE, car.maxSpeed || MAX_SPEED_FORWARD);

    const speedFactor = clamp(Math.abs(car.speed) / 4, 0.15, 1) * (1 - clamp01(Math.abs(car.speed) / MAX_SPEED_FORWARD) * 0.4);
    if (Math.abs(car.speed) > 0.3) {
      car.heading += steerInput * STEER_MAX_RATE * speedFactor * dt * Math.sign(car.speed);
    }
    const fx = Math.sin(car.heading), fz = Math.cos(car.heading);
    car.pos.x += fx * car.speed * dt;
    car.pos.z += fz * car.speed * dt;
  }

  function resolveWorldCollisions(car) {
    let hit = false;
    for (let i = 0; i < world.buildingRects.length; i++) {
      if (pushOutRect(car.pos, world.buildingRects[i], CAR_RADIUS)) hit = true;
    }
    if (clampToWorldBounds(car)) hit = true;
    return hit;
  }

  function createCarState(x, z, heading) {
    return { pos: { x, z }, heading, speed: 0, maxSpeed: MAX_SPEED_FORWARD };
  }

  function pointOnLoop(rect, p) {
    const w = rect.maxX - rect.minX, h = rect.maxZ - rect.minZ;
    const per = 2 * (w + h);
    p = ((p % per) + per) % per;
    if (p < w) return { x: rect.minX + p, z: rect.minZ };
    p -= w;
    if (p < h) return { x: rect.maxX, z: rect.minZ + p };
    p -= h;
    if (p < w) return { x: rect.maxX - p, z: rect.maxZ };
    p -= w;
    return { x: rect.minX, z: rect.maxZ - p };
  }

  /* ------------------------------------------------------------------------
     Globaler Spielzustand
     ------------------------------------------------------------------------ */
  const TRAFFIC_COLORS = [
    [0xd9534f, 0x222222], [0x4c9fe6, 0x1a2733], [0xe0b93c, 0x2a2210],
    [0x7a8a99, 0x1c2229], [0x8a5fc9, 0x241833], [0x5fb87a, 0x172a1c],
  ];
  const POLICE_BODY = 0x1c2b44, POLICE_CABIN = 0x0d1420;

  let player = null;       // { pos, heading, speed, maxSpeed, health, colorIndex, hitCooldown, lastDamageSource }
  let pedestrians = [];
  let trafficCars = [];
  let policeCars = [];
  let particles = [];
  let coins = [];
  let trafficLights = [];

  let wantedHeat = 0;
  let maxWantedReached = 0;
  let vehicleHitTimestamps = [];
  let timeSinceLastPoliceContact = 0;
  let distanceDriven = 0;
  let wantedSecondsAccum = 0;
  let bonusScore = 0;
  let coinsCollected = 0;
  let allCoinsBonusGiven = false;
  let firstWantedShown = false;
  let nextDistanceMilestone = 1000;
  let dayTime = DAY_LENGTH * 0.05; // Start am helllichten Vormittag
  let dayFactor = 1;
  let gameTime = 0;
  let density = DENSITY_PRESETS.normal;
  let selectedCarColorIndex = 0;
  let selectedDensity = 'normal';
  let running = false;
  let ended = false;

  function toast(text, cls) {
    const el = document.createElement('div');
    el.className = 'toast' + (cls ? ' ' + cls : '');
    el.textContent = text;
    dom['toast-stack'].appendChild(el);
    el.addEventListener('animationend', (e) => {
      if (e.animationName === 'toast-out') el.remove();
    });
  }

  // Kleiner 2D-Partikel-Burst (Punkte, die auseinanderfliegen und
  // ausblenden) für Treffer/Crashes — bewusst minimal gehalten.
  function spawnParticles(x, z, color, count) {
    for (let i = 0; i < count; i++) {
      const ang = Math.random() * Math.PI * 2;
      const spd = 2.5 + Math.random() * 4;
      particles.push({
        x, z, color,
        vx: Math.cos(ang) * spd, vz: Math.sin(ang) * spd,
        life: 0.5 + Math.random() * 0.35, maxLife: 0.85,
      });
    }
  }
  function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.x += p.vx * dt; p.z += p.vz * dt;
      p.vx *= (1 - 2.5 * dt); p.vz *= (1 - 2.5 * dt);
      p.life -= dt;
      if (p.life <= 0) particles.splice(i, 1);
    }
  }

  /* ------------------------------------------------------------------------
     Fußgänger
     ------------------------------------------------------------------------ */
  function spawnPedestrian() {
    const loopIndex = Math.floor(worldRand() * world.pedWaypointLoops.length);
    const loop = world.pedWaypointLoops[loopIndex];
    const nodeIndex = Math.floor(worldRand() * loop.length);
    const start = loop[nodeIndex];
    const ped = {
      loopIndex, nodeIndex,
      dir: worldRand() < 0.5 ? 1 : -1,
      pos: { x: start.x, z: start.z },
      heading: 0,
      hue: Math.floor(worldRand() * 360),
      state: 'wander', fleeTimer: 0, fleeDir: { x: 0, z: 1 },
      alive: true, respawnAt: 0, deathT: 0,
      lastNearMissAt: -99,
    };
    pedestrians.push(ped);
    return ped;
  }
  function updatePedestrian(ped, dt) {
    if (!ped.alive) {
      ped.deathT = Math.min(1, ped.deathT + dt / PED_DEATH_ANIM_TIME);
      if (gameTime >= ped.respawnAt) {
        const loopIndex = Math.floor(worldRand() * world.pedWaypointLoops.length);
        const loop = world.pedWaypointLoops[loopIndex];
        const nodeIndex = Math.floor(worldRand() * loop.length);
        const start = loop[nodeIndex];
        ped.loopIndex = loopIndex; ped.nodeIndex = nodeIndex;
        ped.pos.x = start.x; ped.pos.z = start.z;
        ped.state = 'wander'; ped.alive = true; ped.deathT = 0;
      }
      return;
    }
    const distToPlayer = dist2D(ped.pos.x, ped.pos.z, player.pos.x, player.pos.z);
    if (ped.state === 'wander' && distToPlayer < FLEE_RADIUS && Math.abs(player.speed) > 3) {
      ped.state = 'flee';
      ped.fleeTimer = FLEE_DURATION;
      const dx = ped.pos.x - player.pos.x, dz = ped.pos.z - player.pos.z;
      const d = Math.hypot(dx, dz) || 1;
      ped.fleeDir.x = dx / d; ped.fleeDir.z = dz / d;
    }
    if (ped.state === 'flee') {
      ped.fleeTimer -= dt;
      ped.pos.x += ped.fleeDir.x * PED_FLEE_SPEED * dt;
      ped.pos.z += ped.fleeDir.z * PED_FLEE_SPEED * dt;
      ped.heading = Math.atan2(ped.fleeDir.x, ped.fleeDir.z);
      if (ped.fleeTimer <= 0) ped.state = 'wander';
    } else {
      const loop = world.pedWaypointLoops[ped.loopIndex];
      const target = loop[((ped.nodeIndex + ped.dir) % loop.length + loop.length) % loop.length];
      const dx = target.x - ped.pos.x, dz = target.z - ped.pos.z;
      const d = Math.hypot(dx, dz);
      if (d < 0.4) {
        ped.nodeIndex = ((ped.nodeIndex + ped.dir) % loop.length + loop.length) % loop.length;
        if (worldRand() < 0.15) ped.dir *= -1;
      } else {
        ped.pos.x += (dx / d) * PED_WALK_SPEED * dt;
        ped.pos.z += (dz / d) * PED_WALK_SPEED * dt;
        ped.heading = Math.atan2(dx / d, dz / d);
      }
    }
  }
  function killPedestrian(ped) {
    ped.alive = false;
    ped.deathT = 0;
    ped.respawnAt = gameTime + PED_RESPAWN_DELAY;
    spawnParticles(ped.pos.x, ped.pos.z, '#e6544c', 8);
    SFX.hit();
  }

  /* ------------------------------------------------------------------------
     Verkehr (Ambient-KI: fester Rechteck-Umlauf je Block)
     ------------------------------------------------------------------------ */
  function spawnTrafficCar() {
    const loopIndex = Math.floor(worldRand() * world.blockLoops.length);
    const rect = world.blockLoops[loopIndex];
    const per = 2 * ((rect.maxX - rect.minX) + (rect.maxZ - rect.minZ));
    const colors = pick(TRAFFIC_COLORS, worldRand);
    const car = {
      loopIndex, dir: worldRand() < 0.5 ? 1 : -1,
      progress: worldRand() * per,
      cruiseSpeed: lerp(TRAFFIC_SPEED_MIN, TRAFFIC_SPEED_MAX, worldRand()),
      speed: 0,
      pos: { x: 0, z: 0 }, heading: 0,
      bodyColor: colors[0], cabinColor: colors[1],
    };
    const p0 = pointOnLoop(rect, car.progress);
    car.pos.x = p0.x; car.pos.z = p0.z;
    trafficCars.push(car);
  }
  function updateTrafficCar(car, dt) {
    const rect = world.blockLoops[car.loopIndex];
    let targetSpeed = car.cruiseSpeed;
    for (let i = 0; i < trafficCars.length; i++) {
      const other = trafficCars[i];
      if (other === car || other.loopIndex !== car.loopIndex || other.dir !== car.dir) continue;
      const w = rect.maxX - rect.minX, h = rect.maxZ - rect.minZ;
      const per = 2 * (w + h);
      let gap = (other.progress - car.progress) * car.dir;
      gap = ((gap % per) + per) % per;
      const stoppingDistance = 2 + car.speed * 0.6;
      if (gap > 0 && gap < stoppingDistance) {
        targetSpeed = Math.min(targetSpeed, other.speed * (gap / stoppingDistance));
      }
    }
    car.speed = moveToward(car.speed, targetSpeed, TRAFFIC_MAX_ACCEL * dt);
    car.progress += car.dir * car.speed * dt;
    const pos = pointOnLoop(rect, car.progress);
    const ahead = pointOnLoop(rect, car.progress + car.dir * 0.6);
    car.pos.x = pos.x; car.pos.z = pos.z;
    car.heading = Math.atan2(ahead.x - pos.x, ahead.z - pos.z);
  }

  /* ------------------------------------------------------------------------
     Polizei
     ------------------------------------------------------------------------ */
  function spawnPoliceCar() {
    const ang = worldRand() * Math.PI * 2;
    const d = lerp(POLICE_SPAWN_MIN_DIST, POLICE_SPAWN_MAX_DIST, worldRand());
    const x = clamp(player.pos.x + Math.sin(ang) * d, -WORLD_HALF_EXTENT + 5, WORLD_HALF_EXTENT - 5);
    const z = clamp(player.pos.z + Math.cos(ang) * d, -WORLD_HALF_EXTENT + 5, WORLD_HALF_EXTENT - 5);
    const state = createCarState(x, z, ang);
    state.maxSpeed = POLICE_MAX_SPEED;
    policeCars.push(Object.assign(state, { stuckTimer: 0, lastCheckPos: { x, z } }));
  }
  function despawnPoliceCar(p) {
    const idx = policeCars.indexOf(p);
    if (idx !== -1) policeCars.splice(idx, 1);
  }
  function updatePoliceCar(p, dt) {
    const desiredHeading = Math.atan2(player.pos.x - p.pos.x, player.pos.z - p.pos.z);
    const steer = clamp(angleDiff(p.heading, desiredHeading) * 2, -1, 1);
    integrateCarPhysics(p, true, false, steer, dt);
    const hit = resolveWorldCollisions(p);
    if (hit) p.speed *= 0.5;
    p.stuckTimer += dt;
    if (p.stuckTimer > POLICE_STUCK_TIME) {
      const moved = dist2D(p.pos.x, p.pos.z, p.lastCheckPos.x, p.lastCheckPos.z);
      p.stuckTimer = 0;
      p.lastCheckPos = { x: p.pos.x, z: p.pos.z };
      if (moved < 2) {
        despawnPoliceCar(p);
        spawnPoliceCar();
      }
    }
  }

  /* ------------------------------------------------------------------------
     Fahndungsstufe: Erhöhung, Polizei-Spawn/-Abzug, Schaden
     ------------------------------------------------------------------------ */
  function addHeat(amount) {
    const before = wantedHeat;
    wantedHeat = clamp(wantedHeat + amount, 0, 5);
    if (wantedHeat > before) {
      SFX.heatUp();
      if (before < 1 && wantedHeat >= 1 && !firstWantedShown) {
        firstWantedShown = true;
        toast('Erste Fahndungsstufe! Die Polizei ist alarmiert.', 'bad');
      } else {
        toast('Fahndungsstufe erhöht!', 'bad');
      }
    }
    maxWantedReached = Math.max(maxWantedReached, wantedHeat);
  }
  function registerVehicleHit() {
    vehicleHitTimestamps.push(gameTime);
    vehicleHitTimestamps = vehicleHitTimestamps.filter((t) => gameTime - t <= RECKLESS_WINDOW);
    if (vehicleHitTimestamps.length >= RECKLESS_CAR_HITS_THRESHOLD) {
      addHeat(RECKLESS_HEAT);
      vehicleHitTimestamps = [];
    }
  }
  function maintainPolice(dt) {
    const desired = wantedHeat >= 1 ? Math.min(Math.ceil(wantedHeat), density.policeMaxCars) : 0;
    while (policeCars.length < desired) spawnPoliceCar();

    let anyNear = false;
    for (let i = 0; i < policeCars.length; i++) {
      if (dist2D(policeCars[i].pos.x, policeCars[i].pos.z, player.pos.x, player.pos.z) < POLICE_PROXIMITY_DECAY_RADIUS) { anyNear = true; break; }
    }
    if (wantedHeat > 0) {
      if (anyNear) {
        timeSinceLastPoliceContact = 0;
      } else {
        timeSinceLastPoliceContact += dt;
        if (timeSinceLastPoliceContact >= density.evadeTime) {
          timeSinceLastPoliceContact = 0;
          wantedHeat = Math.max(0, wantedHeat - 1);
          SFX.heatDown();
          toast('Fahndungsstufe sinkt', 'good');
          if (policeCars.length > 0) despawnPoliceCar(policeCars[policeCars.length - 1]);
        }
      }
    }
    if (wantedHeat <= 0 && policeCars.length > 0) {
      for (let i = policeCars.length - 1; i >= 0; i--) despawnPoliceCar(policeCars[i]);
    }
  }

  function applyDamage(amount, source) {
    if (ended) return;
    player.health = clamp(player.health - amount, 0, 100);
    player.lastDamageSource = source;
    if (player.health <= 0) endRun(source);
  }

  /* ------------------------------------------------------------------------
     Spieler-Kollisionen gegen Fußgänger / Verkehr / Polizei
     ------------------------------------------------------------------------ */
  function checkPlayerVsPedestrians() {
    if (Math.abs(player.speed) < MIN_HIT_SPEED) return;
    for (let i = 0; i < pedestrians.length; i++) {
      const ped = pedestrians[i];
      if (!ped.alive) continue;
      if (dist2D(player.pos.x, player.pos.z, ped.pos.x, ped.pos.z) < CAR_RADIUS + PED_RADIUS) {
        killPedestrian(ped);
        addHeat(PED_HIT_HEAT);
        player.hitCooldown = 0.3;
      }
    }
  }
  function checkPlayerVsTraffic() {
    for (let i = 0; i < trafficCars.length; i++) {
      const car = trafficCars[i];
      const minD = CAR_RADIUS * 2;
      if (dist2D(player.pos.x, player.pos.z, car.pos.x, car.pos.z) < minD) {
        if (player.hitCooldown <= 0) {
          const impact = Math.abs(player.speed - car.speed);
          applyDamage(Math.max(2, impact * 1.5), 'traffic');
          registerVehicleHit();
          SFX.crash();
          spawnParticles(player.pos.x, player.pos.z, '#ffcf7a', 10);
          player.speed *= 0.35;
          player.hitCooldown = 0.5;
        }
        pushOutCircle(player.pos, car.pos, minD);
      }
    }
  }
  function checkPlayerVsPolice() {
    for (let i = 0; i < policeCars.length; i++) {
      const car = policeCars[i];
      const minD = CAR_RADIUS * 2;
      if (dist2D(player.pos.x, player.pos.z, car.pos.x, car.pos.z) < minD) {
        if (player.hitCooldown <= 0) {
          const impact = Math.abs(player.speed - car.speed);
          applyDamage(Math.max(6, impact * 3.0), 'police');
          registerVehicleHit();
          if (wantedHeat >= 1) addHeat(POLICE_HIT_HEAT);
          SFX.crash();
          spawnParticles(player.pos.x, player.pos.z, '#4c9fe6', 10);
          player.speed *= 0.35;
          player.hitCooldown = 0.5;
        }
        pushOutCircle(player.pos, car.pos, minD);
      }
    }
  }

  /* ------------------------------------------------------------------------
     Münzen einsammeln
     ------------------------------------------------------------------------ */
  function updateCoins() {
    for (let i = 0; i < coins.length; i++) {
      const c = coins[i];
      if (c.collected) continue;
      if (dist2D(player.pos.x, player.pos.z, c.pos.x, c.pos.z) < CAR_RADIUS + COIN_PICKUP_RADIUS) {
        c.collected = true;
        coinsCollected++;
        bonusScore += COIN_SCORE;
        SFX.coin();
        spawnParticles(c.pos.x, c.pos.z, '#ffd75e', 6);
        if (!allCoinsBonusGiven && coinsCollected === coins.length) {
          allCoinsBonusGiven = true;
          bonusScore += ALL_COINS_BONUS;
          toast('Alle Münzen eingesammelt! Bonus: +' + ALL_COINS_BONUS, 'gold');
        }
      }
    }
  }

  // Sanfter roter Vignette-Flash bei kritischer Gesundheit — reine
  // Rückmeldung, kein zusätzlicher Schaden.
  function updateDamageFlash() {
    const low = clamp01((30 - player.health) / 30);
    dom['damage-flash'].style.opacity = String(low * (0.35 + 0.25 * Math.abs(Math.sin(gameTime * 5))));
  }

  /* ------------------------------------------------------------------------
     Beinahe-Unfall-Bonus: knapp und schnell an einem Fußgänger vorbei, ohne
     ihn zu treffen — pro Fußgänger mit Cooldown.
     ------------------------------------------------------------------------ */
  function checkNearMisses() {
    if (Math.abs(player.speed) < NEAR_MISS_MIN_SPEED) return;
    for (let i = 0; i < pedestrians.length; i++) {
      const ped = pedestrians[i];
      if (!ped.alive) continue;
      const d = dist2D(player.pos.x, player.pos.z, ped.pos.x, ped.pos.z);
      if (d >= NEAR_MISS_MIN_GAP && d < NEAR_MISS_MAX_GAP && (gameTime - ped.lastNearMissAt) > NEAR_MISS_COOLDOWN) {
        ped.lastNearMissAt = gameTime;
        bonusScore += NEAR_MISS_SCORE;
        toast('Knapp vorbei! +' + NEAR_MISS_SCORE, 'good');
        SFX.nearMiss();
      }
    }
  }

  /* ------------------------------------------------------------------------
     Tag/Nacht-Zyklus: reine Zahlenwerte (Himmel-/Boden-Farbmischung,
     Laternen-Helligkeit), die renderScene() beim Zeichnen liest.
     ------------------------------------------------------------------------ */
  let skyColorCss = '#8ab7d6';
  let groundColorCss = '#c9c2ae';
  let lampGlowAlpha = 0;
  function updateDayNight(dt) {
    dayTime = (dayTime + dt) % DAY_LENGTH;
    const t = dayTime / DAY_LENGTH;
    dayFactor = (Math.cos(t * Math.PI * 2) + 1) / 2; // 1 = Mittag, 0 = Mitternacht
    skyColorCss = lerpRgb(SKY_NIGHT, SKY_DAY, dayFactor);
    groundColorCss = lerpRgb(GROUND_NIGHT, GROUND_DAY, dayFactor);
    lampGlowAlpha = clamp01((0.55 - dayFactor) / 0.55);
  }

  /* ------------------------------------------------------------------------
     2D-Top-Down-Rendering: feste Nordausrichtung, die Kamera folgt nur der
     Spielerposition (keine Rotation) — wie eine echte Straßenkarte, die
     unter dem Auto mitwandert.
     ------------------------------------------------------------------------ */
  function toScreen(wx, wz) {
    return { x: viewW / 2 + (wx - player.pos.x) * SCALE, y: viewH / 2 + (wz - player.pos.z) * SCALE };
  }
  function viewRadiusWorld() {
    return Math.hypot(viewW, viewH) / 2 / SCALE + 25;
  }
  function nearPlayer(x, z, margin) {
    return dist2D(x, z, player.pos.x, player.pos.z) < viewRadiusWorld() + (margin || 0);
  }

  function drawStreetGrid() {
    const vr = viewRadiusWorld();
    const kMin = Math.floor((player.pos.x - vr + GRID_HALF) / GRID_PERIOD) - 1;
    const kMax = Math.ceil((player.pos.x + vr + GRID_HALF) / GRID_PERIOD) + 1;
    const jMin = Math.floor((player.pos.z - vr + GRID_HALF) / GRID_PERIOD) - 1;
    const jMax = Math.ceil((player.pos.z + vr + GRID_HALF) / GRID_PERIOD) + 1;
    const halfPx = (STREET_WIDTH / 2) * SCALE;

    ctx.fillStyle = '#33383f';
    for (let k = kMin; k <= kMax; k++) {
      const lineX = -GRID_HALF + k * GRID_PERIOD;
      const sx = toScreen(lineX, 0).x;
      ctx.fillRect(sx - halfPx, 0, halfPx * 2, viewH);
    }
    for (let k = jMin; k <= jMax; k++) {
      const lineZ = -GRID_HALF + k * GRID_PERIOD;
      const sy = toScreen(0, lineZ).y;
      ctx.fillRect(0, sy - halfPx, viewW, halfPx * 2);
    }

    // Gestrichelte Mittellinien.
    ctx.save();
    ctx.strokeStyle = '#e7c25a';
    ctx.lineWidth = Math.max(1, 0.3 * SCALE);
    ctx.setLineDash([0.9 * SCALE, 0.9 * SCALE]);
    for (let k = kMin; k <= kMax; k++) {
      const lineX = -GRID_HALF + k * GRID_PERIOD;
      const sx = toScreen(lineX, 0).x;
      ctx.beginPath(); ctx.moveTo(sx, 0); ctx.lineTo(sx, viewH); ctx.stroke();
    }
    for (let k = jMin; k <= jMax; k++) {
      const lineZ = -GRID_HALF + k * GRID_PERIOD;
      const sy = toScreen(0, lineZ).y;
      ctx.beginPath(); ctx.moveTo(0, sy); ctx.lineTo(viewW, sy); ctx.stroke();
    }
    ctx.restore();
  }

  function drawParks() {
    ctx.fillStyle = '#4f7a45';
    for (let i = 0; i < world.parks.length; i++) {
      const p = world.parks[i];
      const c = { x: (p.rect.minX + p.rect.maxX) / 2, z: (p.rect.minZ + p.rect.maxZ) / 2 };
      if (!nearPlayer(c.x, c.z, BLOCK_SIZE)) continue;
      const tl = toScreen(p.rect.minX, p.rect.minZ), br = toScreen(p.rect.maxX, p.rect.maxZ);
      ctx.fillRect(tl.x, tl.y, br.x - tl.x, br.y - tl.y);
      ctx.fillStyle = '#385c31';
      for (let t = 0; t < p.trees.length; t++) {
        const s = toScreen(p.trees[t].x, p.trees[t].z);
        ctx.beginPath(); ctx.arc(s.x, s.y, Math.max(2, 0.9 * SCALE), 0, Math.PI * 2); ctx.fill();
      }
      ctx.fillStyle = '#4f7a45';
    }
  }

  function drawBuildings() {
    for (let i = 0; i < world.buildings.length; i++) {
      const b = world.buildings[i];
      const c = { x: (b.rect.minX + b.rect.maxX) / 2, z: (b.rect.minZ + b.rect.maxZ) / 2 };
      if (!nearPlayer(c.x, c.z, BLOCK_SIZE)) continue;
      const tl = toScreen(b.rect.minX, b.rect.minZ), br = toScreen(b.rect.maxX, b.rect.maxZ);
      const w = br.x - tl.x, h = br.y - tl.y;
      const shadowPx = clamp(b.height / 6, 2, 9);

      ctx.fillStyle = 'rgba(0,0,0,0.28)';
      ctx.fillRect(tl.x + shadowPx, tl.y + shadowPx, w, h);

      ctx.fillStyle = css(b.color);
      ctx.fillRect(tl.x, tl.y, w, h);
      ctx.strokeStyle = 'rgba(0,0,0,0.35)';
      ctx.lineWidth = 1;
      ctx.strokeRect(tl.x + 0.5, tl.y + 0.5, w - 1, h - 1);

      // Helleres "Dach"-Inset für etwas Tiefe.
      const inset = Math.min(w, h) * 0.14;
      if (w - inset * 2 > 3 && h - inset * 2 > 3) {
        ctx.fillStyle = 'rgba(255,255,255,0.08)';
        ctx.fillRect(tl.x + inset, tl.y + inset, w - inset * 2, h - inset * 2);
      }
    }
  }

  function drawLamps() {
    if (lampGlowAlpha <= 0.02) return;
    for (let i = 0; i < world.lamps.length; i++) {
      const l = world.lamps[i];
      if (!nearPlayer(l.x, l.z, 6)) continue;
      const s = toScreen(l.x, l.z);
      const r = 3.2 * SCALE * 0.12;
      const grad = ctx.createRadialGradient(s.x, s.y, 0, s.x, s.y, r * 3.5);
      grad.addColorStop(0, 'rgba(255,214,140,' + (0.55 * lampGlowAlpha) + ')');
      grad.addColorStop(1, 'rgba(255,214,140,0)');
      ctx.fillStyle = grad;
      ctx.beginPath(); ctx.arc(s.x, s.y, r * 3.5, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = 'rgba(255,224,160,' + lampGlowAlpha + ')';
      ctx.beginPath(); ctx.arc(s.x, s.y, r, 0, Math.PI * 2); ctx.fill();
    }
  }

  function drawTrafficLights() {
    for (let i = 0; i < trafficLights.length; i++) {
      const tl = trafficLights[i];
      if (!nearPlayer(tl.x, tl.z, 4)) continue;
      const s = toScreen(tl.x, tl.z);
      const cycle = (gameTime + tl.phase) % TRAFFIC_LIGHT_CYCLE;
      const green = cycle < TRAFFIC_LIGHT_GREEN;
      ctx.fillStyle = '#20242a';
      ctx.fillRect(s.x - 2, s.y - 2, 4, 4);
      ctx.fillStyle = green ? '#3ecb6a' : '#e6544c';
      ctx.beginPath(); ctx.arc(s.x, s.y - 4, 2.6, 0, Math.PI * 2); ctx.fill();
    }
  }

  function drawCoins() {
    for (let i = 0; i < coins.length; i++) {
      const c = coins[i];
      if (c.collected || !nearPlayer(c.pos.x, c.pos.z, 3)) continue;
      const s = toScreen(c.pos.x, c.pos.z);
      const r = (0.45 + 0.06 * Math.sin(gameTime * 4 + i)) * SCALE * 0.55;
      ctx.fillStyle = '#ffd75e';
      ctx.beginPath(); ctx.arc(s.x, s.y, r, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#a3781f';
      ctx.lineWidth = 1;
      ctx.stroke();
      ctx.fillStyle = 'rgba(255,255,255,0.55)';
      ctx.beginPath(); ctx.arc(s.x - r * 0.3, s.y - r * 0.3, r * 0.35, 0, Math.PI * 2); ctx.fill();
    }
  }

  function drawCar2D(wx, wz, heading, bodyHex, cabinHex, isPolice) {
    const s = toScreen(wx, wz);
    const w = CAR_RADIUS * 1.5 * SCALE, len = CAR_RADIUS * 2.6 * SCALE;
    ctx.save();
    ctx.translate(s.x, s.y);
    ctx.rotate(heading);
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    roundRectPath(-w / 2 + 1.5, -len / 2 + 2, w, len, w * 0.3);
    ctx.fill();
    ctx.fillStyle = css(bodyHex);
    roundRectPath(-w / 2, -len / 2, w, len, w * 0.3);
    ctx.fill();
    ctx.fillStyle = css(cabinHex);
    roundRectPath(-w * 0.35, -len * 0.12, w * 0.7, len * 0.5, w * 0.2);
    ctx.fill();
    if (isPolice) {
      const on = Math.floor(gameTime / 0.3) % 2 === 0;
      ctx.fillStyle = on ? '#ff3b3b' : '#3b6bff';
      ctx.fillRect(-w * 0.22, -len / 2 - 3, w * 0.44, 3);
    }
    ctx.restore();
  }

  function drawPedestrians() {
    for (let i = 0; i < pedestrians.length; i++) {
      const ped = pedestrians[i];
      if (!ped.alive && ped.deathT >= 1) continue;
      if (!nearPlayer(ped.pos.x, ped.pos.z, 4)) continue;
      const s = toScreen(ped.pos.x, ped.pos.z);
      const shrink = ped.alive ? 1 : (1 - ped.deathT);
      const r = PED_RADIUS * SCALE * shrink;
      if (r <= 0.2) continue;
      ctx.globalAlpha = ped.alive ? 1 : shrink;
      ctx.fillStyle = 'hsl(' + ped.hue + ',45%,55%)';
      ctx.beginPath(); ctx.arc(s.x, s.y, r, 0, Math.PI * 2); ctx.fill();
      if (ped.alive) {
        const hx = s.x + Math.sin(ped.heading) * r * 0.5, hy = s.y + Math.cos(ped.heading) * r * 0.5;
        ctx.fillStyle = '#e8c39e';
        ctx.beginPath(); ctx.arc(hx, hy, r * 0.45, 0, Math.PI * 2); ctx.fill();
      }
      ctx.globalAlpha = 1;
    }
  }

  function drawParticles() {
    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];
      const s = toScreen(p.x, p.z);
      const a = clamp01(p.life / p.maxLife);
      ctx.globalAlpha = a;
      ctx.fillStyle = p.color;
      ctx.beginPath(); ctx.arc(s.x, s.y, Math.max(1, 2.5 * a), 0, Math.PI * 2); ctx.fill();
      ctx.globalAlpha = 1;
    }
  }

  function renderScene() {
    ctx.fillStyle = skyColorCss;
    ctx.fillRect(0, 0, viewW, viewH);

    const groundTL = toScreen(-WORLD_HALF_EXTENT, -WORLD_HALF_EXTENT);
    const groundBR = toScreen(WORLD_HALF_EXTENT, WORLD_HALF_EXTENT);
    ctx.fillStyle = groundColorCss;
    ctx.fillRect(groundTL.x, groundTL.y, groundBR.x - groundTL.x, groundBR.y - groundTL.y);

    ctx.save();
    ctx.beginPath();
    ctx.rect(groundTL.x, groundTL.y, groundBR.x - groundTL.x, groundBR.y - groundTL.y);
    ctx.clip();
    drawParks();
    drawStreetGrid();
    drawBuildings();
    if (1 - dayFactor > 0.02) {
      ctx.fillStyle = 'rgba(6,8,16,' + (0.55 * (1 - dayFactor)) + ')';
      ctx.fillRect(groundTL.x, groundTL.y, groundBR.x - groundTL.x, groundBR.y - groundTL.y);
    }
    drawLamps();
    drawTrafficLights();
    drawCoins();
    ctx.restore();

    drawPedestrians();
    for (let i = 0; i < trafficCars.length; i++) {
      const c = trafficCars[i];
      if (nearPlayer(c.pos.x, c.pos.z, 4)) drawCar2D(c.pos.x, c.pos.z, c.heading, c.bodyColor, c.cabinColor, false);
    }
    for (let i = 0; i < policeCars.length; i++) {
      const p = policeCars[i];
      if (nearPlayer(p.pos.x, p.pos.z, 4)) drawCar2D(p.pos.x, p.pos.z, p.heading, POLICE_BODY, POLICE_CABIN, true);
    }
    const carColor = CAR_COLORS[selectedCarColorIndex] || CAR_COLORS[0];
    drawCar2D(player.pos.x, player.pos.z, player.heading, carColor.body, carColor.cabin, false);
    drawParticles();
  }

  /* ------------------------------------------------------------------------
     Minimap (nordorientiert, Rasterlinien + Punkte + rotierendes
     Spieler-Dreieck) — eigener, weiter herausgezoomter Überblick zusätzlich
     zur großen Hauptansicht.
     ------------------------------------------------------------------------ */
  function drawMinimap() {
    const canvas = dom.minimap;
    const mctx = canvas.getContext('2d');
    const W = canvas.width, H = canvas.height;
    mctx.clearRect(0, 0, W, H);
    const viewRadius = 55;
    const scale = (Math.min(W, H) / 2 - 4) / viewRadius;
    const cx = W / 2, cz = H / 2;
    function toMap(wx, wz) {
      return { x: cx + (wx - player.pos.x) * scale, y: cz + (wz - player.pos.z) * scale };
    }
    mctx.strokeStyle = 'rgba(255,255,255,0.14)';
    mctx.lineWidth = 1;
    const kMin = Math.floor((player.pos.x - viewRadius + GRID_HALF) / GRID_PERIOD) - 1;
    const kMax = Math.ceil((player.pos.x + viewRadius + GRID_HALF) / GRID_PERIOD) + 1;
    for (let k = kMin; k <= kMax; k++) {
      const lineX = -GRID_HALF + k * GRID_PERIOD;
      const p1 = toMap(lineX, player.pos.z - viewRadius);
      const p2 = toMap(lineX, player.pos.z + viewRadius);
      mctx.beginPath(); mctx.moveTo(p1.x, p1.y); mctx.lineTo(p2.x, p2.y); mctx.stroke();
    }
    const jMin = Math.floor((player.pos.z - viewRadius + GRID_HALF) / GRID_PERIOD) - 1;
    const jMax = Math.ceil((player.pos.z + viewRadius + GRID_HALF) / GRID_PERIOD) + 1;
    for (let k = jMin; k <= jMax; k++) {
      const lineZ = -GRID_HALF + k * GRID_PERIOD;
      const p1 = toMap(player.pos.x - viewRadius, lineZ);
      const p2 = toMap(player.pos.x + viewRadius, lineZ);
      mctx.beginPath(); mctx.moveTo(p1.x, p1.y); mctx.lineTo(p2.x, p2.y); mctx.stroke();
    }
    function dot(wx, wz, color, r) {
      const d = dist2D(wx, wz, player.pos.x, player.pos.z);
      if (d > viewRadius) return;
      const p = toMap(wx, wz);
      mctx.fillStyle = color;
      mctx.beginPath(); mctx.arc(p.x, p.y, r, 0, Math.PI * 2); mctx.fill();
    }
    for (let i = 0; i < pedestrians.length; i++) {
      if (pedestrians[i].alive) dot(pedestrians[i].pos.x, pedestrians[i].pos.z, 'rgba(232,232,232,0.85)', 2);
    }
    for (let i = 0; i < trafficCars.length; i++) dot(trafficCars[i].pos.x, trafficCars[i].pos.z, '#e0b93c', 2.5);
    const policeColor = Math.floor(gameTime / 0.3) % 2 === 0 ? '#ff3b3b' : '#3b6bff';
    for (let i = 0; i < policeCars.length; i++) dot(policeCars[i].pos.x, policeCars[i].pos.z, policeColor, 3);

    mctx.save();
    mctx.translate(cx, cz);
    mctx.rotate(player.heading);
    mctx.fillStyle = '#f2a93a';
    mctx.beginPath();
    mctx.moveTo(0, -6); mctx.lineTo(4, 5); mctx.lineTo(-4, 5); mctx.closePath();
    mctx.fill();
    mctx.restore();
  }

  function updateHud() {
    dom.speed.textContent = String(Math.round(Math.abs(player.speed) * 3.6));
    const stars = Math.round(wantedHeat);
    dom.wantedStars.forEach((el, i) => { el.classList.toggle('active', i < stars); });
    dom['bar-health'].style.width = player.health + '%';
    dom.score.textContent = String(currentScore());
    dom.coins.textContent = String(coinsCollected);
    dom['daytime-icon'].textContent = dayFactor > 0.5 ? '☀️' : '🌙';
    dom['daytime-text'].textContent = dayFactor > 0.5 ? 'Tag' : 'Nacht';
    drawMinimap();
  }
  function currentScore() {
    return Math.floor(distanceDriven) + 50 * Math.floor(wantedSecondsAccum) + bonusScore;
  }

  function endRun(source) {
    if (ended) return;
    ended = true;
    running = false;
    const title = source === 'police' ? 'Busted!' : 'Wasted!';
    dom['overlay-title'].textContent = title;
    const finalScore = currentScore();
    const best = saveHighscoreIfBetter(finalScore);
    dom['overlay-stats'].innerHTML =
      'Strecke: ' + Math.floor(distanceDriven) + ' m<br>' +
      'Münzen: ' + coinsCollected + '/' + coins.length + '<br>' +
      'Zeit gesucht: ' + Math.floor(wantedSecondsAccum) + ' s<br>' +
      'Höchste Fahndungsstufe: ' + Math.round(maxWantedReached) + '<br>' +
      'Punkte: ' + finalScore + ' (Highscore: ' + best + ')';
    dom.overlay.classList.remove('hidden');
    dom['lobby-highscore'].textContent = String(best);
    SFX.busted();
  }

  /* ------------------------------------------------------------------------
     Spieler & Lauf-Zustand
     ------------------------------------------------------------------------ */
  const SPAWN = { x: -GRID_HALF + Math.floor(GRID_N / 2) * GRID_PERIOD, z: 0 };

  function createPlayer() {
    const state = createCarState(SPAWN.x, SPAWN.z, 0);
    state.maxSpeed = MAX_SPEED_FORWARD;
    return Object.assign(state, { health: 100, hitCooldown: 0, lastDamageSource: null });
  }

  function resetRunState() {
    pedestrians = [];
    trafficCars = [];
    policeCars = [];
    particles = [];

    player = createPlayer();

    for (let i = 0; i < density.pedCount; i++) spawnPedestrian();
    for (let i = 0; i < density.trafficCount; i++) spawnTrafficCar();

    // Münzen bleiben Teil der einmalig gebauten Welt — bei einem neuen Lauf
    // wird nur ihr "eingesammelt"-Status zurückgesetzt.
    coins.forEach((c) => { c.collected = false; });
    dom['coins-total'].textContent = String(coins.length);

    wantedHeat = 0;
    maxWantedReached = 0;
    vehicleHitTimestamps = [];
    timeSinceLastPoliceContact = 0;
    distanceDriven = 0;
    wantedSecondsAccum = 0;
    bonusScore = 0;
    coinsCollected = 0;
    allCoinsBonusGiven = false;
    firstWantedShown = false;
    nextDistanceMilestone = 1000;
    dayTime = DAY_LENGTH * 0.05;
    gameTime = 0;
    ended = false;
    dom['damage-flash'].style.opacity = '0';
  }

  /* ------------------------------------------------------------------------
     Eingabe: Tastatur + Touch (Lenkrad-Buttons + Gas-/Bremspedal-Buttons)
     ------------------------------------------------------------------------ */
  const keys = Object.create(null);
  let touchSteer = 0;
  let touchGas = false;
  let touchBrake = false;

  function wireTouchButton(el, onDown, onUp) {
    if (!el) return;
    el.addEventListener('pointerdown', (e) => { e.preventDefault(); onDown(); });
    el.addEventListener('pointerup', onUp);
    el.addEventListener('pointercancel', onUp);
    el.addEventListener('pointerleave', onUp);
  }
  function wireInput() {
    window.addEventListener('keydown', (e) => { keys[e.code] = true; });
    window.addEventListener('keyup', (e) => { keys[e.code] = false; });
    wireTouchButton(dom['steer-left'], () => { touchSteer = -1; }, () => { if (touchSteer === -1) touchSteer = 0; });
    wireTouchButton(dom['steer-right'], () => { touchSteer = 1; }, () => { if (touchSteer === 1) touchSteer = 0; });
    wireTouchButton(dom['pedal-gas'], () => { touchGas = true; }, () => { touchGas = false; });
    wireTouchButton(dom['pedal-brake'], () => { touchBrake = true; }, () => { touchBrake = false; });
  }

  function wireLobby() {
    dom.optionGroups.forEach((group) => {
      const btns = group.querySelectorAll('.option-btn');
      const option = group.dataset.option;
      btns.forEach((btn) => {
        btn.addEventListener('click', () => {
          btns.forEach((b) => b.classList.remove('selected'));
          btn.classList.add('selected');
          if (option === 'carcolor') selectedCarColorIndex = Number(btn.dataset.value);
          else selectedDensity = btn.dataset.value;
        });
      });
    });
    dom['start-btn'].addEventListener('click', () => {
      SFX.ensure(); SFX.resume();
      density = DENSITY_PRESETS[selectedDensity] || DENSITY_PRESETS.normal;
      dom.lobby.classList.add('hidden');
      dom.game.classList.remove('hidden');
      dom.overlay.classList.add('hidden');
      resetRunState();
      running = true;
      onResize();
    });
    dom['restart-btn'].addEventListener('click', () => {
      dom.overlay.classList.add('hidden');
      resetRunState();
      running = true;
    });
    dom['lobby-btn'].addEventListener('click', () => {
      running = false;
      dom.overlay.classList.add('hidden');
      dom.game.classList.add('hidden');
      dom.lobby.classList.remove('hidden');
      dom['lobby-highscore'].textContent = String(loadHighscore());
    });
  }

  /* ------------------------------------------------------------------------
     Game-Loop
     ------------------------------------------------------------------------ */
  let lastTime = 0;
  function gameLoop(t) {
    requestAnimationFrame(gameLoop);
    if (!lastTime) lastTime = t;
    let dt = (t - lastTime) / 1000;
    lastTime = t;
    dt = Math.min(dt, 0.05);

    if (running && !ended) {
      gameTime += dt;

      const steerInput = clamp(
        (keys.KeyA || keys.ArrowLeft ? -1 : 0) + (keys.KeyD || keys.ArrowRight ? 1 : 0) + touchSteer, -1, 1
      );
      const throttle = !!(keys.KeyW || keys.ArrowUp || touchGas);
      const brake = !!(keys.KeyS || keys.ArrowDown || touchBrake);

      integrateCarPhysics(player, throttle, brake, steerInput, dt);
      const hitWorld = resolveWorldCollisions(player);
      if (hitWorld) {
        if (player.hitCooldown <= 0) {
          applyDamage(Math.max(2, Math.abs(player.speed) * 1.2), 'crash');
          SFX.crash();
          spawnParticles(player.pos.x, player.pos.z, '#aaaaaa', 6);
          player.hitCooldown = 0.4;
        }
        player.speed *= 0.3;
      }
      player.hitCooldown = Math.max(0, player.hitCooldown - dt);

      pedestrians.forEach((p) => updatePedestrian(p, dt));
      trafficCars.forEach((c) => updateTrafficCar(c, dt));
      for (let i = policeCars.length - 1; i >= 0; i--) updatePoliceCar(policeCars[i], dt);

      if (!ended) checkPlayerVsPedestrians();
      if (!ended) checkPlayerVsTraffic();
      if (!ended) checkPlayerVsPolice();
      if (!ended) checkNearMisses();
      if (!ended) maintainPolice(dt);

      if (!ended && wantedHeat <= 0 && player.hitCooldown <= 0) {
        player.health = clamp(player.health + HEALTH_REGEN * dt, 0, 100);
      }

      distanceDriven += Math.abs(player.speed) * dt;
      if (wantedHeat >= 1) wantedSecondsAccum += dt;
      if (distanceDriven >= nextDistanceMilestone) {
        toast(nextDistanceMilestone + ' m gefahren!', 'good');
        nextDistanceMilestone += 1000;
      }

      updateCoins();
      updateDayNight(dt);
      updateDamageFlash();
      updateParticles(dt);
      updateHud();
    }

    if (player && ctx) renderScene();
  }

  /* ------------------------------------------------------------------------
     Init
     ------------------------------------------------------------------------ */
  function init() {
    cacheDom();
    dom['lobby-highscore'].textContent = String(loadHighscore());
    initCanvas();
    buildWorld();
    wireLobby();
    wireInput();
    requestAnimationFrame(gameLoop);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
