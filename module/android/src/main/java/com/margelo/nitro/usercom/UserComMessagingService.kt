package com.margelo.nitro.usercom

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.user.sdk.UserCom

// TODO: Messaging service should extend ReactNativeMessagingService for react-native-messaging to work properly
class UserComMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        UserCom.getInstance().onNotification(this, remoteMessage)
        super.onMessageReceived(remoteMessage)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }
}

