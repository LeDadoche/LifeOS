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
    private var loadError = false
    private var isLoading = false
    
    override fun onCreate() {
        Log.d(TAG, "onCreate called")
        loadEventsDirect()
    }
    
    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged called - loading events directly")
        loadEventsDirect()
    }
    
    /**
     * Charge les événements DIRECTEMENT (onDataSetChanged est déjà sur un worker thread)
     * Pas besoin de thread séparé ou de timeout - Android gère ça
     */
    private fun loadEventsDirect() {
        isLoading = true
        loadError = false
        events.clear()
        
        try {
            var eventsJson: String? = null
            
            // Try HomeWidgetPreferences first (home_widget package)
            val homeWidgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            eventsJson = homeWidgetPrefs.getString("events_data", null)
            Log.d(TAG, "📅 HomeWidgetPreferences events_data: $eventsJson")
            
            // Fallback to FlutterSharedPreferences
            if (eventsJson.isNullOrEmpty() || eventsJson == "[]") {
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                eventsJson = flutterPrefs.getString("flutter.events_data", null)
                Log.d(TAG, "📅 FlutterSharedPreferences flutter.events_data: $eventsJson")
            }
            
            if (eventsJson.isNullOrEmpty()) {
                Log.d(TAG, "📅 No events data found in SharedPreferences")
                isLoading = false
                return
            }
            
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
            Log.d(TAG, "✅ Total events loaded: ${events.size}")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error loading events", e)
            e.printStackTrace()
            loadError = true
        } finally {
            isLoading = false
        }
    }
    
    override fun onDestroy() {
        events.clear()
    }
    
    /**
     * Retourne le nombre d'items : 
     * - Si aucun événement → 0 (ListView vide, Provider gère l'affichage)
     * - Sinon → nombre d'événements
     */
    override fun getCount(): Int {
        Log.d(TAG, "getCount: returning ${events.size}")
        return events.size
    }
    
    override fun getViewAt(position: Int): RemoteViews {
        Log.d(TAG, "🎯 getViewAt($position) called - events.size=${events.size}, loadError=$loadError")
        
        // TRY/CATCH GÉANT pour capturer TOUTES les erreurs de rendu
        try {
            // Si erreur de chargement, afficher un message "Appuyez pour rafraîchir"
            if (loadError) {
                Log.d(TAG, "Showing error/refresh view")
                return createErrorView("Erreur de synchro", "Appuyez ici ⟳")
            }
            
            // Si pas d'événements (liste vide avec données valides ou pas de données)
            if (events.isEmpty()) {
                Log.d(TAG, "Showing empty state view")
                return createErrorView("Aucun événement", "Appuyez pour actualiser")
            }
            
            // Vérification des bounds
            if (position < 0 || position >= events.size) {
                Log.w(TAG, "⚠️ Position $position out of bounds (size=${events.size})")
                return createErrorView("Erreur index", "Position invalide")
            }
            
            val event = events[position]
            Log.d(TAG, "🎯 Tentative de rendu de l'item $position avec les données : ${event.title}")
            
            // Créer la vue avec gestion d'erreur pour chaque étape
            val views = RemoteViews(context.packageName, R.layout.widget_agenda_item)
            
            // Set title
            views.setTextViewText(R.id.event_title, event.title)
            Log.d(TAG, "✅ Title set: ${event.title}")
            
            // Set time (avec fallback)
            val timeText = try {
                if (event.isAllDay) {
                    "Toute la journée"
                } else {
                    formatTime(event.date) ?: ""
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error formatting time", e)
                ""
            }
            views.setTextViewText(R.id.event_time, timeText)
            Log.d(TAG, "✅ Time set: $timeText")
            
            // Set location if exists
            try {
                if (!event.location.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.event_location, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.event_location, event.location)
                } else {
                    views.setViewVisibility(R.id.event_location, android.view.View.GONE)
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error setting location", e)
                views.setViewVisibility(R.id.event_location, android.view.View.GONE)
            }
            
            // Date badge supprimé pour simplification
            views.setViewVisibility(R.id.date_badge, android.view.View.GONE)
            
            // Set fill-in intent for click handling (opens event detail)
            try {
                val fillInIntent = Intent().apply {
                    data = Uri.parse("lifeos://agenda/event?id=${event.id}")
                }
                views.setOnClickFillInIntent(R.id.event_item_container, fillInIntent)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error setting click intent", e)
            }
            
            Log.d(TAG, "✅ getViewAt($position) SUCCESS: ${event.title}")
            
            return views
            
        } catch (e: Exception) {
            // CATCH GÉANT - Si QUOI QUE CE SOIT échoue, retourner une vue d'erreur
            Log.e(TAG, "❌❌❌ FATAL ERROR in getViewAt($position)", e)
            e.printStackTrace()
            return createErrorView("Erreur de rendu", "Appuyez pour réessayer")
        }
    }
    
    /**
     * Crée une vue d'erreur/fallback simple
     */
    private fun createErrorView(title: String, subtitle: String): RemoteViews {
        return try {
            val errorViews = RemoteViews(context.packageName, R.layout.widget_agenda_item)
            errorViews.setTextViewText(R.id.event_title, title)
            errorViews.setTextViewText(R.id.event_time, subtitle)
            errorViews.setViewVisibility(R.id.event_location, android.view.View.GONE)
            errorViews.setViewVisibility(R.id.date_badge, android.view.View.GONE)
            
            // Intent pour rafraîchir
            val refreshIntent = Intent().apply {
                data = Uri.parse("lifeos://agenda/refresh")
            }
            errorViews.setOnClickFillInIntent(R.id.event_item_container, refreshIntent)
            
            errorViews
        } catch (e: Exception) {
            Log.e(TAG, "❌❌❌ Even createErrorView failed!", e)
            // Dernier recours: vue minimale
            RemoteViews(context.packageName, R.layout.widget_agenda_item)
        }
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
    
    /**
     * Retourne une vue de chargement simple au lieu de null
     * pour éviter l'affichage du texte "Chargement..." par défaut d'Android
     */
    override fun getLoadingView(): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_agenda_item).apply {
            setTextViewText(R.id.event_title, "")
            setTextViewText(R.id.event_time, "")
            setViewVisibility(R.id.event_location, android.view.View.GONE)
            setViewVisibility(R.id.date_badge, android.view.View.GONE)
        }
    }
    
    override fun getViewTypeCount(): Int = 1
    
    override fun getItemId(position: Int): Long = events.getOrNull(position)?.id?.toLong() ?: position.toLong()
    
    override fun hasStableIds(): Boolean = true
}
