import 'package:camanime/core/engine_error.dart';
import 'package:camanime/features/camera/domain/camera_models.dart';
import 'package:camanime/features/camera/presentation/camera_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_camera_engine.dart';

void main() {
  late FakeCameraEngine engine;
  late ProviderContainer container;

  setUp(() {
    engine = FakeCameraEngine();
    container = ProviderContainer(
      overrides: [cameraEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
  });

  CameraController controller() =>
      container.read(cameraControllerProvider.notifier);
  CameraUiState state() => container.read(cameraControllerProvider);

  test('start moves to running with texture and capabilities', () async {
    await controller().start();

    expect(state().status, CameraStatus.running);
    expect(state().textureId, 10);
    expect(state().capabilities?.zoomMax, 5);
    expect(engine.startedLenses, [Lens.back]);
  });

  test('preview is only ready once the transform event arrives', () async {
    await controller().start();
    expect(state().previewReady, isFalse);

    engine.emit(
      const PreviewTransformEvent(
        width: 1280,
        height: 720,
        rotationDegrees: 90,
        mirrored: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(state().previewReady, isTrue);
    expect(state().preview?.rotationDegrees, 90);
  });

  test(
    'switchLens restarts with the other lens and clears the old preview',
    () async {
      await controller().start();
      engine.emit(
        const PreviewTransformEvent(
          width: 1280,
          height: 720,
          rotationDegrees: 90,
          mirrored: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await controller().switchLens();

      expect(engine.startedLenses, [Lens.back, Lens.front]);
      expect(state().lens, Lens.front);
      expect(state().preview, isNull);
      expect(state().textureId, 11);
    },
  );

  test('start failure surfaces the engine error', () async {
    engine.startError = const EngineError(EngineErrorCode.cameraInUse, 'busy');

    await controller().start();

    expect(state().status, CameraStatus.error);
    expect(state().error?.code, EngineErrorCode.cameraInUse);
    expect(state().textureId, isNull);
  });

  test('native idle event (app backgrounded) clears the texture', () async {
    await controller().start();

    engine.emit(const CameraStateEvent('idle'));
    await Future<void>.delayed(Duration.zero);

    expect(state().status, CameraStatus.idle);
    expect(state().textureId, isNull);
  });

  test('native error event moves to error state', () async {
    await controller().start();

    engine.emit(
      const EngineErrorEvent(
        code: 'CAMERA_IN_USE',
        message: 'x',
        recoverable: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(state().status, CameraStatus.error);
    expect(state().error?.code, EngineErrorCode.cameraInUse);
  });

  test('zoom is clamped by the engine result', () async {
    await controller().start();

    await controller().setZoom(9);

    expect(state().zoom, 5);
  });

  test('torch toggles only when a flash exists', () async {
    await controller().start();
    await controller().toggleTorch();
    expect(state().torchOn, isTrue);

    engine.capabilities = const CameraCapabilities(
      lenses: [Lens.back],
      zoomMin: 1,
      zoomMax: 1,
      hasFlash: false,
    );
    await controller().start();
    await controller().toggleTorch();
    expect(state().torchOn, isFalse);
  });

  test('stop releases the engine and resets state', () async {
    await controller().start();

    await controller().stop();

    expect(state().status, CameraStatus.idle);
    expect(engine.stopCount, 1);
  });
}
