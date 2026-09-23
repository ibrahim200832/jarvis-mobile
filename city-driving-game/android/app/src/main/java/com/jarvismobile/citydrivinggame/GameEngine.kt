package com.jarvismobile.citydrivinggame

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sign
import kotlin.math.sin
import kotlin.random.Random

/* ============================================================================
   HEAT STREETS — Spiel-Logik-Kern, native Portierung des ursprünglichen
   HTML5/Canvas-Prototyps. Bewusst ohne android.*-Importe, damit Weltaufbau,
   Physik und KI unabhängig vom Rendering nachvollziehbar bleiben — das
   Zeichnen übernimmt GameView, das nur diesen Zustand liest.

   Vereinfachungen (bewusst, unverändert aus dem Prototyp übernommen):
   - Kein Aussteigen aus dem Auto, kein Zufußgehen für den Spieler.
   - Verkehrsautos fahren feste Rechteck-Umläufe um je einen Block (kein
     Pathfinding, kein Spurwechsel) und kollidieren nicht untereinander,
     sondern regeln nur Tempo über eine 1D-Abstandsregel entlang der Route.
   - Polizei verfolgt den Spieler direkt (kein Vorhalten/Interception).
   ========================================================================== */

// ---------------------------------------------------------------------------
// Konstanten: Stadtraster
// ---------------------------------------------------------------------------
const val GRID_N = 7
const val LANE_WIDTH = 3.2
const val STREET_WIDTH = LANE_WIDTH * 2
const val BLOCK_SIZE = 34.0
const val GRID_PERIOD = BLOCK_SIZE + STREET_WIDTH
const val GRID_HALF = (GRID_N * GRID_PERIOD) / 2
const val WORLD_MARGIN = 20.0
const val WORLD_HALF_EXTENT = GRID_HALF + WORLD_MARGIN
const val SIDEWALK_WIDTH = 2.4
const val BUILDING_MIN_H = 6.0
const val BUILDING_MAX_H = 32.0
const val PARK_BLOCK_CHANCE = 0.15
val BUILDING_COLORS = intArrayOf(0x8a7d6b, 0x9c8f7a, 0x7d8a94, 0xa3907a, 0x6f7d89, 0x8f8574, 0x7a8a7d)

// ---------------------------------------------------------------------------
// Konstanten: Auto-Physik (Spieler, Verkehr, Polizei teilen sich das Modell)
// ---------------------------------------------------------------------------
const val CAR_RADIUS = 1.1
const val MAX_SPEED_FORWARD = 26.0
const val MAX_SPEED_REVERSE = -8.0
const val ACCEL = 9.0
const val BRAKE_DECEL = 16.0
const val DRAG = 3.5
const val STEER_MAX_RATE = 2.0

// ---------------------------------------------------------------------------
// Konstanten: Fußgänger
// ---------------------------------------------------------------------------
const val PED_RADIUS = 0.4
const val PED_WALK_SPEED = 1.3
const val PED_WALK_SPEED_MIN_MUL = 0.7
const val PED_WALK_SPEED_MAX_MUL = 1.3
const val PED_FLEE_SPEED = 2.8
const val FLEE_RADIUS = 6.0
const val FLEE_DURATION = 2.5
const val MIN_HIT_SPEED = 2.5
const val PED_RESPAWN_DELAY = 20.0
const val PED_DEATH_ANIM_TIME = 0.4
const val PED_CROSSING_CHANCE = 0.35
const val PED_IDLE_CHANCE = 0.25
const val PED_IDLE_MIN = 0.6
const val PED_IDLE_MAX = 2.4

class PedCrossOption(val di: Int, val dj: Int, val mirror: Int)
val PED_NODE_CROSSINGS: Array<Array<PedCrossOption>> = arrayOf(
    arrayOf(PedCrossOption(-1, 0, 1), PedCrossOption(0, -1, 3)),
    arrayOf(PedCrossOption(1, 0, 0), PedCrossOption(0, -1, 2)),
    arrayOf(PedCrossOption(1, 0, 3), PedCrossOption(0, 1, 1)),
    arrayOf(PedCrossOption(-1, 0, 2), PedCrossOption(0, 1, 0))
)

// ---------------------------------------------------------------------------
// Konstanten: Verkehr (Ambient-KI, feste Rechteck-Umläufe je Block)
// ---------------------------------------------------------------------------
const val TRAFFIC_SPEED_MIN = 9.0
const val TRAFFIC_SPEED_MAX = 14.0
const val TRAFFIC_MAX_ACCEL = 6.0

// ---------------------------------------------------------------------------
// Konstanten: Fahndungsstufe & Polizei
// ---------------------------------------------------------------------------
const val PED_HIT_HEAT = 1.0
const val RECKLESS_WINDOW = 8.0
const val RECKLESS_CAR_HITS_THRESHOLD = 3
const val RECKLESS_HEAT = 1.0
const val POLICE_HIT_HEAT = 0.4
const val POLICE_SPAWN_MIN_DIST = 30.0
const val POLICE_SPAWN_MAX_DIST = 70.0
const val POLICE_MAX_SPEED = 22.0
const val POLICE_PROXIMITY_DECAY_RADIUS = 25.0
const val POLICE_STUCK_TIME = 4.0
const val HEALTH_REGEN = 2.0

class DensityPreset(val pedCount: Int, val trafficCount: Int, val policeMaxCars: Int, val evadeTime: Double)
val DENSITY_PRESETS: Map<String, DensityPreset> = linkedMapOf(
    "ruhig" to DensityPreset(20, 6, 3, 10.0),
    "normal" to DensityPreset(32, 12, 4, 12.0),
    "voll" to DensityPreset(44, 18, 5, 16.0)
)

