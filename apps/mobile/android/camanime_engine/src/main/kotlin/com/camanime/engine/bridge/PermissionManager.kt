package com.camanime.engine.bridge

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/** Native permission flow (ADR-008). Must be used from the main thread. */
internal class PermissionManager(private val context: Context) {
    private var activity: Activity? = null
    private var pending: Pair<String, (PermissionState) -> Unit>? = null

    private val prefs by lazy { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }

    fun attach(activity: Activity) {
        this.activity = activity
    }

    fun detach() {
        activity = null
        pending = null
    }

    fun status(permission: String): PermissionState {
        val manifest = manifestPermission(permission)
        val granted = ContextCompat.checkSelfPermission(context, manifest) == PackageManager.PERMISSION_GRANTED
        val rationale = activity?.let { ActivityCompat.shouldShowRequestPermissionRationale(it, manifest) } ?: false
        return PermissionResolver.resolve(granted, rationale, prefs.getBoolean(requestedKey(permission), false))
    }

    fun request(permission: String, onResult: (PermissionState) -> Unit) {
        val host = activity ?: throw EngineException(ErrorCode.INTERNAL, "No activity attached")
        val manifest = manifestPermission(permission)
        if (status(permission).granted) {
            onResult(status(permission))
            return
        }
        if (pending != null) throw EngineException(ErrorCode.INTERNAL, "A permission request is already in progress")
        pending = permission to onResult
        ActivityCompat.requestPermissions(host, arrayOf(manifest), REQUEST_CODE)
    }

    /** Returns true if the result belonged to this manager. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val (permission, callback) = pending ?: return true
        pending = null
        prefs.edit().putBoolean(requestedKey(permission), true).apply()
        callback(status(permission))
        return true
    }

    fun openAppSettings() {
        val host = activity ?: throw EngineException(ErrorCode.INTERNAL, "No activity attached")
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", host.packageName, null))
        host.startActivity(intent)
    }

    private fun manifestPermission(permission: String): String = when (permission) {
        "camera" -> android.Manifest.permission.CAMERA
        // "microphone" (RECORD_AUDIO) is added with recording in M6, together with its manifest entry.
        else -> throw EngineException(ErrorCode.INVALID_ARGUMENT, "Unsupported permission: $permission")
    }

    private fun requestedKey(permission: String) = "requested.$permission"

    private companion object {
        const val PREFS = "camanime_permissions"
        const val REQUEST_CODE = 0x4341
    }
}
