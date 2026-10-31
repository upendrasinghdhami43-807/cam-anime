package com.camanime.engine.camera

internal object ZoomMath {
    fun clamp(requested: Double, min: Float, max: Float): Float {
        require(min <= max) { "min must be <= max" }
        if (requested.isNaN()) return min
        return requested.toFloat().coerceIn(min, max)
    }
}
