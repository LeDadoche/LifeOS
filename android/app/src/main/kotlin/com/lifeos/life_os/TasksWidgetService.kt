package com.lifeos.life_os

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TasksWidgetService : RemoteViewsService() {
    
    companion object {
        private const val TAG = "TasksWidgetService"
    }
    
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        Log.d(TAG, "onGetViewFactory called")
        return TasksRemoteViewsFactory(applicationContext)
    }
}

class TasksRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    
    companion object {
        private const val TAG = "TasksRemoteViewsFactory"
    }
    
    private var tasks = mutableListOf<TaskItem>()
    
    override fun onCreate() {
        Log.d(TAG, "onCreate called")
        loadTasks()
    }
    
    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged called")
        loadTasks()
    }
    
    private fun loadTasks() {
        tasks.clear()
        try {
            // Try multiple preference names as home_widget may use different ones
            var tasksJson: String? = null
            
            // Try the group container name first (recommended for home_widget)
            val groupPrefs = context.getSharedPreferences("group.lifeos.widgets", Context.MODE_PRIVATE)
            tasksJson = groupPrefs.getString("tasks_data", null)
            Log.d(TAG, "group.lifeos.widgets tasks_data: $tasksJson")
            
            if (tasksJson == null) {
                // Try HomeWidgetPreferences
                val homeWidgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                tasksJson = homeWidgetPrefs.getString("tasks_data", null)
                Log.d(TAG, "HomeWidgetPreferences tasks_data: $tasksJson")
            }
            
            if (tasksJson == null) {
                // Try FlutterSharedPreferences
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                tasksJson = flutterPrefs.getString("flutter.tasks_data", null)
                Log.d(TAG, "FlutterSharedPreferences flutter.tasks_data: $tasksJson")
            }
            
            if (tasksJson.isNullOrEmpty() || tasksJson == "[]") {
                Log.d(TAG, "No tasks data found, using empty list")
                return
            }
            
            val jsonArray = JSONArray(tasksJson)
            Log.d(TAG, "Found ${jsonArray.length()} tasks in JSON")
            
            for (i in 0 until minOf(jsonArray.length(), 5)) {
                val obj = jsonArray.getJSONObject(i)
                // Handle null due_date properly - optString returns "null" string if value is JSON null
                val dueDateValue = if (obj.isNull("due_date")) null else obj.optString("due_date", null)
                val cleanDueDate = if (dueDateValue == "null" || dueDateValue.isNullOrEmpty()) null else dueDateValue
                
                tasks.add(TaskItem(
                    id = obj.getInt("id"),
                    title = obj.getString("title"),
                    isStarred = obj.optBoolean("is_starred", false),
                    hasReminder = obj.optBoolean("has_reminder", false),
                    dueDate = cleanDueDate
                ))
                Log.d(TAG, "Added task: ${obj.getString("title")} with dueDate: $cleanDueDate")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading tasks", e)
        }
    }
    
    override fun onDestroy() {
        Log.d(TAG, "onDestroy called")
        tasks.clear()
    }
    
    override fun getCount(): Int {
        Log.d(TAG, "getCount: ${tasks.size}")
        return tasks.size
    }
    
    override fun getViewAt(position: Int): RemoteViews {
        Log.d(TAG, "getViewAt: $position")
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)
        
        if (position >= tasks.size) {
            Log.w(TAG, "Position $position out of bounds (size: ${tasks.size})")
            return views
        }
        
        val task = tasks[position]
        Log.d(TAG, "Rendering task: ${task.title}")
        
        // Set title
        views.setTextViewText(R.id.task_title, task.title)
        
        // Set star icon (using the ImageView inside the FrameLayout)
        views.setImageViewResource(
            R.id.task_star_icon,
            if (task.isStarred) R.drawable.ic_star_filled else R.drawable.ic_star_outline
        )
        
        // Set reminder icon visibility
        views.setViewVisibility(
            R.id.task_reminder_icon,
            if (task.hasReminder) android.view.View.VISIBLE else android.view.View.GONE
        )
        
        // Set due date if exists (also check for "null" string)
        if (!task.dueDate.isNullOrEmpty() && task.dueDate != "null") {
            views.setViewVisibility(R.id.due_date_row, android.view.View.VISIBLE)
            views.setTextViewText(R.id.task_due_date, formatDueDate(task.dueDate))
            
            // Check if overdue and set color
            if (isOverdue(task.dueDate)) {
                views.setTextColor(R.id.task_due_date, 0xFFFF6B6B.toInt()) // Red
            } else {
                views.setTextColor(R.id.task_due_date, 0xFFB0BEC5.toInt()) // Gray
            }
        } else {
            views.setViewVisibility(R.id.due_date_row, android.view.View.GONE)
        }
        
        // Set fill-in intent for checkbox (complete task)
        // The fill-in intent will be merged with the pending intent template
        val checkFillInIntent = Intent().apply {
            putExtra("task_id", task.id)
            putExtra("action", "complete")
        }
        views.setOnClickFillInIntent(R.id.task_check, checkFillInIntent)
        Log.d(TAG, "Set checkbox fill-in intent for task ${task.id}")
        
        // Set fill-in intent for star button (toggle favorite)
        val starFillInIntent = Intent().apply {
            putExtra("task_id", task.id)
            putExtra("action", "star")
        }
        views.setOnClickFillInIntent(R.id.task_star, starFillInIntent)
        Log.d(TAG, "Set star fill-in intent for task ${task.id}")
        
        return views
    }
    
    private fun formatDueDate(dateString: String): String {
        return try {
            val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val date = inputFormat.parse(dateString) ?: return dateString
            
            val outputFormat = SimpleDateFormat("EEE d MMM yyyy", Locale.FRANCE)
            outputFormat.format(date)
        } catch (e: Exception) {
            dateString
        }
    }
    
    private fun isOverdue(dateString: String): Boolean {
        return try {
            val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val date = inputFormat.parse(dateString) ?: return false
            date.before(Date())
        } catch (e: Exception) {
            false
        }
    }
    
    override fun getLoadingView(): RemoteViews? = null
    
    override fun getViewTypeCount(): Int = 1
    
    override fun getItemId(position: Int): Long = tasks.getOrNull(position)?.id?.toLong() ?: position.toLong()
    
    override fun hasStableIds(): Boolean = true
}

// Local data class for TasksWidgetService
data class TaskItem(
    val id: Int,
    val title: String,
    val isStarred: Boolean,
    val hasReminder: Boolean,
    val dueDate: String?
)
