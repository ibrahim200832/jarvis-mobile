(() => {
  "use strict";

  const colliders = [];
  let placedCounts = {};
  let refs = null;

  function addCollider(minX, maxX, minZ, maxZ) {
    colliders.push({ minX, maxX, minZ, maxZ });
  }

  function wallMesh(w, h, d, texture) {
    const mat = new THREE.MeshLambertMaterial({ map: texture });
    return new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  }

  function build(scene) {
    colliders.length = 0;
    placedCounts = {};

    const wallTex = NS.Textures.buildWallTexture("#2b3038", "#20242b");
    wallTex.wrapS = wallTex.wrapT = THREE.RepeatWrapping;
    const floorTex = NS.Textures.buildFloorTexture("#3a3f47", "#33383f");
    floorTex.wrapS = floorTex.wrapT = THREE.RepeatWrapping;
    floorTex.repeat.set(6, 6);

    const group = new THREE.Group();

    const floor = new THREE.Mesh(new THREE.PlaneGeometry(12, 10), new THREE.MeshLambertMaterial({ map: floorTex }));
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(0, 0, -1);
    group.add(floor);

    const backFloor = new THREE.Mesh(new THREE.PlaneGeometry(4, 4), new THREE.MeshLambertMaterial({ map: floorTex }));
    backFloor.rotation.x = -Math.PI / 2;
    backFloor.position.set(0, 0, -7.85);
    group.add(backFloor);

    const exteriorTex = NS.Textures.buildFloorTexture("#12161c", "#171c22");
    exteriorTex.wrapS = exteriorTex.wrapT = THREE.RepeatWrapping;
    exteriorTex.repeat.set(10, 20);
    const exterior = new THREE.Mesh(new THREE.PlaneGeometry(30, 40), new THREE.MeshLambertMaterial({ map: exteriorTex }));
    exterior.rotation.x = -Math.PI / 2;
    exterior.position.set(0, -0.01, 18);
    group.add(exterior);

    const wallHeight = 3;
    const wallThickness = 0.3;

    function pairWithGap(centerZ, isNorth) {
      const left = wallMesh(4.2, wallHeight, wallThickness, wallTex);
      left.position.set(-3.9, wallHeight / 2, centerZ);
      group.add(left);
      addCollider(-6, -1.8, centerZ - 0.15, centerZ + 0.15);

      const right = wallMesh(4.2, wallHeight, wallThickness, wallTex);
      right.position.set(3.9, wallHeight / 2, centerZ);
      group.add(right);
      addCollider(1.8, 6, centerZ - 0.15, centerZ + 0.15);
    }
    pairWithGap(4, false);
    pairWithGap(-6, true);

    const westWall = wallMesh(wallThickness, wallHeight, 10, wallTex);
    westWall.position.set(-6, wallHeight / 2, -1);
    group.add(westWall);
    addCollider(-6.15, -5.85, -6, 4);

    const eastWall = wallMesh(wallThickness, wallHeight, 10, wallTex);
    eastWall.position.set(6, wallHeight / 2, -1);
    group.add(eastWall);
    addCollider(5.85, 6.15, -6, 4);

    const backWallFar = wallMesh(4.2, wallHeight, wallThickness, wallTex);
    backWallFar.position.set(0, wallHeight / 2, -9.7);
    group.add(backWallFar);
    addCollider(-2.1, 2.1, -9.85, -9.55);

    const backWallWest = wallMesh(wallThickness, wallHeight, 3.7, wallTex);
    backWallWest.position.set(-2.1, wallHeight / 2, -7.85);
    group.add(backWallWest);
    addCollider(-2.25, -1.95, -9.7, -6);

    const backWallEast = wallMesh(wallThickness, wallHeight, 3.7, wallTex);
    backWallEast.position.set(2.1, wallHeight / 2, -7.85);
    group.add(backWallEast);
    addCollider(1.95, 2.25, -9.7, -6);

    const counter = new THREE.Mesh(new THREE.BoxGeometry(2, 1, 0.7), new THREE.MeshLambertMaterial({ color: 0x4a4038 }));
    counter.position.set(-4.5, 0.5, 2.5);
    group.add(counter);
    addCollider(-5.5, -3.5, 2.15, 2.85);

    const till = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.3, 0.3), new THREE.MeshLambertMaterial({ color: 0x1c1f24 }));
    till.position.set(-4.5, 1.15, 2.5);
    group.add(till);

    function buildShelf(x, z) {
      const shelf = new THREE.Group();
      const frame = new THREE.Mesh(new THREE.BoxGeometry(1.6, 1.4, 0.5), new THREE.MeshLambertMaterial({ color: 0x2e3238 }));
      frame.position.y = 0.7;
      shelf.add(frame);
      const productColors = [0xe6544c, 0xf2c94c, 0x6bbf59];
      for (let i = 0; i < 3; i++) {
        const product = new THREE.Mesh(
          new THREE.BoxGeometry(0.25, 0.25, 0.25),
          new THREE.MeshLambertMaterial({ color: productColors[i] })
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

    const fridge = new THREE.Mesh(
      new THREE.BoxGeometry(0.6, 1.8, 1.6),
      new THREE.MeshLambertMaterial({ color: 0x1c2a30, emissive: new THREE.Color(0x123044), emissiveIntensity: 0.4 })
    );
    fridge.position.set(5.5, 0.9, -1);
    group.add(fridge);
    addCollider(5.1, 5.9, -1.8, -0.2);

    const busGroup = new THREE.Group();
    const bench = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.5, 0.5), new THREE.MeshLambertMaterial({ color: 0x3a3f47 }));
    bench.position.y = 0.25;
    busGroup.add(bench);
    const sign = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 2, 6), new THREE.MeshLambertMaterial({ color: 0x555b63 }));
    sign.position.set(0.8, 1, 0);
    busGroup.add(sign);
    busGroup.position.set(0, 0, 22);
    group.add(busGroup);

    const pumpMat = new THREE.MeshLambertMaterial({ color: 0x8a3a3a });
    [-3, 3].forEach((x) => {
      const pump = new THREE.Mesh(new THREE.BoxGeometry(0.6, 1.4, 0.5), pumpMat);
      pump.position.set(x, 0.7, 12);
      group.add(pump);
      addCollider(x - 0.35, x + 0.35, 11.75, 12.25);
    });

    scene.add(group);

    refs = {
      colliders,
      busStopPosition: new THREE.Vector3(0, 0, 21.3),
      checkoutPosition: new THREE.Vector3(-4.5, 0, 3.1),
      spawnPosition: new THREE.Vector3(0, 0, 1.5),
      backRoomPosition: new THREE.Vector3(0, 0, -7.85),
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
