package com.jarvis.mobile.jarvis_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Native counterpart of HomeWidgetService (Dart, Runde 14 Einheit 7) —
 * home_widget's HomeWidgetProvider base class already reads the shared
 * "HomeWidgetPreferences" file and hands it in as widgetData, so this only
 * needs to render it into a plain RemoteViews layout (RemoteViews can't
 * host a Flutter engine, hence a fully native, non-Flutter widget UI).
 *
 * Tapping the widget body opens the app normally; tapping the "+
 * Blitz-Notiz" button opens the app with a jarviswidget://quicknote URI,
 * which HomeWidgetService.widgetClicks / initiallyLaunchedFromWidget picks
 * up on the Dart side to show the quick-note dialog directly (see
 * home_screen.dart's _handleWidgetClick/_handleColdStartFromWidget).
 */
class JarvisWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val statusLine = widgetData.getString("status_line", null) ?: "Status unbekannt"
        val openTodoCount = widgetData.getInt("open_todo_count", 0)
        val todoLine = when (openTodoCount) {
            0 -> "Keine offenen Aufgaben"
            1 -> "1 offene Aufgabe"
            else -> "$openTodoCount offene Aufgaben"
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.jarvis_widget_layout).apply {
                setTextViewText(R.id.widget_status, statusLine)
                setTextViewText(R.id.widget_todo_count, todoLine)

                val openAppIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, openAppIntent)

                val quickNoteIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("jarviswidget://quicknote"),
                )
                setOnClickPendingIntent(R.id.widget_quicknote, quickNoteIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
