import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine_error.dart';
import '../../../core/logging.dart';
import '../data/method_channel_camera_engine.dart';
import '../domain/camera_engine.dart';
import '../domain/camera_models.dart';

final cameraEngineProvider = Provider<CameraEngine>(
  (ref) => MethodChannelCameraEngine(),
);

final cameraControllerProvider =
    NotifierProvider<CameraController, CameraUiState>(CameraController.new);

enum CameraStatus { idle, starting, running, error }

class CameraUiState {
  const CameraUiState({
    this.status = CameraStatus.idle,
    this.lens = Lens.back,
    this.textureId,
    this.preview,
    this.capabilities,
    this.zoom = 1,
    this.torchOn = false,
    this.error,
  });

  final CameraStatus status;
  final Lens lens;
  final int? textureId;
  final PreviewTransformEvent? preview;
  final CameraCapabilities? capabilities;
  final double zoom;
  final bool torchOn;
  final EngineError? error;

  bool get previewReady =>
      status == CameraStatus.running && textureId != null && preview != null;

  CameraUiState copyWith({
    CameraStatus? status,
    Lens? lens,
    int? textureId,
    PreviewTransformEvent? preview,
    CameraCapabilities? capabilities,
    double? zoom,
    bool? torchOn,
    EngineError? error,
    bool clearTexture = false,
    bool clearError = false,
  }) => CameraUiState(
    status: status ?? this.status,
    lens: lens ?? this.lens,
    textureId: clearTexture ? null : (textureId ?? this.textureId),
    preview: clearTexture ? null : (preview ?? this.preview),
    capabilities: capabilities ?? this.capabilities,
    zoom: zoom ?? this.zoom,
    torchOn: torchOn ?? this.torchOn,
    error: clearError ? null : (error ?? this.error),
  );
}

class CameraController extends Notifier<CameraUiState> {
  CameraEngine get _engine => ref.read(cameraEngineProvider);

  @override
  CameraUiState build() {
    final subscription = _engine.events.listen(
      _onEvent,
      onError: (Object e) => logError('event stream', error: e),
    );
    ref.onDispose(subscription.cancel);
    return const CameraUiState();
  }

  Future<void> start({Lens? lens}) async {
    if (state.status == CameraStatus.starting) return;
    final target = lens ?? state.lens;
    state = state.copyWith(
      status: CameraStatus.starting,
      lens: target,
      zoom: 1,
      torchOn: false,
      clearTexture: true,
      clearError: true,
    );
    try {
      final result = await _engine.start(target);
      state = state.copyWith(
        status: CameraStatus.running,
        textureId: result.textureId,
        capabilities: result.capabilities,
        zoom: result.capabilities.zoomMin,
      );
    } on EngineError catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        error: e,
        clearTexture: true,
      );
    }
  }

  Future<void> switchLens() => start(lens: state.lens.other);

  Future<void> stop() async {
    if (state.status == CameraStatus.idle) return;
    state = state.copyWith(
      status: CameraStatus.idle,
      clearTexture: true,
      torchOn: false,
    );
    try {
      await _engine.stop();
    } on EngineError catch (e) {
      logError('stop failed', error: e);
    }
  }

  Future<void> setZoom(double ratio) async {
    if (state.status != CameraStatus.running) return;
    state = state.copyWith(zoom: ratio);
    try {
      state = state.copyWith(zoom: await _engine.setZoomRatio(ratio));
    } on EngineError catch (e) {
      logError('zoom failed', error: e);
    }
  }

  Future<void> toggleTorch() async {
    if (state.status != CameraStatus.running ||
        !(state.capabilities?.hasFlash ?? false)) {
      return;
    }
    try {
      state = state.copyWith(
        torchOn: await _engine.setTorch(enabled: !state.torchOn),
      );
    } on EngineError catch (e) {
      logError('torch failed', error: e);
    }
  }

  void _onEvent(EngineEvent event) {
    switch (event) {
      case PreviewTransformEvent():
        if (state.status == CameraStatus.running ||
            state.status == CameraStatus.starting) {
          state = state.copyWith(preview: event);
        }
      case CameraStateEvent(state: final cameraState)
          when cameraState == 'idle':
        // Native released the camera (e.g. the app went to the background).
        state = state.copyWith(
          status: CameraStatus.idle,
          clearTexture: true,
          torchOn: false,
        );
      case EngineErrorEvent():
        state = state.copyWith(
          status: CameraStatus.error,
          error: EngineError(
            EngineErrorCode.fromWire(event.code),
            event.message,
          ),
        );
      case CameraStateEvent() || FirstFrameEvent():
        break;
    }
  }
}
