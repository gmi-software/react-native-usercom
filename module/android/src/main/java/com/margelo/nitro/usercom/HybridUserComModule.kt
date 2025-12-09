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
import com.user.sdk.customer.CustomerUpdateCallback
import com.user.sdk.customer.RegisterResponse

@Keep
@DoNotStrip
class HybridUserComModule : HybridUserComModuleSpec() {

    private val defaultInitTimeout = 1000L

    private fun buildCustomer(customerData: UserComModuleUserData): Customer {
        val customer = Customer()
        customer.id(customerData.id)
        customerData.email?.let { customer.email(it) }
        customerData.firstName?.let { customer.firstName(it) }
        customerData.lastName?.let { customer.lastName(it) }
        customerData.attributes?.forEach { (key, value) ->
            val attrVal = value.asFirstOrNull()
                ?: value.asSecondOrNull() ?: value.asThirdOrNull()
            when (attrVal) {
                is String -> customer.attr(key, attrVal)
                is Boolean -> customer.attr(key, attrVal)
                is Double -> customer.attr(key, attrVal.toInt())
            }
        }
        return customer
    }

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

        val builder =
            UserCom.Builder(application, config.apiKey, config.integrationsApiKey, config.domain)
        builder.setOnSdkInitializedListener(initHandler)
        config.trackAllActivities?.let { builder.trackAllActivities(it) }
        config.openLinksInChromeCustomTabs?.let { builder.openLinksInChromeCustomTabs(it) }
        config.defaultCustomer?.let { builder.setDefaultCustomer(buildCustomer(it)) }

        UserCom.Builder(application, config.apiKey, config.integrationsApiKey, config.domain)
            .setOnSdkInitializedListener(initHandler)
            .build()

        return promise
    }

    override fun registerUser(userData: UserComModuleUserData): Promise<UserComModuleRegisterUserResponse> {
        val promise = Promise<UserComModuleRegisterUserResponse>()

        UserCom.getInstance()
            .register(buildCustomer(userData), object : CustomerUpdateCallback {
                override fun onSuccess(p0: RegisterResponse) {
                    promise.resolve(UserComModuleRegisterUserResponse.create(p0.key))
                }

                override fun onFailure(p0: Throwable) {
                    promise.reject(p0)
                }
            })
        return promise
    }
}
