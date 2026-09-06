(() => {
  "use strict";

  let ctx = null;
  let masterGain = null;
  let droneGain = null;
  let heartbeatGain = null;
  let noiseBuffer = null;
  let heartbeatTimer = 0;
  let heartbeatInterval = 1.1;

  function buildNoiseBuffer() {
    const duration = 0.6;
    const sampleRate = ctx.sampleRate;
    const buffer = ctx.createBuffer(1, sampleRate * duration, sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    return buffer;
  }

  function ensureContext() {
    if (ctx) return;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    ctx = new Ctx();

    masterGain = ctx.createGain();
    masterGain.gain.value = 0.5;
    masterGain.connect(ctx.destination);

    noiseBuffer = buildNoiseBuffer();

    droneGain = ctx.createGain();
    droneGain.gain.value = 0.04;
    droneGain.connect(masterGain);

    [40, 41.5].forEach((freq) => {
      const osc = ctx.createOscillator();
      osc.type = "sine";
      osc.frequency.value = freq;
      osc.connect(droneGain);
      osc.start();
    });

    heartbeatGain = ctx.createGain();
    heartbeatGain.gain.value = 0;
    heartbeatGain.connect(masterGain);
  }

  function init() {
    ensureContext();
    if (ctx && ctx.state === "suspended") ctx.resume();
  }

  function playFootstep() {
    if (!ctx) return;
    const src = ctx.createBufferSource();
    src.buffer = noiseBuffer;
    const filter = ctx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = 420;
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.09);
    src.connect(filter);
    filter.connect(gain);
    gain.connect(masterGain);
    src.start();
    src.stop(ctx.currentTime + 0.12);
  }

  function playBlip() {
    if (!ctx) return;
    const osc = ctx.createOscillator();
    osc.type = "sine";
    osc.frequency.value = 880;
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.18, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);
    osc.connect(gain);
    gain.connect(masterGain);
    osc.start();
    osc.stop(ctx.currentTime + 0.14);
  }

  function playHeartbeatPulse(intensity) {
    if (!ctx) return;
    const osc = ctx.createOscillator();
    osc.type = "sine";
    osc.frequency.value = 55;
    const gain = ctx.createGain();
    const vol = 0.12 + intensity * 0.35;
    gain.gain.setValueAtTime(vol, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.22);
    osc.connect(gain);
    gain.connect(masterGain);
    osc.start();
    osc.stop(ctx.currentTime + 0.25);
  }

  function setThreatLevel(level, dt) {
    if (!ctx) return;
    const clamped = Math.max(0, Math.min(1, level));
    droneGain.gain.value = 0.035 + clamped * 0.13;
    heartbeatInterval = 1.05 - clamped * 0.7;
    heartbeatTimer -= dt;
    if (heartbeatTimer <= 0) {
      playHeartbeatPulse(clamped);
      heartbeatTimer = heartbeatInterval;
    }
  }

  function playJumpscare() {
    if (!ctx) return;
    const osc = ctx.createOscillator();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(90, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(900, ctx.currentTime + 0.4);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.55, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.8);
    osc.connect(gain);
    gain.connect(masterGain);
    osc.start();
    osc.stop(ctx.currentTime + 0.85);

    const src = ctx.createBufferSource();
    src.buffer = noiseBuffer;
    const ngain = ctx.createGain();
    ngain.gain.setValueAtTime(0.45, ctx.currentTime);
    ngain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.6);
    src.connect(ngain);
    ngain.connect(masterGain);
    src.start();
    src.stop(ctx.currentTime + 0.6);
  }

  NS.Audio = { init, playFootstep, playBlip, setThreatLevel, playJumpscare };
})();