// ---------------------------------------------------------------------------
// Konstanten: Münzen
// ---------------------------------------------------------------------------
const val COIN_COUNT = 36
const val COIN_PICKUP_RADIUS = 1.0
const val COIN_SCORE = 20
const val ALL_COINS_BONUS = 200

// ---------------------------------------------------------------------------
// Konstanten: Ampeln an Kreuzungen (rein dekorativ)
// ---------------------------------------------------------------------------
const val TRAFFIC_LIGHT_CYCLE = 8.0
const val TRAFFIC_LIGHT_GREEN = 5.0

// ---------------------------------------------------------------------------
// Konstanten: Beinahe-Unfall-Bonus
// ---------------------------------------------------------------------------
const val NEAR_MISS_MIN_GAP = CAR_RADIUS + PED_RADIUS + 0.15
const val NEAR_MISS_MAX_GAP = NEAR_MISS_MIN_GAP + 1.2
const val NEAR_MISS_MIN_SPEED = 6.0
const val NEAR_MISS_SCORE = 5
const val NEAR_MISS_COOLDOWN = 3.0

// ---------------------------------------------------------------------------
// Konstanten: Tag/Nacht-Zyklus & Farben (RGB-Tripel, 0-255)
// ---------------------------------------------------------------------------
const val DAY_LENGTH = 220.0
val GROUND_DAY = intArrayOf(0xc9, 0xc2, 0xae)
val GROUND_NIGHT = intArrayOf(0x22, 0x24, 0x2a)
val WATER_SHALLOW_DAY = intArrayOf(0x2e, 0x74, 0x8f)
val WATER_SHALLOW_NIGHT = intArrayOf(0x04, 0x0c, 0x16)
val WATER_DEEP_DAY = intArrayOf(0x11, 0x39, 0x52)
val WATER_DEEP_NIGHT = intArrayOf(0x01, 0x04, 0x09)
val SHORE_DAY = intArrayOf(0xe8, 0xda, 0xb8)
val SHORE_NIGHT = intArrayOf(0x2c, 0x2a, 0x24)
val PAVEMENT_DAY = intArrayOf(0xb9, 0xb2, 0x9e)
val PAVEMENT_NIGHT = intArrayOf(0x24, 0x25, 0x28)

class CarColor(val body: Int, val cabin: Int)
val CAR_COLORS = arrayOf(
    CarColor(0xf2a93a, 0x2b1900),
    CarColor(0xe6544c, 0x2b0906),
    CarColor(0x4c9fe6, 0x0d1f2b),
    CarColor(0x5fb87a, 0x0d2b17)
)
val TRAFFIC_COLORS = arrayOf(
    CarColor(0xd9534f, 0x222222), CarColor(0x4c9fe6, 0x1a2733), CarColor(0xe0b93c, 0x2a2210),
    CarColor(0x7a8a99, 0x1c2229), CarColor(0x8a5fc9, 0x241833), CarColor(0x5fb87a, 0x172a1c)
)
const val POLICE_BODY = 0x1c2b44
const val POLICE_CABIN = 0x0d1420

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------
fun clamp(v: Double, lo: Double, hi: Double) = if (v < lo) lo else if (v > hi) hi else v
fun clamp01(v: Double) = clamp(v, 0.0, 1.0)
fun lerp(a: Double, b: Double, t: Double) = a + (b - a) * t
fun moveToward(v: Double, target: Double, maxDelta: Double): Double {
    val d = target - v
    if (d > maxDelta) return v + maxDelta
    if (d < -maxDelta) return v - maxDelta
    return target
}
fun angleDiff(a: Double, b: Double): Double {
    var d = ((b - a + PI) % (PI * 2)) - PI
    if (d < -PI) d += PI * 2
    return d
}
fun dist2D(ax: Double, az: Double, bx: Double, bz: Double) = hypot(ax - bx, az - bz)
fun lerpRgb(a: IntArray, b: IntArray, t: Double): IntArray = intArrayOf(
    lerp(a[0].toDouble(), b[0].toDouble(), t).roundToInt().coerceIn(0, 255),
    lerp(a[1].toDouble(), b[1].toDouble(), t).roundToInt().coerceIn(0, 255),
    lerp(a[2].toDouble(), b[2].toDouble(), t).roundToInt().coerceIn(0, 255)
)

// Deterministischer PRNG (mulberry32, bit-identisch zur JS-Fassung) — sorgt
// dafür, dass die Stadt bei jedem Start gleich aufgebaut wird.
class Mulberry32(private var seed: Int) {
    fun next(): Double {
        seed += 0x6D2B79F5
        var t = seed
        t = (t xor (t ushr 15)) * (t or 1)
        t = (t + (t xor (t ushr 7)) * (t or 61)) xor t
        val u = (t xor (t ushr 14)).toLong() and 0xFFFFFFFFL
        return u.toDouble() / 4294967296.0
    }
    fun nextIndex(bound: Int): Int {
        val i = (next() * bound).toInt()
        return if (i >= bound) bound - 1 else i
    }
    fun <T> pick(items: Array<T>): T = items[nextIndex(items.size)]
}

// ---------------------------------------------------------------------------
// Geometrie
// ---------------------------------------------------------------------------
class Rect(val minX: Double, val maxX: Double, val minZ: Double, val maxZ: Double)
class Pt(val x: Double, val z: Double)
class Pos(var x: Double, var z: Double)

