package com.semesta.semesta

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Reads the timelines the Flutter app publishes for the home-screen widgets.
 *
 * Widgets can't run Dart and the app may not be opened for hours, so the app
 * hands over several upcoming entries and the widget picks the current one
 * each time it redraws. These rules mirror the Dart versions in
 * `lib/data/widget_data.dart` (currentNextUp, todayEntries, deadlineEntries).
 */
object WidgetData {
    const val PREFS = "semesta_widgets"

    const val KEY_NEXT_UP = "nextup"
    const val KEY_TODAY = "today"
    const val KEY_DEADLINES = "deadlines"
    const val KEY_CONTINUE = "continue"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun entries(json: String?): List<JSONObject> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(json)
            val out = ArrayList<JSONObject>()
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i)
                if (item != null) out.add(item)
            }
            out
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** The first next-up entry that has not finished by [nowMs]. */
    fun currentNextUp(json: String?, nowMs: Long): JSONObject? =
        entries(json).firstOrNull { it.optLong("endMs", 0L) > nowMs }

    /** Entries that start on the local calendar day containing [nowMs]. */
    fun todayEntries(json: String?, nowMs: Long): List<JSONObject> {
        val start = Calendar.getInstance().apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val end = (start.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, 1) }
        val from = start.timeInMillis
        val to = end.timeInMillis
        return entries(json).filter {
            val t = it.optLong("startMs", -1L)
            t in from until to
        }
    }

    /** Up to [max] deadlines, soonest first (the app already sorted them). */
    fun deadlines(json: String?, max: Int): List<JSONObject> =
        entries(json).filter { it.has("dueMs") }.take(max)

    /** The continue-reading entry, or null when there is none. */
    fun continueEntry(json: String?): JSONObject? {
        if (json.isNullOrEmpty()) return null
        return try {
            val obj = JSONObject(json)
            if (obj.length() == 0) null else obj
        } catch (e: Exception) {
            null
        }
    }
}
