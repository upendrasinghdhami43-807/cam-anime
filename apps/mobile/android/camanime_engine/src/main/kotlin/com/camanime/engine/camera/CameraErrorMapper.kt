package com.camanime.engine.camera

import androidx.camera.core.CameraState
import com.camanime.engine.bridge.ErrorCode

internal object CameraErrorMapper {
    fun map(cameraXErrorCode: Int): ErrorCode = when (cameraXErrorCode) {
        CameraState.ERROR_CAMERA_IN_USE,
        CameraState.ERROR_MAX_CAMERAS_IN_USE -> ErrorCode.CAMERA_IN_USE

        CameraState.ERROR_CAMERA_DISABLED,
        CameraState.ERROR_DO_NOT_DISTURB_MODE_ENABLED -> ErrorCode.CAMERA_UNAVAILABLE

        else -> ErrorCode.CAMERA_ERROR
    }

    fun isRecoverable(cameraXErrorCode: Int): Boolean = when (cameraXErrorCode) {
        CameraState.ERROR_CAMERA_FATAL_ERROR,
        CameraState.ERROR_CAMERA_DISABLED -> false

        else -> true
    }
}
