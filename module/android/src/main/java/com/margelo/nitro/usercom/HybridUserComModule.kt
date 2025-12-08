package com.margelo.nitro.usercom

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.Keep
import com.facebook.proguard.annotations.DoNotStrip
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
import com.margelo.nitro.core.resolve
import com.user.sdk.UserCom
import com.user.sdk.customer.Customer

@Keep
@DoNotStrip
class HybridUserComModule : HybridUserComModuleSpec() {

    private val defaultInitTimeout = 1000L

    override fun initialize(config: UserComModuleConfig): Promise<Unit> {
        val application = NitroModules.applicationContext?.currentActivity?.application
            ?: return Promise.rejected(
                Throwable()
            )

        val instance = try {
            UserCom.getInstance()
        } catch (_: Throwable) {
            null
        }
        val promise = Promise<Unit>()
        if (instance != null) {
            Log.d("HybridUserComModule", "UserCom SDK already initialized")
            promise.resolve()
            return promise
        }

        val handler = Handler(Looper.getMainLooper())

        val timeoutRunnable = Runnable {
            promise.reject(Throwable("UserCom SDK have not been initialized withing given timeout"))
        }

        handler.postDelayed(timeoutRunnable, config.initTimeoutMs?.toLong() ?: defaultInitTimeout)

        val initHandler = object : UserCom.OnSdkInitializedListener {
            override fun onSdkInitialized(p0: Customer) {
                handler.removeCallbacks(timeoutRunnable)
                promise.resolve()
            }

            override fun onUserRegistrationFailed() {
                handler.removeCallbacks(timeoutRunnable)
                promise.reject(Throwable("User registration failed. Check native exceptions."))
            }
        }


        UserCom.Builder(application, config.apiKey, config.integrationsApiKey, config.domain)
            .setOnSdkInitializedListener(initHandler)
            .build()

        return promise
    }
}
