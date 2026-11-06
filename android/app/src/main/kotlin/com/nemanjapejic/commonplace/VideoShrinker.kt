package com.nemanjapejic.commonplace

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Makes a small copy of a video before it goes to Gemini, which samples one
 * frame a second at low resolution anyway: 480 px on the short side, five
 * frames a second, a modest bitrate. The sound is copied as it is, since
 * that's where most of a reel's words are.
 *
 * One at a time. Every call comes in on the main thread, which is also the
 * thread Transformer wants to be used from.
 */
@OptIn(UnstableApi::class)
class VideoShrinker(private val context: Context) {

    private var transformer: Transformer? = null
    private var pending: MethodChannel.Result? = null
    private var output: File? = null
    private val progress = ProgressHolder()

    fun shrink(input: String, outputPath: String, result: MethodChannel.Result) {
        if (transformer != null) {
            result.error("busy", "Already making a video smaller", null)
            return
        }
        val out = File(outputPath)
        out.delete()
        val effects = Effects(
            /* audioProcessors= */ listOf(),
            /* videoEffects= */ listOf(
                Presentation.createForShortSide(SHORT_SIDE),
                FrameDropEffect.createDefaultFrameDropEffect(FRAME_RATE),
            ),
        )
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(effects)
            .build()
        val encoders = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder().setBitrate(VIDEO_BITRATE).build(),
            )
            .build()
        val t = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setEncoderFactory(encoders)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    val r = exportResult
                    val summary = "${r.width}x${r.height}, ${r.videoFrameCount} frames in " +
                        "${r.durationMs} ms, video ${r.averageVideoBitrate / 1000} kbps " +
                        "(${r.videoEncoderName}), audio ${r.averageAudioBitrate / 1000} kbps " +
                        "(${r.audioEncoderName ?: "copied"})"
                    Log.i(TAG, "Made smaller: $summary")
                    finish()?.success(
                        mapOf("path" to out.path, "bytes" to out.length(), "summary" to summary),
                    )
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    Log.w(TAG, "Couldn't make the video smaller", exportException)
                    out.delete()
                    finish()?.error(
                        "failed",
                        exportException.message,
                        exportException.errorCodeName,
                    )
                }
            })
            .build()
        transformer = t
        pending = result
        output = out
        try {
            t.start(item, out.path)
        } catch (e: Exception) {
            out.delete()
            finish()?.error("failed", e.message, null)
        }
    }

    /** 0 to 100, or -1 when it isn't known (yet). */
    fun progress(): Int {
        val t = transformer ?: return -1
        return if (t.getProgress(progress) == Transformer.PROGRESS_STATE_AVAILABLE) {
            progress.progress
        } else {
            -1
        }
    }

    /** The owner tapped Stop. Transformer doesn't call back after cancel(). */
    fun cancel() {
        val t = transformer ?: return
        t.cancel()
        output?.delete()
        finish()?.error("cancelled", "Stopped", null)
    }

    private fun finish(): MethodChannel.Result? {
        val r = pending
        pending = null
        transformer = null
        output = null
        return r
    }

    companion object {
        private const val TAG = "VideoShrinker"
        private const val SHORT_SIDE = 480
        private const val FRAME_RATE = 5f
        private const val VIDEO_BITRATE = 400_000
    }
}
