package com.margelo.nitro.usercom

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.system.exitProcess

// Stand-in for Nitro config and Android storage; the native module is built separately.
data class UserComModuleConfig(val domain: String, val apiKey: String)
class MemoryPrefs : SharedPreferences {
    private val values = ConcurrentHashMap<String, String>()
    @Volatile var failReads = false
    override fun getString(key: String, fallback: String?): String? {
        check(!failReads) { "Storage unavailable" }; return values[key] ?: fallback
    }
    override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
        private val writes = mutableMapOf<String, String>()
        private val removals = mutableSetOf<String>()
        override fun putString(key: String, value: String) = apply { writes[key] = value }
        override fun remove(key: String) = apply { removals.add(key) }
        override fun commit(): Boolean { removals.forEach { values.remove(it) }; values.putAll(writes); return true }
    }
}
class MemoryContext(val prefs: MemoryPrefs = MemoryPrefs()) : Context() {
    override fun getSharedPreferences(name: String, mode: Int): SharedPreferences = prefs
}
class Server {
    data class Call(val method: String, val key: String, val userId: String)
    val calls = mutableListOf<Call>()
    @Volatile var deleteStatus = 200
    @Volatile var postStatus = 200
    var postStarted: CountDownLatch? = null
    var releasePost: CountDownLatch? = null
    fun connection(url: URL) = object : HttpURLConnection(url) {
        private val body = ByteArrayOutputStream()
        override fun getOutputStream(): OutputStream = body
        override fun getResponseCode(): Int {
            val json = JSONObject(body.toString("UTF-8"))
            val call = Call(requestMethod, getRequestProperty("X-User-Key"), json.optJSONObject("customer")?.optString("user_id") ?: "")
            synchronized(calls) { calls.add(call) }
            if (requestMethod == "POST" && postStarted != null) {
                postStarted!!.countDown(); check(releasePost!!.await(10, TimeUnit.SECONDS))
            }
            return if (requestMethod == "DELETE") deleteStatus else postStatus
        }
        override fun connect() {}
        override fun disconnect() {}
        override fun usingProxy() = false
    }
}
fun awaitCall(operation: ((Throwable?) -> Unit) -> Unit): Throwable? {
    val done = CountDownLatch(1)
    var error: Throwable? = null
    operation { error = it; done.countDown() }
    check(done.await(20, TimeUnit.SECONDS)) { "Operation hung" }
    return error
}
internal fun makeAPI(): Triple<UserComPushApi, MemoryPrefs, Server> {
    val context = MemoryContext(); val server = Server()
    val api = UserComPushApi(context, server::connection)
    api.configure(UserComModuleConfig("fixture.user.com", "fixture-sdk-key"))
    api.identify("account-a", "key-a")
    return Triple(api, context.prefs, server)
}
fun pending(prefs: MemoryPrefs) = JSONObject(prefs.getString("removals", "{}")!!).length()
fun main() {
    try {
        var cases = 0
        for (code in listOf(404, 410, 401, 429, 503)) {
            val (api, prefs, server) = makeAPI()
            check(awaitCall { api.bind("old", it) } == null)
            server.deleteStatus = code
            check(awaitCall { api.bind("new", it) } == null) { "Old removal blocked a new bind" }
            val error = awaitCall { api.unbind(it) }
            if (code in listOf(404, 410)) check(error == null && pending(prefs) == 0)
            else {
                check(error?.message == "User.com messaging HTTP $code" && pending(prefs) == 2)
                server.deleteStatus = 200
                check(awaitCall { api.unbind(it) } == null && pending(prefs) == 0)
            }
            check(server.calls.count { it.method == "POST" } == 2)
            cases++
        }
        run {
            val (api, _, server) = makeAPI()
            check(awaitCall { api.bind("shared", it) } == null)
            api.identify("account-b", "key-b")
            server.deleteStatus = 503
            check(awaitCall { api.bind("shared", it) } == null)
            server.deleteStatus = 200
            check(awaitCall { api.unbind(it) } == null)
            val deletes = server.calls.filter { it.method == "DELETE" }
            check(deletes.size == 1 && deletes[0].key == "key-b") { "Old cleanup deleted the transferred token" }
            cases++
        }
        run {
            val (api, _, server) = makeAPI()
            check(awaitCall { api.bind("old", it) } == null)
            api.clearIdentity()
            check(api.currentUserId().isEmpty())
            check(awaitCall { api.bind("new", it) } != null)
            check(awaitCall { api.unbind(it) } == null)
            check(server.calls.last { it.method == "DELETE" }.key == "key-a")
            cases++
        }
        run {
            val (api, _, server) = makeAPI()
            server.postStatus = 401
            check(awaitCall { api.bind("new", it) }?.message == "User.com messaging HTTP 401")
            check(awaitCall { api.unbind(it) } == null)
            cases++
        }
        run {
            val (api, _, server) = makeAPI()
            val done = CountDownLatch(1)
            server.postStarted = CountDownLatch(1); server.releasePost = CountDownLatch(1)
            var error: Throwable? = null
            api.bind("stale") { error = it; done.countDown() }
            check(server.postStarted!!.await(10, TimeUnit.SECONDS))
            api.clearIdentity(); server.releasePost!!.countDown()
            check(done.await(10, TimeUnit.SECONDS) && error != null)
            server.postStarted = null; server.releasePost = null
            check(awaitCall { api.unbind(it) } == null && api.currentUserId().isEmpty())
            cases++
        }
        run {
            val (api, _, server) = makeAPI()
            val done = CountDownLatch(200)
            val threads = (0 until 200).map { i -> Thread {
                api.identify("account-$i", "key-$i")
                api.currentUserId()
                api.bind("token-$i") { done.countDown() }
            } }
            threads.forEach { it.start() }; threads.forEach { it.join() }
            check(done.await(20, TimeUnit.SECONDS))
            check(awaitCall { api.unbind(it) } == null)
            for (call in server.calls.filter { it.method == "POST" }) {
                check(call.userId.removePrefix("account-") == call.key.removePrefix("key-")) { "Mixed contact snapshot" }
            }
            cases++
        }
        run {
            val (api, prefs, server) = makeAPI()
            server.postStarted = CountDownLatch(1); server.releasePost = CountDownLatch(1)
            val bindingDone = CountDownLatch(1)
            api.bind("in-flight") { bindingDone.countDown() }
            check(server.postStarted!!.await(10, TimeUnit.SECONDS))
            val remembered = CountDownLatch(1)
            var rememberError: Throwable? = null
            api.rememberToken("automatic-sdk-token") { rememberError = it; remembered.countDown() }
            api.invalidatePendingBindings()
            server.releasePost!!.countDown()
            check(bindingDone.await(10, TimeUnit.SECONDS))
            check(remembered.await(10, TimeUnit.SECONDS) && rememberError == null)
            check(JSONObject(prefs.getString("binding", null)!!).getString("token") == "automatic-sdk-token")
            server.postStarted = null; server.releasePost = null
            check(awaitCall { api.unbind(it) } == null)
            cases++
        }
        println("Android push helper: $cases cases passed")
        exitProcess(0)
    } catch (error: Throwable) { error.printStackTrace(); exitProcess(1) }
}