fun pushOutRect(pos: Pos, rect: Rect, r: Double): Boolean {
    val insideX = pos.x > rect.minX && pos.x < rect.maxX
    val insideZ = pos.z > rect.minZ && pos.z < rect.maxZ
    if (insideX && insideZ) {
        val dLeft = pos.x - rect.minX; val dRight = rect.maxX - pos.x
        val dTop = pos.z - rect.minZ; val dBottom = rect.maxZ - pos.z
        val m = min(min(dLeft, dRight), min(dTop, dBottom))
        when (m) {
            dLeft -> pos.x = rect.minX - r
            dRight -> pos.x = rect.maxX + r
            dTop -> pos.z = rect.minZ - r
            else -> pos.z = rect.maxZ + r
        }
        return true
    }
    val cx = clamp(pos.x, rect.minX, rect.maxX)
    val cz = clamp(pos.z, rect.minZ, rect.maxZ)
    val dx = pos.x - cx; val dz = pos.z - cz
    val d = hypot(dx, dz)
    if (d >= r || d == 0.0) return false
    val push = (r - d) / d
    pos.x += dx * push
    pos.z += dz * push
    return true
}

fun pushOutCircle(pos: Pos, center: Pos, minD: Double): Boolean {
    val dx = pos.x - center.x; val dz = pos.z - center.z
    var d = hypot(dx, dz)
    if (d == 0.0) d = 0.0001
    if (d >= minD) return false
    val push = (minD - d) / d
    pos.x += dx * push
    pos.z += dz * push
    return true
}

fun rectPerimeterPoints(rect: Rect): List<Pt> = listOf(
    Pt(rect.minX, rect.minZ), Pt(rect.maxX, rect.minZ), Pt(rect.maxX, rect.maxZ), Pt(rect.minX, rect.maxZ)
)

fun pointOnLoop(rect: Rect, pIn: Double): Pt {
    val w = rect.maxX - rect.minX; val h = rect.maxZ - rect.minZ
    val per = 2 * (w + h)
    var p = ((pIn % per) + per) % per
    if (p < w) return Pt(rect.minX + p, rect.minZ)
    p -= w
    if (p < h) return Pt(rect.maxX, rect.minZ + p)
    p -= h
    if (p < w) return Pt(rect.maxX - p, rect.maxZ)
    p -= w
    return Pt(rect.minX, rect.maxZ - p)
}

// ---------------------------------------------------------------------------
// Auto-Physik — gemeinsamer Integrator für Spieler & Polizei.
// ---------------------------------------------------------------------------
open class CarBody(x: Double, z: Double, heading: Double) {
    val pos = Pos(x, z)
    var heading = heading
    var speed = 0.0
    var maxSpeed = MAX_SPEED_FORWARD
}

fun clampToWorldBounds(car: CarBody): Boolean {
    val x = clamp(car.pos.x, -WORLD_HALF_EXTENT + CAR_RADIUS, WORLD_HALF_EXTENT - CAR_RADIUS)
    val z = clamp(car.pos.z, -WORLD_HALF_EXTENT + CAR_RADIUS, WORLD_HALF_EXTENT - CAR_RADIUS)
    val hit = x != car.pos.x || z != car.pos.z
    car.pos.x = x; car.pos.z = z
    return hit
}

fun integrateCarPhysics(car: CarBody, throttle: Boolean, brake: Boolean, steerInput: Double, dt: Double) {
    car.speed = if (brake) {
        if (car.speed > 0.05) moveToward(car.speed, 0.0, BRAKE_DECEL * dt)
        else moveToward(car.speed, MAX_SPEED_REVERSE, ACCEL * dt)
    } else if (throttle) {
        moveToward(car.speed, MAX_SPEED_FORWARD, ACCEL * dt)
    } else {
        moveToward(car.speed, 0.0, DRAG * dt)
    }
    car.speed = clamp(car.speed, MAX_SPEED_REVERSE, car.maxSpeed)

    val speedFactor = clamp(abs(car.speed) / 4.0, 0.15, 1.0) * (1 - clamp01(abs(car.speed) / MAX_SPEED_FORWARD) * 0.4)
    if (abs(car.speed) > 0.3) {
        car.heading += steerInput * STEER_MAX_RATE * speedFactor * dt * sign(car.speed)
    }
    val fx = sin(car.heading); val fz = cos(car.heading)
    car.pos.x += fx * car.speed * dt
    car.pos.z += fz * car.speed * dt
}

// ---------------------------------------------------------------------------
// Welt-Daten
// ---------------------------------------------------------------------------
class RoofDetail(val x: Double, val z: Double, val r: Double)
class BuildingInfo(val rect: Rect, val blockRect: Rect, val color: Int, val height: Double, val roofDetails: List<RoofDetail>)
class ParkInfo(val rect: Rect, val trees: List<Pt>)
class TrafficLightInfo(val x: Double, val z: Double, val phase: Double)
class CoinInfo(val x: Double, val z: Double) { var collected = false }

class World {
    val buildingRects = mutableListOf<Rect>()
    val buildings = mutableListOf<BuildingInfo>()
    val parks = mutableListOf<ParkInfo>()
    val lamps = mutableListOf<Pt>()
    val blockLoops = mutableListOf<Rect>()
    val pedWaypointLoops = mutableListOf<List<Pt>>()
}

// ---------------------------------------------------------------------------
// Bewegliche Objekte
// ---------------------------------------------------------------------------
class Pedestrian(var loopIndex: Int, var nodeIndex: Int, var dir: Int, x: Double, z: Double, val hue: Int) {
    val pos = Pos(x, z)
    var heading = 0.0
    var walkSpeed = PED_WALK_SPEED
    var idleTimer = 0.0
    var fleeing = false
    var fleeTimer = 0.0
    var fleeDirX = 0.0
    var fleeDirZ = 1.0
    var alive = true
    var respawnAt = 0.0
    var deathT = 0.0
    var lastNearMissAt = -99.0
}

class TrafficCarEntity(val loopIndex: Int, var dir: Int, var progress: Double, val cruiseSpeed: Double, val bodyColor: Int, val cabinColor: Int) {
    val pos = Pos(0.0, 0.0)
    var heading = 0.0
    var speed = 0.0
}

