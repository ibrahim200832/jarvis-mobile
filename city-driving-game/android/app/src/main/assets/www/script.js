/* ============================================================================
   HEAT STREETS — offene Stadt zum Fahren, mit NPCs & Fahndungsstufe
   Reines Vanilla-JS + Three.js (r15x UMD-Build), keine externen Assets außer
   dem vendored three.min.js. Läuft als Web-Seite und im Android-WebView-Wrapper.

   Vereinfachungen (bewusst, damit das Spiel in einem Zug baubar bleibt):
   - Kein Aussteigen aus dem Auto, kein Zufußgehen.
   - Verkehrsautos fahren feste Rechteck-Umläufe um je einen Block (kein
     Pathfinding, kein Spurwechsel) und kollidieren nicht untereinander,
     sondern regeln nur Tempo über eine 1D-Abstandsregel entlang der Route.
   - Polizei verfolgt den Spieler direkt (kein Vorhalten/Interception).
   - Autos sind als Kollisionskreis modelliert, Gebäude/Weltgrenze als
     achsenparallele Rechtecke — keine rotierten Boxen nötig, da das
     komplette Stadtraster achsenparallel ist.
   ========================================================================== */
(function () {
  'use strict';

  /* ------------------------------------------------------------------------
     Konstanten: Stadtraster
     ------------------------------------------------------------------------ */
  const GRID_N = 7;                          // 7x7 Blocks
  const LANE_WIDTH = 3.2;                    // wie racing-game
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
  const BUILDING_COLORS = [0x3a4550, 0x46525e, 0x39424c, 0x515c68, 0x2f3841, 0x445062];

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
  const CAMERA_HEIGHT = 4.2;
  const CAMERA_BACK = 7.5;
  const LOOKAHEAD = 14;

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
  function lerpAngle(a, b, t) {
    let diff = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
    if (diff < -Math.PI) diff += Math.PI * 2;
    return a + diff * t;
  }
  function angleDiff(a, b) {
    let d = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
    if (d < -Math.PI) d += Math.PI * 2;
    return d;
  }
  function dist2D(ax, az, bx, bz) { return Math.hypot(ax - bx, az - bz); }
  function pick(arr, rand) { return arr[Math.floor(rand() * arr.length) % arr.length]; }

  // Deterministischer PRNG (mulberry32) — 1:1 aus adventure-game übernommen,
  // damit die Stadt bei jedem Start identisch generiert wird.
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
  // pushOutRect drückt eine Kreis-Position aus einem Rechteck heraus, falls sie
  // näher als r am Rechteck liegt — Closest-Point-Clamp-Idee, analog zu
  // adventure-games distToSegment/pointInLocalBox, nur für Rechtecke statt
  // Liniensegmente/rotierte Boxen (hier reicht achsenparallel, da das ganze
  // Stadtraster nicht rotiert ist).
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
  // Kreis-Kreis-Trennung — 1:1 die Idee von adventure-games pushOutCircle.
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
     Highscore (localStorage) — gleiches Muster wie racing-game
     ------------------------------------------------------------------------ */
  function loadHighscore() { return Number(localStorage.getItem(HIGHSCORE_KEY) || 0); }
  function saveHighscoreIfBetter(value) {
    const current = loadHighscore();
    if (value > current) localStorage.setItem(HIGHSCORE_KEY, String(value));
    return Math.max(current, value);
  }

  /* ------------------------------------------------------------------------
     Prozedurales WebAudio (keine Audio-Dateien) — Primitive nach adventure-
     games SFX-Objekt-Muster
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
    siren() { this._tone(700, 0.18, 'sine', 0.08, 1000); },
    heatUp() { this._tone(220, 0.18, 'sawtooth', 0.22, 440); },
    heatDown() { this._tone(440, 0.18, 'sine', 0.15, 220); },
    busted() { this._tone(300, 0.5, 'sawtooth', 0.25, 60); },
  };

  /* ------------------------------------------------------------------------
     DOM-Referenzen
     ------------------------------------------------------------------------ */
  let dom = {};
  function cacheDom() {
    const ids = [
      'lobby', 'game', 'start-btn', 'lobby-highscore',
      'stage', 'hud', 'wanted-row', 'bar-health', 'minimap',
      'speed', 'score', 'toast-stack',
      'steer-left', 'steer-right', 'pedal-gas', 'pedal-brake',
      'overlay', 'overlay-title', 'overlay-stats', 'restart-btn', 'lobby-btn',
    ];
    ids.forEach((id) => { dom[id] = document.getElementById(id); });
    dom.wantedStars = Array.prototype.slice.call(document.querySelectorAll('.wanted-star'));
    dom.optionGroups = document.querySelectorAll('.option-buttons');
  }

  /* ------------------------------------------------------------------------
     Three.js Grundgerüst
     ------------------------------------------------------------------------ */
  let renderer, scene, camera;

  function initThree() {
    renderer = new THREE.WebGLRenderer({ canvas: dom.stage, antialias: true, powerPreference: 'high-performance' });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(window.innerWidth, window.innerHeight);
    if ('outputColorSpace' in renderer) renderer.outputColorSpace = THREE.SRGBColorSpace;
    scene = new THREE.Scene();
    scene.fog = new THREE.Fog(0x0d1119, 70, 240);
    scene.background = new THREE.Color(0x0d1119);
    camera = new THREE.PerspectiveCamera(64, window.innerWidth / window.innerHeight, 0.1, 400);

    const hemi = new THREE.HemisphereLight(0x8fa8c9, 0x1a1f26, 1.0);
    scene.add(hemi);
    const sun = new THREE.DirectionalLight(0xfff3d8, 0.9);
    sun.position.set(60, 90, 40);
    scene.add(sun);

    window.addEventListener('resize', onResize);
    onResize();
  }
  function onResize() {
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }

  /* ------------------------------------------------------------------------
     Fahrbahntextur — Idee aus racing-games buildRoadTexture(), als
     wiederholbare Textur für die Straßen-Streifen des Stadtrasters statt für
     eine einzelne Endlos-Spur.
     ------------------------------------------------------------------------ */
  function buildRoadTexture() {
    const canvas = document.createElement('canvas');
    canvas.width = 64; canvas.height = 64;
    const g = canvas.getContext('2d');
    g.fillStyle = '#2a2f36';
    g.fillRect(0, 0, 64, 64);
    g.fillStyle = '#e7c25a';
    g.fillRect(28, 4, 8, 24);
    g.fillRect(28, 36, 8, 24);
    const tex = new THREE.CanvasTexture(canvas);
    tex.wrapS = THREE.RepeatWrapping;
    tex.wrapT = THREE.RepeatWrapping;
    return tex;
  }

  /* ------------------------------------------------------------------------
     Stadt-Welt: deterministisch aus worldRand() aufgebaut.
     Straßen sind einfach die Rasterlinien alle GRID_PERIOD Einheiten; jeder
     Block zwischen ihnen ist entweder Park (begehbar, keine Kollision) oder
     Gebäude (Box-Mesh, um SIDEWALK_WIDTH von den Blockkanten eingerückt).
     Der verbleibende Ring dazwischen ist der Gehweg (Fußgänger-Wegpunkte).
     ------------------------------------------------------------------------ */
  const world = {
    buildingRects: [],
    blockLoops: [],      // { rect, dir } — ein Rechteck-Umlauf pro Block, für Verkehr
    pedWaypointLoops: [], // Array von Punktlisten (im Uhrzeigersinn) je Block
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
    const group = new THREE.Group();

    // Basis-Boden (Gehweg/Erde-Farbton), deckt die ganze Welt ab.
    const groundGeo = new THREE.PlaneGeometry((WORLD_HALF_EXTENT + 10) * 2, (WORLD_HALF_EXTENT + 10) * 2);
    const groundMat = new THREE.MeshLambertMaterial({ color: 0x333c47 });
    const ground = new THREE.Mesh(groundGeo, groundMat);
    ground.rotation.x = -Math.PI / 2;
    ground.position.y = 0;
    group.add(ground);

    const roadTex = buildRoadTexture();

    // Straßen-Streifen: GRID_N+1 Linien in jede Richtung.
    const streetLen = GRID_N * GRID_PERIOD + WORLD_MARGIN;
    for (let k = 0; k <= GRID_N; k++) {
      const centerX = -GRID_HALF + k * GRID_PERIOD;
      const texV = roadTex.clone();
      texV.wrapS = THREE.RepeatWrapping; texV.wrapT = THREE.RepeatWrapping;
      texV.repeat.set(1, streetLen / 8);
      const stripV = new THREE.Mesh(
        new THREE.PlaneGeometry(STREET_WIDTH, streetLen),
        new THREE.MeshLambertMaterial({ map: texV })
      );
      stripV.rotation.x = -Math.PI / 2;
      stripV.position.set(centerX, 0.01, 0);
      group.add(stripV);

      const centerZ = centerX;
      const texH = roadTex.clone();
      texH.wrapS = THREE.RepeatWrapping; texH.wrapT = THREE.RepeatWrapping;
      texH.repeat.set(1, streetLen / 8);
      const stripH = new THREE.Mesh(
        new THREE.PlaneGeometry(STREET_WIDTH, streetLen),
        new THREE.MeshLambertMaterial({ map: texH })
      );
      stripH.rotation.x = -Math.PI / 2;
      stripH.rotation.z = Math.PI / 2;
      stripH.position.set(0, 0.012, centerZ);
      group.add(stripH);
    }

    // Blocks: Park oder Gebäude, plus Gehweg-Wegpunktschleife und
    // Verkehrs-Umlauf (Straßenmitte rund um den Block).
    for (let i = 0; i < GRID_N; i++) {
      const bx = blockRange(i);
      for (let j = 0; j < GRID_N; j++) {
        const bz = blockRange(j);
        const blockRect = { minX: bx.min, maxX: bx.max, minZ: bz.min, maxZ: bz.max };

        const isPark = worldRand() < PARK_BLOCK_CHANCE;
        if (isPark) {
          const parkPlane = new THREE.Mesh(
            new THREE.PlaneGeometry(BLOCK_SIZE, BLOCK_SIZE),
            new THREE.MeshLambertMaterial({ color: 0x3f6b3a })
          );
          parkPlane.rotation.x = -Math.PI / 2;
          parkPlane.position.set(bx.center, 0.008, bz.center);
          group.add(parkPlane);
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
          const mesh = new THREE.Mesh(
            new THREE.BoxGeometry(rect.maxX - rect.minX, height, rect.maxZ - rect.minZ),
            new THREE.MeshLambertMaterial({ color })
          );
          mesh.position.set((rect.minX + rect.maxX) / 2, height / 2, (rect.minZ + rect.maxZ) / 2);
          group.add(mesh);
          world.buildingRects.push(rect);
        }

        // Gehweg-Wegpunktschleife: Ring knapp innerhalb der Blockkante, in der
        // Mitte des Gehweg-Streifens (unabhängig davon ob Park oder Gebäude).
        const wpRect = {
          minX: bx.min + SIDEWALK_WIDTH / 2, maxX: bx.max - SIDEWALK_WIDTH / 2,
          minZ: bz.min + SIDEWALK_WIDTH / 2, maxZ: bz.max - SIDEWALK_WIDTH / 2,
        };
        world.pedWaypointLoops.push(rectPerimeterPoints(wpRect));

        // Verkehrs-Umlauf: Straßenmitte rund um diesen Block.
        const loopRect = {
          minX: bx.min - STREET_WIDTH / 2, maxX: bx.max + STREET_WIDTH / 2,
          minZ: bz.min - STREET_WIDTH / 2, maxZ: bz.max + STREET_WIDTH / 2,
        };
        world.blockLoops.push(loopRect);
      }
    }

    // Weltgrenze: Reihe aus Betonpollern.
    const barrierMat = new THREE.MeshLambertMaterial({ color: 0x8a8f96 });
    const barrierCount = 90;
    for (let i = 0; i < barrierCount; i++) {
      const t = (i / barrierCount) * Math.PI * 2;
      // Auf ein Rechteck statt Kreis projizieren, damit die Poller entlang
      // der quadratischen Weltgrenze liegen statt auf einem Kreisbogen.
      const cosT = Math.cos(t), sinT = Math.sin(t);
      const scale = WORLD_HALF_EXTENT / Math.max(Math.abs(cosT), Math.abs(sinT) || 0.0001);
      const px = cosT * scale, pz = sinT * scale;
      const barrier = new THREE.Mesh(new THREE.BoxGeometry(1.6, 1.4, 1.6), barrierMat);
      barrier.position.set(px, 0.7, pz);
      group.add(barrier);
    }

    scene.add(group);
  }

  /* ------------------------------------------------------------------------
     Auto-Mesh — 1:1 aus racing-games buildCarMesh() übernommen (Body-Box +
     Kabine-Box + 4 Zylinder-Räder); Polizeiautos bekommen zusätzlich einen
     Dachbalken, der abwechselnd rot/blau blinkt.
     ------------------------------------------------------------------------ */
  function buildCarMesh(bodyColor, cabinColor, withLightBar) {
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
    [[-0.85, 1.15], [0.85, 1.15], [-0.85, -1.15], [0.85, -1.15]].forEach(([x, z]) => {
      const wheel = new THREE.Mesh(wheelGeo, wheelMat);
      wheel.rotation.z = Math.PI / 2;
      wheel.position.set(x, wheelRadius, z);
      group.add(wheel);
    });

    let lightBar = null;
    if (withLightBar) {
      const barMat = new THREE.MeshBasicMaterial({ color: 0xff3b3b });
      lightBar = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.16, 0.3), barMat);
      lightBar.position.set(0, wheelRadius + 1.02, -0.2);
      group.add(lightBar);
    }

    return { group, lightBar };
  }

  /* ------------------------------------------------------------------------
     Auto-Physik — gemeinsamer Integrator für Spieler & Polizei (freie
     Position/Heading/Speed statt racing-games Spur-Snap).
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

  // Gebäude- und Weltgrenzen-Kollision für ein frei bewegliches Auto
  // (Spieler oder Polizei). Gibt true zurück, falls ein Aufprall passiert ist,
  // damit der Aufrufer Schaden/Tempo-Dämpfung anwenden kann.
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

  /* ------------------------------------------------------------------------
     Globaler Spielzustand
     ------------------------------------------------------------------------ */
  const TRAFFIC_COLORS = [
    [0xd9534f, 0x222222], [0x4c9fe6, 0x1a2733], [0xe0b93c, 0x2a2210],
    [0x7a8a99, 0x1c2229], [0x8a5fc9, 0x241833], [0x5fb87a, 0x172a1c],
  ];
  const POLICE_BODY = 0x1c2b44, POLICE_CABIN = 0x0d1420;
  const PLAYER_BODY = 0xf2a93a, PLAYER_CABIN = 0x2b1900;

  let player = null;       // { pos, heading, speed, maxSpeed, health, mesh, lastDamageSource, hitCooldown }
  let pedestrians = [];
  let trafficCars = [];
  let policeCars = [];
  let particles = [];
  let tweens = [];

  let wantedHeat = 0;
  let maxWantedReached = 0;
  let vehicleHitTimestamps = [];
  let timeSinceLastPoliceContact = 0;
  let distanceDriven = 0;
  let wantedSecondsAccum = 0;
  let gameTime = 0;
  let density = DENSITY_PRESETS.normal;
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

  // Kleiner Partikel-Burst (einfache Boxen mit Schwerkraft/Fade) für
  // Treffer/Crashes — bewusst minimal gehalten, kein Pooling nötig bei den
  // hier vorkommenden Stückzahlen.
  function spawnParticles(pos, color, count) {
    for (let i = 0; i < count; i++) {
      const mesh = new THREE.Mesh(
        new THREE.BoxGeometry(0.12, 0.12, 0.12),
        new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 1 })
      );
      const ang = Math.random() * Math.PI * 2;
      const spd = 2 + Math.random() * 3;
      mesh.position.set(pos.x, 0.6, pos.z);
      scene.add(mesh);
      particles.push({
        mesh,
        vel: { x: Math.cos(ang) * spd, y: 2 + Math.random() * 2.5, z: Math.sin(ang) * spd },
        life: 0.6 + Math.random() * 0.4,
        maxLife: 1,
      });
    }
  }
  function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.vel.y -= 9 * dt;
      p.mesh.position.x += p.vel.x * dt;
      p.mesh.position.y += p.vel.y * dt;
      p.mesh.position.z += p.vel.z * dt;
      p.life -= dt;
      p.mesh.material.opacity = clamp01(p.life / p.maxLife);
      if (p.life <= 0 || p.mesh.position.y < 0) {
        scene.remove(p.mesh);
        p.mesh.geometry.dispose(); p.mesh.material.dispose();
        particles.splice(i, 1);
      }
    }
  }
  function addTween(target, duration, onUpdate, onComplete) {
    tweens.push({ target, t: 0, duration, onUpdate, onComplete });
  }
  function updateTweens(dt) {
    for (let i = tweens.length - 1; i >= 0; i--) {
      const tw = tweens[i];
      tw.t += dt;
      const p = clamp01(tw.t / tw.duration);
      tw.onUpdate(p);
      if (p >= 1) {
        if (tw.onComplete) tw.onComplete();
        tweens.splice(i, 1);
      }
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
    const hue = Math.floor(worldRand() * 360);
    const color = new THREE.Color('hsl(' + hue + ', 45%, 55%)');
    const group = new THREE.Group();
    const torso = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.26, 0.9, 8), new THREE.MeshLambertMaterial({ color }));
    torso.position.y = 0.65;
    group.add(torso);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.18, 8, 8), new THREE.MeshLambertMaterial({ color: 0xe8c39e }));
    head.position.y = 1.22;
    group.add(head);
    group.position.set(start.x, 0, start.z);
    scene.add(group);
    const ped = {
      mesh: group, loopIndex, nodeIndex,
      dir: worldRand() < 0.5 ? 1 : -1,
      pos: { x: start.x, z: start.z },
      state: 'wander', fleeTimer: 0, fleeDir: { x: 0, z: 1 },
      alive: true, respawnAt: 0,
    };
    pedestrians.push(ped);
    return ped;
  }
  function updatePedestrian(ped, dt) {
    if (!ped.alive) {
      if (gameTime >= ped.respawnAt) {
        const loopIndex = Math.floor(worldRand() * world.pedWaypointLoops.length);
        const loop = world.pedWaypointLoops[loopIndex];
        const nodeIndex = Math.floor(worldRand() * loop.length);
        const start = loop[nodeIndex];
        ped.loopIndex = loopIndex; ped.nodeIndex = nodeIndex;
        ped.pos.x = start.x; ped.pos.z = start.z;
        ped.mesh.position.set(start.x, 0, start.z);
        ped.mesh.rotation.set(0, 0, 0);
        ped.mesh.scale.set(1, 1, 1);
        ped.mesh.visible = true;
        ped.state = 'wander'; ped.alive = true;
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
      }
    }
    ped.mesh.position.set(ped.pos.x, Math.sin(gameTime * 6 + ped.pos.x) * 0.03, ped.pos.z);
    if (distToPlayer < MIN_HIT_SPEED + 4) {
      ped.mesh.lookAt(player.pos.x, 0, player.pos.z);
    }
  }
  function killPedestrian(ped) {
    ped.alive = false;
    ped.respawnAt = gameTime + PED_RESPAWN_DELAY;
    spawnParticles(ped.pos, 0xe6544c, 8);
    SFX.hit();
    const startY = ped.mesh.position.y;
    addTween(ped, 0.4, (p) => {
      ped.mesh.rotation.x = p * Math.PI * 0.5;
      ped.mesh.position.y = startY - p * 0.6;
      ped.mesh.scale.setScalar(1 - p * 0.7);
    }, () => { ped.mesh.visible = false; });
  }

  /* ------------------------------------------------------------------------
     Verkehr (Ambient-KI: fester Rechteck-Umlauf je Block)
     ------------------------------------------------------------------------ */
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
  function spawnTrafficCar() {
    const loopIndex = Math.floor(worldRand() * world.blockLoops.length);
    const rect = world.blockLoops[loopIndex];
    const per = 2 * ((rect.maxX - rect.minX) + (rect.maxZ - rect.minZ));
    const [bodyColor, cabinColor] = pick(TRAFFIC_COLORS, worldRand);
    const { group } = buildCarMesh(bodyColor, cabinColor, false);
    scene.add(group);
    const car = {
      loopIndex, dir: worldRand() < 0.5 ? 1 : -1,
      progress: worldRand() * per,
      cruiseSpeed: lerp(TRAFFIC_SPEED_MIN, TRAFFIC_SPEED_MAX, worldRand()),
      speed: 0,
      pos: { x: 0, z: 0 }, heading: 0,
      mesh: group,
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
    car.mesh.position.set(car.pos.x, 0, car.pos.z);
    car.mesh.rotation.y = car.heading;
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
    const { group, lightBar } = buildCarMesh(POLICE_BODY, POLICE_CABIN, true);
    group.position.set(x, 0, z);
    scene.add(group);
    policeCars.push(Object.assign(state, { mesh: group, lightBar, stuckTimer: 0, lastCheckPos: { x, z } }));
  }
  function despawnPoliceCar(p) {
    scene.remove(p.mesh);
    const idx = policeCars.indexOf(p);
    if (idx !== -1) policeCars.splice(idx, 1);
  }
  function updatePoliceCar(p, dt) {
    const desiredHeading = Math.atan2(player.pos.x - p.pos.x, player.pos.z - p.pos.z);
    const steer = clamp(angleDiff(p.heading, desiredHeading) * 2, -1, 1);
    integrateCarPhysics(p, true, false, steer, dt);
    const hit = resolveWorldCollisions(p);
    if (hit) p.speed *= 0.5;
    p.mesh.position.set(p.pos.x, 0, p.pos.z);
    p.mesh.rotation.y = p.heading;
    if (p.lightBar) {
      p.lightBar.material.color.setHex(Math.floor(gameTime / 0.3) % 2 === 0 ? 0xff3b3b : 0x3b6bff);
    }
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
    if (wantedHeat > before) { SFX.heatUp(); toast('Fahndungsstufe erhöht!', 'bad'); }
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
  function checkPlayerVsTraffic(dt) {
    for (let i = 0; i < trafficCars.length; i++) {
      const car = trafficCars[i];
      const minD = CAR_RADIUS * 2;
      if (dist2D(player.pos.x, player.pos.z, car.pos.x, car.pos.z) < minD) {
        if (player.hitCooldown <= 0) {
          const impact = Math.abs(player.speed - car.speed);
          applyDamage(impact * 1.5, 'traffic');
          registerVehicleHit();
          SFX.crash();
          spawnParticles(player.pos, 0xffcf7a, 10);
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
          spawnParticles(player.pos, 0x4c9fe6, 10);
          player.speed *= 0.35;
          player.hitCooldown = 0.5;
        }
        pushOutCircle(player.pos, car.pos, minD);
      }
    }
  }

  /* ------------------------------------------------------------------------
     Minimap (nordorientiert, Rasterlinien + Punkte + rotierendes
     Spieler-Dreieck) — adaptiert von adventure-games drawMinimap()-Idee.
     ------------------------------------------------------------------------ */
  function drawMinimap() {
    const canvas = dom.minimap;
    const ctx = canvas.getContext('2d');
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);
    const viewRadius = 55;
    const scale = (Math.min(W, H) / 2 - 4) / viewRadius;
    const cx = W / 2, cz = H / 2;
    function toMap(wx, wz) {
      return { x: cx + (wx - player.pos.x) * scale, y: cz + (wz - player.pos.z) * scale };
    }
    ctx.strokeStyle = 'rgba(255,255,255,0.14)';
    ctx.lineWidth = 1;
    const kMin = Math.floor((player.pos.x - viewRadius + GRID_HALF) / GRID_PERIOD) - 1;
    const kMax = Math.ceil((player.pos.x + viewRadius + GRID_HALF) / GRID_PERIOD) + 1;
    for (let k = kMin; k <= kMax; k++) {
      const lineX = -GRID_HALF + k * GRID_PERIOD;
      const p1 = toMap(lineX, player.pos.z - viewRadius);
      const p2 = toMap(lineX, player.pos.z + viewRadius);
      ctx.beginPath(); ctx.moveTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.stroke();
    }
    const jMin = Math.floor((player.pos.z - viewRadius + GRID_HALF) / GRID_PERIOD) - 1;
    const jMax = Math.ceil((player.pos.z + viewRadius + GRID_HALF) / GRID_PERIOD) + 1;
    for (let k = jMin; k <= jMax; k++) {
      const lineZ = -GRID_HALF + k * GRID_PERIOD;
      const p1 = toMap(player.pos.x - viewRadius, lineZ);
      const p2 = toMap(player.pos.x + viewRadius, lineZ);
      ctx.beginPath(); ctx.moveTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.stroke();
    }
    function dot(wx, wz, color, r) {
      const d = dist2D(wx, wz, player.pos.x, player.pos.z);
      if (d > viewRadius) return;
      const p = toMap(wx, wz);
      ctx.fillStyle = color;
      ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2); ctx.fill();
    }
    for (let i = 0; i < pedestrians.length; i++) {
      if (pedestrians[i].alive) dot(pedestrians[i].pos.x, pedestrians[i].pos.z, 'rgba(232,232,232,0.85)', 2);
    }
    for (let i = 0; i < trafficCars.length; i++) dot(trafficCars[i].pos.x, trafficCars[i].pos.z, '#e0b93c', 2.5);
    const policeColor = Math.floor(gameTime / 0.3) % 2 === 0 ? '#ff3b3b' : '#3b6bff';
    for (let i = 0; i < policeCars.length; i++) dot(policeCars[i].pos.x, policeCars[i].pos.z, policeColor, 3);

    ctx.save();
    ctx.translate(cx, cz);
    ctx.rotate(player.heading);
    ctx.fillStyle = '#f2a93a';
    ctx.beginPath();
    ctx.moveTo(0, -6); ctx.lineTo(4, 5); ctx.lineTo(-4, 5); ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function updateHud() {
    dom.speed.textContent = String(Math.round(Math.abs(player.speed) * 3.6));
    const stars = Math.round(wantedHeat);
    dom.wantedStars.forEach((el, i) => { el.classList.toggle('active', i < stars); });
    dom['bar-health'].style.width = player.health + '%';
    dom.score.textContent = String(currentScore());
    drawMinimap();
  }
  function currentScore() {
    return Math.floor(distanceDriven) + 50 * Math.floor(wantedSecondsAccum);
  }

  function updateCamera() {
    const fx = Math.sin(player.heading), fz = Math.cos(player.heading);
    camera.position.set(player.pos.x - fx * CAMERA_BACK, CAMERA_HEIGHT, player.pos.z - fz * CAMERA_BACK);
    camera.lookAt(player.pos.x + fx * LOOKAHEAD, 1, player.pos.z + fz * LOOKAHEAD);
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
    const { group } = buildCarMesh(PLAYER_BODY, PLAYER_CABIN, false);
    scene.add(group);
    const state = createCarState(SPAWN.x, SPAWN.z, 0);
    state.maxSpeed = MAX_SPEED_FORWARD;
    return Object.assign(state, { mesh: group, health: 100, hitCooldown: 0, lastDamageSource: null });
  }

  // Räumt Geometrie/Material eines entfernten Meshes (bzw. einer ganzen
  // Gruppe wie beim Auto-/Fußgänger-Mesh) auf, damit wiederholte Neustarts
  // in derselben Session keinen GPU-Speicher anhäufen.
  function disposeObject(obj) {
    scene.remove(obj);
    obj.traverse((child) => {
      if (child.geometry) child.geometry.dispose();
      if (child.material) child.material.dispose();
    });
  }

  function resetRunState() {
    pedestrians.forEach((p) => disposeObject(p.mesh));
    pedestrians = [];
    trafficCars.forEach((c) => disposeObject(c.mesh));
    trafficCars = [];
    policeCars.forEach((c) => disposeObject(c.mesh));
    policeCars = [];
    particles.forEach((p) => scene.remove(p.mesh));
    particles = [];
    tweens = [];

    if (player) disposeObject(player.mesh);
    player = createPlayer();

    for (let i = 0; i < density.pedCount; i++) spawnPedestrian();
    for (let i = 0; i < density.trafficCount; i++) spawnTrafficCar();

    wantedHeat = 0;
    maxWantedReached = 0;
    vehicleHitTimestamps = [];
    timeSinceLastPoliceContact = 0;
    distanceDriven = 0;
    wantedSecondsAccum = 0;
    gameTime = 0;
    ended = false;
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
      btns.forEach((btn) => {
        btn.addEventListener('click', () => {
          btns.forEach((b) => b.classList.remove('selected'));
          btn.classList.add('selected');
          selectedDensity = btn.dataset.value;
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
  let selectedDensity = 'normal';

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
          applyDamage(Math.abs(player.speed) * 1.2, 'crash');
          SFX.crash();
          spawnParticles(player.pos, 0xaaaaaa, 6);
          player.hitCooldown = 0.4;
        }
        player.speed *= 0.3;
      }
      player.hitCooldown = Math.max(0, player.hitCooldown - dt);

      pedestrians.forEach((p) => updatePedestrian(p, dt));
      trafficCars.forEach((c) => updateTrafficCar(c, dt));
      for (let i = policeCars.length - 1; i >= 0; i--) updatePoliceCar(policeCars[i], dt);

      if (!ended) checkPlayerVsPedestrians();
      if (!ended) checkPlayerVsTraffic(dt);
      if (!ended) checkPlayerVsPolice();
      if (!ended) maintainPolice(dt);

      if (!ended && wantedHeat <= 0 && player.hitCooldown <= 0) {
        player.health = clamp(player.health + HEALTH_REGEN * dt, 0, 100);
      }

      distanceDriven += Math.abs(player.speed) * dt;
      if (wantedHeat >= 1) wantedSecondsAccum += dt;

      player.mesh.position.set(player.pos.x, 0, player.pos.z);
      player.mesh.rotation.y = player.heading;

      updateParticles(dt);
      updateTweens(dt);
      updateCamera();
      updateHud();
    }

    if (renderer) renderer.render(scene, camera);
  }

  /* ------------------------------------------------------------------------
     Init
     ------------------------------------------------------------------------ */
  function init() {
    cacheDom();
    dom['lobby-highscore'].textContent = String(loadHighscore());
    initThree();
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
