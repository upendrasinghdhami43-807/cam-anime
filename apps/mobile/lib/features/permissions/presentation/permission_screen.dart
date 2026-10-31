import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../domain/permission_status.dart';

/// S-03: explains why the camera is needed and offers the right recovery action.
class PermissionScreen extends StatelessWidget {
  const PermissionScreen({
    required this.gate,
    required this.onRequest,
    required this.onOpenSettings,
    super.key,
  });

  final CameraPermissionGate gate;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final content = switch (gate) {
      CameraPermissionGate.checking => const _Content(
        icon: Icons.hourglass_empty,
        title: 'Checking camera access…',
        body: '',
      ),
      CameraPermissionGate.needsPermission => _Content(
        icon: Icons.photo_camera_outlined,
        title: 'Camera access',
        body:
            'Cam-Anime turns what the camera sees into a cartoon, live. '
            'Everything is processed on your phone and never uploaded.',
        actionLabel: 'Continue',
        onAction: onRequest,
      ),
      CameraPermissionGate.denied => _Content(
        icon: Icons.no_photography_outlined,
        title: 'Camera permission needed',
        body: 'Without the camera there is nothing to turn into a cartoon. You can try again.',
        actionLabel: 'Try again',
        onAction: onRequest,
      ),
      CameraPermissionGate.blocked => _Content(
        icon: Icons.settings_outlined,
        title: 'Camera is blocked',
        body: 'Android will not ask again. Open the app settings and allow Camera, then come back.',
        actionLabel: 'Open app settings',
        onAction: onOpenSettings,
      ),
      CameraPermissionGate.granted => const _Content(
        icon: Icons.check,
        title: 'Ready',
        body: '',
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(content.icon, size: 64, color: AppColors.brandPrimary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  content.title,
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (content.body.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    content.body,
                    style: text.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (content.actionLabel != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: content.onAction,
                    child: Text(content.actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Content {
  const _Content({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
}
