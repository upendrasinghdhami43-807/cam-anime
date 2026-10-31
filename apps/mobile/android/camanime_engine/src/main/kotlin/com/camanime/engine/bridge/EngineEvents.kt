package com.camanime.engine.bridge

internal fun interface EngineEvents {
    fun emit(type: String, payload: Map<String, Any?>)
}
