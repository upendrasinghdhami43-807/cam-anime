enum Lens {
  back,
  front;

  Lens get other => this == Lens.back ? Lens.front : Lens.back;
}

class CameraCapabilities {
  const CameraCapabilities({
    required this.lenses,
    required this.zoomMin,
    required this.zoomMax,
    required this.hasFlash,
  });

  factory CameraCapabilities.fromMap(Map<Object?, Object?> map) =>
      CameraCapabilities(
        lenses: [
          for (final name in (map['lenses'] as List<Object?>? ?? const []))
            if (name == 'back') Lens.back else if (name == 'front') Lens.front,
        ],
        zoomMin: (map['zoomMin'] as num?)?.toDouble() ?? 1,
        zoomMax: (map['zoomMax'] as num?)?.toDouble() ?? 1,
        hasFlash: map['hasFlash'] == true,
      );

  final List<Lens> lenses;
  final double zoomMin;
  final double zoomMax;
  final bool hasFlash;

  bool get canSwitchLens => lenses.length > 1;
}

class CameraStartResult {
  const CameraStartResult({
    required this.textureId,
    required this.capabilities,
  });

  factory CameraStartResult.fromMap(Map<Object?, Object?> map) =>
      CameraStartResult(
        textureId: (map['textureId'] as num).toInt(),
        capabilities: CameraCapabilities.fromMap(
          map['capabilities']! as Map<Object?, Object?>,
        ),
      );

  final int textureId;
  final CameraCapabilities capabilities;
}

class EngineInfo {
  const EngineInfo({
    required this.apiVersion,
    required this.engineVersion,
    required this.androidSdk,
  });

  factory EngineInfo.fromMap(Map<Object?, Object?> map) => EngineInfo(
    apiVersion: (map['apiVersion'] as num).toInt(),
    engineVersion: map['engineVersion']! as String,
    androidSdk: (map['androidSdk'] as num).toInt(),
  );

  final int apiVersion;
  final String engineVersion;
  final int androidSdk;
}

/// Events streamed by the native engine (docs/integrations/API.md §4).
sealed class EngineEvent {
  const EngineEvent();

  static EngineEvent? fromMap(Map<Object?, Object?> map) {
    switch (map['type']) {
      case 'cameraState':
        return CameraStateEvent(map['state'] as String? ?? 'idle');
      case 'previewTransform':
        return PreviewTransformEvent(
          width: (map['width'] as num).toInt(),
          height: (map['height'] as num).toInt(),
          rotationDegrees: (map['rotationDegrees'] as num).toInt(),
          mirrored: map['mirrored'] == true,
        );
      case 'firstFrame':
        return const FirstFrameEvent();
      case 'error':
        return EngineErrorEvent(
          code: map['code'] as String? ?? 'INTERNAL',
          message: map['message'] as String? ?? '',
          recoverable: map['recoverable'] == true,
        );
    }
    return null;
  }
}

class CameraStateEvent extends EngineEvent {
  const CameraStateEvent(this.state);
  final String state;
}

class PreviewTransformEvent extends EngineEvent {
  const PreviewTransformEvent({
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.mirrored,
  });

  /// Buffer size as delivered by the camera (sensor orientation, usually landscape).
  final int width;
  final int height;

  /// Clockwise rotation needed to make the buffer upright.
  final int rotationDegrees;
  final bool mirrored;
}

class FirstFrameEvent extends EngineEvent {
  const FirstFrameEvent();
}

class EngineErrorEvent extends EngineEvent {
  const EngineErrorEvent({
    required this.code,
    required this.message,
    required this.recoverable,
  });
  final String code;
  final String message;
  final bool recoverable;
}
