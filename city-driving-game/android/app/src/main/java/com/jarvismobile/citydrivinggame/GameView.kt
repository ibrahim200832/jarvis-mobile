package com.jarvismobile.citydrivinggame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.view.Choreographer
import android.view.KeyEvent
import android.view.View
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * 2D-Top-Down-Rendering + Game-Loop, gezeichnet direkt mit
 * android.graphics.Canvas (kein WebView, kein Browser-Renderer). Feste
 * Nordausrichtung, die Kamera folgt nur der Spielerposition (keine
 * Kartenrotation) — funktional identisch zum ursprünglichen
 * Canvas2D-Prototyp, nur die Zeichen-API ist jetzt nativ.
 */
class GameView(context: Context, attrs: AttributeSet?) : View(context, attrs), Choreographer.FrameCallback {

    lateinit var engine: GameEngine
    var onFrame: (() -> Unit)? = null

    // ---- Eingabe (von MainActivity/Touch-Buttons gesetzt) ----
    var touchSteer = 0.0
    var touchGas = false
    var touchBrake = false
    private var keyLeft = false
    private var keyRight = false
    private var keyUp = false
    private var keyDown = false

    private var scale = 16.0
    private var viewW = 0.0
    private var viewH = 0.0
    private var lastFrameNanos = 0L
    private var running = false

    private val texRand = Mulberry32(31337)
    private var terrainTexture: Bitmap? = null
    private var waterSheen: Bitmap? = null

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val fillPath = Path()

    init {
        isFocusable = true
        isFocusableInTouchMode = true
    }

    fun attach(engine: GameEngine, onFrame: () -> Unit) {
        this.engine = engine
        this.onFrame = onFrame
        if (terrainTexture == null) terrainTexture = generateTerrainTexture()
    }

    fun startLoop() {
        if (running) return
        running = true
        lastFrameNanos = 0L
        Choreographer.getInstance().postFrameCallback(this)
    }

    fun stopLoop() {
        running = false
        Choreographer.getInstance().removeFrameCallback(this)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        viewW = w.toDouble()
        viewH = h.toDouble()
        // dp-normalisierte Breite statt Rohpixel, damit die Zoomstufe auf
        // jeder Displaydichte gleich "groß" wirkt (analog zu CSS-Pixeln im
        // ursprünglichen Web-Prototyp).
        val density = resources.displayMetrics.density.toDouble()
        val widthDp = if (density > 0) viewW / density else viewW
        scale = clamp(widthDp / 46.0, 11.0, 22.0) * density
        waterSheen = generateWaterSheen(w, h)
    }

