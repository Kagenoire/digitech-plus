package com.digitech.digitech_plus

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import android.widget.SeekBar
import android.widget.TextView

/**
 * Full screen alarm shown for deadline reminders, missed tugas, and presensi
 * dibuka. Rings continuously and can only be stopped by sliding the bar,
 * mirroring the native Android alarm clock experience.
 */
class AlarmActivity : Activity() {

    companion object {
        const val EXTRA_TYPE = "type"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_CHANNEL_ID = "channelId"
        private const val DISMISS_THRESHOLD = 85
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var dismissed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()
        setContentView(R.layout.activity_alarm)

        findViewById<TextView>(R.id.alarmTitle).text =
            intent.getStringExtra(EXTRA_TITLE) ?: "Alarm"
        findViewById<TextView>(R.id.alarmBody).text =
            intent.getStringExtra(EXTRA_BODY) ?: ""

        startRinging()
        setupSlideToDismiss()
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        keyguardManager.requestDismissKeyguard(this, null)
    }

    // Uses the sound the user picked for this specific notification channel
    // (via the in-app Settings screen), falling back to the system alarm
    // ringtone if the channel has no custom sound set.
    private fun resolveSoundUri(): android.net.Uri? {
        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID)
        if (channelId != null) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelSound = notificationManager.getNotificationChannel(channelId)?.sound
            if (channelSound != null) return channelSound
        }
        return RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }

    private fun startRinging() {
        try {
            val alarmUri = resolveSoundUri()
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@AlarmActivity, alarmUri!!)
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {
            // No usable ringtone on this device, fall back to vibration only.
        }

        val pattern = longArrayOf(0, 800, 400)
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
    }

    private fun stopRinging() {
        mediaPlayer?.apply {
            try {
                if (isPlaying) stop()
            } catch (_: Exception) {
            }
            release()
        }
        mediaPlayer = null
        vibrator?.cancel()
    }

    private fun setupSlideToDismiss() {
        val seekBar = findViewById<SeekBar>(R.id.slideToDismiss)
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar, progress: Int, fromUser: Boolean) {}

            override fun onStartTrackingTouch(bar: SeekBar) {}

            override fun onStopTrackingTouch(bar: SeekBar) {
                if (bar.progress >= DISMISS_THRESHOLD) {
                    dismiss()
                } else {
                    bar.progress = 0
                }
            }
        })
    }

    private fun dismiss() {
        if (dismissed) return
        dismissed = true
        stopRinging()
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(intent)
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Alarm can only be stopped by sliding to dismiss, not the back button.
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }
}