class PoliceCarEntity(x: Double, z: Double, heading: Double) : CarBody(x, z, heading) {
    var stuckTimer = 0.0
    var lastCheckX = x
    var lastCheckZ = z
}

class PlayerEntity(x: Double, z: Double, heading: Double) : CarBody(x, z, heading) {
    var health = 100.0
    var hitCooldown = 0.0
    var lastDamageSource: String? = null
}

class Particle(var x: Double, var z: Double, val color: Int, var vx: Double, var vz: Double, var life: Double, val maxLife: Double)

// ---------------------------------------------------------------------------
// Ereignisse, die die UI-Schicht (MainActivity/GameView) braucht.
// ---------------------------------------------------------------------------
interface GameListener {
    fun onToast(text: String, cls: String)
    fun onSfx(name: String)
    fun onRunEnded(source: String, finalScore: Int, best: Int)
}

interface HighscoreStore {
    fun load(): Int
    fun saveIfBetter(value: Int): Int
}

class GameEngine(private val listener: GameListener, private val highscoreStore: HighscoreStore) {
    private val worldRand = Mulberry32(4242)

    // Eigener PRNG-Strom nur für rein kosmetische Details (Dachaufbauten) —
    // bewusst getrennt von worldRand(), damit zusätzliche Deko-Zufallsaufrufe
    // niemals das Stadtlayout verschieben.
    private val decoRand = Mulberry32(31337)

    val world = World()

    val SPAWN_X = -GRID_HALF + floor(GRID_N / 2.0) * GRID_PERIOD
    val SPAWN_Z = 0.0

    var player: PlayerEntity = PlayerEntity(SPAWN_X, SPAWN_Z, 0.0)
        private set
    val pedestrians = mutableListOf<Pedestrian>()
    val trafficCars = mutableListOf<TrafficCarEntity>()
    val policeCars = mutableListOf<PoliceCarEntity>()
    val particles = mutableListOf<Particle>()
    val coins = mutableListOf<CoinInfo>()
    val trafficLights = mutableListOf<TrafficLightInfo>()

    var wantedHeat = 0.0; private set
    var maxWantedReached = 0.0; private set
    private val vehicleHitTimestamps = mutableListOf<Double>()
    private var timeSinceLastPoliceContact = 0.0
    var distanceDriven = 0.0; private set
    var wantedSecondsAccum = 0.0; private set
    private var bonusScore = 0
    var coinsCollected = 0; private set
    private var allCoinsBonusGiven = false
    private var firstWantedShown = false
    private var nextDistanceMilestone = 1000.0

    var dayTime = DAY_LENGTH * 0.05; private set
    var dayFactor = 1.0; private set
    var gameTime = 0.0; private set

    var groundColor = GROUND_DAY; private set
    var waterShallowColor = WATER_SHALLOW_DAY; private set
    var waterDeepColor = WATER_DEEP_DAY; private set
    var shoreColor = SHORE_DAY; private set
    var pavementColor = PAVEMENT_DAY; private set
    var lampGlowAlpha = 0.0; private set

    var density: DensityPreset = DENSITY_PRESETS.getValue("normal")
    var selectedCarColorIndex = 0
    var selectedDensity = "normal"
    var running = false
    var ended = false

    init {
        buildWorld()
    }

    // -----------------------------------------------------------------------
    // Weltaufbau — deterministisch aus worldRand(). Straßen sind die
    // Rasterlinien alle GRID_PERIOD Einheiten; jeder Block dazwischen ist
    // entweder Park oder Gebäude, umgeben vom Gehweg-Ring.
    // -----------------------------------------------------------------------
    private fun blockMin(i: Int) = -GRID_HALF + i * GRID_PERIOD + STREET_WIDTH

    private fun makeRoofDetails(rect: Rect): List<RoofDetail> {
        val w = rect.maxX - rect.minX; val h = rect.maxZ - rect.minZ
        val count = (decoRand.next() * 3).toInt()
        val items = mutableListOf<RoofDetail>()
        repeat(count) {
            items.add(
                RoofDetail(
                    lerp(w * 0.2, w * 0.8, decoRand.next()),
                    lerp(h * 0.2, h * 0.8, decoRand.next()),
                    lerp(0.6, 1.3, decoRand.next())
                )
            )
        }
        return items
    }

