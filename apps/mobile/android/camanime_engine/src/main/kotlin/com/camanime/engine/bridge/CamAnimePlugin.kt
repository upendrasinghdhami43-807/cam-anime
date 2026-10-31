package com.camanime.engine.bridge

import android.os.Handler
import android.os.Looper
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.camanime.engine.camera.CameraController
import com.camanime.engine.camera.Lens
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
/** Entry point of the native engine. Registered manually from MainActivity (ADR-014). */
class CamAnimePlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var permissions: PermissionManager? = null
    private var camera: CameraController? = null
    private var owner: LifecycleOwner? = null
    private var activityBinding: ActivityPluginBinding? = null

    private val permissionListener = PluginRegistry.RequestPermissionsResultListener { requestCode, _, _ ->
        permissions?.onRequestPermissionsResult(requestCode) ?: false
    }

    private val stopObserver = object : DefaultLifecycleObserver {
        // Privacy: never hold the camera while the app is not visible (AC-18).
        override fun onStop(owner: LifecycleOwner) {
            camera?.stop()
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        permissions = PermissionManager(context)
        camera = CameraController(context, binding.textureRegistry, ::emit)
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        camera?.stop()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        camera = null
        permissions = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        permissions?.attach(binding.activity)
        binding.addRequestPermissionsResultListener(permissionListener)
        (binding.activity as? LifecycleOwner)?.let {
            owner = it
            it.lifecycle.addObserver(stopObserver)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        camera?.stop()
        owner?.lifecycle?.removeObserver(stopObserver)
        owner = null
        permissions?.detach()
        activityBinding?.removeRequestPermissionsResultListener(permissionListener)
        activityBinding = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emit(type: String, payload: Map<String, Any?>) {
        val event = HashMap<String, Any?>(payload).apply {
            put("type", type)
            put("tsMs", System.currentTimeMillis())
        }
        mainHandler.post { eventSink?.success(event) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            dispatch(call, result)
        } catch (e: EngineException) {
            result.error(e.code.name, e.message, null)
        } catch (e: Exception) {
            result.error(ErrorCode.INTERNAL.name, e.message ?: "Unexpected error", null)
        }
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "engine.getInfo" -> result.success(
                mapOf("apiVersion" to API_VERSION, "engineVersion" to ENGINE_VERSION, "androidSdk" to android.os.Build.VERSION.SDK_INT),
            )

            "permissions.getStatus" -> result.success(requirePermissions().status(call.requireString("permission")).toMap())

            "permissions.request" -> requirePermissions().request(call.requireString("permission")) { result.success(it.toMap()) }

            "permissions.openAppSettings" -> {
                requirePermissions().openAppSettings()
                result.success(emptyMap<String, Any>())
            }

            "camera.start", "camera.switchLens" -> {
                val lifecycleOwner = owner ?: throw EngineException(ErrorCode.INTERNAL, "Activity is not a LifecycleOwner")
                if (!requirePermissions().status("camera").granted) {
                    throw EngineException(ErrorCode.PERMISSION_DENIED, "Camera permission is not granted")
                }
                val lens = Lens.fromWire(call.argument<String>("lens"))
                requireCamera().start(lifecycleOwner, lens) { outcome ->
                    outcome.fold(
                        onSuccess = { result.success(it.toMap()) },
                        onFailure = {
                            val failure = it as? EngineException
                            result.error(failure?.code?.name ?: ErrorCode.CAMERA_ERROR.name, it.message, null)
                        },
                    )
                }
            }

            "camera.stop" -> {
                requireCamera().stop()
                result.success(emptyMap<String, Any>())
            }

            "camera.setZoomRatio" -> {
                val ratio = call.argument<Double>("ratio") ?: throw EngineException(ErrorCode.INVALID_ARGUMENT, "ratio is required")
                result.success(mapOf("ratio" to requireCamera().setZoomRatio(ratio)))
            }

            "camera.setTorch" -> {
                val enabled = call.argument<Boolean>("enabled") ?: throw EngineException(ErrorCode.INVALID_ARGUMENT, "enabled is required")
                result.success(mapOf("enabled" to requireCamera().setTorch(enabled)))
            }

            else -> result.notImplemented()
        }
    }

    private fun requirePermissions() = permissions ?: throw EngineException(ErrorCode.INTERNAL, "Engine is not attached")

    private fun requireCamera() = camera ?: throw EngineException(ErrorCode.INTERNAL, "Engine is not attached")

    private fun MethodCall.requireString(name: String): String =
        argument<String>(name) ?: throw EngineException(ErrorCode.INVALID_ARGUMENT, "$name is required")

    companion object {
        const val METHOD_CHANNEL = "camanime/engine"
        const val EVENT_CHANNEL = "camanime/engine/events"
        const val API_VERSION = 1
        const val ENGINE_VERSION = "0.1.0-m1"
    }
}
