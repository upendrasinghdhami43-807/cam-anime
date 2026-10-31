package com.camanime.engine.camera

import android.content.Context
import android.util.Size
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.Observer
import com.camanime.engine.bridge.EngineEvents
import com.camanime.engine.bridge.EngineException
import com.camanime.engine.bridge.ErrorCode
import io.flutter.view.TextureRegistry

internal enum class Lens(val wire: String) {
    BACK("back"),
    FRONT("front");

    companion object {
        fun fromWire(value: String?): Lens =
            entries.firstOrNull { it.wire == value }
                ?: throw EngineException(ErrorCode.INVALID_ARGUMENT, "Unknown lens: $value")
    }
}

internal data class Capabilities(
    val lenses: List<String>,
    val zoomMin: Float,
    val zoomMax: Float,
    val hasFlash: Boolean,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "lenses" to lenses,
        "zoomMin" to zoomMin.toDouble(),
        "zoomMax" to zoomMax.toDouble(),
        "hasFlash" to hasFlash,
        "hasTorch" to hasFlash,
    )
}

internal data class StartResult(val textureId: Long, val capabilities: Capabilities) {
    fun toMap(): Map<String, Any> = mapOf(
        "textureId" to textureId,
        "capabilities" to capabilities.toMap(),
    )
}

/**
 * Owns the CameraX session and the Flutter texture it renders into.
 * All methods must be called on the main thread (CameraX binding requirement).
 * M1: CameraX Preview writes straight into the Flutter surface; no frame ever reaches Dart.
 */