    private fun buildWorld() {
        for (i in 0 until GRID_N) {
            val bxMin = blockMin(i); val bxMax = bxMin + BLOCK_SIZE
            for (j in 0 until GRID_N) {
                val bzMin = blockMin(j); val bzMax = bzMin + BLOCK_SIZE

                val isPark = worldRand.next() < PARK_BLOCK_CHANCE
                if (isPark) {
                    val rect = Rect(bxMin, bxMax, bzMin, bzMax)
                    val treeCount = 3 + (worldRand.next() * 4).toInt()
                    val trees = mutableListOf<Pt>()
                    repeat(treeCount) {
                        trees.add(
                            Pt(
                                lerp(rect.minX + 2, rect.maxX - 2, worldRand.next()),
                                lerp(rect.minZ + 2, rect.maxZ - 2, worldRand.next())
                            )
                        )
                    }
                    world.parks.add(ParkInfo(rect, trees))
                } else {
                    val insetMinX = bxMin + SIDEWALK_WIDTH; val insetMinZ = bzMin + SIDEWALK_WIDTH
                    val insetMaxX = bxMax - SIDEWALK_WIDTH; val insetMaxZ = bzMax - SIDEWALK_WIDTH
                    val availW = insetMaxX - insetMinX; val availD = insetMaxZ - insetMinZ
                    val footW = availW * lerp(0.6, 0.9, worldRand.next())
                    val footD = availD * lerp(0.6, 0.9, worldRand.next())
                    val offX = (availW - footW) * worldRand.next()
                    val offZ = (availD - footD) * worldRand.next()
                    val rect = Rect(insetMinX + offX, insetMinX + offX + footW, insetMinZ + offZ, insetMinZ + offZ + footD)
                    val height = lerp(BUILDING_MIN_H, BUILDING_MAX_H, worldRand.next())
                    val color = worldRand.pick(BUILDING_COLORS.toTypedArray())
                    val blockRect = Rect(bxMin, bxMax, bzMin, bzMax)
                    world.buildingRects.add(rect)
                    world.buildings.add(BuildingInfo(rect, blockRect, color, height, makeRoofDetails(rect)))
                }

                // Gehweg-Wegpunktschleife: Ring knapp innerhalb der Blockkante.
                val wpRect = Rect(
                    bxMin + SIDEWALK_WIDTH / 2, bxMax - SIDEWALK_WIDTH / 2,
                    bzMin + SIDEWALK_WIDTH / 2, bzMax - SIDEWALK_WIDTH / 2
                )
                val loopPoints = rectPerimeterPoints(wpRect)
                world.pedWaypointLoops.add(loopPoints)
                world.lamps.add(loopPoints[0])
                world.lamps.add(loopPoints[2])

                // Verkehrs-Umlauf: Straßenmitte rund um diesen Block.
                world.blockLoops.add(
                    Rect(bxMin - STREET_WIDTH / 2, bxMax + STREET_WIDTH / 2, bzMin - STREET_WIDTH / 2, bzMax + STREET_WIDTH / 2)
                )
            }
        }

        // Münzen entlang der Straßen-Umläufe verstreut.
        repeat(COIN_COUNT) {
            val loopRect = world.blockLoops[worldRand.nextIndex(world.blockLoops.size)]
            val per = 2 * ((loopRect.maxX - loopRect.minX) + (loopRect.maxZ - loopRect.minZ))
            val p = pointOnLoop(loopRect, worldRand.next() * per)
            coins.add(CoinInfo(p.x, p.z))
        }

        // Ampeln an jeder Straßenkreuzung — rein dekorativ.
        for (k in 0..GRID_N) {
            for (j in 0..GRID_N) {
                val ix = -GRID_HALF + k * GRID_PERIOD; val iz = -GRID_HALF + j * GRID_PERIOD
                val offset = STREET_WIDTH / 2 + 0.6
                trafficLights.add(TrafficLightInfo(ix + offset, iz + offset, worldRand.next() * TRAFFIC_LIGHT_CYCLE))
            }
        }
    }

    private fun resolveWorldCollisions(car: CarBody): Boolean {
        var hit = false
        for (rect in world.buildingRects) {
            if (pushOutRect(car.pos, rect, CAR_RADIUS)) hit = true
        }
        if (clampToWorldBounds(car)) hit = true
        return hit
    }

    // -----------------------------------------------------------------------
    // Fußgänger
    // -----------------------------------------------------------------------
    private fun spawnPedestrian() {
        val loopIndex = worldRand.nextIndex(world.pedWaypointLoops.size)
        val loop = world.pedWaypointLoops[loopIndex]
        val nodeIndex = worldRand.nextIndex(loop.size)
        val start = loop[nodeIndex]
        val ped = Pedestrian(
            loopIndex, nodeIndex,
            dir = if (worldRand.next() < 0.5) 1 else -1,
            x = start.x, z = start.z,
            hue = (worldRand.next() * 360).toInt()
        )
        ped.walkSpeed = PED_WALK_SPEED * lerp(PED_WALK_SPEED_MIN_MUL, PED_WALK_SPEED_MAX_MUL, worldRand.next())
        pedestrians.add(ped)
    }

    private fun updatePedestrian(ped: Pedestrian, dt: Double) {
        if (!ped.alive) {
            ped.deathT = min(1.0, ped.deathT + dt / PED_DEATH_ANIM_TIME)
            if (gameTime >= ped.respawnAt) {
                val loopIndex = worldRand.nextIndex(world.pedWaypointLoops.size)
                val loop = world.pedWaypointLoops[loopIndex]
                val nodeIndex = worldRand.nextIndex(loop.size)
                val start = loop[nodeIndex]
                ped.loopIndex = loopIndex; ped.nodeIndex = nodeIndex
                ped.pos.x = start.x; ped.pos.z = start.z
                ped.walkSpeed = PED_WALK_SPEED * lerp(PED_WALK_SPEED_MIN_MUL, PED_WALK_SPEED_MAX_MUL, worldRand.next())
                ped.idleTimer = 0.0
                ped.fleeing = false; ped.alive = true; ped.deathT = 0.0
            }
            return
        }
        val distToPlayer = dist2D(ped.pos.x, ped.pos.z, player.pos.x, player.pos.z)
        if (!ped.fleeing && distToPlayer < FLEE_RADIUS && abs(player.speed) > 3) {
            ped.fleeing = true
            ped.fleeTimer = FLEE_DURATION
            val dx = ped.pos.x - player.pos.x; val dz = ped.pos.z - player.pos.z
            var d = hypot(dx, dz)
            if (d == 0.0) d = 1.0
            ped.fleeDirX = dx / d; ped.fleeDirZ = dz / d
        }
        if (ped.fleeing) {
            ped.fleeTimer -= dt
            ped.pos.x += ped.fleeDirX * PED_FLEE_SPEED * dt
            ped.pos.z += ped.fleeDirZ * PED_FLEE_SPEED * dt
            ped.heading = atan2(ped.fleeDirX, ped.fleeDirZ)
            if (ped.fleeTimer <= 0) ped.fleeing = false
        } else if (ped.idleTimer > 0) {
            ped.idleTimer = (ped.idleTimer - dt).coerceAtLeast(0.0)
        } else {
            val loop = world.pedWaypointLoops[ped.loopIndex]
            val target = loop[((ped.nodeIndex + ped.dir) % loop.size + loop.size) % loop.size]
            val dx = target.x - ped.pos.x; val dz = target.z - ped.pos.z
            val d = hypot(dx, dz)
            if (d < 0.4) {
                ped.nodeIndex = ((ped.nodeIndex + ped.dir) % loop.size + loop.size) % loop.size
                if (worldRand.next() < 0.15) ped.dir *= -1

                // Gelegenheit, die Straße zu überqueren und im Nachbarblock
                // weiterzulaufen, statt für immer im selben Block zu kreisen.
                if (worldRand.next() < PED_CROSSING_CHANCE) {
                    val bi = ped.loopIndex / GRID_N; val bj = ped.loopIndex % GRID_N
                    val options = PED_NODE_CROSSINGS[ped.nodeIndex]
                    val choice = options[worldRand.nextIndex(options.size)]
                    val ni = bi + choice.di; val nj = bj + choice.dj
                    if (ni in 0 until GRID_N && nj in 0 until GRID_N) {
                        ped.loopIndex = ni * GRID_N + nj
                        ped.nodeIndex = choice.mirror
                    }
                } else if (worldRand.next() < PED_IDLE_CHANCE) {
                    ped.idleTimer = lerp(PED_IDLE_MIN, PED_IDLE_MAX, worldRand.next())
                }
            } else {
                ped.pos.x += (dx / d) * ped.walkSpeed * dt
                ped.pos.z += (dz / d) * ped.walkSpeed * dt
                ped.heading = atan2(dx / d, dz / d)
            }
        }
    }

