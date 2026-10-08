package com.margelo.nitro.usercom

import android.os.Handler
import android.os.Looper
import android.app.Application
import android.content.Intent
import android.graphics.Typeface
import android.util.Log
import com.facebook.react.bridge.BaseActivityEventListener
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.RemoteMessage
import androidx.annotation.Keep
import com.facebook.proguard.annotations.DoNotStrip
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.AnyMap
import com.margelo.nitro.core.Promise
import com.margelo.nitro.core.resolve
import com.margelo.nitro.core.resolved
import com.user.sdk.UserCom
import com.user.sdk.customer.Customer
import com.user.sdk.customer.CustomerUpdateCallback
import com.user.sdk.customer.RegisterResponse
import com.user.sdk.events.ProductEventType
import java.util.concurrent.atomic.AtomicBoolean

@Keep
@DoNotStrip
class HybridUserComModule : HybridUserComModuleSpec() {

    private val defaultInitTimeout = 10000L
    private val pushApi by lazy {
        UserComPushApi(requireNotNull(NitroModules.applicationContext))
    }
    @Volatile private var pushEnabled = false
    @Volatile private var inAppEnabled = false
    private var linkHandler: ((String) -> Unit)? = null
    private var pendingIntent: Intent? = null
    private var pendingInAppLink: String? = null
    private var activeInAppOwner: String? = null
    private var activityListenerInstalled = false

    private fun configureMessageHandlers(instance: UserCom) {
        instance.setFontResolver { name ->
            // Templates may refer to a font unavailable in the host application.
            Typeface.create(name, Typeface.NORMAL) ?: Typeface.DEFAULT
        }
        if (inAppEnabled || linkHandler != null) {
            instance.setInAppNotificationClickHandler { url ->
                if (inAppEnabled && activeInAppOwner == pushApi.currentUserId()) {
                    val handler = linkHandler
                    if (handler != null) handler(url) else pendingInAppLink = url
                }
            }
        }
        if (!activityListenerInstalled) {
            NitroModules.applicationContext?.addActivityEventListener(object : BaseActivityEventListener() {
                override fun onNewIntent(intent: Intent) {
                    pendingIntent = intent
                    if (pushEnabled && linkHandler != null && intent.getStringExtra("user_com_notification") != null) {
                        val owner = intent.getStringExtra("_nitro_user_id")
                        if (owner != null && owner != pushApi.currentUserId()) { pendingIntent = null; return }
                        intent.getStringExtra("id")?.let { id ->
                            pushApi.clicked(id) { error ->
                                if (error != null) Log.w("UserCom", "Notification click could not be recorded", error)
                            }
                        }
                        intent.getStringExtra("link")?.let { link -> linkHandler?.invoke(link) }
                        intent.removeExtra("user_com_notification")
                        pendingIntent = null
                    }
                }
            })
            activityListenerInstalled = true
        }
    }

    override fun setMessagingEnabled(pushEnabled: Boolean, inAppEnabled: Boolean) {
        this.pushEnabled = pushEnabled
        this.inAppEnabled = inAppEnabled
        UserComMessagePolicy.setEnabled(requireNotNull(NitroModules.applicationContext), pushEnabled, inAppEnabled)
        if (!inAppEnabled) { pendingInAppLink = null; activeInAppOwner = null }
        if (!pushEnabled && !inAppEnabled) pendingIntent = null
        if (inAppEnabled) runCatching { UserCom.getInstance() }.onSuccess { configureMessageHandlers(it) }
    }

    override fun setNotificationLinkHandler(handler: ((String) -> Unit)?) {
        linkHandler = handler
        if (handler != null) {
            runCatching { UserCom.getInstance() }.onSuccess { configureMessageHandlers(it) }
            val pending = pendingInAppLink
            pendingInAppLink = null
            if (inAppEnabled && pending != null) handler(pending)
        }
    }

    override fun consumeInitialNotification(): AnyMap? {
        val activity = NitroModules.applicationContext?.currentActivity
        val intent = pendingIntent ?: activity?.intent ?: return null
        pendingIntent = null
        if (intent.getStringExtra("user_com_notification") == null) return null
        val result = AnyMap()
        intent.extras?.keySet()?.forEach { key ->
            intent.extras?.get(key)?.let { result.setString(key, it.toString()) }
        }
        intent.removeExtra("user_com_notification")
        return result
    }

    override fun registerPushToken(token: String): Promise<Unit> {
        if (!pushEnabled && !inAppEnabled) return Promise.rejected(Throwable("Messaging is disabled"))
        val promise = Promise<Unit>()
        pushApi.bind(token) { error ->
            if (error != null) promise.reject(error) else promise.resolve()
        }
        return promise
    }

    override fun unregisterPushToken(): Promise<Unit> {
        val promise = Promise<Unit>()
        pushApi.unbind { error ->
            if (error != null) promise.reject(error) else promise.resolve()
        }
        return promise
    }

