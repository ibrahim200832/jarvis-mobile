(() => {
  "use strict";

  NS.ITEM_LABELS = {
    cola_can: "Cola",
    snack_box: "Snacks",
    cleaning_spray: "Reiniger",
    old_battery: "Batterie",
    energy_drink: "Energy-Drink",
  };

  // Bonus finds in the extended map - not needed for any quest, just a
  // reward for exploring the storage room / kiosk detour.
  const BONUS_ITEMS = [
    { itemId: "old_battery", position: [0, 0.3, -14.3] },
    { itemId: "energy_drink", position: [9.7, 0.3, 20] },
  ];

  const mike = (questId, dialogue) => ({
    id: "mike",
    name: "Mike",
    position: [-3.3, 0, 1.7],
    rotationY: Math.PI,
    uniformColor: 0x4a5a6a,
    facePreset: "mike",
    questId,
    dialogue,
  });

  const lena = (questId, dialogue) => ({
    id: "lena",
    name: "Lena",
    position: [1.8, 0, -1.6],
    rotationY: 0,
    uniformColor: 0x6a4a5a,
    facePreset: "lena",
    questId,
    dialogue,
  });

  const tom = (questId, dialogue) => ({
    id: "tom",
    name: "Tom",
    position: [0, 0, -7.2],
    rotationY: Math.PI,
    uniformColor: 0x4a5a3a,
    facePreset: "default",
    questId,
    dialogue,
  });

  NS.NIGHTS = [
    {
      id: 1,
      label: "Nacht 1",
      introLine: "Erste Schicht. Nichts Besonderes, sagen sie.",
      npcs: [
        mike("n1_restock", {
          idle: ["Ruhige Nacht bisher."],
          questOffer: [
            "Hey, du bist neu, oder?",
            "Kannst du mir 3 Cola-Dosen aus dem Regal ins Kühlregal bringen?",
            "Einfach aufsammeln und herbringen.",
          ],
          questActive: ["Hast du die Colas schon gefunden?"],
          questTurnIn: ["Perfekt, danke dir!", "Der Bus fährt gleich – mach Feierabend."],
        }),
      ],
      quests: [
        { id: "n1_restock", giverId: "mike", type: "collect", itemId: "cola_can", targetCount: 3, title: "3 Cola-Dosen zu Mike bringen" },
      ],
      itemsToSpawn: [
        { itemId: "cola_can", position: [-1.5, 0.3, -2.6] },
        { itemId: "cola_can", position: [1.5, 0.3, -2.6] },
        { itemId: "cola_can", position: [-1.5, 0.3, 0.6] },
        ...BONUS_ITEMS,
      ],
      placementZones: [],
      environment: { ambientIntensity: 0.22, fogNear: 6, fogFar: 34 },
      threat: {
        variant: "stalker_humanoid",
        patrolSpeed: 0.9,
        huntSpeed: 2.6,
        alertThreshold: 65,
        huntThreshold: 95,
        decayPerSecond: 10,
        catchRadius: 0.8,
        noticeRadius: 5,
        patrolPoints: [
          [0, 0, -7.85],
          [-1.5, 0, -3],
          [1.5, 0, -3],
          [0, 0, -1],
          [0, 0, -12.35],
        ],
        scriptedScares: [],
      },
    },
    {
      id: 2,
      label: "Nacht 2",
      introLine: "Nacht 2. Irgendwas fühlt sich anders an.",
      npcs: [
        mike("n2_checkout", {
          idle: ["Kunden heute Nacht komisch ruhig."],
          questOffer: ["Kannst du die Kasse ein paar Mal durchgehen? Übung macht den Meister.", "Zwei Durchläufe reichen."],
          questActive: ["Kasse schon benutzt?"],
          questTurnIn: ["Gut gemacht.", "Bus steht gleich bereit."],
        }),
        lena("n2_restock", {
          idle: ["Die Regale leeren sich schnell heute."],
          questOffer: ["Bring mir 2 Snack-Boxen und leg sie ins Regal da drüben.", "Der markierte Ring zeigt dir wo."],
          questActive: ["Die Snacks noch nicht eingeräumt?"],
          questTurnIn: ["Sieht schon viel voller aus, danke!"],
        }),
      ],
      quests: [
        { id: "n2_checkout", giverId: "mike", type: "useCheckout", targetCount: 2, title: "Kasse 2x benutzen" },
        { id: "n2_restock", giverId: "lena", type: "place", itemId: "snack_box", targetCount: 2, zoneId: "shelf_restock", title: "2 Snack-Boxen einräumen" },
      ],
      itemsToSpawn: [
        { itemId: "snack_box", position: [-4.8, 0.3, -5] },
        { itemId: "snack_box", position: [4.8, 0.3, -5] },
        ...BONUS_ITEMS,
      ],
      placementZones: [{ id: "shelf_restock", position: [1.5, 0, 0.6], itemId: "snack_box" }],
      environment: { ambientIntensity: 0.18, fogNear: 5.5, fogFar: 30 },
      threat: {
        variant: "stalker_humanoid",
        patrolSpeed: 1.1,
        huntSpeed: 3.0,
        alertThreshold: 50,
        huntThreshold: 85,
        decayPerSecond: 8,
        catchRadius: 0.8,
        noticeRadius: 6,
        patrolPoints: [
          [0, 0, -7.85],
          [-4, 0, -4],
          [4, 0, -4],
          [0, 0, 2],
          [0, 0, -12.35],
          [-4.6, 0, -12.35],
        ],
        scriptedScares: [{ atSeconds: 60, type: "shelfNoise", position: [1.5, 0, -3] }],
      },
    },
    {
      id: 3,
      label: "Nacht 3",
      introLine: "Nacht 3. Aus dem Hinterzimmer kam vorhin ein Geräusch.",
      npcs: [
        mike("n3_backroom", {
          idle: ["Bleib besser vorne, ja?"],
          questOffer: ["Im Hinterzimmer klappert was rum. Schau kurz nach, ja?", "Ich bleib hier vorne."],
          questActive: ["Warst du schon hinten?"],
          questTurnIn: ["War wohl nichts. Trotzdem danke."],
        }),
        lena("n3_spill", {
          idle: ["Pass auf, wo du hintrittst."],
          questOffer: ["Da hinten ist was ausgelaufen. Reiniger schnappen und dort saubermachen.", "Der Ring markiert die Stelle."],
          questActive: ["Ist der Fleck weg?"],
          questTurnIn: ["Endlich, danke!"],
        }),
        tom("n3_checkout", {
          idle: ["Volle Nacht heute."],
          questOffer: ["Kannst du die Kasse dreimal übernehmen? Ich hab hier zu tun."],
          questActive: ["Schon dreimal kassiert?"],
          questTurnIn: ["Super, danke für die Hilfe."],
        }),
      ],
      quests: [
        { id: "n3_backroom", giverId: "mike", type: "findAndReport", zoneId: "back_room_check", title: "Hinterzimmer überprüfen" },
        { id: "n3_spill", giverId: "lena", type: "place", itemId: "cleaning_spray", targetCount: 1, zoneId: "spill_zone", title: "Fleck wegputzen" },
        { id: "n3_checkout", giverId: "tom", type: "useCheckout", targetCount: 3, title: "Kasse 3x benutzen" },
      ],
      itemsToSpawn: [{ itemId: "cleaning_spray", position: [-5, 0.3, 2.8] }, ...BONUS_ITEMS],
      placementZones: [
        { id: "back_room_check", position: [0, 0, -13.5], itemId: null, radius: 1.8, autoTrigger: true },
        { id: "spill_zone", position: [-1.5, 0, -2.6], itemId: "cleaning_spray" },
      ],
      environment: { ambientIntensity: 0.14, fogNear: 5, fogFar: 26 },
      threat: {
        variant: "stalker_humanoid",
        patrolSpeed: 1.4,
        huntSpeed: 3.7,
        alertThreshold: 38,
        huntThreshold: 72,
        decayPerSecond: 5,
        catchRadius: 0.85,
        noticeRadius: 7,
        patrolPoints: [
          [0, 0, -7.85],
          [-1.5, 0, -3],
          [1.5, 0, 0],
          [-4, 0, 2],
          [0, 0, -13.5],
          [-4.6, 0, -12.35],
          [-7.6, 0, -6],
        ],
        scriptedScares: [
          { atSeconds: 45, type: "shelfNoise", position: [-1.5, 0, 0] },
          { atSeconds: 110, type: "shelfNoise", position: [0, 0, -7.85] },
        ],
      },
    },
    {
      id: 4,
      label: "Nacht 4",
      introLine: "Letzte Nacht der Woche. Einfach durchhalten.",
      npcs: [
        mike("n4_survive", {
          idle: ["Fast geschafft."],
          questOffer: ["Halt einfach durch bis Ladenschluss.", "Ich sag Bescheid, wenn's soweit ist."],
          questActive: ["Noch nicht Ladenschluss."],
          questTurnIn: ["Geschafft. Ab nach Hause mit dir."],
        }),
        lena("n4_checkout", {
          idle: ["Fast Feierabend."],
          questOffer: ["Kasse noch viermal, dann ist Ruhe."],
          questActive: ["Viermal kassiert?"],
          questTurnIn: ["Das war's für heute."],
        }),
      ],
      quests: [
        { id: "n4_survive", giverId: "mike", type: "surviveUntil", targetSeconds: 90, title: "Bis Ladenschluss durchhalten" },
        { id: "n4_checkout", giverId: "lena", type: "useCheckout", targetCount: 4, title: "Kasse 4x benutzen" },
      ],
      itemsToSpawn: [...BONUS_ITEMS],
      placementZones: [],
      environment: { ambientIntensity: 0.1, fogNear: 4.5, fogFar: 22 },
      threat: {
        variant: "stalker_humanoid",
        patrolSpeed: 1.6,
        huntSpeed: 4.2,
        alertThreshold: 30,
        huntThreshold: 62,
        decayPerSecond: 3,
        catchRadius: 0.9,
        noticeRadius: 8,
        patrolPoints: [
          [0, 0, -7.85],
          [-4, 0, -4],
          [4, 0, -4],
          [0, 0, 2],
          [-4, 0, 2],
          [0, 0, -13.5],
          [-4.6, 0, -12.35],
          [-7.6, 0, -6],
          [9.7, 0, 20],
        ],
        scriptedScares: [
          { atSeconds: 30, type: "shelfNoise", position: [1.5, 0, -3] },
          { atSeconds: 70, type: "shelfNoise", position: [-1.5, 0, 0] },
          { atSeconds: 110, type: "shelfNoise", position: [0, 0, -7.85] },
        ],
      },
    },
  ];
})();