    private fun killPedestrian(ped: Pedestrian) {
        ped.alive = false
        ped.deathT = 0.0
        ped.respawnAt = gameTime + PED_RESPAWN_DELAY
        spawnParticles(ped.pos.x, ped.pos.z, 0xe6544c, 8)
        listener.onSfx("hit")
    }

    // -----------------------------------------------------------------------
    // Verkehr (Ambient-KI: fester Rechteck-Umlauf je Block)
    // -----------------------------------------------------------------------
    private fun spawnTrafficCar() {
        val loopIndex = worldRand.nextIndex(world.blockLoops.size)
        val rect = world.blockLoops[loopIndex]
        val per = 2 * ((rect.maxX - rect.minX) + (rect.maxZ - rect.minZ))
        val colors = worldRand.pick(TRAFFIC_COLORS)
        val car = TrafficCarEntity(
            loopIndex,
            dir = if (worldRand.next() < 0.5) 1 else -1,
            progress = worldRand.next() * per,
            cruiseSpeed = lerp(TRAFFIC_SPEED_MIN, TRAFFIC_SPEED_MAX, worldRand.next()),
            bodyColor = colors.body, cabinColor = colors.cabin
        )
        val p0 = pointOnLoop(rect, car.progress)
        car.pos.x = p0.x; car.pos.z = p0.z
        trafficCars.add(car)
    }

    private fun updateTrafficCar(car: TrafficCarEntity, dt: Double) {
        val rect = world.blockLoops[car.loopIndex]
        var targetSpeed = car.cruiseSpeed
        for (other in trafficCars) {
            if (other === car || other.loopIndex != car.loopIndex || other.dir != car.dir) continue
            val w = rect.maxX - rect.minX; val h = rect.maxZ - rect.minZ
            val per = 2 * (w + h)
            var gap = (other.progress - car.progress) * car.dir
            gap = ((gap % per) + per) % per
            val stoppingDistance = 2 + car.speed * 0.6
            if (gap > 0 && gap < stoppingDistance) {
                targetSpeed = min(targetSpeed, other.speed * (gap / stoppingDistance))
            }
        }
        car.speed = moveToward(car.speed, targetSpeed, TRAFFIC_MAX_ACCEL * dt)
        car.progress += car.dir * car.speed * dt
        val pos = pointOnLoop(rect, car.progress)
        val ahead = pointOnLoop(rect, car.progress + car.dir * 0.6)
        car.pos.x = pos.x; car.pos.z = pos.z
        car.heading = atan2(ahead.x - pos.x, ahead.z - pos.z)
    }

    // -----------------------------------------------------------------------
    // Polizei
    // -----------------------------------------------------------------------
    private fun spawnPoliceCar() {
        val ang = worldRand.next() * PI * 2
        val d = lerp(POLICE_SPAWN_MIN_DIST, POLICE_SPAWN_MAX_DIST, worldRand.next())
        val x = clamp(player.pos.x + sin(ang) * d, -WORLD_HALF_EXTENT + 5, WORLD_HALF_EXTENT - 5)
        val z = clamp(player.pos.z + cos(ang) * d, -WORLD_HALF_EXTENT + 5, WORLD_HALF_EXTENT - 5)
        val car = PoliceCarEntity(x, z, ang)
        car.maxSpeed = POLICE_MAX_SPEED
        policeCars.add(car)
    }

    private fun despawnPoliceCar(p: PoliceCarEntity) {
        policeCars.remove(p)
    }

    private fun updatePoliceCar(p: PoliceCarEntity, dt: Double) {
        val desiredHeading = atan2(player.pos.x - p.pos.x, player.pos.z - p.pos.z)
        val steer = clamp(angleDiff(p.heading, desiredHeading) * 2, -1.0, 1.0)
        integrateCarPhysics(p, true, false, steer, dt)
        val hit = resolveWorldCollisions(p)
        if (hit) p.speed *= 0.5
        p.stuckTimer += dt
        if (p.stuckTimer > POLICE_STUCK_TIME) {
            val moved = dist2D(p.pos.x, p.pos.z, p.lastCheckX, p.lastCheckZ)
            p.stuckTimer = 0.0
            p.lastCheckX = p.pos.x; p.lastCheckZ = p.pos.z
            if (moved < 2) {
                despawnPoliceCar(p)
                spawnPoliceCar()
            }
        }
    }

