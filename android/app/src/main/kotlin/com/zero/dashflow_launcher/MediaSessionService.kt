package com.zero.dashflow_launcher

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MediaSessionService : NotificationListenerService() {

    companion object {
        @Volatile
        var instance: MediaSessionService? = null

        fun getMediaInfo(context: Context): Map<String, Any?> {
            return instance?.buildMediaInfo(context) ?: mapOf(
                "isPlaying" to false,
                "title" to "",
                "artist" to "",
                "album" to "",
                "albumArt" to null,
                "duration" to 0L,
                "position" to 0L,
            )
        }

        fun sendCommand(context: Context, command: String, positionMs: Long = -1L) {
            instance?.handleCommand(context, command, positionMs)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance === this) instance = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {}
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {}

    private fun getActiveController(context: Context): MediaController? {
        val mgr = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            ?: return null
        val comp = ComponentName(context, MediaSessionService::class.java)
        return try {
            mgr.getActiveSessions(comp)
                .firstOrNull { ctrl ->
                    val state = ctrl.playbackState?.state
                    state == PlaybackState.STATE_PLAYING ||
                    state == PlaybackState.STATE_PAUSED ||
                    state == PlaybackState.STATE_BUFFERING
                } ?: mgr.getActiveSessions(comp).firstOrNull()
        } catch (_: SecurityException) {
            null
        }
    }

    fun buildMediaInfo(context: Context): Map<String, Any?> {
        val ctrl = getActiveController(context)
            ?: return mapOf(
                "isPlaying" to false,
                "title" to "",
                "artist" to "",
                "album" to "",
                "albumArt" to null,
                "duration" to 0L,
                "position" to 0L,
            )

        val meta = ctrl.metadata
        val state = ctrl.playbackState
        val isPlaying = state?.state == PlaybackState.STATE_PLAYING

        val title = meta?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
        val artist = meta?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: meta?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST) ?: ""
        val album = meta?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
        val duration = meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val position = state?.position ?: 0L

        val artBitmap = meta?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: meta?.getBitmap(MediaMetadata.METADATA_KEY_ART)
        val artBytes = artBitmap?.let { encodeBitmap(it) }

        return mapOf(
            "isPlaying" to isPlaying,
            "title" to title,
            "artist" to artist,
            "album" to album,
            "albumArt" to artBytes,
            "duration" to duration,
            "position" to position,
        )
    }

    fun handleCommand(context: Context, command: String, positionMs: Long = -1L) {
        val ctrl = getActiveController(context) ?: return
        when (command) {
            "play"     -> ctrl.transportControls.play()
            "pause"    -> ctrl.transportControls.pause()
            "next"     -> ctrl.transportControls.skipToNext()
            "previous" -> ctrl.transportControls.skipToPrevious()
            "seekTo"   -> if (positionMs >= 0) ctrl.transportControls.seekTo(positionMs)
        }
    }

    private fun encodeBitmap(bitmap: Bitmap): ByteArray? {
        // Scale down to keep transfer size small
        val maxSize = 128
        val scaled = if (bitmap.width > maxSize || bitmap.height > maxSize) {
            val ratio = minOf(maxSize.toFloat() / bitmap.width, maxSize.toFloat() / bitmap.height)
            Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width * ratio).toInt(),
                (bitmap.height * ratio).toInt(),
                true,
            )
        } else bitmap

        return ByteArrayOutputStream(8192).use { out ->
            val ok = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                scaled.compress(Bitmap.CompressFormat.WEBP_LOSSY, 80, out)
            } else {
                @Suppress("DEPRECATION")
                scaled.compress(Bitmap.CompressFormat.WEBP, 80, out)
            }
            if (scaled !== bitmap) scaled.recycle()
            if (ok) out.toByteArray() else null
        }
    }
}
