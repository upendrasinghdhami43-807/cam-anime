import 'package:camanime/features/camera/presentation/camera_providers.dart';
import 'package:camanime/features/permissions/domain/permission_status.dart';
import 'package:camanime/features/permissions/presentation/permission_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_camera_engine.dart';

void main() {
  group('gateFor', () {
    test('granted', () {
      const status = PermissionStatus(
        granted: true,
        shouldShowRationale: false,
        blocked: false,
      );
      expect(gateFor(status), CameraPermissionGate.granted);
    });

    test('never asked', () {
      const status = PermissionStatus(
        granted: false,
        shouldShowRationale: false,
        blocked: false,
      );
      expect(gateFor(status), CameraPermissionGate.needsPermission);
    });

    test('denied once, can ask again', () {
      const status = PermissionStatus(
        granted: false,
        shouldShowRationale: true,
        blocked: false,
      );
      expect(gateFor(status), CameraPermissionGate.denied);
    });

    test('permanently denied', () {
      const status = PermissionStatus(
        granted: false,
        shouldShowRationale: false,
        blocked: true,
      );
      expect(gateFor(status), CameraPermissionGate.blocked);
    });
  });

  group('CameraPermissionController', () {
    late FakeCameraEngine engine;
    late ProviderContainer container;

    setUp(() {
      engine = FakeCameraEngine();
      container = ProviderContainer(
        overrides: [cameraEngineProvider.overrideWithValue(engine)],
      );
      addTearDown(container.dispose);
    });

    test('starts in checking, then resolves from the OS state', () async {
      expect(
        container.read(cameraPermissionProvider),
        CameraPermissionGate.checking,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(cameraPermissionProvider),
        CameraPermissionGate.needsPermission,
      );
    });

    test('request grants', () async {
      await container.read(cameraPermissionProvider.notifier).request();
      expect(
        container.read(cameraPermissionProvider),
        CameraPermissionGate.granted,
      );
      expect(engine.requestCount, 1);
    });

    test('request denied permanently becomes blocked and refresh picks up Settings changes', () async {
      engine.permissionAfterRequest = const PermissionStatus(
        granted: false,
        shouldShowRationale: false,
        blocked: true,
      );
      final notifier = container.read(cameraPermissionProvider.notifier);
      await notifier.request();
      expect(
        container.read(cameraPermissionProvider),
        CameraPermissionGate.blocked,
      );

      engine.permission = const PermissionStatus(
        granted: true,
        shouldShowRationale: false,
        blocked: false,
      );
      await notifier.refresh();
      expect(
        container.read(cameraPermissionProvider),
        CameraPermissionGate.granted,
      );
    });
  });
}
