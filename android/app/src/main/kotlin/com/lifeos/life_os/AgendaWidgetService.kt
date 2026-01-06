package com.lifeos.life_os

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class AgendaWidgetService : RemoteViewsService() {
    
    companion object {
        private const val TAG = "AgendaWidgetService"
    }
    
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        Log.d(TAG, "onGetViewFactory called")
        return AgendaRemoteViewsFactory(applicationContext)
    }
}

class AgendaRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    
    companion object {
        private const val TAG = "AgendaViewsFactory"
    }
    
    private var events = mutableListOf<EventWidgetData>()
    
    override fun onCreate() {
        Log.d(TAG, "onCreate called")
        loadEvents()
    }
    
    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged called")
        loadEvents()
    }
    
    private fun loadEvents() {
        events.clear()
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val eventsJson = prefs.getString("events_data", "[]") ?: "[]"
            Log.d(TAG, "📅 events_data from SharedPrefs: $eventsJson")
            
            val jsonArray = JSONArray(eventsJson)
            Log.d(TAG, "📅 Parsed ${jsonArray.length()} events from JSON")
            
            for (i in 0 until minOf(jsonArray.length(), 3)) {
                val obj = jsonArray.getJSONObject(i)
                val eventData = EventWidgetData(
                    id = obj.getInt("id"),
                    title = obj.getString("title"),
                    date = obj.getString("date"),
                    isAllDay = obj.optBoolean("is_all_day", false),
                    location = obj.optString("location", null)
                )
                events.add(eventData)
                Log.d(TAG, "📅 Added event: ${eventData.title}")
            }
            Log.d(TAG, "📅 Total events loaded: ${events.size}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error loading events", e)
            e.printStackTrace()
        }
    }
    
    override fun onDestroy() {
        events.clear()
    }
    
    override fun getCount(): Int = events.size
    
    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_agenda_item)
        
        if (position >= events.size) return views
        
        val event = events[position]
        
        // Set title
        views.setTextViewText(R.id.event_title, event.title)
        
        // Set time
        val timeText = if (event.isAllDay) {
            "Toute la journée"
        } else {
            formatTime(event.date)
        }
        views.setTextViewText(R.id.event_time, timeText)
        
        // Set location if exists
        if (!event.location.isNullOrEmpty()) {
            views.setViewVisibility(R.id.event_location, android.view.View.VISIBLE)
            views.setTextViewText(R.id.event_location, "📍 ${event.location}")
        } else {
            views.setViewVisibility(R.id.event_location, android.view.View.GONE)
        }
        
        // Show date badge if not today
        if (!isToday(event.date)) {
            views.setViewVisibility(R.id.date_badge, android.view.View.VISIBLE)
            val dateParts = getDateParts(event.date)
            views.setTextViewText(R.id.date_day, dateParts.first)
            views.setTextViewText(R.id.date_month, dateParts.second)
        } else {
            views.setViewVisibility(R.id.date_badge, android.view.View.GONE)
        }
        
        // Set fill-in intent for click handling (opens event detail)
        val fillInIntent = Intent().apply {
            data = Uri.parse("lifeos://agenda/event?id=${event.id}")
        }
        views.setOnClickFillInIntent(R.id.event_item_container, fillInIntent)
        
        Log.d(TAG, "📅 getViewAt($position): ${event.title}")
        
        return views
    }
    
    private fun formatTime(dateString: String): String {
        return try {
            // Try multiple date formats
            val formats = listOf(
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.getDefault()),
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.getDefault()),
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()),
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
            )
            
            var date: java.util.Date? = null
            for (format in formats) {
                try {
                    date = format.parse(dateString)
                    if (date != null) break
                } catch (e: Exception) {
                    // Try next format
                }
            }
            
            if (date == null) {
                Log.e(TAG, "❌ Could not parse date: $dateString")
                return ""
            }
            
            val outputFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            outputFormat.format(date)
        } catch (e: Exception) {
            ""
        }
    }
    
    private fun isToday(dateString: String): Boolean {
        return try {
            val date = parseDate(dateString) ?: return false
            
            val today = Calendar.getInstance()
            val eventCal = Calendar.getInstance().apply { time = date }
            
            today.get(Calendar.YEAR) == eventCal.get(Calendar.YEAR) &&
            today.get(Calendar.DAY_OF_YEAR) == eventCal.get(Calendar.DAY_OF_YEAR)
        } catch (e: Exception) {
            false
        }
    }
    
    private fun getDateParts(dateString: String): Pair<String, String> {
        return try {
            val date = parseDate(dateString) ?: return Pair("", "")
            
            val dayFormat = SimpleDateFormat("d", Locale.getDefault())
            val monthFormat = SimpleDateFormat("MMM", Locale.FRANCE)
            
            Pair(dayFormat.format(date), monthFormat.format(date).uppercase())
        } catch (e: Exception) {
            Pair("", "")
        }
    }
    
    private fun parseDate(dateString: String): java.util.Date? {
        val formats = listOf(
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.getDefault()),
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.getDefault()),
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()),
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
        )
        
        for (format in formats) {
            try {
                val date = format.parse(dateString)
                if (date != null) return date
            } catch (e: Exception) {
                // Try next format
            }
        }
        return null
    }
    
    override fun getLoadingView(): RemoteViews? = null
    
    override fun getViewTypeCount(): Int = 1
    
    override fun getItemId(position: Int): Long = events.getOrNull(position)?.id?.toLong() ?: position.toLong()
    
    override fun hasStableIds(): Boolean = true
}
