package com.lifeos.life_os

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker for periodic widget refresh.
 * Runs every 15-30 minutes to keep widget data up to date.
 */
class WidgetRefreshWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    override fun doWork(): Result {
        return try {
            // Notify all widgets to refresh
            refreshWidgets()
            Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            Result.retry()
        }
    }

    private fun refreshWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(context)

        // Refresh Tasks Widget
        val tasksComponent = ComponentName(context, TasksWidgetProvider::class.java)
        val tasksWidgetIds = appWidgetManager.getAppWidgetIds(tasksComponent)
        if (tasksWidgetIds.isNotEmpty()) {
            appWidgetManager.notifyAppWidgetViewDataChanged(tasksWidgetIds, android.R.id.list)
            
            // Trigger an update broadcast
            val tasksIntent = android.content.Intent(context, TasksWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, tasksWidgetIds)
            }
            context.sendBroadcast(tasksIntent)
        }

        // Refresh Agenda Widget
        val agendaComponent = ComponentName(context, AgendaWidgetProvider::class.java)
        val agendaWidgetIds = appWidgetManager.getAppWidgetIds(agendaComponent)
        if (agendaWidgetIds.isNotEmpty()) {
            appWidgetManager.notifyAppWidgetViewDataChanged(agendaWidgetIds, android.R.id.list)
            
            // Trigger an update broadcast
            val agendaIntent = android.content.Intent(context, AgendaWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, agendaWidgetIds)
            }
            context.sendBroadcast(agendaIntent)
        }
    }

    companion object {
        private const val WORK_NAME = "widget_refresh_work"

        /**
         * Schedule periodic widget refresh.
         * Runs every 15 minutes (minimum allowed by WorkManager).
         */
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val workRequest = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(
                15, TimeUnit.MINUTES  // Minimum allowed period
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
        }

        /**
         * Cancel scheduled widget refresh.
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
