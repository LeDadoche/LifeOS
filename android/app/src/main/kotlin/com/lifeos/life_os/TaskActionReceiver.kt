package com.lifeos.life_os

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Custom BroadcastReceiver for handling task actions from the widget.
 * This receiver extracts the task_id and action from the fill-in intent extras
 * and forwards them to the home_widget background callback.
 */
class TaskActionReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "TaskActionReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "TaskActionReceiver onReceive called")
        Log.d(TAG, "========================================")
        
        // Extract extras from the fill-in intent
        val taskId = intent.getIntExtra("task_id", -1)
        val action = intent.getStringExtra("action") ?: "unknown"
        
        Log.d(TAG, "Task ID: $taskId")
        Log.d(TAG, "Action: $action")
        
        if (taskId == -1) {
            Log.e(TAG, "No task_id found in intent extras")
            return
        }
        
        // Build the URI for the home_widget callback
        val uri = when (action) {
            "complete" -> "lifeos://tasks/complete?id=$taskId"
            "star" -> "lifeos://tasks/star?id=$taskId"
            else -> {
                Log.e(TAG, "Unknown action: $action")
                return
            }
        }
        
        Log.d(TAG, "Forwarding to HomeWidget callback with URI: $uri")
        
        // Create a broadcast to the HomeWidget background receiver
        val homeWidgetIntent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
            data = Uri.parse(uri)
            this.action = "es.antonborri.home_widget.action.BACKGROUND"
        }
        
        context.sendBroadcast(homeWidgetIntent)
        Log.d(TAG, "Broadcast sent to HomeWidgetBackgroundReceiver")
    }
}
