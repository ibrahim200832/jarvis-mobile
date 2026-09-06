(() => {
  "use strict";

  const colliders = [];
  let placedCounts = {};
  let refs = null;

  function addCollider(minX, maxX, minZ, maxZ) {
    colliders.push({ minX, maxX, minZ, maxZ });
  }

  function tagShadow(mesh, cast, receive) {
    mesh.castShadow = cast !== false;
    mesh.receiveShadow = receive !== false;
    return mesh;
  }

  function materialFor(map, kind, settings, extra) {
    if (settings.quality === "high") {
      const presets = {
        wood: { roughness: 0.75, metalness: 0.0 },
        stone: { roughness: 0.9, metalness: 0.0 },
        metal: { roughness: 0.35, metalness: 0.75 },
      };
      return new THREE.MeshStandardMaterial(Object.assign({ map }, presets[kind], extra));
    }
    return new THREE.MeshLambertMaterial(Object.assign({ map }, extra));
  }

  function build(scene) {
    colliders.length = 0;
    placedCounts = {};

    const settings = NS.Settings.load();
    const texSize = NS.Settings.getTextureSize(64, settings);

    function wallMesh(w, h, d, texture, kind) {
      return tagShadow(new THREE.Mesh(new THREE.BoxGeometry(w, h, d), materialFor(texture, kind, settings)));
    }

    // Interior stone/plaster: warm tone, grouted-block look.
    const interiorWallTex = NS.Textures.buildStoneTexture("#4a4038", "#2e2822", texSize, { blocks: true });
    interiorWallTex.wrapS = interiorWallTex.wrapT = THREE.RepeatWrapping;

    const interiorFloorTex = NS.Textures.buildStoneTexture("#4a4038", "#2e2822", texSize, { blocks: true });
    interiorFloorTex.wrapS = interiorFloorTex.wrapT = THREE.RepeatWrapping;
    interiorFloorTex.repeat.set(6, 6);

    const backFloorTex = NS.Textures.buildStoneTexture("#443b34", "#2a231e", texSize, { blocks: true });
    backFloorTex.wrapS = backFloorTex.wrapT = THREE.RepeatWrapping;
    backFloorTex.repeat.set(2, 2);

    const storageFloorTex = NS.Textures.buildStoneTexture("#3f382f", "#28221c", texSize, { blocks: true });
    storageFloorTex.wrapS = storageFloorTex.wrapT = THREE.RepeatWrapping;
    storageFloorTex.repeat.set(2, 2.4);

    // Exterior stone/concrete: cooler tone, veined like quartz/masonry.
    const exteriorGroundTex = NS.Textures.buildStoneTexture("#3a3f47", "#8a92a0", texSize, { veins: true });
    exteriorGroundTex.wrapS = exteriorGroundTex.wrapT = THREE.RepeatWrapping;
    exteriorGroundTex.repeat.set(10, 20);

    const alleyFloorTex = NS.Textures.buildStoneTexture("#33373e", "#7a828e", texSize, { veins: true });
    alleyFloorTex.wrapS = alleyFloorTex.wrapT = THREE.RepeatWrapping;
    alleyFloorTex.repeat.set(2, 2);

    const corridorFloorTex = NS.Textures.buildStoneTexture("#33373e", "#7a828e", texSize, { veins: true });
    corridorFloorTex.wrapS = corridorFloorTex.wrapT = THREE.RepeatWrapping;
    corridorFloorTex.repeat.set(1, 3);

    const kioskWallTex = NS.Textures.buildStoneTexture("#3a3f47", "#8a92a0", texSize, { veins: true });
    kioskWallTex.wrapS = kioskWallTex.wrapT = THREE.RepeatWrapping;

    const woodTex = NS.Textures.buildWoodTexture("#7a5233", "#4a2f1c", texSize);
    const metalTex = NS.Textures.buildMetalTexture("#5a5f66", "#c9d3dc", texSize);

    const group = new THREE.Group();

    function addFloor(w, d, x, z, texture, y) {
      const floorMesh = tagShadow(
        new THREE.Mesh(new THREE.PlaneGeometry(w, d), materialFor(texture, "stone", settings)),
        false,
        true
      );
      floorMesh.rotation.x = -Math.PI / 2;
      floorMesh.position.set(x, y !== undefined ? y : 0, z);
      group.add(floorMesh);
      return floorMesh;
    }

    addFloor(12, 10, 0, -1, interiorFloorTex);
    addFloor(4, 4, 0, -7.85, backFloorTex);
    addFloor(30, 40, 0, 18, exteriorGroundTex, -0.01);

    const wallHeight = 3;
    const wallThickness = 0.3;

    function pairWithGap(centerZ) {
      const left = wallMesh(4.2, wallHeight, wallThickness, interiorWallTex, "stone");
      left.position.set(-3.9, wallHeight / 2, centerZ);
      group.add(left);
      addCollider(-6, -1.8, centerZ - 0.15, centerZ + 0.15);

      const right = wallMesh(4.2, wallHeight, wallThickness, interiorWallTex, "stone");
      right.position.set(3.9, wallHeight / 2, centerZ);
      group.add(right);
      addCollider(1.8, 6, centerZ - 0.15, centerZ + 0.15);
    }
    pairWithGap(4);
    pairWithGap(-6);

    const westWall = wallMesh(wallThickness, wallHeight, 10, interiorWallTex, "stone");
    westWall.position.set(-6, wallHeight / 2, -1);
    group.add(westWall);
    addCollider(-6.15, -5.85, -6, 4);

    const eastWall = wallMesh(wallThickness, wallHeight, 10, interiorWallTex, "stone");
    eastWall.position.set(6, wallHeight / 2, -1);
    group.add(eastWall);
    addCollider(5.85, 6.15, -6, 4);

    const backWallWest = wallMesh(wallThickness, wallHeight, 3.7, interiorWallTex, "stone");
    backWallWest.position.set(-2.1, wallHeight / 2, -7.85);
    group.add(backWallWest);
    addCollider(-2.25, -1.95, -9.7, -6);

    const backWallEast = wallMesh(wallThickness, wallHeight, 3.7, interiorWallTex, "stone");
    backWallEast.position.set(2.1, wallHeight / 2, -7.85);
    group.add(backWallEast);
    addCollider(1.95, 2.25, -9.7, -6);

    // Back room's far wall is now a narrow doorway into the storage room
    // instead of a dead end.
    const backWallFarLeft = wallMesh(1.4, wallHeight, wallThickness, interiorWallTex, "stone");
    backWallFarLeft.position.set(-1.4, wallHeight / 2, -9.7);
    group.add(backWallFarLeft);
    addCollider(-2.1, -0.7, -9.85, -9.55);

    const backWallFarRight = wallMesh(1.4, wallHeight, wallThickness, interiorWallTex, "stone");
    backWallFarRight.position.set(1.4, wallHeight / 2, -9.7);
    group.add(backWallFarRight);
    addCollider(0.7, 2.1, -9.85, -9.55);

    // Storage room: extends the back room north, dead-ends at z=-15 with a
    // bonus item, and opens west into the alley via a second narrow doorway.
    addFloor(4.2, 5, 0, -12.35, storageFloorTex);

    const storageNorthWall = wallMesh(4.2, wallHeight, wallThickness, interiorWallTex, "stone");
    storageNorthWall.position.set(0, wallHeight / 2, -15);
    group.add(storageNorthWall);
    addCollider(-2.1, 2.1, -15.15, -14.85);

    const storageEastWall = wallMesh(wallThickness, wallHeight, 5, interiorWallTex, "stone");
    storageEastWall.position.set(2.1, wallHeight / 2, -12.35);
    group.add(storageEastWall);
    addCollider(1.95, 2.25, -14.85, -9.85);

    const storageWestWallSouth = wallMesh(wallThickness, wallHeight, 1.8, interiorWallTex, "stone");
    storageWestWallSouth.position.set(-2.1, wallHeight / 2, -10.75);
    group.add(storageWestWallSouth);
    addCollider(-2.25, -1.95, -11.65, -9.85);

    const storageWestWallNorth = wallMesh(wallThickness, wallHeight, 1.8, interiorWallTex, "stone");
    storageWestWallNorth.position.set(-2.1, wallHeight / 2, -13.95);
    group.add(storageWestWallNorth);
    addCollider(-2.25, -1.95, -14.85, -13.05);

    // Alley: an outdoor back-lot alcove behind the shop, connected to the
    // storage room's west doorway, running south alongside the shop's west
    // wall back out onto the main exterior plane.
    const fenceHeight = 2.4;
    addFloor(5, 5, -4.6, -12.35, alleyFloorTex, -0.01);
    addFloor(3, 8, -7.6, -6, corridorFloorTex, -0.01);

    const alcoveNorthCap = wallMesh(5, fenceHeight, wallThickness, kioskWallTex, "stone");
    alcoveNorthCap.position.set(-4.6, fenceHeight / 2, -15);
    group.add(alcoveNorthCap);
    addCollider(-7.1, -2.1, -15.15, -14.85);

    const corridorWestFence = wallMesh(wallThickness, fenceHeight, 8.3, kioskWallTex, "stone");
    corridorWestFence.position.set(-9.25, fenceHeight / 2, -6);
    group.add(corridorWestFence);
    addCollider(-9.4, -9.1, -10.15, -1.85);

    const counter = tagShadow(new THREE.Mesh(new THREE.BoxGeometry(2, 1, 0.7), materialFor(woodTex, "wood", settings)));
    counter.position.set(-4.5, 0.5, 2.5);
    group.add(counter);
    addCollider(-5.5, -3.5, 2.15, 2.85);

    const till = tagShadow(new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.3, 0.3), materialFor(metalTex, "metal", settings)));
    till.position.set(-4.5, 1.15, 2.5);
    group.add(till);

    function buildShelf(x, z) {
      const shelf = new THREE.Group();
      const frame = tagShadow(new THREE.Mesh(new THREE.BoxGeometry(1.6, 1.4, 0.5), materialFor(woodTex, "wood", settings)));
      frame.position.y = 0.7;
      shelf.add(frame);
      const productColors = [0xe6544c, 0xf2c94c, 0x6bbf59];
      for (let i = 0; i < 3; i++) {
        const product = tagShadow(
          new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.25, 0.25), new THREE.MeshLambertMaterial({ color: productColors[i] }))
        );
        product.position.set(-0.5 + i * 0.5, 1.25, 0.05);
        shelf.add(product);
      }
      shelf.position.set(x, 0, z);
      group.add(shelf);
      addCollider(x - 0.8, x + 0.8, z - 0.25, z + 0.25);
    }
    buildShelf(-1.5, -3);
    buildShelf(1.5, -3);
    buildShelf(-1.5, 0);
    buildShelf(1.5, 0);

    const fridgeGlow = { emissive: new THREE.Color(0x123044), emissiveIntensity: 0.4 };
    const fridge = tagShadow(
      new THREE.Mesh(new THREE.BoxGeometry(0.6, 1.8, 1.6), materialFor(metalTex, "metal", settings, fridgeGlow))
    );
    fridge.position.set(5.5, 0.9, -1);
    group.add(fridge);
    addCollider(5.1, 5.9, -1.8, -0.2);

    const poleSegments = NS.Settings.getSegments(6, settings);
    const busGroup = new THREE.Group();
    const bench = tagShadow(new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.5, 0.5), materialFor(woodTex, "wood", settings)));
    bench.position.y = 0.25;
    busGroup.add(bench);
    const sign = tagShadow(
      new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 2, poleSegments), materialFor(metalTex, "metal", settings))
    );
    sign.position.set(0.8, 1, 0);
    busGroup.add(sign);
    busGroup.position.set(0, 0, 22);
    group.add(busGroup);

    [-3, 3].forEach((x) => {
      const pump = tagShadow(new THREE.Mesh(new THREE.BoxGeometry(0.6, 1.4, 0.5), materialFor(metalTex, "metal", settings)));
      pump.position.set(x, 0.7, 12);
      group.add(pump);
      addCollider(x - 0.35, x + 0.35, 11.75, 12.25);
    });

    // Parked cars: exterior set-dressing that also breaks the stalker's line
    // of sight, giving the open lot some real cover.
    function buildCar(x, z, bodyColor) {
      const body = tagShadow(
        new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.9, 4.2), new THREE.MeshLambertMaterial({ color: bodyColor }))
      );
      body.position.set(x, 0.45, z);
      group.add(body);
      const cabin = tagShadow(
        new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.5, 2.0), new THREE.MeshLambertMaterial({ color: 0x14181d }))
      );
      cabin.position.set(x, 1.15, z);
      group.add(cabin);
      addCollider(x - 0.9, x + 0.9, z - 2.1, z + 2.1);
    }
    buildCar(7, 9, 0x8a3a3a);
    buildCar(-7, 14, 0x3a5a8a);
    buildCar(9, 15, 0x4a4a4a);

    // Concrete planters: a soft second fork between the shop door and the
    // bus stop - easy to walk around either side, not a hard wall.
    [7, 11, 15].forEach((z) => {
      const planter = tagShadow(
        new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.5, 2.0), materialFor(kioskWallTex, "stone", settings))
      );
      planter.position.set(0, 0.25, z);
      group.add(planter);
      addCollider(-0.4, 0.4, z - 1, z + 1);
    });

    // Kiosk: small optional detour building east of the pumps, entered from
    // the open (east) side of its counter.
    addFloor(3, 3, 10, 20, kioskWallTex, -0.005);

    const kioskBack = wallMesh(3, fenceHeight, 0.25, kioskWallTex, "stone");
    kioskBack.position.set(10, fenceHeight / 2, 21.4);
    group.add(kioskBack);
    addCollider(8.5, 11.5, 21.275, 21.525);

    const kioskWest = wallMesh(0.25, fenceHeight, 3, kioskWallTex, "stone");
    kioskWest.position.set(8.5, fenceHeight / 2, 20);
    group.add(kioskWest);
    addCollider(8.375, 8.625, 18.5, 21.5);

    const kioskEast = wallMesh(0.25, fenceHeight, 3, kioskWallTex, "stone");
    kioskEast.position.set(11.5, fenceHeight / 2, 20);
    group.add(kioskEast);
    addCollider(11.375, 11.625, 18.5, 21.5);

    // Counter only spans the west two-thirds of the opening, leaving a gap
    // on the east side to actually walk in.
    const kioskCounter = tagShadow(new THREE.Mesh(new THREE.BoxGeometry(2, 1.0, 0.4), materialFor(woodTex, "wood", settings)));
    kioskCounter.position.set(9.5, 0.5, 18.7);
    group.add(kioskCounter);
    addCollider(8.5, 10.5, 18.5, 18.9);

    scene.add(group);

    refs = {
      colliders,
      busStopPosition: new THREE.Vector3(0, 0, 21.3),
      checkoutPosition: new THREE.Vector3(-4.5, 0, 3.1),
      spawnPosition: new THREE.Vector3(0, 0, 1.5),
      backRoomPosition: new THREE.Vector3(0, 0, -7.85),
      storageRoomPosition: new THREE.Vector3(0, 0, -13.6),
      kioskPosition: new THREE.Vector3(9.7, 0, 20),
    };
    return refs;
  }

  function collides(x, z, radius) {
    radius = radius || 0.35;
    for (let i = 0; i < colliders.length; i++) {
      const c = colliders[i];
      if (x + radius > c.minX && x - radius < c.maxX && z + radius > c.minZ && z - radius < c.maxZ) {
        return true;
      }
    }
    return false;
  }

  function resolveMove(x, z, nx, nz, radius) {
    let newX = x;
    let newZ = z;
    if (!collides(nx, z, radius)) newX = nx;
    if (!collides(newX, nz, radius)) newZ = nz;
    return { x: newX, z: newZ };
  }

  function registerPlacement(zoneId) {
    placedCounts[zoneId] = (placedCounts[zoneId] || 0) + 1;
  }

  function getPlacedCount(zoneId) {
    return placedCounts[zoneId] || 0;
  }

  NS.Environment = {
    build,
    collides,
    resolveMove,
    registerPlacement,
    getPlacedCount,
    getRefs: () => refs,
  };
})();