    // -----------------------------------------------------------------------
    // Fahndungsstufe: Erhöhung, Polizei-Spawn/-Abzug, Schaden
    // -----------------------------------------------------------------------
    private fun addHeat(amount: Double) {
        val before = wantedHeat
        wantedHeat = clamp(wantedHeat + amount, 0.0, 5.0)
        if (wantedHeat > before) {
            listener.onSfx("heatUp")
            if (before < 1 && wantedHeat >= 1 && !firstWantedShown) {
                firstWantedShown = true
                listener.onToast("Erste Fahndungsstufe! Die Polizei ist alarmiert.", "bad")
            } else {
                listener.onToast("Fahndungsstufe erhöht!", "bad")
            }
        }
        maxWantedReached = maxOf(maxWantedReached, wantedHeat)
    }

    private fun registerVehicleHit() {
        vehicleHitTimestamps.add(gameTime)
        vehicleHitTimestamps.removeAll { gameTime - it > RECKLESS_WINDOW }
        if (vehicleHitTimestamps.size >= RECKLESS_CAR_HITS_THRESHOLD) {
            addHeat(RECKLESS_HEAT)
            vehicleHitTimestamps.clear()
        }
    }

    private fun maintainPolice(dt: Double) {
        val desired = if (wantedHeat >= 1) min(ceil(wantedHeat).toInt(), density.policeMaxCars) else 0
        while (policeCars.size < desired) spawnPoliceCar()

        var anyNear = false
        for (p in policeCars) {
            if (dist2D(p.pos.x, p.pos.z, player.pos.x, player.pos.z) < POLICE_PROXIMITY_DECAY_RADIUS) { anyNear = true; break }
        }
        if (wantedHeat > 0) {
            if (anyNear) {
                timeSinceLastPoliceContact = 0.0
            } else {
                timeSinceLastPoliceContact += dt
                if (timeSinceLastPoliceContact >= density.evadeTime) {
                    timeSinceLastPoliceContact = 0.0
                    wantedHeat = maxOf(0.0, wantedHeat - 1)
                    listener.onSfx("heatDown")
                    listener.onToast("Fahndungsstufe sinkt", "good")
                    if (policeCars.isNotEmpty()) despawnPoliceCar(policeCars.last())
                }
            }
        }
        if (wantedHeat <= 0 && policeCars.isNotEmpty()) {
            for (i in policeCars.indices.reversed()) despawnPoliceCar(policeCars[i])
        }
    }

    private fun applyDamage(amount: Double, source: String) {
        if (ended) return
        player.health = clamp(player.health - amount, 0.0, 100.0)
        player.lastDamageSource = source
        if (player.health <= 0) endRun(source)
    }

    // -----------------------------------------------------------------------
    // Spieler-Kollisionen gegen Fußgänger / Verkehr / Polizei
    // -----------------------------------------------------------------------
    private fun checkPlayerVsPedestrians() {
        if (abs(player.speed) < MIN_HIT_SPEED) return
        for (ped in pedestrians) {
            if (!ped.alive) continue
            if (dist2D(player.pos.x, player.pos.z, ped.pos.x, ped.pos.z) < CAR_RADIUS + PED_RADIUS) {
                killPedestrian(ped)
                addHeat(PED_HIT_HEAT)
                player.hitCooldown = 0.3
            }
        }
    }

    private fun checkPlayerVsTraffic() {
        for (car in trafficCars) {
            val minD = CAR_RADIUS * 2
            if (dist2D(player.pos.x, player.pos.z, car.pos.x, car.pos.z) < minD) {
                if (player.hitCooldown <= 0) {
                    val impact = abs(player.speed - car.speed)
                    applyDamage(maxOf(2.0, impact * 1.5), "traffic")
                    registerVehicleHit()
                    listener.onSfx("crash")
                    spawnParticles(player.pos.x, player.pos.z, 0xffcf7a, 10)
                    player.speed *= 0.35
                    player.hitCooldown = 0.5
                }
                pushOutCircle(player.pos, car.pos, minD)
            }
        }
    }

