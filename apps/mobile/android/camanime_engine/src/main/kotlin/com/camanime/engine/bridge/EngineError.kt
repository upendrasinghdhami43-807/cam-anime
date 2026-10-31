package com.camanime.engine.bridge

/** Stable error codes shared with Dart (see docs/integrations/API.md). */
internal enum class ErrorCode {
    PERMISSION_DENIED,
    CAMERA_IN_USE,
    CAMERA_UNAVAILABLE,
    CAMERA_ERROR,
    INVALID_ARGUMENT,
    NOT_STARTED,
    UNSUPPORTED,
    INTERNAL,
}

internal class EngineException(
    val code: ErrorCode,
    override val message: String,
) : Exception(message)