internal class CameraController(
    private val context: Context,
    private val textures: TextureRegistry,
    private val events: EngineEvents,
) {
    private val mainExecutor = ContextCompat.getMainExecutor(context)
    private var provider: ProcessCameraProvider? = null
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var camera: Camera? = null
    private var lens: Lens = Lens.BACK
    private var stateObserver: Observer<CameraState>? = null
    private var observedCamera: Camera? = null
    private var generation = 0

    val isRunning: Boolean get() = camera != null

    fun start(owner: LifecycleOwner, requested: Lens, onDone: (Result<StartResult>) -> Unit) {
        release(notify = false)
        val gen = ++generation
        events.emit("cameraState", mapOf("state" to "starting"))

        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            if (gen != generation) {
                onDone(Result.failure(EngineException(ErrorCode.CAMERA_ERROR, "Start superseded by a newer request")))
                return@addListener
            }
            try {
                val cameraProvider = future.get()
                provider = cameraProvider
                val selector = selectorFor(cameraProvider, requested)
                lens = requested

                val newProducer = textures.createSurfaceProducer()
                producer = newProducer

                val preview = Preview.Builder()
                    .setResolutionSelector(
                        ResolutionSelector.Builder()
                            .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
                            .setResolutionStrategy(
                                ResolutionStrategy(
                                    Size(PREVIEW_WIDTH, PREVIEW_HEIGHT),
                                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                                ),
                            )
                            .build(),
                    )
                    .build()
                preview.setSurfaceProvider(mainExecutor) { request -> onSurfaceRequest(gen, newProducer, request) }

                cameraProvider.unbindAll()
                val bound = cameraProvider.bindToLifecycle(owner, selector, preview)
                camera = bound
                observeCameraState(owner, bound)

                onDone(Result.success(StartResult(newProducer.id(), capabilities(cameraProvider, bound))))
            } catch (e: EngineException) {
                release(notify = false)
                onDone(Result.failure(e))
            } catch (e: Exception) {
                release(notify = false)
                onDone(Result.failure(EngineException(ErrorCode.CAMERA_ERROR, e.message ?: "Camera start failed")))
            }
        }, mainExecutor)
    }

    fun stop() = release(notify = true)

    fun setZoomRatio(ratio: Double): Double {
        val active = camera ?: throw EngineException(ErrorCode.NOT_STARTED, "Camera is not running")
        val zoom = active.cameraInfo.zoomState.value
        val clamped = ZoomMath.clamp(ratio, zoom?.minZoomRatio ?: 1f, zoom?.maxZoomRatio ?: 1f)
        active.cameraControl.setZoomRatio(clamped)
        return clamped.toDouble()
    }

    fun setTorch(enabled: Boolean): Boolean {
        val active = camera ?: throw EngineException(ErrorCode.NOT_STARTED, "Camera is not running")
        if (!active.cameraInfo.hasFlashUnit()) {
            throw EngineException(ErrorCode.UNSUPPORTED, "This camera has no flash unit")
        }
        active.cameraControl.enableTorch(enabled)
        return enabled
    }

    private fun onSurfaceRequest(gen: Int, target: TextureRegistry.SurfaceProducer, request: SurfaceRequest) {
        if (gen != generation) {
            request.willNotProvideSurface()
            return
        }
        val size = request.resolution
        target.setSize(size.width, size.height)
        request.provideSurface(target.surface, mainExecutor) { /* surface released by CameraX */ }
        request.setTransformationInfoListener(mainExecutor) { info ->
            if (gen != generation) return@setTransformationInfoListener
            events.emit(
                "previewTransform",
                mapOf(
                    "width" to size.width,
                    "height" to size.height,
                    "rotationDegrees" to info.rotationDegrees,
                    "mirrored" to (lens == Lens.FRONT),
                ),
            )
            events.emit("firstFrame", emptyMap())
        }
    }

    private fun observeCameraState(owner: LifecycleOwner, bound: Camera) {
        val observer = Observer<CameraState> { state ->
            val error = state.error
            when {
                error != null -> events.emit(
                    "error",
                    mapOf(
                        "code" to CameraErrorMapper.map(error.code).name,
                        "message" to "CameraX error ${error.code}",
                        "recoverable" to CameraErrorMapper.isRecoverable(error.code),
                    ),
                )

                state.type == CameraState.Type.OPEN ->
                    events.emit("cameraState", mapOf("state" to "running"))

                else -> Unit
            }
        }
        stateObserver = observer
        observedCamera = bound
        bound.cameraInfo.cameraState.observe(owner, observer)
    }

    private fun selectorFor(cameraProvider: ProcessCameraProvider, requested: Lens): CameraSelector {
        val selector = when (requested) {
            Lens.BACK -> CameraSelector.DEFAULT_BACK_CAMERA
            Lens.FRONT -> CameraSelector.DEFAULT_FRONT_CAMERA
        }
        if (!cameraProvider.hasCamera(selector)) {
            throw EngineException(ErrorCode.UNSUPPORTED, "No ${requested.wire} camera on this device")
        }
        return selector
    }

    private fun capabilities(cameraProvider: ProcessCameraProvider, bound: Camera): Capabilities {
        val lenses = buildList {
            if (cameraProvider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) add(Lens.BACK.wire)
            if (cameraProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) add(Lens.FRONT.wire)
        }
        val zoom = bound.cameraInfo.zoomState.value
        return Capabilities(
            lenses = lenses,
            zoomMin = zoom?.minZoomRatio ?: 1f,
            zoomMax = zoom?.maxZoomRatio ?: 1f,
            hasFlash = bound.cameraInfo.hasFlashUnit(),
        )
    }

    private fun release(notify: Boolean) {
        generation++
        val observer = stateObserver
        val observed = observedCamera
        if (observer != null && observed != null) {
            observed.cameraInfo.cameraState.removeObserver(observer)
        }
        stateObserver = null
        observedCamera = null
        provider?.unbindAll()
        camera = null
        producer?.release()
        producer = null
        if (notify) events.emit("cameraState", mapOf("state" to "idle"))
    }

    private companion object {
        const val PREVIEW_WIDTH = 1280
        const val PREVIEW_HEIGHT = 720
    }
}
