(() => {
  "use strict";

  const KEY = "nightshift-game-settings";
  const DEFAULTS = { quality: "medium", shadows: false, drawDistance: "medium", vignette: true };

  function load() {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return Object.assign({}, DEFAULTS);
      return Object.assign({}, DEFAULTS, JSON.parse(raw));
    } catch (e) {
      return Object.assign({}, DEFAULTS);
    }
  }

  function save(settings) {
    try {
      localStorage.setItem(KEY, JSON.stringify(settings));
    } catch (e) {
      // localStorage unavailable (private mode, etc.) - settings just won't persist.
    }
  }

  function getPixelRatio(settings) {
    const device = window.devicePixelRatio || 1;
    if (settings.quality === "low") return 1;
    if (settings.quality === "high") return Math.min(device, 2);
    return Math.min(device, 1.5);
  }

  function getTextureSize(base, settings) {
    if (settings.quality === "low") return Math.max(32, Math.round(base * 0.75));
    if (settings.quality === "high") return Math.round(base * 1.5);
    return base;
  }

  function getSegments(base, settings) {
    if (settings.quality === "low") return Math.max(6, base - 4);
    if (settings.quality === "high") return base + 6;
    return base;
  }

  function getFogMultiplier(settings) {
    if (settings.drawDistance === "short") return 0.6;
    if (settings.drawDistance === "far") return 1.6;
    return 1;
  }

  NS.Settings = { load, save, DEFAULTS, getPixelRatio, getTextureSize, getSegments, getFogMultiplier };
})();
