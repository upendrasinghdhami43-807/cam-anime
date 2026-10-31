package com.camanime.engine.camera

import androidx.camera.core.CameraState
import com.camanime.engine.bridge.ErrorCode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ZoomMathTest {
    @Test
    fun clampsAboveMax() = assertEquals(5f, ZoomMath.clamp(9.0, 1f, 5f), 0f)

    @Test
    fun clampsBelowMin() = assertEquals(1f, ZoomMath.clamp(0.2, 1f, 5f), 0f)

    @Test
    fun keepsValueInRange() = assertEquals(2.5f, ZoomMath.clamp(2.5, 1f, 5f), 0f)

    @Test
    fun nanFallsBackToMin() = assertEquals(1f, ZoomMath.clamp(Double.NaN, 1f, 5f), 0f)
}

class CameraErrorMapperTest {
    @Test
    fun inUseMapsToCameraInUse() {
        assertEquals(ErrorCode.CAMERA_IN_USE, CameraErrorMapper.map(CameraState.ERROR_CAMERA_IN_USE))
        assertEquals(ErrorCode.CAMERA_IN_USE, CameraErrorMapper.map(CameraState.ERROR_MAX_CAMERAS_IN_USE))
    }

    @Test
    fun disabledMapsToUnavailable() {
        assertEquals(ErrorCode.CAMERA_UNAVAILABLE, CameraErrorMapper.map(CameraState.ERROR_CAMERA_DISABLED))
    }

    @Test
    fun otherMapsToGenericError() {
        assertEquals(ErrorCode.CAMERA_ERROR, CameraErrorMapper.map(CameraState.ERROR_CAMERA_FATAL_ERROR))
    }

    @Test
    fun fatalIsNotRecoverable() {
        assertFalse(CameraErrorMapper.isRecoverable(CameraState.ERROR_CAMERA_FATAL_ERROR))
        assertTrue(CameraErrorMapper.isRecoverable(CameraState.ERROR_CAMERA_IN_USE))
    }
}
