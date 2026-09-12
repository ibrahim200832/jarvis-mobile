package com.jarvismobile.citydrivinggame

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin
import kotlin.random.Random

/**
 * Prozedurale Soundeffekte (keine Audio-Dateien im APK) — native Portierung
 * der WebAudio-Oszillator-Synthese aus dem ursprünglichen Web-Prototyp.
 * Statt OscillatorNode/GainNode wird die Wellenform direkt als PCM-Puffer
 * berechnet und einmalig über AudioTrack abgespielt. Jeder Aufruf läuft auf
 * einem eigenen Kurzlebig-Thread, damit die Puffer-Berechnung nie den
 * Game-Loop (Hauptthread) blockiert.
 */
object Sfx {
    private const val SAMPLE_RATE = 44100
    var volume = 0.6

    private fun play(samples: ShortArray) {
        Thread {
            try {
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                val format = AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
                val track = AudioTrack(
                    attrs, format, samples.size * 2, AudioTrack.MODE_STATIC, AudioTrack.SESSION_ID_GENERATE
                )
                track.write(samples, 0, samples.size)
                track.play()
                val durationMs = samples.size * 1000L / SAMPLE_RATE + 150
                Thread.sleep(durationMs)
                track.release()
            } catch (e: Exception) {
                // Audio nicht verfügbar - Spiel läuft trotzdem weiter.
            }
        }.start()
    }

    // Ton mit optionalem Frequenz-Sweep (exponentiell, wie
    // exponentialRampToValueAtTime) und kurzer Attack/Decay-Hüllkurve.
    private fun tone(freq: Double, duration: Double, waveform: String, gain: Double, slideTo: Double? = null) {
        val n = (SAMPLE_RATE * duration).toInt().coerceAtLeast(1)
        val samples = ShortArray(n)
        val attackN = (SAMPLE_RATE * 0.015).toInt().coerceAtLeast(1)
        var phase = 0.0
        for (i in 0 until n) {
            val t = i.toDouble() / SAMPLE_RATE
            val f = if (slideTo != null) freq * (max(1.0, slideTo) / freq).pow(t / duration) else freq
            phase += f / SAMPLE_RATE
            val cyclePos = phase - Math.floor(phase)
            val wave = when (waveform) {
                "square" -> if (cyclePos < 0.5) 1.0 else -1.0
                "sawtooth" -> 2.0 * cyclePos - 1.0
                "triangle" -> 4.0 * abs(cyclePos - 0.5) - 1.0
                else -> sin(2.0 * PI * phase)
            }
            val env = if (i < attackN) {
                i.toDouble() / attackN
            } else {
                val decayT = (i - attackN).toDouble() / (n - attackN).coerceAtLeast(1)
                (1.0 - decayT).coerceIn(0.0, 1.0).pow(2)
            }
            val sample = wave * env * gain * volume
            samples[i] = (sample.coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
        }
        play(samples)
    }

    // Kurzes, zu 0 hin abklingendes Rauschen (Crash/Treffer-Impuls).
    private fun noise(duration: Double, gain: Double) {
        val n = (SAMPLE_RATE * duration).toInt().coerceAtLeast(1)
        val samples = ShortArray(n)
        for (i in 0 until n) {
            val env = 1.0 - i.toDouble() / n
            val sample = (Random.nextDouble() * 2 - 1) * env * gain * volume
            samples[i] = (sample.coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
        }
        play(samples)
    }

    fun crash() { noise(0.35, 0.5); tone(120.0, 0.25, "sawtooth", 0.25, 60.0) }
    fun hit() { noise(0.15, 0.35); tone(300.0, 0.12, "square", 0.2, 140.0) }
    fun heatUp() { tone(220.0, 0.18, "sawtooth", 0.22, 440.0) }
    fun heatDown() { tone(440.0, 0.18, "sine", 0.15, 220.0) }
    fun busted() { tone(300.0, 0.5, "sawtooth", 0.25, 60.0) }
    fun coin() { tone(660.0, 0.08, "square", 0.15, 990.0); tone(990.0, 0.1, "square", 0.12, 1320.0) }
    fun nearMiss() { tone(500.0, 0.1, "triangle", 0.12, 300.0) }

    fun playByName(name: String) {
        when (name) {
            "crash" -> crash()
            "hit" -> hit()
            "heatUp" -> heatUp()
            "heatDown" -> heatDown()
            "busted" -> busted()
            "coin" -> coin()
            "nearMiss" -> nearMiss()
        }
    }
}
