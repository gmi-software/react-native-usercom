package com.margelo.nitro.usercom

import android.util.Log
import androidx.annotation.Keep
import com.facebook.proguard.annotations.DoNotStrip
import com.user.sdk.UserCom

@Keep
@DoNotStrip
class HybridUserComModule : HybridUserComModuleSpec() {
    override fun initialize() {
        val instance = UserCom.getInstance()
        Log.d("HybridUserComModule", "Initialized successfully")
    }
}
