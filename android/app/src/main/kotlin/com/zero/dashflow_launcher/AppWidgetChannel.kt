package com.zero.dashflow_launcher

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

const val WIDGET_CHANNEL = "com.zero.dashflow_launcher/widgets"
const val REQUEST_PICK_WIDGET = 2001
const val REQUEST_BIND_WIDGET = 2002
const val REQUEST_CONFIGURE_WIDGET = 2003

class AppWidgetChannel(
    private val activity: Activity,
    private val host: AppWidgetHost,
    engine: FlutterEngine,
) {
    private val manager = AppWidgetManager.getInstance(activity)
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)

    // Pending result for the pick/bind/configure flow
    private var pendingResult: MethodChannel.Result? = null
    private var pendingWidgetId: Int = -1

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAvailableWidgets" -> result.success(getAvailableWidgets())
                "allocateWidgetId" -> result.success(host.allocateAppWidgetId())
                "bindWidget" -> {
                    val widgetId = call.argument<Int>("appWidgetId")!!
                    val provider = call.argument<String>("provider")!!
                    val pkg = provider.substringBefore("/")
                    val cls = provider.substringAfter("/")
                    val cn = android.content.ComponentName(pkg, cls)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        val allowed = manager.bindAppWidgetIdIfAllowed(widgetId, cn)
                        if (allowed) {
                            maybeConfigure(widgetId, result)
                        } else {
                            // Need user permission
                            pendingResult = result
                            pendingWidgetId = widgetId
                            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND).apply {
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, cn)
                            }
                            activity.startActivityForResult(intent, REQUEST_BIND_WIDGET)
                        }
                    } else {
                        result.error("UNSUPPORTED", "API < 21", null)
                    }
                }
                "deleteWidget" -> {
                    val widgetId = call.argument<Int>("appWidgetId")!!
                    host.deleteAppWidgetId(widgetId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun maybeConfigure(widgetId: Int, result: MethodChannel.Result) {
        val info = manager.getAppWidgetInfo(widgetId)
        if (info?.configure != null) {
            pendingResult = result
            pendingWidgetId = widgetId
            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE).apply {
                component = info.configure
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            activity.startActivityForResult(intent, REQUEST_CONFIGURE_WIDGET)
        } else {
            result.success(widgetId)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            REQUEST_BIND_WIDGET -> {
                if (resultCode == Activity.RESULT_OK) {
                    maybeConfigure(pendingWidgetId, pendingResult ?: return)
                } else {
                    host.deleteAppWidgetId(pendingWidgetId)
                    pendingResult?.error("BIND_DENIED", "User denied widget bind", null)
                    pendingResult = null
                }
            }
            REQUEST_CONFIGURE_WIDGET -> {
                if (resultCode == Activity.RESULT_OK) {
                    pendingResult?.success(pendingWidgetId)
                } else {
                    host.deleteAppWidgetId(pendingWidgetId)
                    pendingResult?.error("CONFIG_CANCELLED", "User cancelled configuration", null)
                }
                pendingResult = null
            }
        }
    }

    private fun getAvailableWidgets(): List<Map<String, Any?>> {
        val infos: List<AppWidgetProviderInfo> = manager.installedProviders
        return infos.map { info ->
            val label = info.loadLabel(activity.packageManager)
            val icon = try { encodeDrawable(info.loadPreviewImage(activity, 0) ?: info.loadIcon(activity, 0)) } catch (_: Exception) { null }
            mapOf(
                "provider" to "${info.provider.packageName}/${info.provider.className}",
                "label" to label,
                "package" to info.provider.packageName,
                "previewImage" to icon,
                "minWidth" to info.minWidth,
                "minHeight" to info.minHeight,
            )
        }
    }

    private fun encodeDrawable(drawable: Drawable?): ByteArray? {
        drawable ?: return null
        val w = drawable.intrinsicWidth.takeIf { it > 0 } ?: 80
        val h = drawable.intrinsicHeight.takeIf { it > 0 } ?: 80
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, w, h)
        drawable.draw(Canvas(bmp))
        return ByteArrayOutputStream().use { out ->
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            bmp.recycle()
            out.toByteArray()
        }
    }
}