    private fun checkPlayerVsPolice() {
        for (car in policeCars) {
            val minD = CAR_RADIUS * 2
            if (dist2D(player.pos.x, player.pos.z, car.pos.x, car.pos.z) < minD) {
                if (player.hitCooldown <= 0) {
                    val impact = abs(player.speed - car.speed)
                    applyDamage(maxOf(6.0, impact * 3.0), "police")
                    registerVehicleHit()
                    if (wantedHeat >= 1) addHeat(POLICE_HIT_HEAT)
                    listener.onSfx("crash")
                    spawnParticles(player.pos.x, player.pos.z, 0x4c9fe6, 10)
                    player.speed *= 0.35
                    player.hitCooldown = 0.5
                }
                pushOutCircle(player.pos, car.pos, minD)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Münzen, Beinahe-Unfälle, Partikel
    // -----------------------------------------------------------------------
    private fun updateCoins() {
        for (c in coins) {
            if (c.collected) continue
            if (dist2D(player.pos.x, player.pos.z, c.x, c.z) < CAR_RADIUS + COIN_PICKUP_RADIUS) {
                c.collected = true
                coinsCollected++
                bonusScore += COIN_SCORE
                listener.onSfx("coin")
                spawnParticles(c.x, c.z, 0xffd75e, 6)
                if (!allCoinsBonusGiven && coinsCollected == coins.size) {
                    allCoinsBonusGiven = true
                    bonusScore += ALL_COINS_BONUS
                    listener.onToast("Alle Münzen eingesammelt! Bonus: +$ALL_COINS_BONUS", "gold")
                }
            }
        }
    }

    private fun checkNearMisses() {
        if (abs(player.speed) < NEAR_MISS_MIN_SPEED) return
        for (ped in pedestrians) {
            if (!ped.alive) continue
            val d = dist2D(player.pos.x, player.pos.z, ped.pos.x, ped.pos.z)
            if (d >= NEAR_MISS_MIN_GAP && d < NEAR_MISS_MAX_GAP && (gameTime - ped.lastNearMissAt) > NEAR_MISS_COOLDOWN) {
                ped.lastNearMissAt = gameTime
                bonusScore += NEAR_MISS_SCORE
                listener.onToast("Knapp vorbei! +$NEAR_MISS_SCORE", "good")
                listener.onSfx("nearMiss")
            }
        }
    }

    private fun spawnParticles(x: Double, z: Double, color: Int, count: Int) {
        repeat(count) {
            val ang = Random.nextDouble() * PI * 2
            val spd = 2.5 + Random.nextDouble() * 4
            particles.add(
                Particle(
                    x, z, color,
                    vx = cos(ang) * spd, vz = sin(ang) * spd,
                    life = 0.5 + Random.nextDouble() * 0.35, maxLife = 0.85
                )
            )
        }
    }

    private fun updateParticles(dt: Double) {
        val it = particles.iterator()
        while (it.hasNext()) {
            val p = it.next()
            p.x += p.vx * dt; p.z += p.vz * dt
            p.vx *= (1 - 2.5 * dt); p.vz *= (1 - 2.5 * dt)
            p.life -= dt
            if (p.life <= 0) it.remove()
        }
    }

    // -----------------------------------------------------------------------
    // Tag/Nacht-Zyklus
    // -----------------------------------------------------------------------
    private fun updateDayNight(dt: Double) {
        dayTime = (dayTime + dt) % DAY_LENGTH
        val t = dayTime / DAY_LENGTH
        dayFactor = (cos(t * PI * 2) + 1) / 2
        groundColor = lerpRgb(GROUND_NIGHT, GROUND_DAY, dayFactor)
        waterShallowColor = lerpRgb(WATER_SHALLOW_NIGHT, WATER_SHALLOW_DAY, dayFactor)
        waterDeepColor = lerpRgb(WATER_DEEP_NIGHT, WATER_DEEP_DAY, dayFactor)
        shoreColor = lerpRgb(SHORE_NIGHT, SHORE_DAY, dayFactor)
        pavementColor = lerpRgb(PAVEMENT_NIGHT, PAVEMENT_DAY, dayFactor)
        lampGlowAlpha = clamp01((0.55 - dayFactor) / 0.55)
    }

    // -----------------------------------------------------------------------
    // Score / Run-Lifecycle
    // -----------------------------------------------------------------------
    fun currentScore(): Int = floor(distanceDriven).toInt() + 50 * floor(wantedSecondsAccum).toInt() + bonusScore

    private fun endRun(source: String) {
        if (ended) return
        ended = true
        running = false
        val finalScore = currentScore()
        val best = highscoreStore.saveIfBetter(finalScore)
        listener.onSfx("busted")
        listener.onRunEnded(source, finalScore, best)
    }

    fun resetRunState() {
        pedestrians.clear()
        trafficCars.clear()
        policeCars.clear()
        particles.clear()

        player = PlayerEntity(SPAWN_X, SPAWN_Z, 0.0)

        repeat(density.pedCount) { spawnPedestrian() }
        repeat(density.trafficCount) { spawnTrafficCar() }

        coins.forEach { it.collected = false }

        wantedHeat = 0.0
        maxWantedReached = 0.0
        vehicleHitTimestamps.clear()
        timeSinceLastPoliceContact = 0.0
        distanceDriven = 0.0
        wantedSecondsAccum = 0.0
        bonusScore = 0
        coinsCollected = 0
        allCoinsBonusGiven = false
        firstWantedShown = false
        nextDistanceMilestone = 1000.0
        dayTime = DAY_LENGTH * 0.05
        gameTime = 0.0
        ended = false
    }

    /** Ein Simulationsschritt; von GameView einmal pro Frame aufgerufen. */
    fun update(dt: Double, throttle: Boolean, brake: Boolean, steerInput: Double) {
        if (!running || ended) return
        gameTime += dt

        integrateCarPhysics(player, throttle, brake, steerInput, dt)
        val hitWorld = resolveWorldCollisions(player)
        if (hitWorld) {
            if (player.hitCooldown <= 0) {
                applyDamage(maxOf(2.0, abs(player.speed) * 1.2), "crash")
                listener.onSfx("crash")
                spawnParticles(player.pos.x, player.pos.z, 0xaaaaaa, 6)
                player.hitCooldown = 0.4
            }
            player.speed *= 0.3
        }
        player.hitCooldown = maxOf(0.0, player.hitCooldown - dt)

        pedestrians.forEach { updatePedestrian(it, dt) }
        trafficCars.forEach { updateTrafficCar(it, dt) }
        for (i in policeCars.indices.reversed()) updatePoliceCar(policeCars[i], dt)

        if (!ended) checkPlayerVsPedestrians()
        if (!ended) checkPlayerVsTraffic()
        if (!ended) checkPlayerVsPolice()
        if (!ended) checkNearMisses()
        if (!ended) maintainPolice(dt)

        if (!ended && wantedHeat <= 0 && player.hitCooldown <= 0) {
            player.health = clamp(player.health + HEALTH_REGEN * dt, 0.0, 100.0)
        }

        distanceDriven += abs(player.speed) * dt
        if (wantedHeat >= 1) wantedSecondsAccum += dt
        if (distanceDriven >= nextDistanceMilestone) {
            listener.onToast("${nextDistanceMilestone.toInt()} m gefahren!", "good")
            nextDistanceMilestone += 1000
        }

        updateCoins()
        updateDayNight(dt)
        updateParticles(dt)
    }
}
