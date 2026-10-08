package com.margelo.nitro.usercom

import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/** Mobile SDK endpoints, not the privileged public REST API. No Firebase dependency. */
internal class UserComPushApi(context: Context) {
    private val storage = context.getSharedPreferences("nitro_usercom_messaging", Context.MODE_PRIVATE)
    private val executor = Executors.newSingleThreadExecutor()
    private var baseUrl = ""
    private var apiKey = ""
    private var userKey = ""
    private var userId = ""
    fun currentUserId(): String = userId

    fun configure(config: UserComModuleConfig) {
        val host = config.domain.trim().removePrefix("https://").removePrefix("http://").trimEnd('/')
        require(host.endsWith(".user.com") && !host.contains('/') && !host.contains('@')) {
            "Expected a User.com workspace host"
        }
        baseUrl = "https://$host/"
        apiKey = config.apiKey
    }

    fun identify(id: String, key: String) {
        userId = id
        userKey = key
    }

    fun rememberToken(token: String, complete: (Throwable?) -> Unit) {
        val binding = snapshot(token)
        executor.execute {
            try {
                require(binding.getString("userKey").isNotEmpty()) { "Register a contact before binding a token" }
                saveBinding(binding)
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

    private fun snapshot(token: String): JSONObject = JSONObject()
        .put("baseUrl", baseUrl).put("apiKey", apiKey)
        .put("userKey", userKey).put("userId", userId).put("token", token)

    fun bind(token: String, complete: (Throwable?) -> Unit) {
        val binding = snapshot(token)
        executor.execute {
            try {
                require(binding.getString("userKey").isNotEmpty()) { "Register a contact first" }
                saveBinding(binding)
                flushRemovals()
                request(binding, "POST", "api/sdk/v1/ping/", JSONObject()
                    .put("customer", JSONObject().put("user_id", binding.getString("userId")))
                    .put("device", JSONObject().put("os_type", "Android").put("fcm_key", token)))
                complete(null)
            } catch (error: Throwable) { complete(error) }
        }
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
        for (key in pending.keys().asSequence().toList()) {
            val binding = pending.getJSONObject(key)
            request(binding, "DELETE", "api/sdk/v1/delete-fcm-token/",
                JSONObject().put("fcm_key", binding.getString("token")))
            pending.remove(key)
            storage.edit().putString("removals", pending.toString()).commit()
        }
    }

    fun clicked(id: String, complete: (Throwable?) -> Unit) {
        val binding = snapshot("")
        executor.execute {
            try {
                require(id.matches(Regex("[A-Za-z0-9_-]+"))) { "Invalid notification delivery ID" }
                request(binding, "POST", "api/sdk/v1/push-notification/$id/clicked/", JSONObject())
                complete(null)
            } catch (error: Throwable) { complete(error) }
        }
    }

    private fun request(binding: JSONObject, method: String, path: String, body: JSONObject) {
        val connection = URL(binding.getString("baseUrl") + path).openConnection() as HttpURLConnection
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
            check(connection.responseCode in 200..299) { "User.com messaging HTTP ${connection.responseCode}" }
        } finally { connection.disconnect() }
    }
}
