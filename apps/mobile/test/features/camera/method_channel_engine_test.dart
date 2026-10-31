import 'package:camanime/features/camera/data/method_channel_camera_engine.dart';
import 'package:camanime/features/camera/domain/camera_models.dart';
import 'package:camanime/core/engine_error.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('camanime/engine');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('start sends the lens and parses the result', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return {
        'textureId': 7,
        'capabilities': {
          'lenses': ['back', 'front'],
          'zoomMin': 1.0,
          'zoomMax': 8.0,
          'hasFlash': true,
        },
      };
    });

    final result = await MethodChannelCameraEngine().start(Lens.front);

    expect(received?.method, 'camera.start');
    expect(received?.arguments, {'lens': 'front'});
    expect(result.textureId, 7);
    expect(result.capabilities.lenses, [Lens.back, Lens.front]);
    expect(result.capabilities.zoomMax, 8);
  });

  test('permission status is parsed', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'granted': false,
        'shouldShowRationale': false,
        'blocked': true,
      },
    );

    final status = await MethodChannelCameraEngine().cameraPermissionStatus();

    expect(status.blocked, isTrue);
    expect(status.granted, isFalse);
  });

  test('platform errors become typed engine errors', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          throw PlatformException(code: 'CAMERA_IN_USE', message: 'busy'),
    );

    expect(
      MethodChannelCameraEngine().start(Lens.back),
      throwsA(
        isA<EngineError>().having(
          (e) => e.code,
          'code',
          EngineErrorCode.cameraInUse,
        ),
      ),
    );
  });

  test('getInfo rejects an incompatible engine API version', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'apiVersion': 99,
        'engineVersion': 'x',
        'androidSdk': 35,
      },
    );

    expect(
      MethodChannelCameraEngine().getInfo(),
      throwsA(
        isA<EngineError>().having(
          (e) => e.code,
          'code',
          EngineErrorCode.unsupported,
        ),
      ),
    );
  });

  test('events map known types and ignore unknown ones', () {
    expect(
      EngineEvent.fromMap({
        'type': 'previewTransform',
        'width': 1280,
        'height': 720,
        'rotationDegrees': 270,
        'mirrored': true,
      }),
      isA<PreviewTransformEvent>().having(
        (e) => e.rotationDegrees,
        'rotation',
        270,
      ),
    );
    expect(EngineEvent.fromMap({'type': 'something-new'}), isNull);
  });
}
