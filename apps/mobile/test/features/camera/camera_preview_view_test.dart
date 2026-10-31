import 'package:camanime/features/camera/domain/camera_models.dart';
import 'package:camanime/features/camera/presentation/camera_preview_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Size> previewSize(
    WidgetTester tester,
    PreviewTransformEvent transform,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: CameraPreviewView(textureId: 1, transform: transform),
        ),
      ),
    );
    return tester.getSize(find.byType(Texture));
  }

  testWidgets('90° rotation of a landscape buffer becomes a portrait preview', (
    tester,
  ) async {
    final size = await previewSize(
      tester,
      const PreviewTransformEvent(
        width: 1280,
        height: 720,
        rotationDegrees: 90,
        mirrored: false,
      ),
    );

    expect(size.width / size.height, closeTo(1280 / 720, 0.01));
    final box = tester.getSize(find.byType(RotatedBox));
    expect(box.width / box.height, closeTo(720 / 1280, 0.01));
  });

  testWidgets('mirrored previews are flipped horizontally', (tester) async {
    await previewSize(
      tester,
      const PreviewTransformEvent(
        width: 1280,
        height: 720,
        rotationDegrees: 270,
        mirrored: true,
      ),
    );

    final flip = tester.widget<Transform>(find.byType(Transform).first);
    expect(flip.transform.getRow(0).x, -1);
  });

  testWidgets('unmirrored previews are not flipped', (tester) async {
    await previewSize(
      tester,
      const PreviewTransformEvent(
        width: 1280,
        height: 720,
        rotationDegrees: 90,
        mirrored: false,
      ),
    );

    final flip = tester.widget<Transform>(find.byType(Transform).first);
    expect(flip.transform.getRow(0).x, 1);
  });
}
