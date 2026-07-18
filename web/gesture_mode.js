// JARVIS Gesten-Modus — Handerkennung per Webcam (MediaPipe Hands) mit
// einem kleinen Partikel-Effekt an der Zeigefinger-Spitze. Läuft nur im
// Browser (Flutter Web); die MediaPipe-Bibliotheken werden erst geladen,
// wenn der Gesten-Modus tatsächlich geöffnet wird, damit normale Nutzer
// nichts davon herunterladen müssen.
(function () {
  let handsInstance = null;
  let cameraInstance = null;
  let canvasEl = null;
  let ctx = null;
  let particles = [];
  let running = false;

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      if (document.querySelector('script[src="' + src + '"]')) {
        resolve();
        return;
      }
      const el = document.createElement('script');
      el.src = src;
      el.onload = () => resolve();
      el.onerror = () => reject(new Error('Konnte ' + src + ' nicht laden.'));
      document.head.appendChild(el);
    });
  }

  async function ensureMediaPipeLoaded() {
    if (
      typeof window.Hands !== 'undefined' &&
      typeof window.Camera !== 'undefined' &&
      typeof window.drawConnectors !== 'undefined'
    ) {
      return;
    }
    await Promise.all([
      loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js'),
      loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js'),
      loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/hands/hands.js'),
    ]);
  }

  function spawnParticles(x, y, count) {
    for (let i = 0; i < count; i++) {
      particles.push({
        x,
        y,
        vx: (Math.random() - 0.5) * 4,
        vy: (Math.random() - 0.5) * 4,
        life: 1,
        hue: 15 + Math.random() * 25,
      });
    }
  }

  function updateParticles() {
    for (const p of particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.02;
      p.life -= 0.02;
    }
    particles = particles.filter((p) => p.life > 0);
  }

  function drawParticles() {
    for (const p of particles) {
      ctx.beginPath();
      ctx.fillStyle = 'hsla(' + p.hue + ', 100%, 60%, ' + Math.max(p.life, 0) + ')';
      ctx.arc(p.x, p.y, 3 * p.life + 1, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function onResults(results) {
    if (!ctx || !canvasEl) return;
    ctx.save();
    ctx.clearRect(0, 0, canvasEl.width, canvasEl.height);
    ctx.drawImage(results.image, 0, 0, canvasEl.width, canvasEl.height);

    if (results.multiHandLandmarks && results.multiHandLandmarks.length > 0) {
      for (const landmarks of results.multiHandLandmarks) {
        window.drawConnectors(ctx, landmarks, window.HAND_CONNECTIONS, {
          color: '#ff8a3d',
          lineWidth: 2,
        });
        window.drawLandmarks(ctx, landmarks, {
          color: '#ffffff',
          fillColor: '#ff8a3d',
          radius: 3,
        });
        const tip = landmarks[8]; // Zeigefinger-Spitze
        if (tip) {
          spawnParticles(tip.x * canvasEl.width, tip.y * canvasEl.height, 3);
        }
      }
    }

    updateParticles();
    drawParticles();
    ctx.restore();
  }

  async function start(containerId, onError) {
    if (running) return;
    const container = document.getElementById(containerId);
    if (!container) {
      if (onError) onError('Container nicht gefunden.');
      return;
    }
    container.innerHTML = '';

    const videoEl = document.createElement('video');
    videoEl.style.display = 'none';
    videoEl.setAttribute('playsinline', '');
    canvasEl = document.createElement('canvas');
    canvasEl.style.width = '100%';
    canvasEl.style.height = '100%';
    canvasEl.style.objectFit = 'contain';
    canvasEl.width = 640;
    canvasEl.height = 480;
    ctx = canvasEl.getContext('2d');
    container.appendChild(videoEl);
    container.appendChild(canvasEl);

    try {
      await ensureMediaPipeLoaded();
    } catch (e) {
      if (onError) onError('Hand-Tracking konnte nicht geladen werden (Internetverbindung prüfen).');
      return;
    }

    handsInstance = new window.Hands({
      locateFile: (file) => 'https://cdn.jsdelivr.net/npm/@mediapipe/hands/' + file,
    });
    handsInstance.setOptions({
      maxNumHands: 1,
      modelComplexity: 1,
      minDetectionConfidence: 0.6,
      minTrackingConfidence: 0.5,
    });
    handsInstance.onResults(onResults);

    try {
      cameraInstance = new window.Camera(videoEl, {
        onFrame: async () => {
          if (handsInstance) {
            await handsInstance.send({ image: videoEl });
          }
        },
        width: 640,
        height: 480,
      });
      await cameraInstance.start();
      running = true;
    } catch (e) {
      if (onError) onError('Kamera-Zugriff wurde verweigert oder ist fehlgeschlagen.');
    }
  }

  function stop() {
    running = false;
    if (cameraInstance) {
      cameraInstance.stop();
      cameraInstance = null;
    }
    if (handsInstance) {
      handsInstance.close();
      handsInstance = null;
    }
    particles = [];
    ctx = null;
    canvasEl = null;
  }

  window.jarvisGesture = { start, stop };
})();
