(() => {
  "use strict";

  function buildHumanoid(opts) {
    opts = opts || {};
    const uniformColor = opts.uniformColor !== undefined ? opts.uniformColor : 0x3a4a5a;
    const skinColor = opts.skinColor !== undefined ? opts.skinColor : 0xe0b088;
    const limbColor = opts.limbColor !== undefined ? opts.limbColor : 0x1c1f24;
    const scale = opts.scale || 1;
    const facePreset = opts.facePreset || "default";
    const emissive = opts.emissive || null;

    const group = new THREE.Group();

    const hipY = 0.9 * scale;
    const torsoMat = new THREE.MeshLambertMaterial({ color: uniformColor });
    if (emissive) {
      torsoMat.emissive = new THREE.Color(emissive);
      torsoMat.emissiveIntensity = 0.35;
    }
    const torso = new THREE.Mesh(new THREE.BoxGeometry(0.5 * scale, 0.7 * scale, 0.3 * scale), torsoMat);
    torso.position.y = hipY + 0.35 * scale;
    group.add(torso);

    const headSize = 0.34 * scale;
    const faceTexture = NS.Textures.buildFaceTexture(facePreset, 64);
    const skinMat = new THREE.MeshLambertMaterial({ color: skinColor });
    const faceMat = new THREE.MeshLambertMaterial({ map: faceTexture });
    // BoxGeometry face material order is [+x, -x, +y, -y, +z, -z]; +z is the front.
    const head = new THREE.Mesh(new THREE.BoxGeometry(headSize, headSize, headSize), [
      skinMat,
      skinMat,
      skinMat,
      skinMat,
      faceMat,
      skinMat,
    ]);
    head.position.y = torso.position.y + 0.35 * scale + headSize / 2;
    group.add(head);

    function buildLimb(isArm, side) {
      const pivot = new THREE.Group();
      const length = (isArm ? 0.55 : 0.8) * scale;
      const thickness = (isArm ? 0.12 : 0.16) * scale;
      const mesh = new THREE.Mesh(
        new THREE.BoxGeometry(thickness, length, thickness),
        new THREE.MeshLambertMaterial({ color: isArm ? uniformColor : limbColor })
      );
      mesh.position.y = -length / 2;
      pivot.add(mesh);
      const x = side * (isArm ? 0.32 : 0.14) * scale;
      const y = isArm ? torso.position.y + 0.3 * scale : hipY;
      pivot.position.set(x, y, 0);
      group.add(pivot);
      return pivot;
    }

    const shoulderL = buildLimb(true, -1);
    const shoulderR = buildLimb(true, 1);
    const hipL = buildLimb(false, -1);
    const hipR = buildLimb(false, 1);

    const refs = {
      group,
      torso,
      head,
      shoulderL,
      shoulderR,
      hipL,
      hipR,
      baseTorsoY: torso.position.y,
      walkCycleT: 0,
      walkAmount: 0,
    };
    return refs;
  }

  function updateWalkCycle(refs, dt, isMoving) {
    const target = isMoving ? 1 : 0;
    refs.walkAmount += (target - refs.walkAmount) * Math.min(1, dt * 6);
    const amount = refs.walkAmount;
    refs.walkCycleT += dt * (isMoving ? 7 : 3) * Math.max(amount, 0.15);
    const t = refs.walkCycleT;
    const strideAmp = 0.9 * amount;
    const armAmp = 0.7 * amount;
    refs.hipL.rotation.x = Math.sin(t) * strideAmp;
    refs.hipR.rotation.x = Math.sin(t + Math.PI) * strideAmp;
    refs.shoulderL.rotation.x = Math.sin(t + Math.PI) * armAmp;
    refs.shoulderR.rotation.x = Math.sin(t) * armAmp;
    refs.torso.position.y = refs.baseTorsoY + Math.abs(Math.sin(t)) * 0.03 * amount;
  }

  NS.Character = { buildHumanoid, updateWalkCycle };
})();
