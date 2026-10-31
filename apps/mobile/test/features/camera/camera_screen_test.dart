import 'package:camanime/features/camera/domain/camera_models.dart';
import 'package:camanime/features/camera/presentation/camera_providers.dart';
import 'package:camanime/features/camera/presentation/camera_screen.dart';
import 'package:camanime/features/permissions/domain/permission_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_camera_engine.dart';

const _granted = PermissionStatus(
  granted: true,
  shouldShowRationale: false,
  blocked: false,
);

void main() {
  Future<void> pumpScreen(WidgetTester tester, FakeCameraEngine engine) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [cameraEngineProvider.overrideWithValue(engine)],
          child: const MaterialApp(home: CameraScreen()),
        ),
      );

  testWidgets(
    'shows the rationale first, then starts the rear camera after Continue',
    (tester) async {
      final engine = FakeCameraEngine();
      await pumpScreen(tester, engine);
      await tester.pump();

      expect(find.text('Camera access'), findsOneWidget);
      expect(engine.startedLenses, isEmpty);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();

      expect(engine.requestCount, 1);
      expect(engine.startedLenses, [Lens.back]);
    },
  );

  testWidgets(
    'starts immediately when permission is already granted and shows controls',
    (tester) async {
      final engine = FakeCameraEngine()..permission = _granted;
      await pumpScreen(tester, engine);
      await tester.pump();
      await tester.pump();

      expect(engine.startedLenses, [Lens.back]);
      expect(find.bySemanticsLabel('Switch to front camera'), findsOneWidget);
      expect(find.bySemanticsLabel('Turn torch on'), findsOneWidget);
    },
  );

  testWidgets('camera in use shows a retry panel', (tester) async {
    final engine = FakeCameraEngine()..permission = _granted;
    await pumpScreen(tester, engine);
    await tester.pump();
    await tester.pump();

    engine.emit(
      const EngineErrorEvent(
        code: 'CAMERA_IN_USE',
        message: 'x',
        recoverable: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Another app is using the camera.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
