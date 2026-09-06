(() => {
  "use strict";

  function makeCanvas(w, h) {
    const c = document.createElement("canvas");
    c.width = w;
    c.height = h;
    return c;
  }

  function buildWallTexture(baseColor, lineColor) {
    const c = makeCanvas(64, 64);
    const g = c.getContext("2d");
    g.fillStyle = baseColor;
    g.fillRect(0, 0, 64, 64);
    g.strokeStyle = lineColor;
    g.lineWidth = 2;
    g.strokeRect(1, 1, 62, 62);
    g.beginPath();
    g.moveTo(32, 0);
    g.lineTo(32, 64);
    g.moveTo(0, 32);
    g.lineTo(64, 32);
    g.stroke();
    return new THREE.CanvasTexture(c);
  }

  function buildFloorTexture(colorA, colorB) {
    const c = makeCanvas(64, 64);
    const g = c.getContext("2d");
    g.fillStyle = colorA;
    g.fillRect(0, 0, 64, 64);
    g.fillStyle = colorB;
    g.fillRect(0, 0, 32, 32);
    g.fillRect(32, 32, 32, 32);
    return new THREE.CanvasTexture(c);
  }

  const FACE_PRESETS = {
    default: { skin: "#e0b088", eye: "#1c1c1c", mouth: "#7a3b3b", expression: "neutral" },
    mike: { skin: "#d9b189", eye: "#233043", mouth: "#7a3b3b", expression: "smile" },
    lena: { skin: "#e8c9a8", eye: "#3a2a20", mouth: "#8a4a4a", expression: "neutral" },
    stalker: { skin: "#0d0d10", eye: "#c23b3b", mouth: "#000000", expression: "blank" },
  };

  function buildFaceTexture(presetKey, size) {
    size = size || 64;
    const preset = FACE_PRESETS[presetKey] || FACE_PRESETS.default;
    const c = makeCanvas(size, size);
    const g = c.getContext("2d");
    g.imageSmoothingEnabled = false;
    g.fillStyle = preset.skin;
    g.fillRect(0, 0, size, size);

    const eyeW = size * 0.14;
    const eyeH = size * 0.14;
    const eyeY = size * 0.38;
    g.fillStyle = preset.eye;
    g.fillRect(size * 0.22, eyeY, eyeW, eyeH);
    g.fillRect(size * 0.64, eyeY, eyeW, eyeH);

    g.fillStyle = preset.mouth;
    if (preset.expression === "smile") {
      g.fillRect(size * 0.32, size * 0.66, size * 0.36, size * 0.06);
    } else if (preset.expression === "scared") {
      g.fillRect(size * 0.4, size * 0.62, size * 0.2, size * 0.16);
    } else if (preset.expression === "blank") {
      // Deliberately no mouth drawn - part of what makes the stalker's face unsettling.
    } else {
      g.fillRect(size * 0.34, size * 0.68, size * 0.32, size * 0.045);
    }

    const tex = new THREE.CanvasTexture(c);
    tex.needsUpdate = true;
    return tex;
  }

  function buildLabelTexture(text, bg, fg) {
    const c = makeCanvas(128, 64);
    const g = c.getContext("2d");
    g.fillStyle = bg || "#2a2f36";
    g.fillRect(0, 0, 128, 64);
    g.fillStyle = fg || "#f2f6f8";
    g.font = "bold 22px sans-serif";
    g.textAlign = "center";
    g.textBaseline = "middle";
    g.fillText(text, 64, 32);
    return new THREE.CanvasTexture(c);
  }

  function buildRingTexture(color) {
    const c = makeCanvas(64, 64);
    const g = c.getContext("2d");
    g.clearRect(0, 0, 64, 64);
    g.strokeStyle = color || "#3ecbe0";
    g.lineWidth = 5;
    g.beginPath();
    g.arc(32, 32, 26, 0, Math.PI * 2);
    g.stroke();
    return new THREE.CanvasTexture(c);
  }

  NS.Textures = {
    buildWallTexture,
    buildFloorTexture,
    buildFaceTexture,
    buildLabelTexture,
    buildRingTexture,
    FACE_PRESETS,
  };
})();
