(() => {
  "use strict";

  let refs = null;
  let state = "patrol";
  let awareness = 0;
  let patrolPoints = [];
  let patrolIndex = 0;
  let config = {};
  let lastKnownPlayerPos = new THREE.Vector3();
  let alertTimer = 0;
  let caughtCallback = null;
  let scares = [];
  let elapsed = 0;
  let lastFootstepPhase = 0;

  function init(scene, threatConfig, onCaught) {
    config = threatConfig || {};
    caughtCallback = onCaught;
    refs = NS.Character.buildHumanoid({
      uniformColor: 0x0d0d10,
      skinColor: 0x14161a,
      limbColor: 0x0a0a0c,
      scale: 1.15,
      facePreset: "stalker",
      emissive: 0x3a0f0f,
    });
    scene.add(refs.group);
    patrolPoints = (config.patrolPoints || [[0, 0, -2]]).map((p) => new THREE.Vector3(p[0], 0, p[2]));
    refs.group.position.copy(patrolPoints[0]);
    patrolIndex = 0;
    state = "patrol";
    awareness = 0;
    alertTimer = 0;
    elapsed = 0;
    lastFootstepPhase = 0;
    scares = (config.scriptedScares || []).map((s) => Object.assign({ fired: false }, s));
  }

  function dispose(scene) {
    if (refs) scene.remove(refs.group);
    refs = null;
  }

  function hasLineOfSight(fromV3, toV3) {
    const steps = 10;
    for (let i = 1; i < steps; i++) {
      const t = i / steps;
      const x = fromV3.x + (toV3.x - fromV3.x) * t;
      const z = fromV3.z + (toV3.z - fromV3.z) * t;
      if (NS.Environment.collides(x, z, 0.05)) return false;
    }
    return true;
  }

  function update(dt, playerPos, playerMoving, playerRunning, flashlightOn) {
    if (!refs || state === "caught") return;
    elapsed += dt;

    scares.forEach((s) => {
      if (!s.fired && elapsed >= s.atSeconds) {
        s.fired = true;
        NS.Audio.playFootstep();
      }
    });

    const distance = refs.group.position.distanceTo(playerPos);
    const noticeRadius = config.noticeRadius || 6;
    const los = distance < 14 && hasLineOfSight(refs.group.position, playerPos);

    let gain = 0;
    if (playerMoving) gain += (playerRunning ? 14 : 6) / Math.max(1, distance * 0.5);
    if (flashlightOn && los) gain += 10 / Math.max(1, distance * 0.5);
    if (los && distance < noticeRadius) gain += 12 * (1 - distance / noticeRadius);
    awareness += gain * dt;
    awareness -= (config.decayPerSecond || 5) * dt;
    awareness = Math.max(0, Math.min(100, awareness));

    const alertThreshold = config.alertThreshold || 40;
    const huntThreshold = config.huntThreshold || 80;

    if (state === "patrol" && awareness >= alertThreshold) {
      state = "alert";
      alertTimer = 6;
      lastKnownPlayerPos.copy(playerPos);
    } else if (state === "alert") {
      if (awareness >= huntThreshold) {
        state = "hunt";
      } else {
        alertTimer -= dt;
        if (los) lastKnownPlayerPos.copy(playerPos);
        if (alertTimer <= 0) state = "patrol";
      }
    } else if (state === "hunt") {
      lastKnownPlayerPos.copy(playerPos);
      if (awareness <= alertThreshold * 0.5) {
        state = "alert";
        alertTimer = 4;
      }
    }

    let targetPos;
    let speed;
    if (state === "patrol") {
      targetPos = patrolPoints[patrolIndex];
      speed = config.patrolSpeed || 1.2;
      if (refs.group.position.distanceTo(targetPos) < 0.4) {
        patrolIndex = (patrolIndex + 1) % patrolPoints.length;
      }
    } else if (state === "alert") {
      targetPos = lastKnownPlayerPos;
      speed = config.alertSpeed || (config.patrolSpeed || 1.2) * 1.6;
    } else {
      targetPos = playerPos;
      speed = config.huntSpeed || 3.4;
    }

    const dir = new THREE.Vector3(targetPos.x - refs.group.position.x, 0, targetPos.z - refs.group.position.z);
    const dist2 = dir.length();
    let moved = false;
    if (dist2 > 0.05) {
      dir.normalize();
      const nx = refs.group.position.x + dir.x * speed * dt;
      const nz = refs.group.position.z + dir.z * speed * dt;
      const resolved = NS.Environment.resolveMove(refs.group.position.x, refs.group.position.z, nx, nz, 0.4);
      refs.group.position.x = resolved.x;
      refs.group.position.z = resolved.z;
      refs.group.rotation.y = Math.atan2(dir.x, dir.z);
      moved = true;
    }
    NS.Character.updateWalkCycle(refs, dt, moved);

    const phase = Math.floor(refs.walkCycleT / Math.PI);
    if (moved && phase !== lastFootstepPhase) {
      lastFootstepPhase = phase;
      if (state !== "patrol") NS.Audio.playFootstep();
    }

    NS.Audio.setThreatLevel(awareness / 100, dt);

    if (state === "hunt" && distance < (config.catchRadius || 0.8)) {
      state = "caught";
      NS.Audio.playJumpscare();
      if (caughtCallback) caughtCallback();
    }
  }

  function getAwareness() {
    return awareness;
  }

  function getState() {
    return state;
  }

  NS.Threat = { init, dispose, update, getAwareness, getState };
})();
