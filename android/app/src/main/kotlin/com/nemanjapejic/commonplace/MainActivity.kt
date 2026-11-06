package com.nemanjapejic.commonplace

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.webkit.CookieManager
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val shrinker by lazy { VideoShrinker(applicationContext) }

    /**
     * Gives Dart the cookies the Instagram sign-in web view received. The
     * webview_flutter plugin can set cookies but not read them, and the
     * session cookie is HttpOnly, so it isn't visible to page JavaScript.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "commonplace/web_cookies")
            .setMethodCallHandler { call, result ->
                val cookies = CookieManager.getInstance()
                when (call.method) {
                    "get" -> result.success(cookies.getCookie(call.argument<String>("url")))
                    "clear" -> cookies.removeAllCookies { removed ->
                        cookies.flush()
                        result.success(removed)
                    }
                    else -> result.notImplemented()
                }
            }
        // A smaller copy of a video before it goes to the AI (VideoShrinker).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "commonplace/video")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shrink" -> shrinker.shrink(
                        call.argument<String>("input")!!,
                        call.argument<String>("output")!!,
                        result,
                    )
                    "progress" -> result.success(shrinker.progress())
                    "cancel" -> {
                        shrinker.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Making notes while the app is in the background (NoteWorkService).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "commonplace/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        NoteWorkService.start(this, call.argument<String>("text") ?: "")
                        result.success(null)
                    }
                    "stop" -> {
                        NoteWorkService.stop(this)
                        result.success(null)
                    }
                    "askForNotifications" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        dropUnreadableStreams(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        dropUnreadableStreams(intent)
        super.onNewIntent(intent)
    }

    /**
     * Some apps share files without granting read access. The share plugin
     * reads them on the main thread and would crash the app, so unreadable
     * files are removed here and the rest of the share still goes through.
     */
    private fun dropUnreadableStreams(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return

        val uris = streamUris(intent)
        if (uris.isEmpty()) return
        val readable = uris.filter(::canRead)
        if (readable.size == uris.size) return

        Toast.makeText(
            this,
            "Commonplace couldn't open that file. Save it to your gallery first, then add it from there.",
            Toast.LENGTH_LONG,
        ).show()

        val hasText = !intent.getStringExtra(Intent.EXTRA_TEXT).isNullOrBlank()
        when {
            readable.isEmpty() && !hasText -> {
                // Nothing usable left; make the plugin ignore this intent.
                intent.removeExtra(Intent.EXTRA_STREAM)
                intent.action = Intent.ACTION_MAIN
            }
            action == Intent.ACTION_SEND -> intent.removeExtra(Intent.EXTRA_STREAM)
            else -> intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(readable))
        }
    }

    private fun streamUris(intent: Intent): List<Uri> =
        if (intent.action == Intent.ACTION_SEND) {
            listOfNotNull(
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                },
            )
        } else {
            (
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
            ).orEmpty()
        }

    private fun canRead(uri: Uri): Boolean =
        try {
            contentResolver.openInputStream(uri)?.close()
            true
        } catch (e: Exception) {
            false
        }
}
