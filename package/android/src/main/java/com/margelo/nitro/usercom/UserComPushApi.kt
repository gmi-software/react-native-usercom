package com.margelo.nitro.usercom

import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/** Mobile SDK endpoints, not the privileged public REST API. No Firebase dependency. */
internal class UserComPushApi(
    context: Context,
    private val connectionFactory: (URL) -> HttpURLConnection = { it.openConnection() as HttpURLConnection }
) {
    private val storage = context.getSharedPreferences("nitro_usercom_messaging", Context.MODE_PRIVATE)
    private val executor = Executors.newSingleThreadExecutor()
    private val stateLock = Any()
    private var baseUrl = ""
    private var apiKey = ""
    private var userKey = ""
    private var userId = ""
    private var generation = 0L
    private var identityGeneration = 0L
    private data class Snapshot(val binding: JSONObject, val generation: Long, val identityGeneration: Long)
    private class HttpError(val status: Int) : IllegalStateException("User.com messaging HTTP $status")

    fun currentUserId(): String = synchronized(stateLock) { userId }

    fun invalidatePendingBindings() { synchronized(stateLock) { generation++ } }

    fun clearIdentity() {
        synchronized(stateLock) { generation++; identityGeneration++; userId = ""; userKey = "" }
    }

    private fun checkIdentity(snapshot: Snapshot, bindingOperation: Boolean = true) {
        check(synchronized(stateLock) {
            identityGeneration == snapshot.identityGeneration && userKey.isNotEmpty() &&
                (!bindingOperation || generation == snapshot.generation)
        }) {
            "User.com contact changed before token operation"
        }
    }

    fun configure(config: UserComModuleConfig) {
        val host = config.domain.trim().removePrefix("https://").removePrefix("http://").trimEnd('/')
        require(host.endsWith(".user.com") && !host.contains('/') && !host.contains('@')) {
            "Expected a User.com workspace host"
        }
        synchronized(stateLock) {
            val url = "https://$host/"
            if (baseUrl != url || apiKey != config.apiKey) {
                generation++; identityGeneration++; userId = ""; userKey = ""
            }
            baseUrl = url
            apiKey = config.apiKey
        }
    }

    fun identify(id: String, key: String) {
        synchronized(stateLock) {
            if (userId != id || userKey != key) { generation++; identityGeneration++ }
            userId = id
            userKey = key
        }
    }

    fun rememberToken(token: String, complete: (Throwable?) -> Unit) {
        val snapshot = snapshot(token)
        executor.execute {
            try {
                // The upstream SDK may already have bound this token even after
                // messaging opt-out. Remember it for cleanup, without re-enabling it.
                checkIdentity(snapshot, bindingOperation = false)
                saveBinding(snapshot.binding)
                complete(null)
            } catch (error: Throwable) { complete(error) }
        }
    }

    private fun recordKey(binding: JSONObject): String = binding.getString("baseUrl") + ":" + binding.getString("userKey") + ":" + binding.getString("token")

    private fun saveBinding(binding: JSONObject) {
        val old = storage.getString("binding", null)?.let { JSONObject(it) }
        if (old != null && recordKey(old) != recordKey(binding)) {
            val pending = JSONObject(storage.getString("removals", "{}")!!)
            pending.put(recordKey(old), old)
            storage.edit().putString("removals", pending.toString()).commit()
        }
        // Persist before HTTP: a timeout may still have registered the token.
        storage.edit().putString("binding", binding.toString()).commit()
    }

    private fun snapshot(token: String): Snapshot = synchronized(stateLock) {
        Snapshot(JSONObject().put("baseUrl", baseUrl).put("apiKey", apiKey)
            .put("userKey", userKey).put("userId", userId).put("token", token), generation, identityGeneration)
    }

    fun bind(token: String, complete: (Throwable?) -> Unit) {
        val snapshot = snapshot(token)
        val binding = snapshot.binding
        executor.execute {
            try {
                checkIdentity(snapshot)
                saveBinding(binding)
                checkIdentity(snapshot)
                request(binding, "POST", "api/sdk/v1/ping/", JSONObject()
                    .put("customer", JSONObject().put("user_id", binding.getString("userId")))
                    .put("device", JSONObject().put("os_type", "Android").put("fcm_key", token)))
                discardTransferredRemovals(binding)
                checkIdentity(snapshot)
                complete(null)
                runCatching { flushRemovals() }.onFailure {
                    android.util.Log.w("UserCom", "Previous token removal remains pending", it)
                }
            } catch (error: Throwable) { complete(error) }
        }
    }

    private fun discardTransferredRemovals(active: JSONObject) {
        val pending = JSONObject(storage.getString("removals", "{}")!!)
        for (key in pending.keys().asSequence().toList()) {
            val old = pending.getJSONObject(key)
            if (old.getString("baseUrl") == active.getString("baseUrl") && old.getString("token") == active.getString("token")) {
                pending.remove(key)
            }
        }
        storage.edit().putString("removals", pending.toString()).commit()
    }

    fun unbind(complete: (Throwable?) -> Unit) {
        executor.execute {
            try {
                val binding = storage.getString("binding", null)
                if (binding != null) {
                    val pending = JSONObject(storage.getString("removals", "{}")!!)
                    val record = JSONObject(binding)
                    pending.put(recordKey(record), record)
                    storage.edit().putString("removals", pending.toString()).remove("binding").commit()
                }
                flushRemovals()
                complete(null)
            } catch (error: Throwable) { complete(error) }
        }
    }

    private fun flushRemovals() {
        val pending = JSONObject(storage.getString("removals", "{}")!!)
        var firstError: Throwable? = null
        for (key in pending.keys().asSequence().toList()) {
            val binding = pending.getJSONObject(key)
            try {
                request(binding, "DELETE", "api/sdk/v1/delete-fcm-token/",
                    JSONObject().put("fcm_key", binding.getString("token")))
                pending.remove(key)
            } catch (error: Throwable) {
                if (error is HttpError && error.status in listOf(404, 410)) pending.remove(key)
                else if (firstError == null) firstError = error
            }
            storage.edit().putString("removals", pending.toString()).commit()
        }
        firstError?.let { throw it }
    }

    fun clicked(id: String, complete: (Throwable?) -> Unit) {
        val snapshot = snapshot("")
        executor.execute {
            try {
                require(id.matches(Regex("[A-Za-z0-9_-]+"))) { "Invalid notification delivery ID" }
                checkIdentity(snapshot)
                request(snapshot.binding, "POST", "api/sdk/v1/push-notification/$id/clicked/", JSONObject())
                complete(null)
            } catch (error: Throwable) { complete(error) }
        }
    }

    private fun request(binding: JSONObject, method: String, path: String, body: JSONObject) {
        val connection = connectionFactory(URL(binding.getString("baseUrl") + path))
        try {
            connection.requestMethod = method
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("Authorization", "Token " + binding.getString("apiKey"))
            connection.setRequestProperty("X-User-Key", binding.getString("userKey"))
            connection.setRequestProperty("Accept", "*/*;version=2")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) throw HttpError(status)
        } finally { connection.disconnect() }
    }
}
