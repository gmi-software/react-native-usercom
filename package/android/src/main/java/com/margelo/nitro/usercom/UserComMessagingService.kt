package com.margelo.nitro.usercom

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.user.sdk.UserCom

/** Optional FCM receiver for apps without another FirebaseMessagingService. */
class UserComMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // FCM can start this service before the host app initializes User.com.
        runCatching { UserCom.getInstance() }
            .onSuccess { it.onNotification(applicationContext, remoteMessage) }
    }
}
