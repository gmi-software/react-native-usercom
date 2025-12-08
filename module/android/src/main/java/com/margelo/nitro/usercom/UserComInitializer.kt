package com.margelo.nitro.usercom

import android.app.Application
import android.util.Log
import com.user.sdk.UserCom
import com.user.sdk.customer.Customer

object UserComInitializer : UserCom.OnSdkInitializedListener {
    @Volatile
    private var initialized = false
    private var initializing = false

    fun init(app: Application, apiKey: String, integrationsApiKey: String, domain: String) {
        if (initialized || initializing) {
            Log.d("UserComInitializer", "Already initialized, skipping.")
            return
        }
        initializing = true

        try {
            Log.d("UserComInitializer", "Initializing User.com SDK…")
            Log.d("UserComInitializer", "apiKey: $apiKey")
            Log.d("UserComInitializer", "integrationsApiKey: $integrationsApiKey")
            Log.d("UserComInitializer", "domain: $domain")

            UserCom.Builder(app, apiKey, integrationsApiKey, domain).build()

            Log.d("UserComInitializer", "User.com SDK initialized successfully.")

        } catch (e: Exception) {
            Log.e("UserComInitializer", "Failed to initialize User.com SDK", e)
        }
    }

    override fun onSdkInitialized(p0: Customer?) {
        initialized = true
        initializing = false
    }

    override fun onUserRegistrationFailed() {

    }
}