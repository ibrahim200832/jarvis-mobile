(() => {
  "use strict";

  let quests = [];

  function load(questsData) {
    quests = (questsData || []).map((q) =>
      Object.assign({ state: "locked", checkoutCount: 0, foundZone: false }, q)
    );
  }

  function byId(id) {
    return quests.find((q) => q.id === id) || null;
  }

  function byGiver(giverId) {
    return quests.find((q) => q.giverId === giverId) || null;
  }

  function offer(questId) {
    const q = byId(questId);
    if (q && q.state === "locked") q.state = "active";
  }

  function turnIn(questId) {
    const q = byId(questId);
    if (q && q.state === "readyToTurnIn") q.state = "complete";
  }

  function notifyCheckoutUse() {
    quests.forEach((q) => {
      if (q.type === "useCheckout" && q.state === "active") q.checkoutCount++;
    });
  }

  function notifyZoneEnter(zoneId) {
    quests.forEach((q) => {
      if (q.type === "findAndReport" && q.zoneId === zoneId && q.state === "active") q.foundZone = true;
    });
  }

  function update(nightElapsedSeconds) {
    quests.forEach((q) => {
      if (q.state !== "active") return;
      let done = false;
      if (q.type === "collect") done = NS.Inventory.count(q.itemId) >= q.targetCount;
      else if (q.type === "place") done = NS.Environment.getPlacedCount(q.zoneId) >= q.targetCount;
      else if (q.type === "useCheckout") done = q.checkoutCount >= q.targetCount;
      else if (q.type === "surviveUntil") done = nightElapsedSeconds >= q.targetSeconds;
      else if (q.type === "findAndReport") done = q.foundZone;
      if (done) q.state = "readyToTurnIn";
    });
  }

  function allComplete() {
    return quests.length > 0 && quests.every((q) => q.state === "complete");
  }

  function activeBannerQuest() {
    return quests.find((q) => q.state !== "complete") || null;
  }

  function list() {
    return quests;
  }

  NS.Quests = { load, byId, byGiver, offer, turnIn, notifyCheckoutUse, notifyZoneEnter, update, allComplete, activeBannerQuest, list };
})();
