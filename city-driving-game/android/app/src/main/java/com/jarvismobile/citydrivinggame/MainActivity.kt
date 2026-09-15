package com.jarvismobile.citydrivinggame

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import java.io.PrintWriter
import java.io.StringWriter
import kotlin.math.roundToInt

/**
 * Lobby + HUD + Verkabelung. Der ganze Bildschirm ist nativ aufgebaut
 * (Buttons, TextViews, ProgressBar) — keine Web-Ansicht, kein HTML. Das
 * eigentliche Spielfeld zeichnet GameView direkt auf einem Canvas.
 */
class MainActivity : Activity(), GameListener {

    private lateinit var engine: GameEngine
    private lateinit var highscoreStore: HighscoreStore
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var lobbyScreen: View
    private lateinit var gameScreen: View
    private lateinit var lobbyHighscoreLabel: TextView
    private lateinit var startBtn: Button
    private lateinit var densityButtons: Map<String, Button>
    private lateinit var carColorButtons: List<Button>

    private lateinit var gameView: GameView
    private lateinit var minimapView: MinimapView
    private lateinit var wantedStars: List<TextView>
    private lateinit var healthBar: ProgressBar
    private lateinit var daytimeChip: TextView
    private lateinit var coinChip: TextView
    private lateinit var speedText: TextView
    private lateinit var scoreText: TextView
    private lateinit var toastStack: LinearLayout
    private lateinit var overlay: View
    private lateinit var overlayTitle: TextView
    private lateinit var overlayStats: TextView

    private var selectedDensity = "normal"
    private var selectedCarColorIndex = 0
    private var showingGame = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        installCrashHandler()
        setContentView(R.layout.activity_main)

        highscoreStore = PrefsHighscoreStore(this)
        engine = GameEngine(this, highscoreStore)

        bindViews()
        wireLobby()
        wireTouchControls()

        gameView.attach(engine) { updateHud() }
        minimapView.attach(engine)

        lobbyHighscoreLabel.text = "Highscore: ${highscoreStore.load()} Punkte"

