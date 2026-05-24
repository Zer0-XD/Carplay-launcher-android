package com.zero.dashflow_launcher

import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.Context
import android.os.Bundle
import android.view.View
import android.view.ViewTreeObserver
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

// Unique host ID — must be consistent across app restarts
const val WIDGET_HOST_ID = 1024

class AppWidgetHostViewFactory(
    private val context: Context,
    private val appWidgetHost: AppWidgetHost,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(ctx: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val appWidgetId = (params?.get("appWidgetId") as? Int) ?: -1
        return HostedAppWidget(context, appWidgetHost, appWidgetId)
    }
}

private class HostedAppWidget(
    private val context: Context,
    private val host: AppWidgetHost,
    private val appWidgetId: Int,
) : PlatformView {

    private val hostView: AppWidgetHostView? = createView()

    private fun createView(): AppWidgetHostView? {
        if (appWidgetId < 0) return null
        val manager = AppWidgetManager.getInstance(context)
        val info: AppWidgetProviderInfo = manager.getAppWidgetInfo(appWidgetId) ?: return null
        val view = host.createView(context, appWidgetId, info)
        view.setAppWidget(appWidgetId, info)

        // Many widgets (Spotify, YouTube Music, etc.) stay gray until they
        // receive a size via updateAppWidgetOptions. We push the size once the
        // view has been laid out so we have real pixel dimensions to convert.
        view.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                view.viewTreeObserver.removeOnGlobalLayoutListener(this)
                pushSizeOptions(manager, view)
            }
        })

        // Also push size after a short delay so the provider gets it even if
        // the OnGlobalLayoutListener fires before the view is window-attached.
        view.postDelayed({ pushSizeOptions(manager, view) }, 300)

        return view
    }

    private fun pushSizeOptions(manager: AppWidgetManager, view: AppWidgetHostView) {
        try {
            val density = context.resources.displayMetrics.density
            // Use actual measured size if available, fall back to info minWidth/minHeight.
            val info = manager.getAppWidgetInfo(appWidgetId) ?: return
            val wPx = if (view.width > 0) view.width else
                (info.minWidth * density).toInt()
            val hPx = if (view.height > 0) view.height else
                (info.minHeight * density).toInt()

            // AppWidgetManager expects dp values in the options bundle.
            val wDp = (wPx / density).toInt().coerceAtLeast(info.minWidth)
            val hDp = (hPx / density).toInt().coerceAtLeast(info.minHeight)

            val opts = Bundle().apply {
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, wDp)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, hDp)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, wDp)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, hDp)
            }
            manager.updateAppWidgetOptions(appWidgetId, opts)
        } catch (_: Exception) {}
    }

    override fun getView(): View = hostView ?: View(context)

    override fun dispose() {}
}
