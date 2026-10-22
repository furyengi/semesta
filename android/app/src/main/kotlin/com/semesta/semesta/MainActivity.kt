package com.semesta.semesta

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var widgets: WidgetChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = WidgetChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // A widget tap that started the app (cold start).
        channel.launchPayload = WidgetIntents.payloadOf(intent)
        widgets = channel
    }

    // A widget tap while the app is already open (the activity is singleTop).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        WidgetIntents.payloadOf(intent)?.let { widgets?.sendTap(it) }
    }
}
