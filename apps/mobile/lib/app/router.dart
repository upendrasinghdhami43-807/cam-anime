import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/camera/presentation/camera_screen.dart';
import '../features/developer/presentation/developer_screen.dart';

abstract final class AppRoutes {
  static const camera = '/';
  static const developer = '/developer';
}

GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.camera,
      builder: (context, state) => const CameraScreen(),
    ),
    // Developer tools talk to the optional test backend; they are not part of release builds.
    if (!kReleaseMode)
      GoRoute(
        path: AppRoutes.developer,
        builder: (context, state) => const DeveloperScreen(),
      ),
  ],
);