    override fun handleNotification(data: AnyMap, foreground: Boolean, opened: Boolean): Promise<Boolean> {
        val payload = data.toHashMap().mapValues { it.value.toString() }
        if (!payload.containsValue("user_com_notification")) return Promise.resolved(false)
        val inApp = payload["type"] == "4" || payload.containsKey("inapp_message")
        if (inApp && (!inAppEnabled || !foreground || opened)) return Promise.resolved(false)
        if (!inApp && !pushEnabled) return Promise.resolved(false)
        val promise = Promise<Boolean>()
        if (opened) {
            val id = payload["id"] ?: return Promise.rejected(Throwable("Missing notification delivery ID"))
            pushApi.clicked(id) { error ->
                if (error != null) promise.reject(error) else promise.resolve(true)
            }
        } else {
            Handler(Looper.getMainLooper()).post {
                try {
                    if (inApp && !inAppEnabled || !inApp && !pushEnabled) { promise.resolve(false); return@post }
                    val context = requireNotNull(NitroModules.applicationContext)
                    // RemoteMessage.Builder preserves the SDK's string-valued data contract.
                    val ownedPayload = payload + ("_nitro_user_id" to pushApi.currentUserId())
                    if (inApp) activeInAppOwner = pushApi.currentUserId()
                    val message = RemoteMessage.Builder(context.packageName).setData(ownedPayload).build()
                    promise.resolve(UserCom.getInstance().onNotification(context, message))
                } catch (error: Throwable) { promise.reject(error) }
            }
        }
        return promise
    }

    private fun buildCustomer(customerData: UserComModuleUserData): Customer {
        val customer = Customer()
        customer.id(customerData.id)
        customerData.email?.let { customer.email(it) }
        customerData.firstName?.let { customer.firstName(it) }
        customerData.lastName?.let { customer.lastName(it) }
        customerData.phoneNumber?.let { customer.attr("phone_number", it) }
        customerData.attributes?.forEach { (key, value) ->
            val attrVal = value.asFirstOrNull()
                ?: value.asSecondOrNull() ?: value.asThirdOrNull()
            when (attrVal) {
                is String -> customer.attr(key, attrVal)
                is Boolean -> customer.attr(key, attrVal)
                is Double -> {
                    require(attrVal.isFinite() && attrVal % 1.0 == 0.0 && attrVal >= Int.MIN_VALUE && attrVal <= Int.MAX_VALUE) {
                        "Android User.com SDK does not support decimal contact attributes: $key"
                    }
                    customer.attr(key, attrVal.toInt())
                }
            }
        }
        return customer
    }

    override fun initialize(config: UserComModuleConfig): Promise<Unit> {
        val application = NitroModules.applicationContext?.applicationContext as? Application
            ?: return Promise.rejected(
                Throwable("Application context is not available")
            )

        try { pushApi.configure(config) } catch (error: Throwable) { return Promise.rejected(error) }
        val instance = try {
            UserCom.getInstance()
        } catch (_: Throwable) {
            null
        }
        val promise = Promise<Unit>()
        if (instance != null) {
            configureMessageHandlers(instance)
            Log.d("HybridUserComModule", "UserCom SDK already initialized")
            promise.resolve()
            return promise
        }

        val handler = Handler(Looper.getMainLooper())
        val settled = AtomicBoolean(false)

        val timeoutRunnable = Runnable {
            if (settled.compareAndSet(false, true))
                promise.reject(Throwable("UserCom SDK have not been initialized within given timeout"))
        }

        handler.postDelayed(timeoutRunnable, config.initTimeoutMs?.toLong() ?: defaultInitTimeout)

        val initHandler = object : UserCom.OnSdkInitializedListener {
            override fun onSdkInitialized(p0: Customer) {
                handler.removeCallbacks(timeoutRunnable)
                try {
                    configureMessageHandlers(UserCom.getInstance())
                    if (settled.compareAndSet(false, true)) promise.resolve()
                } catch (error: Throwable) {
                    if (settled.compareAndSet(false, true)) promise.reject(error)
                }
            }

            override fun onUserRegistrationFailed() {
                handler.removeCallbacks(timeoutRunnable)
                if (settled.compareAndSet(false, true))
                    promise.reject(Throwable("User registration failed. Check native exceptions."))
            }
        }

        // Android SDK expects a URL; iOS SDK expects a host. Accept either form from JS.
        val domain = config.domain.trim().trimEnd('/')
        val baseUrl = if (domain.startsWith("https://") || domain.startsWith("http://")) {
            "$domain/"
        } else {
            "https://$domain/"
        }
        try {
            val builder =
                UserCom.Builder(application, config.apiKey, config.integrationsApiKey, baseUrl)
            builder.setOnSdkInitializedListener(initHandler)
            config.trackAllActivities?.let { builder.trackAllActivities(it) }
            config.openLinksInChromeCustomTabs?.let { builder.openLinksInChromeCustomTabs(it) }
            config.defaultCustomer?.let { builder.setDefaultCustomer(buildCustomer(it)) }
            builder.build()
        } catch (error: Throwable) {
            handler.removeCallbacks(timeoutRunnable)
            if (settled.compareAndSet(false, true)) promise.reject(error)
        }

        return promise
    }

