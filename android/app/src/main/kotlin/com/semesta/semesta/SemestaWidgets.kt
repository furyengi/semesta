package com.semesta.semesta

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

/**
 * Base for Semesta's home-screen widgets. Each widget reads what the app
 * last published and draws the entry that is current right now.
 */
abstract class SemestaWidget : AppWidgetProvider() {
    protected abstract val layoutRes: Int

    protected abstract fun bind(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        nowMs: Long,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = WidgetData.prefs(context)
        val now = System.currentTimeMillis()
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutRes)
            try {
                bind(context, views, prefs, now)
            } catch (e: Exception) {
                // Bad data should never leave a broken widget on the home screen.
                showEmpty(context, views, R.string.widget_error)
                views.setOnClickPendingIntent(R.id.widget_root, WidgetIntents.open(context, "tab:0"))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** Hides the content and shows a short message instead. */
    protected fun showEmpty(context: Context, views: RemoteViews, messageRes: Int) {
        views.setViewVisibility(R.id.content, android.view.View.GONE)
        views.setViewVisibility(R.id.empty, android.view.View.VISIBLE)
        views.setTextViewText(R.id.empty, context.getString(messageRes))
    }

    protected fun setClick(context: Context, views: RemoteViews, viewId: Int, payload: String) {
        views.setOnClickPendingIntent(viewId, WidgetIntents.open(context, payload))
    }
}

/** The next class or exam. */
class NextUpWidget : SemestaWidget() {
    override val layoutRes = R.layout.widget_next_up

    override fun bind(context: Context, views: RemoteViews, prefs: SharedPreferences, nowMs: Long) {
        val entry = WidgetData.currentNextUp(prefs.getString(WidgetData.KEY_NEXT_UP, null), nowMs)
        if (entry == null) {
            showEmpty(context, views, R.string.widget_empty_next_up)
            setClick(context, views, R.id.widget_root, "tab:2")
            return
        }
        val ongoing = entry.optLong("startMs", Long.MAX_VALUE) <= nowMs
        views.setTextViewText(
            R.id.header,
            context.getString(if (ongoing) R.string.widget_header_now else R.string.widget_header_next_up),
        )
        views.setTextViewText(R.id.title, entry.optString("title"))
        views.setTextViewText(R.id.when_text, entry.optString("when"))
        val subtitle = entry.optString("subtitle")
        if (subtitle.isEmpty()) {
            views.setViewVisibility(R.id.subtitle, android.view.View.GONE)
        } else {
            views.setTextViewText(R.id.subtitle, subtitle)
        }
        setClick(context, views, R.id.widget_root, entry.optString("payload", "tab:2"))
    }
}

/** Today's classes, study sessions and deadlines. */
class TodayWidget : SemestaWidget() {
    override val layoutRes = R.layout.widget_today

    private val rows = intArrayOf(R.id.row1, R.id.row2, R.id.row3, R.id.row4, R.id.row5)
    private val times = intArrayOf(R.id.time1, R.id.time2, R.id.time3, R.id.time4, R.id.time5)
    private val titles = intArrayOf(R.id.title1, R.id.title2, R.id.title3, R.id.title4, R.id.title5)

    override fun bind(context: Context, views: RemoteViews, prefs: SharedPreferences, nowMs: Long) {
        val items = WidgetData.todayEntries(prefs.getString(WidgetData.KEY_TODAY, null), nowMs)
        setClick(context, views, R.id.widget_root, "tab:2")
        if (items.isEmpty()) {
            showEmpty(context, views, R.string.widget_empty_today)
            return
        }
        val dim = context.getColor(R.color.widget_dim)
        for (i in rows.indices) {
            if (i >= items.size) {
                views.setViewVisibility(rows[i], android.view.View.GONE)
                continue
            }
            val item = items[i]
            views.setViewVisibility(rows[i], android.view.View.VISIBLE)
            views.setTextViewText(times[i], item.optString("time"))
            views.setTextViewText(titles[i], item.optString("title"))
            // Things that are already over fade back.
            if (item.optLong("endMs", Long.MAX_VALUE) < nowMs) {
                views.setTextColor(titles[i], dim)
            }
            setClick(context, views, rows[i], item.optString("payload", "tab:2"))
        }
        if (items.size > rows.size) {
            views.setViewVisibility(R.id.more, android.view.View.VISIBLE)
            views.setTextViewText(R.id.more, context.getString(R.string.widget_more, items.size - rows.size))
        }
    }
}

/** The next few assignment deadlines. */
class DeadlinesWidget : SemestaWidget() {
    override val layoutRes = R.layout.widget_deadlines

    private val rows = intArrayOf(R.id.dl1, R.id.dl2, R.id.dl3, R.id.dl4)
    private val titles = intArrayOf(R.id.dl1_title, R.id.dl2_title, R.id.dl3_title, R.id.dl4_title)
    private val whens = intArrayOf(R.id.dl1_when, R.id.dl2_when, R.id.dl3_when, R.id.dl4_when)

    override fun bind(context: Context, views: RemoteViews, prefs: SharedPreferences, nowMs: Long) {
        val items = WidgetData.deadlines(prefs.getString(WidgetData.KEY_DEADLINES, null), rows.size)
        setClick(context, views, R.id.widget_root, "tab:1")
        if (items.isEmpty()) {
            showEmpty(context, views, R.string.widget_empty_deadlines)
            return
        }
        val overdueColor = context.getColor(R.color.widget_overdue)
        for (i in rows.indices) {
            if (i >= items.size) {
                views.setViewVisibility(rows[i], android.view.View.GONE)
                continue
            }
            val item = items[i]
            views.setViewVisibility(rows[i], android.view.View.VISIBLE)
            views.setTextViewText(titles[i], item.optString("title"))
            val whenText = item.optString("when")
            val subtitle = item.optString("subtitle")
            val line = if (subtitle.isEmpty()) whenText else "$whenText · $subtitle"
            if (item.optLong("dueMs", Long.MAX_VALUE) < nowMs) {
                views.setTextViewText(whens[i], context.getString(R.string.widget_overdue, line))
                views.setTextColor(whens[i], overdueColor)
            } else {
                views.setTextViewText(whens[i], line)
            }
            setClick(context, views, rows[i], item.optString("payload", "tab:1"))
        }
    }
}

/** A shortcut back into the document you were reading. */
class ContinueReadingWidget : SemestaWidget() {
    override val layoutRes = R.layout.widget_continue

    override fun bind(context: Context, views: RemoteViews, prefs: SharedPreferences, nowMs: Long) {
        val entry = WidgetData.continueEntry(prefs.getString(WidgetData.KEY_CONTINUE, null))
        if (entry == null) {
            showEmpty(context, views, R.string.widget_empty_continue)
            setClick(context, views, R.id.widget_root, "tab:0")
            return
        }
        views.setTextViewText(R.id.title, entry.optString("title"))
        views.setTextViewText(R.id.subtitle, entry.optString("subtitle"))
        views.setProgressBar(R.id.progress, 100, entry.optInt("progress", 0).coerceIn(0, 100), false)
        setClick(context, views, R.id.widget_root, entry.optString("payload", "tab:0"))
    }
}
