package com.margelo.nitro.usercom

import android.app.NotificationManager
import android.content.Context
import android.os.Build

/** Shared with the optional standalone service; absent settings retain its legacy behavior. */
internal object UserComMessagePolicy {
    fun setEnabled(context: Context, push: Boolean, inApp: Boolean) {
        context.getSharedPreferences("nitro_usercom_messaging", Context.MODE_PRIVATE)
            .edit().putBoolean("pushEnabled", push).putBoolean("inAppEnabled", inApp).commit()
        if (!push && Build.VERSION.SDK_INT >= 26) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.activeNotifications.filter { it.notification.channelId == "userComNotificationChannel" }
                .forEach { manager.cancel(it.tag, it.id) }
        }
    }

    fun allows(context: Context, data: Map<String, String>): Boolean {
        val preferences = context.getSharedPreferences("nitro_usercom_messaging", Context.MODE_PRIVATE)
        return if (data["type"] == "4" || data.containsKey("inapp_message")) {
            preferences.getBoolean("inAppEnabled", true)
        } else preferences.getBoolean("pushEnabled", true)
    }
}
