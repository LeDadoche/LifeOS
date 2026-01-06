package com.lifeos.life_os

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class AgendaWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "AgendaWidgetProvider"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "onUpdate called with ${appWidgetIds.size} widget(s)")
        
        for (widgetId in appWidgetIds) {
            try {
                Log.d(TAG, "Updating widget ID: $widgetId")
                val views = RemoteViews(context.packageName, R.layout.widget_agenda)

                // Get events data from shared preferences
                val eventsJson = widgetData.getString("events_data", null)
                Log.d(TAG, "Events data from SharedPrefs: $eventsJson")
                
                val events = if (eventsJson.isNullOrEmpty()) {
                    emptyList()
                } else {
                    parseEventsJson(eventsJson)
                }
                
                Log.d(TAG, "Parsed ${events.size} events")

                // Setup header buttons
                setupHeaderButtons(context, views)

                // Update the widget with events
                if (events.isEmpty()) {
                    views.setViewVisibility(R.id.events_list, android.view.View.GONE)
                    views.setViewVisibility(R.id.empty_text, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.empty_text, "Rien de prévu 🥳")
                    Log.d(TAG, "Showing empty state")
                } else {
                    views.setViewVisibility(R.id.events_list, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.empty_text, android.view.View.GONE)
                    
                    // Set up the RemoteViewsService for the ListView
                    val intent = android.content.Intent(context, AgendaWidgetService::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        data = Uri.parse(toUri(android.content.Intent.URI_INTENT_SCHEME))
                    }
                    views.setRemoteAdapter(R.id.events_list, intent)
                    
                    // Set up the pending intent template for list item clicks
                    val clickIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("lifeos://agenda/event")
                    )
                    views.setPendingIntentTemplate(R.id.events_list, clickIntent)
                    Log.d(TAG, "Showing ${events.size} events")
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.events_list)
                Log.d(TAG, "Widget $widgetId updated successfully")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget $widgetId", e)
            }
        }
    }

    private fun setupHeaderButtons(context: Context, views: RemoteViews) {
        try {
            // Refresh button - triggers widget update via background
            val refreshIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("lifeos://agenda/refresh")
            )
            views.setOnClickPendingIntent(R.id.btn_refresh, refreshIntent)

            // Add button - opens app to add event
            val addIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("lifeos://agenda/add")
            )
            views.setOnClickPendingIntent(R.id.btn_add, addIntent)
            
            Log.d(TAG, "Header buttons setup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up header buttons", e)
        }
    }

    private fun parseEventsJson(json: String): List<EventWidgetData> {
        val events = mutableListOf<EventWidgetData>()
        try {
            val jsonArray = JSONArray(json)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                events.add(EventWidgetData(
                    id = obj.getInt("id"),
                    title = obj.getString("title"),
                    date = obj.getString("date"),
                    isAllDay = obj.optBoolean("is_all_day", false),
                    location = obj.optString("location", null)
                ))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return events.take(3) // Limit to 3 events
    }
}

data class EventWidgetData(
    val id: Int,
    val title: String,
    val date: String,
    val isAllDay: Boolean,
    val location: String?
)
