import 'dart:async';

import 'package:camanime/core/engine_error.dart';
import 'package:camanime/features/camera/domain/camera_engine.dart';
import 'package:camanime/features/camera/domain/camera_models.dart';
import 'package:camanime/features/permissions/domain/permission_status.dart';

/// Scriptable in-memory engine for unit and widget tests.
class FakeCameraEngine implements CameraEngine {
  PermissionStatus permission = const PermissionStatus(
    granted: false,
    shouldShowRationale: false,
    blocked: false,
  );
  PermissionStatus permissionAfterRequest = const PermissionStatus(
    granted: true,
    shouldShowRationale: false,
    blocked: false,
  );
  EngineError? startError;
  CameraCapabilities capabilities = const CameraCapabilities(
    lenses: [Lens.back, Lens.front],
    zoomMin: 1,
    zoomMax: 5,
    hasFlash: true,
  );

  final startedLenses = <Lens>[];
  var stopCount = 0;
  var openSettingsCount = 0;
  var requestCount = 0;
  var _nextTexture = 10;
  final _events = StreamController<EngineEvent>.broadcast();

  void emit(EngineEvent event) => _events.add(event);

  @override
  Stream<EngineEvent> get events => _events.stream;

  @override
  Future<EngineInfo> getInfo() async =>
      const EngineInfo(apiVersion: 1, engineVersion: 'test', androidSdk: 35);

  @override
  Future<PermissionStatus> cameraPermissionStatus() async => permission;

  @override
  Future<PermissionStatus> requestCameraPermission() async {
    requestCount++;
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<void> openAppSettings() async => openSettingsCount++;

  @override
  Future<CameraStartResult> start(Lens lens) async {
    startedLenses.add(lens);
    final error = startError;
    if (error != null) throw error;
    return CameraStartResult(
      textureId: _nextTexture++,
      capabilities: capabilities,
    );
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<double> setZoomRatio(double ratio) async =>
      ratio.clamp(capabilities.zoomMin, capabilities.zoomMax);

  @override
  Future<bool> setTorch({required bool enabled}) async => enabled;
}