    override fun doFrame(frameTimeNanos: Long) {
        if (!running) return
        Choreographer.getInstance().postFrameCallback(this)
        if (lastFrameNanos == 0L) lastFrameNanos = frameTimeNanos
        var dt = (frameTimeNanos - lastFrameNanos) / 1_000_000_000.0
        lastFrameNanos = frameTimeNanos
        dt = min(dt, 0.05)

        if (::engine.isInitialized) {
            val steerInput = clamp((if (keyLeft) -1.0 else 0.0) + (if (keyRight) 1.0 else 0.0) + touchSteer, -1.0, 1.0)
            val throttle = keyUp || touchGas
            val brake = keyDown || touchBrake
            engine.update(dt, throttle, brake, steerInput)
        }
        onFrame?.invoke()
        invalidate()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_A -> keyLeft = true
            KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_D -> keyRight = true
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_W -> keyUp = true
            KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_S -> keyDown = true
            else -> return super.onKeyDown(keyCode, event)
        }
        return true
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_A -> keyLeft = false
            KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_D -> keyRight = false
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_W -> keyUp = false
            KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_S -> keyDown = false
            else -> return super.onKeyUp(keyCode, event)
        }
        return true
    }

    // -------------------------------------------------------------------
    // Texturen: einmal (bzw. bei Größenänderung fürs Wasser) vorberechnete
    // Bitmaps statt teurer Pro-Frame-Rauschgenerierung.
    // -------------------------------------------------------------------
    private fun makeBlotchTexture(w: Int, h: Int, tones: IntArray, alphas: DoubleArray, count: Int, minR: Double, maxR: Double, rand: Mulberry32): Bitmap {
        val bmp = Bitmap.createBitmap(max(1, w), max(1, h), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        repeat(count) {
            val x = (rand.next() * w).toFloat()
            val y = (rand.next() * h).toFloat()
            val r = lerp(minR, maxR, rand.next()).toFloat()
            val idx = rand.nextIndex(tones.size)
            val tone = tones[idx]
            val alpha = (alphas[idx] * 255).toInt().coerceIn(0, 255)
            val color = Color.argb(alpha, (tone shr 16) and 0xFF, (tone shr 8) and 0xFF, tone and 0xFF)
            p.shader = RadialGradient(x, y, max(1f, r), color, Color.TRANSPARENT, Shader.TileMode.CLAMP)
            c.drawCircle(x, y, r, p)
        }
        return bmp
    }

    private fun generateTerrainTexture(): Bitmap = makeBlotchTexture(
        1400, 1400,
        intArrayOf(0x465a37, 0x5f643c, 0x2d3e2a, 0x7d7152),
        doubleArrayOf(0.35, 0.28, 0.32, 0.22),
        260, 12.0, 60.0, texRand
    )

    private fun generateWaterSheen(w: Int, h: Int): Bitmap {
        val count = max(20, ((w.toLong() * h) / 9000L).toInt())
        val sheenRand = Mulberry32(4242 xor (w * 31 + h))
        return makeBlotchTexture(
            w, h,
            intArrayOf(0xffffff, 0xffffff, 0x001428),
            doubleArrayOf(0.10, 0.05, 0.18),
            count, 20.0, 90.0, sheenRand
        )
    }

    // -------------------------------------------------------------------
    // Weltraum <-> Bildschirm
    // -------------------------------------------------------------------
    private fun toScreenX(wx: Double) = (viewW / 2 + (wx - engine.player.pos.x) * scale).toFloat()
    private fun toScreenY(wz: Double) = (viewH / 2 + (wz - engine.player.pos.z) * scale).toFloat()
    private fun viewRadiusWorld() = hypot(viewW, viewH) / 2 / scale + 25
    private fun nearPlayer(x: Double, z: Double, margin: Double) =
        dist2D(x, z, engine.player.pos.x, engine.player.pos.z) < viewRadiusWorld() + margin

    private fun roundRect(x: Float, y: Float, w: Float, h: Float, r: Float): Path {
        fillPath.reset()
        fillPath.addRoundRect(RectF(x, y, x + w, y + h), r, r, Path.Direction.CW)
        return fillPath
    }

    private fun rgb(hex: Int, alpha: Int = 255): Int =
        Color.argb(alpha, (hex shr 16) and 0xFF, (hex shr 8) and 0xFF, hex and 0xFF)

    private fun rgbArr(a: IntArray, alpha: Int = 255): Int = Color.argb(alpha, a[0], a[1], a[2])

    override fun onDraw(canvas: Canvas) {
        if (!::engine.isInitialized) return
        val e = engine

        drawWater(canvas, e)

        val gTLx = toScreenX(-WORLD_HALF_EXTENT); val gTLy = toScreenY(-WORLD_HALF_EXTENT)
        val gBRx = toScreenX(WORLD_HALF_EXTENT); val gBRy = toScreenY(WORLD_HALF_EXTENT)
        val gw = gBRx - gTLx; val gh = gBRy - gTLy
        val coastR = max(0f, min(16f * scale.toFloat(), min(gw / 2, gh / 2)))
        val shoreWidth = max(4f, (3 * scale).toFloat())

        paint.shader = null
        paint.style = Paint.Style.FILL
        paint.color = rgbArr(e.shoreColor)
        canvas.drawPath(roundRect(gTLx, gTLy, gw, gh, coastR), paint)

        canvas.save()
        canvas.clipPath(
            roundRect(
                gTLx + shoreWidth, gTLy + shoreWidth,
                max(0f, gw - shoreWidth * 2), max(0f, gh - shoreWidth * 2),
                max(0f, coastR - shoreWidth)
            )
        )
        paint.color = rgbArr(e.groundColor)
        canvas.drawRect(gTLx, gTLy, gBRx, gBRy, paint)
        drawTerrainPatch(canvas, Rect(-WORLD_HALF_EXTENT, WORLD_HALF_EXTENT, -WORLD_HALF_EXTENT, WORLD_HALF_EXTENT), 255)
        drawParks(canvas, e)
        drawStreetGrid(canvas, e)
        drawBuildings(canvas, e)
        if (1 - e.dayFactor > 0.02) {
            paint.color = rgb(0x060810, (0.55 * (1 - e.dayFactor) * 255).toInt())
            canvas.drawRect(gTLx, gTLy, gBRx, gBRy, paint)
        }
        drawLamps(canvas, e)
        drawTrafficLights(canvas, e)
        drawCoins(canvas, e)
        canvas.restore()

        drawPedestrians(canvas, e)
        for (c in e.trafficCars) {
            if (nearPlayer(c.pos.x, c.pos.z, 4.0)) drawCar(canvas, c.pos.x, c.pos.z, c.heading, c.bodyColor, c.cabinColor, false)
        }
        for (p in e.policeCars) {
            if (nearPlayer(p.pos.x, p.pos.z, 4.0)) drawCar(canvas, p.pos.x, p.pos.z, p.heading, POLICE_BODY, POLICE_CABIN, true)
        }
        val carColor = CAR_COLORS.getOrElse(e.selectedCarColorIndex) { CAR_COLORS[0] }
        drawCar(canvas, e.player.pos.x, e.player.pos.z, e.player.heading, carColor.body, carColor.cabin, false)
        drawParticles(canvas, e)
    }

    private fun drawWater(canvas: Canvas, e: GameEngine) {
        paint.shader = LinearGradient(
            0f, 0f, 0f, viewH.toFloat(),
            rgbArr(e.waterDeepColor), rgbArr(e.waterShallowColor), Shader.TileMode.CLAMP
        )
        paint.style = Paint.Style.FILL
        canvas.drawRect(0f, 0f, viewW.toFloat(), viewH.toFloat(), paint)
        paint.shader = null
        waterSheen?.let {
            paint.alpha = (0.85 * 255).toInt()
            canvas.drawBitmap(it, 0f, 0f, paint)
            paint.alpha = 255
        }
    }

    private fun drawTerrainPatch(canvas: Canvas, rect: Rect, alpha: Int) {
        val tex = terrainTexture ?: return
        val worldSize = WORLD_HALF_EXTENT * 2
        val texW = tex.width; val texH = tex.height
        val sx = ((rect.minX + WORLD_HALF_EXTENT) / worldSize * texW).toInt()
        val sy = ((rect.minZ + WORLD_HALF_EXTENT) / worldSize * texH).toInt()
        val sw = ((rect.maxX - rect.minX) / worldSize * texW).toInt().coerceAtLeast(1)
        val sh = ((rect.maxZ - rect.minZ) / worldSize * texH).toInt().coerceAtLeast(1)
        val srcRight = (sx + sw).coerceAtMost(texW)
        val srcBottom = (sy + sh).coerceAtMost(texH)
        if (sx >= srcRight || sy >= srcBottom) return
        val src = android.graphics.Rect(sx, sy, srcRight, srcBottom)
        val dst = RectF(toScreenX(rect.minX), toScreenY(rect.minZ), toScreenX(rect.maxX), toScreenY(rect.maxZ))
        paint.alpha = alpha
        canvas.drawBitmap(tex, src, dst, paint)
        paint.alpha = 255
    }

    private fun drawStreetGrid(canvas: Canvas, e: GameEngine) {
        val vr = viewRadiusWorld()
        val kMin = floor((e.player.pos.x - vr + GRID_HALF) / GRID_PERIOD).toInt() - 1
        val kMax = ceil((e.player.pos.x + vr + GRID_HALF) / GRID_PERIOD).toInt() + 1
        val jMin = floor((e.player.pos.z - vr + GRID_HALF) / GRID_PERIOD).toInt() - 1
        val jMax = ceil((e.player.pos.z + vr + GRID_HALF) / GRID_PERIOD).toInt() + 1
        val halfPx = (STREET_WIDTH / 2 * scale).toFloat()

        paint.shader = null
        paint.style = Paint.Style.FILL
        paint.color = rgb(0x33383f)
        for (k in kMin..kMax) {
            val sx = toScreenX(-GRID_HALF + k * GRID_PERIOD)
            canvas.drawRect(sx - halfPx, 0f, sx + halfPx, viewH.toFloat(), paint)
        }
        for (k in jMin..jMax) {
            val sy = toScreenY(-GRID_HALF + k * GRID_PERIOD)
            canvas.drawRect(0f, sy - halfPx, viewW.toFloat(), sy + halfPx, paint)
        }

        paint.style = Paint.Style.STROKE
        paint.color = rgb(0xe7c25a)
        paint.strokeWidth = max(1f, (0.3 * scale).toFloat())
        paint.pathEffect = DashPathEffect(floatArrayOf((0.9 * scale).toFloat(), (0.9 * scale).toFloat()), 0f)
        for (k in kMin..kMax) {
            val sx = toScreenX(-GRID_HALF + k * GRID_PERIOD)
            canvas.drawLine(sx, 0f, sx, viewH.toFloat(), paint)
        }
        for (k in jMin..jMax) {
            val sy = toScreenY(-GRID_HALF + k * GRID_PERIOD)
            canvas.drawLine(0f, sy, viewW.toFloat(), sy, paint)
        }
        paint.pathEffect = null

        paint.color = rgb(0xffffff, 40)
        paint.strokeWidth = max(1f, (0.1 * scale).toFloat())
        for (k in kMin..kMax) {
            val sx = toScreenX(-GRID_HALF + k * GRID_PERIOD)
            canvas.drawLine(sx - halfPx, 0f, sx - halfPx, viewH.toFloat(), paint)
            canvas.drawLine(sx + halfPx, 0f, sx + halfPx, viewH.toFloat(), paint)
        }
        for (k in jMin..jMax) {
            val sy = toScreenY(-GRID_HALF + k * GRID_PERIOD)
            canvas.drawLine(0f, sy - halfPx, viewW.toFloat(), sy - halfPx, paint)
            canvas.drawLine(0f, sy + halfPx, viewW.toFloat(), sy + halfPx, paint)
        }
        paint.style = Paint.Style.FILL
    }

    private fun drawParks(canvas: Canvas, e: GameEngine) {
        for (p in e.world.parks) {
            val cx = (p.rect.minX + p.rect.maxX) / 2; val cz = (p.rect.minZ + p.rect.maxZ) / 2
            if (!nearPlayer(cx, cz, BLOCK_SIZE)) continue
            paint.color = rgb(0x4f7a45)
            canvas.drawRect(toScreenX(p.rect.minX), toScreenY(p.rect.minZ), toScreenX(p.rect.maxX), toScreenY(p.rect.maxZ), paint)
            drawTerrainPatch(canvas, p.rect, (0.5 * 255).toInt())

            for (t in p.trees) {
                val sx = toScreenX(t.x); val sy = toScreenY(t.z)
                val r = max(2f, (0.9 * scale).toFloat())
                paint.color = rgb(0x000000, 51)
                canvas.drawCircle(sx + r * 0.15f, sy + r * 0.15f, r, paint)
                paint.color = rgb(0x385c31)
                canvas.drawCircle(sx, sy, r, paint)
                paint.color = rgb(0x527d47)
                canvas.drawCircle(sx - r * 0.25f, sy - r * 0.25f, r * 0.6f, paint)
            }
        }
    }

    private fun drawBuildings(canvas: Canvas, e: GameEngine) {
        for (b in e.world.buildings) {
            val cx = (b.rect.minX + b.rect.maxX) / 2; val cz = (b.rect.minZ + b.rect.maxZ) / 2
            if (!nearPlayer(cx, cz, BLOCK_SIZE)) continue

            paint.color = rgbArr(e.pavementColor)
            canvas.drawRect(
                toScreenX(b.blockRect.minX), toScreenY(b.blockRect.minZ),
                toScreenX(b.blockRect.maxX), toScreenY(b.blockRect.maxZ), paint
            )

            val tlx = toScreenX(b.rect.minX); val tly = toScreenY(b.rect.minZ)
            val brx = toScreenX(b.rect.maxX); val bry = toScreenY(b.rect.maxZ)
            val w = brx - tlx; val h = bry - tly
            val shadowPx = clamp(b.height / 6, 2.0, 9.0).toFloat()

            paint.color = rgb(0x000000, 71)
            canvas.drawRect(tlx + shadowPx, tly + shadowPx, tlx + shadowPx + w, tly + shadowPx + h, paint)

            paint.color = rgb(b.color)
            canvas.drawRect(tlx, tly, brx, bry, paint)

            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1f
            paint.color = rgb(0x000000, 89)
            canvas.drawRect(tlx + 0.5f, tly + 0.5f, brx - 0.5f, bry - 0.5f, paint)
            paint.style = Paint.Style.FILL

            val inset = min(w, h) * 0.14f
            if (w - inset * 2 > 3 && h - inset * 2 > 3) {
                paint.color = rgb(0xffffff, 20)
                canvas.drawRect(tlx + inset, tly + inset, brx - inset, bry - inset, paint)
            }

            for (rd in b.roofDetails) {
                val rr = (rd.r * scale * 0.3).toFloat()
                if (rr < 1f) continue
                val rx = tlx + (rd.x * scale).toFloat(); val rz = tly + (rd.z * scale).toFloat()
                paint.color = rgb(0x000000, 71)
                canvas.drawRect(rx - rr, rz - rr, rx + rr, rz + rr, paint)
            }
        }
    }

    private fun drawLamps(canvas: Canvas, e: GameEngine) {
        if (e.lampGlowAlpha <= 0.02) return
        for (l in e.world.lamps) {
            if (!nearPlayer(l.x, l.z, 6.0)) continue
            val sx = toScreenX(l.x); val sy = toScreenY(l.z)
            val r = (3.2 * scale * 0.12).toFloat()
            paint.shader = RadialGradient(
                sx, sy, r * 3.5f,
                rgb(0xffd68c, (0.55 * e.lampGlowAlpha * 255).toInt()), rgb(0xffd68c, 0), Shader.TileMode.CLAMP
            )
            canvas.drawCircle(sx, sy, r * 3.5f, paint)
            paint.shader = null
            paint.color = rgb(0xffe0a0, (e.lampGlowAlpha * 255).toInt())
            canvas.drawCircle(sx, sy, r, paint)
        }
    }

    private fun drawTrafficLights(canvas: Canvas, e: GameEngine) {
        for (tl in e.trafficLights) {
            if (!nearPlayer(tl.x, tl.z, 4.0)) continue
            val sx = toScreenX(tl.x); val sy = toScreenY(tl.z)
            val cycle = (e.gameTime + tl.phase) % TRAFFIC_LIGHT_CYCLE
            val green = cycle < TRAFFIC_LIGHT_GREEN
            paint.color = rgb(0x20242a)
            canvas.drawRect(sx - 2, sy - 2, sx + 2, sy + 2, paint)
            paint.color = if (green) rgb(0x3ecb6a) else rgb(0xe6544c)
            canvas.drawCircle(sx, sy - 4, 2.6f, paint)
        }
    }

    private fun drawCoins(canvas: Canvas, e: GameEngine) {
        e.coins.forEachIndexed { i, c ->
            if (c.collected || !nearPlayer(c.x, c.z, 3.0)) return@forEachIndexed
            val sx = toScreenX(c.x); val sy = toScreenY(c.z)
            val r = ((0.45 + 0.06 * sin(e.gameTime * 4 + i)) * scale * 0.55).toFloat()
            paint.color = rgb(0xffd75e)
            canvas.drawCircle(sx, sy, r, paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1f
            paint.color = rgb(0xa3781f)
            canvas.drawCircle(sx, sy, r, paint)
            paint.style = Paint.Style.FILL
            paint.color = rgb(0xffffff, 140)
            canvas.drawCircle(sx - r * 0.3f, sy - r * 0.3f, r * 0.35f, paint)
        }
    }

    private fun drawCar(canvas: Canvas, wx: Double, wz: Double, heading: Double, bodyHex: Int, cabinHex: Int, isPolice: Boolean) {
        val sx = toScreenX(wx); val sy = toScreenY(wz)
        val w = (CAR_RADIUS * 1.5 * scale).toFloat(); val len = (CAR_RADIUS * 2.6 * scale).toFloat()
        canvas.save()
        canvas.translate(sx, sy)
        canvas.rotate(Math.toDegrees(heading).toFloat())
        paint.color = rgb(0x000000, 77)
        canvas.drawPath(roundRect(-w / 2 + 1.5f, -len / 2 + 2f, w, len, w * 0.3f), paint)
        paint.color = rgb(bodyHex)
        canvas.drawPath(roundRect(-w / 2, -len / 2, w, len, w * 0.3f), paint)
        paint.color = rgb(cabinHex)
        canvas.drawPath(roundRect(-w * 0.35f, -len * 0.12f, w * 0.7f, len * 0.5f, w * 0.2f), paint)
        if (isPolice) {
            val on = (floor(engine.gameTime / 0.3).toLong() % 2L) == 0L
            paint.color = if (on) rgb(0xff3b3b) else rgb(0x3b6bff)
            canvas.drawRect(-w * 0.22f, -len / 2 - 3f, w * 0.22f, -len / 2, paint)
        }
        canvas.restore()
    }

    private fun drawPedestrians(canvas: Canvas, e: GameEngine) {
        for (ped in e.pedestrians) {
            if (!ped.alive && ped.deathT >= 1) continue
            if (!nearPlayer(ped.pos.x, ped.pos.z, 4.0)) continue
            val sx = toScreenX(ped.pos.x); val sy = toScreenY(ped.pos.z)
            val shrink = if (ped.alive) 1.0 else (1.0 - ped.deathT)
            val r = (PED_RADIUS * scale * shrink).toFloat()
            if (r <= 0.2f) continue
            val alpha = ((if (ped.alive) 1.0 else shrink) * 255).toInt()
            paint.color = hslToColor(ped.hue.toDouble(), 0.45, 0.55, alpha)
            canvas.drawCircle(sx, sy, r, paint)
            if (ped.alive) {
                val hx = sx + (sin(ped.heading) * r * 0.5).toFloat()
                val hy = sy + (Math.cos(ped.heading) * r * 0.5).toFloat()
                paint.color = rgb(0xe8c39e, alpha)
                canvas.drawCircle(hx, hy, r * 0.45f, paint)
            }
        }
    }

    private fun drawParticles(canvas: Canvas, e: GameEngine) {
        for (p in e.particles) {
            val sx = toScreenX(p.x); val sy = toScreenY(p.z)
            val a = clamp01(p.life / p.maxLife)
            paint.color = rgb(p.color, (a * 255).toInt())
            canvas.drawCircle(sx, sy, max(1f, (2.5 * a).toFloat()), paint)
        }
    }
}

private fun hslToColor(hDeg: Double, s: Double, l: Double, alpha: Int): Int {
    val h = (((hDeg % 360) + 360) % 360) / 360.0
    fun hue2rgb(p: Double, q: Double, tIn: Double): Double {
        var t = tIn
        if (t < 0) t += 1
        if (t > 1) t -= 1
        return when {
            t < 1.0 / 6 -> p + (q - p) * 6 * t
            t < 1.0 / 2 -> q
            t < 2.0 / 3 -> p + (q - p) * (2.0 / 3 - t) * 6
            else -> p
        }
    }
    if (s == 0.0) {
        val v = (l * 255).toInt().coerceIn(0, 255)
        return Color.argb(alpha, v, v, v)
    }
    val q = if (l < 0.5) l * (1 + s) else l + s - l * s
    val p = 2 * l - q
    val r = (hue2rgb(p, q, h + 1.0 / 3) * 255).toInt().coerceIn(0, 255)
    val g = (hue2rgb(p, q, h) * 255).toInt().coerceIn(0, 255)
    val b = (hue2rgb(p, q, h - 1.0 / 3) * 255).toInt().coerceIn(0, 255)
    return Color.argb(alpha, r, g, b)
}
