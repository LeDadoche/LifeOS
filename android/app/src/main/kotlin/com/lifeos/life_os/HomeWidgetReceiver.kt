package com.lifeos.life_os

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * HomeWidget Receiver for handling widget background callbacks.
 * This receiver is called when users interact with widgets.
 */
class HomeWidgetReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Forward the intent to HomeWidget plugin for processing
        HomeWidgetPlugin.getData(context)
    }
}
