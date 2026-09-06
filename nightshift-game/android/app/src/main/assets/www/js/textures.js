(() => {
  "use strict";

  function makeCanvas(w, h) {
    const c = document.createElement("canvas");
    c.width = w;
    c.height = h;
    return c;
  }

  function shadeColor(hex, percent) {
    const num = parseInt(hex.replace("#", ""), 16);
    let r = (num >> 16) & 0xff;
    let g = (num >> 8) & 0xff;
    let b = num & 0xff;
    r = Math.max(0, Math.min(255, Math.round(r + (percent < 0 ? r : 255 - r) * percent)));
    g = Math.max(0, Math.min(255, Math.round(g + (percent < 0 ? g : 255 - g) * percent)));
    b = Math.max(0, Math.min(255, Math.round(b + (percent < 0 ? b : 255 - b) * percent)));
    return "rgb(" + r + "," + g + "," + b + ")";
  }

  function hexToRgba(hex, alpha) {
    const num = parseInt(hex.replace("#", ""), 16);
    const r = (num >> 16) & 0xff;
    const g = (num >> 8) & 0xff;
    const b = num & 0xff;
    return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
  }

  function buildWallTexture(baseColor, lineColor, size) {
    size = size || 64;
    const s = size / 64;
    const c = makeCanvas(size, size);
    const g = c.getContext("2d");
    g.fillStyle = baseColor;
    g.fillRect(0, 0, size, size);
    g.strokeStyle = lineColor;
    g.lineWidth = 2 * s;
    g.strokeRect(1 * s, 1 * s, size - 2 * s, size - 2 * s);
    g.beginPath();
    g.moveTo(size / 2, 0);
    g.lineTo(size / 2, size);
    g.moveTo(0, size / 2);
    g.lineTo(size, size / 2);
    g.stroke();
    return new THREE.CanvasTexture(c);
  }

  function buildFloorTexture(colorA, colorB, size) {
    size = size || 64;
    const c = makeCanvas(size, size);
    const g = c.getContext("2d");
    g.fillStyle = colorA;
    g.fillRect(0, 0, size, size);
    g.fillStyle = colorB;
    g.fillRect(0, 0, size / 2, size / 2);
    g.fillRect(size / 2, size / 2, size / 2, size / 2);
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

  function buildWoodTexture(baseColor, grainColor, size) {
    size = size || 64;
    const c = makeCanvas(size, size);
    const g = c.getContext("2d");

    g.fillStyle = baseColor;
    g.fillRect(0, 0, size, size);

    const shade = g.createLinearGradient(0, 0, 0, size);
    shade.addColorStop(0, "rgba(0,0,0,0.08)");
    shade.addColorStop(0.5, "rgba(0,0,0,0)");
    shade.addColorStop(1, "rgba(0,0,0,0.08)");
    g.fillStyle = shade;
    g.fillRect(0, 0, size, size);

    const plankCount = size >= 128 ? 4 : 3;
    const plankWidth = size / plankCount;
    const lineWidth = Math.max(1, size / 64);
    for (let i = 1; i < plankCount; i++) {
      const x = i * plankWidth;
      g.strokeStyle = "rgba(30,16,8,0.5)";
      g.lineWidth = lineWidth;
      g.beginPath();
      g.moveTo(x, 0);
      g.lineTo(x, size);
      g.stroke();
      g.strokeStyle = "rgba(255,255,255,0.06)";
      g.beginPath();
      g.moveTo(x + lineWidth, 0);
      g.lineTo(x + lineWidth, size);
      g.stroke();
    }

    const linesPerPlank = size >= 128 ? 10 : 6;
    for (let p = 0; p < plankCount; p++) {
      const plankX0 = p * plankWidth;
      for (let i = 0; i < linesPerPlank; i++) {
        const baseX = plankX0 + Math.random() * plankWidth;
        const freq = 0.05 + Math.random() * 0.1;
        const amplitude = (2 + Math.random() * 4) * (size / 64);
        const phase = Math.random() * Math.PI * 2;
        g.strokeStyle = Math.random() < 0.5 ? shadeColor(grainColor, 0.15) : shadeColor(grainColor, -0.15);
        g.globalAlpha = 0.15 + Math.random() * 0.25;
        g.lineWidth = 0.5 + Math.random() * 2;
        g.beginPath();
        const steps = 8;
        for (let s = 0; s <= steps; s++) {
          const y = (s / steps) * size;
          const x = baseX + Math.sin(y * freq + phase) * amplitude;
          if (s === 0) g.moveTo(x, y);
          else g.lineTo(x, y);
        }
        g.stroke();

        if (Math.random() < 0.1) {
          const knotY = Math.random() * size;
          const knotX = baseX + Math.sin(knotY * freq + phase) * amplitude;
          for (let k = 3; k > 0; k--) {
            g.globalAlpha = 0.25;
            g.fillStyle = shadeColor(grainColor, -0.1 * k);
            g.beginPath();
            g.ellipse(knotX, knotY, k * 1.6 * (size / 64), k * 1.1 * (size / 64), 0, 0, Math.PI * 2);
            g.fill();
          }
        }
      }
    }
    g.globalAlpha = 1;

    const speckleCount = Math.min(800, Math.round((size * size) / 8));
    for (let i = 0; i < speckleCount; i++) {
      g.globalAlpha = 0.05 + Math.random() * 0.1;
      g.fillStyle = Math.random() < 0.5 ? shadeColor(baseColor, 0.2) : shadeColor(baseColor, -0.2);
      g.fillRect(Math.random() * size, Math.random() * size, 1, 1);
    }
    g.globalAlpha = 1;

    return new THREE.CanvasTexture(c);
  }

  function generateVeinPoints(size, depth) {
    let x = Math.random() * size;
    let y = Math.random() < 0.5 ? 0 : size;
    let angle = (y === 0 ? Math.PI / 2 : -Math.PI / 2) + (Math.random() - 0.5) * 0.6;
    const points = [[x, y]];
    const branches = [];
    const steps = 12 + Math.floor(Math.random() * 10);
    const stepLen = (size / steps) * 1.5;
    for (let i = 0; i < steps; i++) {
      angle += (Math.random() - 0.5) * 0.6;
      x += Math.cos(angle) * stepLen;
      y += Math.sin(angle) * stepLen;
      points.push([x, y]);
      if (depth < 1 && Math.random() < 0.12) {
        branches.push(generateVeinPoints(size, depth + 1));
      }
      if (x < -5 || x > size + 5 || y < -5 || y > size + 5) break;
    }
    return { points, branches };
  }

  function strokeVein(g, vein, color) {
    g.strokeStyle = color;
    g.lineWidth = 0.5 + Math.random();
    g.globalAlpha = 0.2 + Math.random() * 0.2;
    g.beginPath();
    vein.points.forEach((pt, i) => {
      if (i === 0) g.moveTo(pt[0], pt[1]);
      else g.lineTo(pt[0], pt[1]);
    });
    g.stroke();
    vein.branches.forEach((b) => strokeVein(g, b, color));
    g.globalAlpha = 1;
  }

  function buildStoneTexture(baseColor, accentColor, size, opts) {
    size = size || 64;
    opts = opts || {};
    const c = makeCanvas(size, size);
    const g = c.getContext("2d");

    g.fillStyle = baseColor;
    g.fillRect(0, 0, size, size);

    const mottleCount = Math.max(20, Math.round((size * size) / 40));
    for (let i = 0; i < mottleCount; i++) {
      const r = (2 + Math.random() * 6) * (size / 64);
      g.globalAlpha = 0.05 + Math.random() * 0.1;
      g.fillStyle = Math.random() < 0.5 ? shadeColor(baseColor, 0.15) : shadeColor(baseColor, -0.15);
      g.beginPath();
      g.arc(Math.random() * size, Math.random() * size, r, 0, Math.PI * 2);
      g.fill();
    }

    const speckleCount = Math.max(40, Math.round((size * size) / 6));
    for (let i = 0; i < speckleCount; i++) {
      g.globalAlpha = 0.1 + Math.random() * 0.2;
      g.fillStyle = Math.random() < 0.5 ? shadeColor(baseColor, 0.25) : shadeColor(baseColor, -0.25);
      g.fillRect(Math.random() * size, Math.random() * size, 1 + Math.random(), 1 + Math.random());
    }
    g.globalAlpha = 1;

    if (opts.veins) {
      const veinCount = 2 + Math.floor(Math.random() * 4);
      for (let v = 0; v < veinCount; v++) {
        strokeVein(g, generateVeinPoints(size, 0), accentColor);
      }
    }

    if (opts.blocks) {
      const grid = size >= 128 ? 3 : 2;
      g.strokeStyle = shadeColor(baseColor, -0.35);
      g.lineWidth = Math.max(1, size / 64);
      g.globalAlpha = 0.6;
      for (let i = 1; i < grid; i++) {
        const p = (i / grid) * size;
        g.beginPath();
        g.moveTo(p, 0);
        g.lineTo(p, size);
        g.stroke();
        g.beginPath();
        g.moveTo(0, p);
        g.lineTo(size, p);
        g.stroke();
      }
      g.globalAlpha = 1;
    }

    return new THREE.CanvasTexture(c);
  }

  function buildMetalTexture(baseColor, highlightColor, size) {
    size = size || 64;
    const c = makeCanvas(size, size);
    const g = c.getContext("2d");

    g.fillStyle = baseColor;
    g.fillRect(0, 0, size, size);

    const streakCount = Math.round(size * 1.5);
    for (let i = 0; i < streakCount; i++) {
      const w = size * (0.2 + Math.random() * 0.6);
      g.globalAlpha = 0.08 + Math.random() * 0.12;
      g.fillStyle = Math.random() < 0.5 ? shadeColor(baseColor, 0.08) : shadeColor(baseColor, -0.08);
      g.fillRect(Math.random() * (size - w), Math.random() * size, w, 1);
    }
    g.globalAlpha = 1;

    const sheen = g.createLinearGradient(0, 0, size, 0);
    sheen.addColorStop(0, "rgba(0,0,0,0)");
    sheen.addColorStop(0.45, "rgba(0,0,0,0)");
    sheen.addColorStop(0.55, hexToRgba(highlightColor, 0.25));
    sheen.addColorStop(0.65, "rgba(0,0,0,0)");
    sheen.addColorStop(1, "rgba(0,0,0,0)");
    g.fillStyle = sheen;
    g.fillRect(0, 0, size, size);

    for (let i = 0; i < 5; i++) {
      const x1 = Math.random() * size;
      const y1 = Math.random() * size;
      const len = size * (0.15 + Math.random() * 0.25);
      const angle = Math.PI / 4 + (Math.random() - 0.5) * 0.5;
      g.strokeStyle = shadeColor(baseColor, 0.3);
      g.globalAlpha = 0.06 + Math.random() * 0.06;
      g.lineWidth = 0.5;
      g.beginPath();
      g.moveTo(x1, y1);
      g.lineTo(x1 + Math.cos(angle) * len, y1 + Math.sin(angle) * len);
      g.stroke();
    }
    g.globalAlpha = 1;

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
    buildWoodTexture,
    buildStoneTexture,
    buildMetalTexture,
    buildFaceTexture,
    buildLabelTexture,
    buildRingTexture,
    FACE_PRESETS,
  };
})();
