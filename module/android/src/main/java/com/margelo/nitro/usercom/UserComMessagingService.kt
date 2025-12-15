package com.margelo.nitro.usercom

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.user.sdk.UserCom
//import io.invertase.firebase.messaging.ReactNativeFirebaseMessagingService

// TODO: Messaging service should extend ReactNativeMessagingService for react-native-messaging to work properly
class UserComMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val success = UserCom.getInstance().onNotification(this, remoteMessage)
        Log.d("UserComMessagingService", success.toString())
        super.onMessageReceived(remoteMessage)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }
}

