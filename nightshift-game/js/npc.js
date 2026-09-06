(() => {
  "use strict";

  const TALK_RANGE = 1.6;

  let panelEl, nameEl, portraitCanvas, textEl, nextBtn;
  let dialogueLines = [];
  let dialogueIndex = 0;
  let onCloseCallback = null;

  function init(elements) {
    panelEl = elements.panel;
    nameEl = elements.name;
    portraitCanvas = elements.portrait;
    textEl = elements.text;
    nextBtn = elements.nextBtn;
    nextBtn.addEventListener("click", advance);
  }

  function spawn(scene, npcDefs) {
    return (npcDefs || []).map((def) => {
      const refs = NS.Character.buildHumanoid({
        uniformColor: def.uniformColor,
        facePreset: def.facePreset,
        scale: 1,
      });
      refs.group.position.set(def.position[0], 0, def.position[2]);
      refs.group.rotation.y = def.rotationY || Math.PI;
      scene.add(refs.group);
      return { def, refs };
    });
  }

  function clear(scene, npcRuntimeList) {
    (npcRuntimeList || []).forEach((npc) => scene.remove(npc.refs.group));
  }

  function drawPortrait(facePreset) {
    const tex = NS.Textures.buildFaceTexture(facePreset, 96);
    const ctx = portraitCanvas.getContext("2d");
    ctx.clearRect(0, 0, portraitCanvas.width, portraitCanvas.height);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(tex.image, 0, 0, portraitCanvas.width, portraitCanvas.height);
  }

  function resolveLinesForNpc(npc) {
    const dialogue = npc.def.dialogue || {};
    if (!npc.def.questId) {
      return dialogue.idle || ["..."];
    }
    const quest = NS.Quests.byId(npc.def.questId);
    if (!quest) return dialogue.idle || ["..."];
    if (quest.state === "locked") return dialogue.questOffer || ["Kannst du mir helfen?"];
    if (quest.state === "active") return dialogue.questActive || ["Noch nicht fertig?"];
    if (quest.state === "readyToTurnIn") return dialogue.questTurnIn || ["Danke dir!"];
    return dialogue.idle || ["Danke nochmal."];
  }

  function applyQuestTransition(npc) {
    if (!npc.def.questId) return;
    const quest = NS.Quests.byId(npc.def.questId);
    if (!quest) return;
    if (quest.state === "locked") NS.Quests.offer(npc.def.questId);
    else if (quest.state === "readyToTurnIn") NS.Quests.turnIn(npc.def.questId);
  }

  function talkTo(npc, onClose) {
    dialogueLines = resolveLinesForNpc(npc);
    dialogueIndex = 0;
    onCloseCallback = onClose || null;
    nameEl.textContent = npc.def.name;
    drawPortrait(npc.def.facePreset);
    textEl.textContent = dialogueLines[0];
    panelEl.classList.remove("hidden");
    applyQuestTransition(npc);
  }

  function advance() {
    dialogueIndex++;
    if (dialogueIndex >= dialogueLines.length) {
      close();
      return;
    }
    textEl.textContent = dialogueLines[dialogueIndex];
  }

  function close() {
    panelEl.classList.add("hidden");
    if (onCloseCallback) onCloseCallback();
  }

  function isOpen() {
    return panelEl && !panelEl.classList.contains("hidden");
  }

  function nearestInRange(npcRuntimeList, playerPos) {
    let best = null;
    let bestDist = TALK_RANGE;
    (npcRuntimeList || []).forEach((npc) => {
      const d = Math.hypot(npc.refs.group.position.x - playerPos.x, npc.refs.group.position.z - playerPos.z);
      if (d < bestDist) {
        bestDist = d;
        best = npc;
      }
    });
    return best;
  }

  NS.NPC = { init, spawn, clear, talkTo, isOpen, nearestInRange, TALK_RANGE };
})();
