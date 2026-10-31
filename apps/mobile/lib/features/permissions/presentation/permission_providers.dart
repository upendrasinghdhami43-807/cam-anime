import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/domain/camera_engine.dart';
import '../../camera/presentation/camera_providers.dart';
import '../domain/permission_status.dart';

final cameraPermissionProvider =
    NotifierProvider<CameraPermissionController, CameraPermissionGate>(
      CameraPermissionController.new,
    );

class CameraPermissionController extends Notifier<CameraPermissionGate> {
  CameraEngine get _engine => ref.read(cameraEngineProvider);

  @override
  CameraPermissionGate build() {
    Future<void>.microtask(refresh);
    return CameraPermissionGate.checking;
  }

  /// Re-reads the OS state; call on app resume (the user may have changed it in Settings).
  Future<void> refresh() async {
    try {
      state = gateFor(await _engine.cameraPermissionStatus());
    } on Object {
      state = CameraPermissionGate.needsPermission;
    }
  }

  Future<void> request() async {
    try {
      state = gateFor(await _engine.requestCameraPermission());
    } on Object {
      state = CameraPermissionGate.denied;
    }
  }

  Future<void> openSettings() => _engine.openAppSettings();
}
