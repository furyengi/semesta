package com.semesta.semesta

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge between the Flutter app and the home-screen widgets.
 *
 * Dart calls: `publish` (store the widget data and redraw), `canPin`, `pin`
 * (ask the launcher to add a widget) and `launchPayload` (the widget tap that
 * started the app). Native calls Dart's `onWidgetTap` when a widget is tapped
 * while the app is running.
 */
class WidgetChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, NAME)

    /** Payload of the widget tap that launched the app; handed over once. */
    var launchPayload: String? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "publish" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("bad_args", "publish expects a map of strings", null)
                    return
                }
                val editor = WidgetData.prefs(context).edit()
                for ((key, value) in args) {
                    if (key is String && value is String) editor.putString(key, value)
                }
                editor.apply()
                refreshAll()
                result.success(null)
            }
            "canPin" -> result.success(canPin())
            "pin" -> result.success(pin(call.arguments as? String))
            "launchPayload" -> {
                val payload = launchPayload
                launchPayload = null
                result.success(payload)
            }
            else -> result.notImplemented()
        }
    }

    /** Tells Dart a widget was tapped while the app was already running. */
    fun sendTap(payload: String) {
        channel.invokeMethod("onWidgetTap", payload)
    }

    private fun refreshAll() {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in PROVIDERS.values) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isEmpty()) continue
            val update = Intent(context, provider).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(update)
        }
    }

    private fun canPin(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported
    }

    private fun pin(kind: String?): Boolean {
        val provider = PROVIDERS[kind] ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = AppWidgetManager.getInstance(context)
        if (!manager.isRequestPinAppWidgetSupported) return false
        return manager.requestPinAppWidget(ComponentName(context, provider), null, null)
    }

    companion object {
        const val NAME = "com.semesta.semesta/widgets"

        /** Keys match `WidgetKind.id` on the Dart side. */
        val PROVIDERS: Map<String, Class<out SemestaWidget>> = mapOf(
            "nextUp" to NextUpWidget::class.java,
            "today" to TodayWidget::class.java,
            "deadlines" to DeadlinesWidget::class.java,
            "continueReading" to ContinueReadingWidget::class.java,
        )
    }
}