    override fun registerUser(userData: UserComModuleUserData): Promise<UserComModuleRegisterUserResponse> {
        val promise = Promise<UserComModuleRegisterUserResponse>()

        val instance = try {
            UserCom.getInstance()
        } catch (_: Throwable) {
            promise.reject(Throwable("SDK is not initialized, call initialize() first"))
            return promise
        }

        val customer = try {
            buildCustomer(userData)
        } catch (error: Throwable) {
            return Promise.rejected(error)
        }

        instance.register(customer, object : CustomerUpdateCallback {
                override fun onSuccess(p0: RegisterResponse) {
                    pushApi.identify(userData.id, p0.key)
                    // Android SDK automatically binds its token during register(). Remember
                    // it even in analytics-only mode so the host can detach it immediately.
                    FirebaseMessaging.getInstance().token
                        .addOnSuccessListener { token ->
                            try {
                                pushApi.rememberToken(token) { error ->
                                    if (error != null) promise.reject(error)
                                    else promise.resolve(UserComModuleRegisterUserResponse.create(p0.key))
                                }
                            } catch (error: Throwable) { promise.reject(error) }
                        }
                        .addOnFailureListener { error -> promise.reject(error) }
                }

                override fun onFailure(p0: Throwable) {
                    promise.reject(p0)
                }
            })
        return promise
    }

    override fun logout(): Promise<Unit> {
        val instance = try {
            UserCom.getInstance()
        } catch (_: Throwable) {
            return Promise.rejected(Throwable("SDK is not initialized, call initialize() first"))
        }
        setMessagingEnabled(false, false)
        val promise = Promise<Unit>()
        pushApi.unbind { error ->
            Handler(Looper.getMainLooper()).post {
                try {
                    instance.logout()
                    // SDK 1.2.14 provides no logout-completed callback. This resolves
                    // after token removal and dispatch, not after anonymous registration.
                    if (error != null) promise.reject(error) else promise.resolve()
                } catch (sdkError: Throwable) { promise.reject(sdkError) }
            }
        }
        return promise
    }

    override fun sendProductEvent(
        productId: String,
        eventType: UserComProductEventType,
        params: AnyMap?
    ): Promise<Unit> {
        val instance = try {
            UserCom.getInstance()
        } catch (_: Throwable) {
            return Promise.rejected(Throwable("SDK is not initialized, call initialize() first"))
        }

        val eventType = when (eventType) {
            UserComProductEventType.ADDTOCART -> ProductEventType.ADD_TO_CART
            UserComProductEventType.PURCHASE -> ProductEventType.PURCHASE
            UserComProductEventType.LIKING -> ProductEventType.LIKING
            UserComProductEventType.ADDTOOBSERVATION -> ProductEventType.ADD_TO_OBSERVATION
            UserComProductEventType.ORDER -> ProductEventType.ORDER
            UserComProductEventType.RESERVATION -> ProductEventType.RESERVATION
            UserComProductEventType.RETURN -> ProductEventType.RETURN
            UserComProductEventType.VIEW -> ProductEventType.VIEW
            UserComProductEventType.CLICK -> ProductEventType.CLICK
            UserComProductEventType.DETAIL -> ProductEventType.DETAIL
            UserComProductEventType.ADD -> ProductEventType.ADD
            UserComProductEventType.REMOVE -> ProductEventType.REMOVE
            UserComProductEventType.CHECKOUT -> ProductEventType.CHECKOUT
            UserComProductEventType.CHECKOUTOPTION -> ProductEventType.CHECKOUT_OPTION
            UserComProductEventType.REFUND -> ProductEventType.REFUND
            UserComProductEventType.PROMOCLICK -> ProductEventType.PROMO_CLICK
        }

        instance.sendProductEvent(productId, eventType, params?.toHashMap())
        return Promise.resolved()
    }

    override fun sendCustomEvent(
        eventName: String,
        data: AnyMap
    ): Promise<Unit> {
        val instance = try {
            UserCom.getInstance()
        } catch (_: Throwable) {
            return Promise.rejected(Throwable("SDK is not initialized, call initialize() first"))
        }

        instance.sendEvent(eventName, data.toHashMap())
        return Promise.resolved()
    }

    override fun sendScreenEvent(screenName: String): Promise<Unit> {
        val instance = try {
            UserCom.getInstance()
        } catch (_: Throwable) {
            return Promise.rejected(Throwable("SDK is not initialized, call initialize() first"))
        }

        instance.trackScreen(screenName)
        return Promise.resolved()
    }
}
