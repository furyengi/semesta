package com.semesta.semesta

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Taps on a widget open the app with a "payload" such as `tab:2` or
 * `doc:ID:7`, the same format reminders use, which the Flutter side maps to
 * a screen.
 */
object WidgetIntents {
    const val ACTION_OPEN = "com.semesta.semesta.action.OPEN_FROM_WIDGET"
    private const val PARAM_PAYLOAD = "payload"

    /** The payload carried by an intent made by [open], or null. */
    fun payloadOf(intent: Intent?): String? {
        if (intent == null || intent.action != ACTION_OPEN) return null
        return intent.data?.getQueryParameter(PARAM_PAYLOAD)
    }

    fun open(context: Context, payload: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN
            // Different payloads must be different intents, or the system
            // would reuse one PendingIntent for all of them.
            data = Uri.parse("semesta://widget").buildUpon()
                .appendQueryParameter(PARAM_PAYLOAD, payload)
                .build()
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            payload.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
