package com.lifeos.life_os

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class TasksWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "TasksWidgetProvider"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "=== TASKS WIDGET onUpdate CALLED ===")
        Log.d(TAG, "========================================")
        Log.d(TAG, "Widget IDs count: ${appWidgetIds.size}")
        
        for (widgetId in appWidgetIds) {
            try {
                Log.d(TAG, ">>> Processing widget ID: $widgetId")
                val views = RemoteViews(context.packageName, R.layout.widget_tasks)
                Log.d(TAG, "RemoteViews created successfully")

                // Get tasks data from shared preferences
                val tasksJson = widgetData.getString("tasks_data", null)
                Log.d(TAG, "Tasks data: ${tasksJson?.take(100)}...")
                
                val tasks = if (tasksJson.isNullOrEmpty()) {
                    emptyList()
                } else {
                    parseTasksJson(tasksJson)
                }
                
                Log.d(TAG, "Parsed ${tasks.size} tasks")

                // Setup header buttons
                setupHeaderButtons(context, views)

                if (tasks.isEmpty()) {
                    views.setViewVisibility(R.id.tasks_list, android.view.View.GONE)
                    views.setViewVisibility(R.id.empty_text, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.empty_text, "Aucune tâche\nTouchez + pour ajouter")
                    Log.d(TAG, "Showing empty state")
                } else {
                    views.setViewVisibility(R.id.tasks_list, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.empty_text, android.view.View.GONE)
                    
                    // Set up the RemoteViewsService for the ListView
                    val intent = Intent(context, TasksWidgetService::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                    }
                    views.setRemoteAdapter(R.id.tasks_list, intent)
                    
                    // Set up the pending intent template for list item clicks
                    // Use FLAG_MUTABLE to allow fill-in intents to modify the data
                    val clickIntent = Intent(context, TaskActionReceiver::class.java).apply {
                        action = "com.lifeos.life_os.TASK_ACTION"
                    }
                    val pendingIntent = android.app.PendingIntent.getBroadcast(
                        context,
                        0,
                        clickIntent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                    )
                    views.setPendingIntentTemplate(R.id.tasks_list, pendingIntent)
                    Log.d(TAG, "Showing ${tasks.size} tasks with ListView (mutable pending intent template set)")
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.tasks_list)
                Log.d(TAG, ">>> Widget $widgetId updated SUCCESSFULLY")
                
            } catch (e: Exception) {
                Log.e(TAG, "!!! EXCEPTION updating widget $widgetId !!!", e)
                Log.e(TAG, "Exception: ${e.message}")
            }
        }
        
        Log.d(TAG, "=== TASKS WIDGET onUpdate FINISHED ===")
    }

    private fun setupHeaderButtons(context: Context, views: RemoteViews) {
        try {
            // Refresh button
            val refreshIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("lifeos://tasks/refresh")
            )
            views.setOnClickPendingIntent(R.id.btn_refresh, refreshIntent)

            // Add button - opens app to add task
            val addIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("lifeos://tasks/add")
            )
            views.setOnClickPendingIntent(R.id.btn_add, addIntent)

            // Settings button
            val settingsIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("lifeos://settings")
            )
            views.setOnClickPendingIntent(R.id.btn_settings, settingsIntent)
            
            Log.d(TAG, "Header buttons setup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up header buttons", e)
        }
    }

    private fun parseTasksJson(json: String): List<TaskWidgetData> {
        val tasks = mutableListOf<TaskWidgetData>()
        try {
            val jsonArray = JSONArray(json)
            for (i in 0 until minOf(jsonArray.length(), 5)) {
                val obj = jsonArray.getJSONObject(i)
                tasks.add(TaskWidgetData(
                    id = obj.getInt("id"),
                    title = obj.getString("title"),
                    isStarred = obj.optBoolean("is_starred", false),
                    hasReminder = obj.optBoolean("has_reminder", false),
                    dueDate = obj.optString("due_date", null)
                ))
            }
            Log.d(TAG, "Parsed ${tasks.size} tasks from JSON")
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing tasks JSON", e)
        }
        return tasks
    }
}

data class TaskWidgetData(
    val id: Int,
    val title: String,
    val isStarred: Boolean,
    val hasReminder: Boolean,
    val dueDate: String?
)
