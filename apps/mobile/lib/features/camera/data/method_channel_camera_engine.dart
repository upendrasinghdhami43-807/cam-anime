import 'package:flutter/services.dart';

import '../../../core/engine_error.dart';
import '../../permissions/domain/permission_status.dart';
import '../domain/camera_engine.dart';
import '../domain/camera_models.dart';

/// Channel names and payloads follow docs/integrations/API.md. This is the only Dart file that knows them.
class MethodChannelCameraEngine implements CameraEngine {
  MethodChannelCameraEngine({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _method = methodChannel ?? const MethodChannel('camanime/engine'),
       _eventChannel =
           eventChannel ?? const EventChannel('camanime/engine/events');

  static const supportedApiVersion = 1;

  final MethodChannel _method;
  final EventChannel _eventChannel;

  Future<Map<Object?, Object?>> _call(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    try {
      final result = await _method.invokeMapMethod<Object?, Object?>(
        method,
        args,
      );
      return result ?? const {};
    } on PlatformException catch (e) {
      throw EngineError(EngineErrorCode.fromWire(e.code), e.message ?? e.code);
    }
  }

  @override
  Future<EngineInfo> getInfo() async {
    final info = EngineInfo.fromMap(await _call('engine.getInfo'));
    if (info.apiVersion != supportedApiVersion) {
      throw EngineError(
        EngineErrorCode.unsupported,
        'Engine API ${info.apiVersion} does not match app API $supportedApiVersion',
      );
    }
    return info;
  }

  @override
  Future<PermissionStatus> cameraPermissionStatus() async =>
      PermissionStatus.fromMap(
        await _call('permissions.getStatus', {'permission': 'camera'}),
      );

  @override
  Future<PermissionStatus> requestCameraPermission() async =>
      PermissionStatus.fromMap(
        await _call('permissions.request', {'permission': 'camera'}),
      );

  @override
  Future<void> openAppSettings() => _call('permissions.openAppSettings');

  @override
  Future<CameraStartResult> start(Lens lens) async => CameraStartResult.fromMap(
    await _call('camera.start', {'lens': lens.name}),
  );

  @override
  Future<void> stop() => _call('camera.stop');

  @override
  Future<double> setZoomRatio(double ratio) async =>
      ((await _call('camera.setZoomRatio', {'ratio': ratio}))['ratio']! as num)
          .toDouble();

  @override
  Future<bool> setTorch({required bool enabled}) async =>
      (await _call('camera.setTorch', {'enabled': enabled}))['enabled'] == true;

  @override
  Stream<EngineEvent> get events => _eventChannel
      .receiveBroadcastStream()
      .map(
        (raw) => raw is Map<Object?, Object?> ? EngineEvent.fromMap(raw) : null,
      )
      .where((event) => event != null)
      .cast<EngineEvent>();
}
