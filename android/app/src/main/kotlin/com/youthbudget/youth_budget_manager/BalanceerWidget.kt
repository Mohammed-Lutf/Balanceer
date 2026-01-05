package com.youthbudget.youth_budget_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BalanceerWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: android.content.SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val amount = widgetData.getString("amount", "0.00")
                val currency = widgetData.getString("currency", "SAR")
                
                setTextViewText(R.id.widget_amount, "$amount $currency")

                // Open App on widget click
                val pendingIntent = Intent(context, MainActivity::class.java).let { intent ->
                    PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                }
                setOnClickPendingIntent(R.id.widget_title, pendingIntent)
                setOnClickPendingIntent(R.id.widget_amount, pendingIntent)
                setOnClickPendingIntent(R.id.widget_button, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
