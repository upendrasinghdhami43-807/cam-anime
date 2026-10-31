/// Error codes sent by the native engine (docs/integrations/API.md §5).
enum EngineErrorCode {
  permissionDenied,
  cameraInUse,
  cameraUnavailable,
  cameraError,
  invalidArgument,
  notStarted,
  unsupported,
  internal;

  static EngineErrorCode fromWire(String? code) => switch (code) {
    'PERMISSION_DENIED' => permissionDenied,
    'CAMERA_IN_USE' => cameraInUse,
    'CAMERA_UNAVAILABLE' => cameraUnavailable,
    'CAMERA_ERROR' => cameraError,
    'INVALID_ARGUMENT' => invalidArgument,
    'NOT_STARTED' => notStarted,
    'UNSUPPORTED' => unsupported,
    _ => internal,
  };
}

class EngineError implements Exception {
  const EngineError(this.code, this.message);

  final EngineErrorCode code;
  final String message;

  @override
  String toString() => 'EngineError($code): $message';
}
