(() => {
  "use strict";

  let counts = {};
  let barEl = null;

  function init(containerEl) {
    counts = {};
    barEl = containerEl;
    render();
  }

  function add(itemId, amount) {
    counts[itemId] = (counts[itemId] || 0) + (amount || 1);
    render();
  }

  function remove(itemId, amount) {
    counts[itemId] = Math.max(0, (counts[itemId] || 0) - (amount || 1));
    render();
  }

  function has(itemId, amount) {
    return (counts[itemId] || 0) >= (amount || 1);
  }

  function count(itemId) {
    return counts[itemId] || 0;
  }

  function render() {
    if (!barEl) return;
    barEl.innerHTML = "";
    Object.keys(counts).forEach((id) => {
      if (counts[id] <= 0) return;
      const chip = document.createElement("div");
      chip.className = "inv-chip";
      const label = (NS.ITEM_LABELS && NS.ITEM_LABELS[id]) || id;
      chip.textContent = label + " x" + counts[id];
      barEl.appendChild(chip);
    });
  }

  NS.Inventory = { init, add, remove, has, count };
})();
