package com.camanime.engine.bridge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PermissionResolverTest {
    @Test
    fun grantedIsNeverBlocked() {
        val state = PermissionResolver.resolve(granted = true, shouldShowRationale = false, requestedBefore = true)
        assertTrue(state.granted)
        assertFalse(state.blocked)
    }

    @Test
    fun neverRequestedIsNotBlocked() {
        val state = PermissionResolver.resolve(granted = false, shouldShowRationale = false, requestedBefore = false)
        assertFalse(state.blocked)
    }

    @Test
    fun deniedOnceWithRationaleCanAskAgain() {
        val state = PermissionResolver.resolve(granted = false, shouldShowRationale = true, requestedBefore = true)
        assertFalse(state.blocked)
        assertTrue(state.shouldShowRationale)
    }

    @Test
    fun deniedWithoutRationaleAfterRequestIsBlocked() {
        val state = PermissionResolver.resolve(granted = false, shouldShowRationale = false, requestedBefore = true)
        assertTrue(state.blocked)
    }

    @Test
    fun mapContainsWireKeys() {
        val map = PermissionResolver.resolve(false, false, true).toMap()
        assertEquals(setOf("granted", "shouldShowRationale", "blocked"), map.keys)
    }
}
