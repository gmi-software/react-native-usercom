package com.margelo.nitro.usercom

import android.util.Log
import androidx.annotation.Keep
import com.facebook.proguard.annotations.DoNotStrip

@Keep
@DoNotStrip
class HybridUserComModule : HybridUserComModuleSpec() {
    override fun initialize() {
        Log.d("HybridUserComModule", "Initialized successfully")
    }
}
