package com.lifeos.life_os

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Schedule periodic widget refresh
        WidgetRefreshWorker.schedule(this)
    }
}
