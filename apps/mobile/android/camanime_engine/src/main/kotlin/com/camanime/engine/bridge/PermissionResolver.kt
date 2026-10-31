package com.camanime.engine.bridge

internal data class PermissionState(
    val granted: Boolean,
    val shouldShowRationale: Boolean,
    val blocked: Boolean,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "granted" to granted,
        "shouldShowRationale" to shouldShowRationale,
        "blocked" to blocked,
    )
}

internal object PermissionResolver {
    /**
     * Android reports `shouldShowRationale == false` both before the first request and after
     * "don't ask again", so "blocked" is only known once a request has been made.
     */
    fun resolve(granted: Boolean, shouldShowRationale: Boolean, requestedBefore: Boolean) =
        PermissionState(
            granted = granted,
            shouldShowRationale = shouldShowRationale,
            blocked = !granted && requestedBefore && !shouldShowRationale,
        )
}
