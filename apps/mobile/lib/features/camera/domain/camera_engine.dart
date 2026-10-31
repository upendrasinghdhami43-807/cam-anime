import '../../permissions/domain/permission_status.dart';
import 'camera_models.dart';

/// The only way Dart talks to the native engine. Control and small state only: never pixels.
abstract interface class CameraEngine {
  Future<EngineInfo> getInfo();
  Future<PermissionStatus> cameraPermissionStatus();
  Future<PermissionStatus> requestCameraPermission();
  Future<void> openAppSettings();
  Future<CameraStartResult> start(Lens lens);
  Future<void> stop();
  Future<double> setZoomRatio(double ratio);
  Future<bool> setTorch({required bool enabled});
  Stream<EngineEvent> get events;
}
