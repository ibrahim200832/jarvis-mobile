package com.jarvismobile.citydrivinggame

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.AttributeSet
import android.view.View
import kotlin.math.ceil
import kotlin.math.floor

/**
 * Nordorientierte Miniaturkarte (Rasterlinien + Punkte + rotierendes
 * Spieler-Dreieck) — eigener, weiter herausgezoomter Überblick zusätzlich
 * zur großen Hauptansicht in GameView. Wird von MainActivity einmal pro
 * Frame invalidiert.
 */
class MinimapView(context: Context, attrs: AttributeSet?) : View(context, attrs) {

    lateinit var engine: GameEngine
    private val viewRadius = 55.0
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val trianglePath = Path()

    fun attach(engine: GameEngine) {
        this.engine = engine
    }

    private fun toMapX(cx: Float, scale: Float, wx: Double) = cx + ((wx - engine.player.pos.x) * scale).toFloat()
    private fun toMapY(cz: Float, scale: Float, wz: Double) = cz + ((wz - engine.player.pos.z) * scale).toFloat()

    override fun onDraw(canvas: Canvas) {
        if (!::engine.isInitialized) return
        val e = engine
        val w = width.toFloat(); val h = height.toFloat()
        if (w <= 0f || h <= 0f) return
        val scale = (minOf(w, h) / 2 - 4) / viewRadius.toFloat()
        val cx = w / 2; val cz = h / 2

        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1f
        paint.color = Color.argb(36, 255, 255, 255)
        val kMin = floor((e.player.pos.x - viewRadius + GRID_HALF) / GRID_PERIOD).toInt() - 1
        val kMax = ceil((e.player.pos.x + viewRadius + GRID_HALF) / GRID_PERIOD).toInt() + 1
        for (k in kMin..kMax) {
            val lineX = -GRID_HALF + k * GRID_PERIOD
            canvas.drawLine(
                toMapX(cx, scale, lineX), toMapY(cz, scale, e.player.pos.z - viewRadius),
                toMapX(cx, scale, lineX), toMapY(cz, scale, e.player.pos.z + viewRadius), paint
            )
        }
        val jMin = floor((e.player.pos.z - viewRadius + GRID_HALF) / GRID_PERIOD).toInt() - 1
        val jMax = ceil((e.player.pos.z + viewRadius + GRID_HALF) / GRID_PERIOD).toInt() + 1
        for (k in jMin..jMax) {
            val lineZ = -GRID_HALF + k * GRID_PERIOD
            canvas.drawLine(
                toMapX(cx, scale, e.player.pos.x - viewRadius), toMapY(cz, scale, lineZ),
                toMapX(cx, scale, e.player.pos.x + viewRadius), toMapY(cz, scale, lineZ), paint
            )
        }

        paint.style = Paint.Style.FILL
        fun dot(wx: Double, wz: Double, color: Int, r: Float) {
            if (dist2D(wx, wz, e.player.pos.x, e.player.pos.z) > viewRadius) return
            paint.color = color
            canvas.drawCircle(toMapX(cx, scale, wx), toMapY(cz, scale, wz), r, paint)
        }
        for (p in e.pedestrians) if (p.alive) dot(p.pos.x, p.pos.z, Color.argb(217, 232, 232, 232), 2f)
        for (c in e.trafficCars) dot(c.pos.x, c.pos.z, Color.rgb(0xe0, 0xb9, 0x3c), 2.5f)
        val policeColor = if ((floor(e.gameTime / 0.3).toLong() % 2L) == 0L) Color.rgb(0xff, 0x3b, 0x3b) else Color.rgb(0x3b, 0x6b, 0xff)
        for (p in e.policeCars) dot(p.pos.x, p.pos.z, policeColor, 3f)

        canvas.save()
        canvas.translate(cx, cz)
        canvas.rotate(Math.toDegrees(e.player.heading).toFloat())
        trianglePath.reset()
        trianglePath.moveTo(0f, -6f)
        trianglePath.lineTo(4f, 5f)
        trianglePath.lineTo(-4f, 5f)
        trianglePath.close()
        paint.color = Color.rgb(0xf2, 0xa9, 0x3a)
        canvas.drawPath(trianglePath, paint)
        canvas.restore()
    }
}
