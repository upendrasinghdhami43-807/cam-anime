import 'package:camanime/features/permissions/domain/permission_status.dart';
import 'package:camanime/features/permissions/presentation/permission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    CameraPermissionGate gate, {
    VoidCallback? onRequest,
    VoidCallback? onSettings,
  }) => tester.pumpWidget(
    MaterialApp(
      home: PermissionScreen(
        gate: gate,
        onRequest: onRequest ?? () {},
        onOpenSettings: onSettings ?? () {},
      ),
    ),
  );

  testWidgets('needsPermission explains and requests on Continue', (
    tester,
  ) async {
    var requested = 0;
    await pump(
      tester,
      CameraPermissionGate.needsPermission,
      onRequest: () => requested++,
    );

    expect(find.text('Camera access'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(requested, 1);
  });

  testWidgets('denied offers Try again', (tester) async {
    var requested = 0;
    await pump(
      tester,
      CameraPermissionGate.denied,
      onRequest: () => requested++,
    );

    await tester.tap(find.text('Try again'));
    expect(requested, 1);
  });

  testWidgets('blocked offers Open app settings, not another request', (
    tester,
  ) async {
    var settings = 0;
    var requested = 0;
    await pump(
      tester,
      CameraPermissionGate.blocked,
      onRequest: () => requested++,
      onSettings: () => settings++,
    );

    await tester.tap(find.text('Open app settings'));
    expect(settings, 1);
    expect(requested, 0);
  });

  testWidgets('checking shows no action', (tester) async {
    await pump(tester, CameraPermissionGate.checking);

    expect(find.byType(FilledButton), findsNothing);
  });
}