        showLastCrashIfAny()
    }

    // -------------------------------------------------------------------
    // Absturz-Diagnose: es gibt in dieser Sandbox kein echtes Gerät/Logcat,
    // um einen Absturz-Stacktrace zu sehen. Daher wird jeder unbehandelte
    // Fehler persistiert und beim nächsten Start als kopierbarer Dialog
    // angezeigt, damit er sich weitergeben lässt.
    // -------------------------------------------------------------------
    private fun installCrashHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val sw = StringWriter()
                throwable.printStackTrace(PrintWriter(sw))
                getSharedPreferences("crash", Context.MODE_PRIVATE).edit()
                    .putString("last_crash", sw.toString())
                    .apply()
            } catch (e: Exception) {
                // Konnte den Absturz nicht speichern - Standardverhalten übernimmt.
            }
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun showLastCrashIfAny() {
        val prefs = getSharedPreferences("crash", Context.MODE_PRIVATE)
        val trace = prefs.getString("last_crash", null) ?: return
        prefs.edit().remove("last_crash").apply()
        AlertDialog.Builder(this)
            .setTitle("Letzter Absturz")
            .setMessage(trace)
            .setPositiveButton("OK", null)
            .show()
    }

    private fun bindViews() {
        lobbyScreen = findViewById<View>(R.id.lobbyScreen)
        gameScreen = findViewById<View>(R.id.gameScreen)
        lobbyHighscoreLabel = findViewById<TextView>(R.id.lobbyHighscoreLabel)
        startBtn = findViewById<Button>(R.id.startBtn)
        densityButtons = mapOf(
            "ruhig" to findViewById<Button>(R.id.densityRuhig),
            "normal" to findViewById<Button>(R.id.densityNormal),
            "voll" to findViewById<Button>(R.id.densityVoll)
        )
        carColorButtons = listOf(
            findViewById<Button>(R.id.carColor0), findViewById<Button>(R.id.carColor1),
            findViewById<Button>(R.id.carColor2), findViewById<Button>(R.id.carColor3)
        )

        gameView = findViewById<GameView>(R.id.gameView)
        minimapView = findViewById<MinimapView>(R.id.minimapView)
        wantedStars = listOf(
            findViewById<TextView>(R.id.star0), findViewById<TextView>(R.id.star1), findViewById<TextView>(R.id.star2),
            findViewById<TextView>(R.id.star3), findViewById<TextView>(R.id.star4)
        )
        healthBar = findViewById<ProgressBar>(R.id.healthBar)
        daytimeChip = findViewById<TextView>(R.id.daytimeChip)
        coinChip = findViewById<TextView>(R.id.coinChip)
        speedText = findViewById<TextView>(R.id.speedText)
        scoreText = findViewById<TextView>(R.id.scoreText)
        toastStack = findViewById<LinearLayout>(R.id.toastStack)
        overlay = findViewById<View>(R.id.overlay)
        overlayTitle = findViewById<TextView>(R.id.overlayTitle)
        overlayStats = findViewById<TextView>(R.id.overlayStats)
    }

    private fun wireLobby() {
        densityButtons.forEach { (key, btn) ->
            btn.setOnClickListener {
                selectedDensity = key
                densityButtons.forEach { (k, b) -> setOptionSelected(b, k == key) }
            }
        }
        carColorButtons.forEachIndexed { index, btn ->
            btn.setOnClickListener {
                selectedCarColorIndex = index
                carColorButtons.forEachIndexed { i, b -> setOptionSelected(b, i == index) }
            }
        }
        startBtn.setOnClickListener { startRun() }
        findViewById<Button>(R.id.restartBtn).setOnClickListener {
            overlay.visibility = View.GONE
            startRun()
        }
        findViewById<Button>(R.id.lobbyBtn).setOnClickListener {
            showingGame = false
            gameView.stopLoop()
            overlay.visibility = View.GONE
            gameScreen.visibility = View.GONE
            lobbyScreen.visibility = View.VISIBLE
            lobbyHighscoreLabel.text = "Highscore: ${highscoreStore.load()} Punkte"
        }
    }

    private fun setOptionSelected(btn: Button, selected: Boolean) {
        btn.setBackgroundResource(if (selected) R.drawable.pill_accent else R.drawable.pill_outline)
        btn.setTextColor(if (selected) getColorCompat(R.color.on_accent) else getColorCompat(R.color.muted))
    }

    @Suppress("DEPRECATION")
    private fun getColorCompat(id: Int): Int = resources.getColor(id)

    private fun startRun() {
        engine.selectedDensity = selectedDensity
        engine.density = DENSITY_PRESETS.getValue(selectedDensity)
        engine.selectedCarColorIndex = selectedCarColorIndex
        lobbyScreen.visibility = View.GONE
        gameScreen.visibility = View.VISIBLE
        overlay.visibility = View.GONE
        engine.resetRunState()
        engine.running = true
        showingGame = true
        gameView.startLoop()
    }

    private fun wireTouchControls() {
        wireHold(findViewById<View>(R.id.steerLeftBtn)) { down -> gameView.touchSteer = if (down) -1.0 else if (gameView.touchSteer == -1.0) 0.0 else gameView.touchSteer }
        wireHold(findViewById<View>(R.id.steerRightBtn)) { down -> gameView.touchSteer = if (down) 1.0 else if (gameView.touchSteer == 1.0) 0.0 else gameView.touchSteer }
        wireHold(findViewById<View>(R.id.pedalGasBtn)) { down -> gameView.touchGas = down }
        wireHold(findViewById<View>(R.id.pedalBrakeBtn)) { down -> gameView.touchBrake = down }
    }

    // Für Halte-Steuerung (Lenkrad/Pedale) statt Klick — reagiert auf
    // ACTION_DOWN/UP wie auch die POINTER_-Varianten (wenn dieser Finger
    // nicht der einzige aktive ist, z.B. gleichzeitig Lenken + Gasgeben),
    // und gibt sichtbares Drück-Feedback über den Hintergrund.
    private fun wireHold(view: View, onChange: (Boolean) -> Unit) {
        view.setOnTouchListener { v, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                    v.setBackgroundResource(R.drawable.bg_touch_btn_pressed)
                    onChange(true)
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                    v.setBackgroundResource(R.drawable.bg_touch_btn)
                    onChange(false)
                }
            }
            true
        }
    }

    // -------------------------------------------------------------------
    // Pro-Frame-HUD-Update (aus GameView.onFrame aufgerufen, Hauptthread)
    // -------------------------------------------------------------------
    private fun updateHud() {
        val e = engine
        speedText.text = "${(kotlin.math.abs(e.player.speed) * 3.6).roundToInt()} km/h"
        scoreText.text = "Punkte: ${e.currentScore()}"
        healthBar.progress = e.player.health.roundToInt().coerceIn(0, 100)
        val stars = e.wantedHeat.roundToInt()
        wantedStars.forEachIndexed { i, star ->
            star.setTextColor(if (i < stars) getColorCompat(R.color.error) else Color.parseColor("#2effffff"))
        }
        coinChip.text = "🪙 ${e.coinsCollected}/${e.coins.size}"
        daytimeChip.text = if (e.dayFactor > 0.5) "☀️ Tag" else "🌙 Nacht"
        minimapView.invalidate()
    }

    // -------------------------------------------------------------------
    // GameListener — Rückrufe aus der Engine (laufen auf dem Hauptthread,
    // da update() aus GameView.doFrame() auf dem Hauptthread aufgerufen wird)
    // -------------------------------------------------------------------
    override fun onToast(message: String, cls: String) {
        val tv = TextView(this).apply {
            text = message
            setBackgroundResource(R.drawable.pill_chip)
            setPadding(dp(14), dp(5), dp(14), dp(5))
            textSize = 12.5f
            setTextColor(
                when (cls) {
                    "bad" -> getColorCompat(R.color.error)
                    "good" -> getColorCompat(R.color.accent_glow)
                    "gold" -> Color.parseColor("#ffd75e")
                    else -> getColorCompat(R.color.foreground)
                }
            )
            alpha = 0f
        }
        val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        lp.topMargin = dp(6)
        toastStack.addView(tv, lp)
        tv.animate().alpha(1f).setDuration(200).start()
        mainHandler.postDelayed({
            tv.animate().alpha(0f).setDuration(400).withEndAction { toastStack.removeView(tv) }.start()
        }, 2400)
    }

    override fun onSfx(name: String) {
        Sfx.playByName(name)
    }

    override fun onRunEnded(source: String, finalScore: Int, best: Int) {
        overlayTitle.text = if (source == "police") "Busted!" else "Wasted!"
        overlayStats.text = "Strecke: ${engine.distanceDriven.toInt()} m\n" +
            "Münzen: ${engine.coinsCollected}/${engine.coins.size}\n" +
            "Zeit gesucht: ${engine.wantedSecondsAccum.toInt()} s\n" +
            "Höchste Fahndungsstufe: ${engine.maxWantedReached.roundToInt()}\n" +
            "Punkte: $finalScore (Highscore: $best)"
        overlay.visibility = View.VISIBLE
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).roundToInt()

    override fun onResume() {
        super.onResume()
        if (showingGame) gameView.startLoop()
    }

    override fun onPause() {
        super.onPause()
        gameView.stopLoop()
    }
}

private class PrefsHighscoreStore(context: Context) : HighscoreStore {
    private val prefs = context.getSharedPreferences("city-driving-game", Context.MODE_PRIVATE)
    override fun load(): Int = prefs.getInt("highscore", 0)
    override fun saveIfBetter(value: Int): Int {
        val current = load()
        if (value > current) prefs.edit().putInt("highscore", value).apply()
        return maxOf(current, value)
    }
}
