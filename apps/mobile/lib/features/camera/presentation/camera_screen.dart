import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/engine_error.dart';
import '../../permissions/domain/permission_status.dart';
import '../../permissions/presentation/permission_providers.dart';
import '../../permissions/presentation/permission_screen.dart';
import '../domain/camera_models.dart';
import 'camera_preview_view.dart';
import 'camera_providers.dart';

/// S-04. M1 scope: preview, lens switch, torch, zoom. No styles, capture or gallery yet.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  double _scaleBaseZoom = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(ref.read(cameraControllerProvider.notifier).stop());
      case AppLifecycleState.resumed:
        _resume();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _resume() async {
    await ref.read(cameraPermissionProvider.notifier).refresh();
    if (!mounted) return;
    _startIfPossible();
  }

  void _startIfPossible() {
    final gate = ref.read(cameraPermissionProvider);
    final camera = ref.read(cameraControllerProvider);
    if (gate == CameraPermissionGate.granted &&
        camera.status == CameraStatus.idle) {
      ref.read(cameraControllerProvider.notifier).start();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cameraPermissionProvider, (previous, next) {
      if (next == CameraPermissionGate.granted) _startIfPossible();
    });

    final gate = ref.watch(cameraPermissionProvider);
    if (gate != CameraPermissionGate.granted) {
      final permission = ref.read(cameraPermissionProvider.notifier);
      return PermissionScreen(
        gate: gate,
        onRequest: permission.request,
        onOpenSettings: permission.openSettings,
      );
    }

    final camera = ref.watch(cameraControllerProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onScaleStart: (_) => _scaleBaseZoom = camera.zoom,
            onScaleUpdate: (details) {
              if (details.pointerCount < 2) return;
              controller.setZoom(_scaleBaseZoom * details.scale);
            },
            child: switch (camera.status) {
              CameraStatus.error => _ErrorPanel(
                error: camera.error,
                onRetry: controller.start,
              ),
              _ when camera.previewReady => CameraPreviewView(
                textureId: camera.textureId!,
                transform: camera.preview!,
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!kReleaseMode)
                        _RoundButton(
                          icon: Icons.bug_report_outlined,
                          label: 'Developer tools',
                          onPressed: () => context.push(AppRoutes.developer),
                        )
                      else
                        const SizedBox(width: 48),
                      if (camera.capabilities?.hasFlash ?? false)
                        _RoundButton(
                          icon: camera.torchOn
                              ? Icons.flash_on
                              : Icons.flash_off,
                          label: camera.torchOn
                              ? 'Turn torch off'
                              : 'Turn torch on',
                          active: camera.torchOn,
                          onPressed: controller.toggleTorch,
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                  const Spacer(),
                  if (camera.status == CameraStatus.running &&
                      camera.capabilities != null)
                    _ZoomControl(
                      zoom: camera.zoom,
                      min: camera.capabilities!.zoomMin,
                      max: camera.capabilities!.zoomMax,
                      onChanged: controller.setZoom,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (camera.capabilities?.canSwitchLens ?? false)
                        _RoundButton(
                          icon: Icons.cameraswitch_outlined,
                          label: camera.lens.other == Lens.front
                              ? 'Switch to front camera'
                              : 'Switch to rear camera',
                          onPressed: controller.switchLens,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: active ? AppColors.brandPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    ),
  );
}

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({
    required this.zoom,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double zoom;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // Slider range is capped so very large optical+digital ranges stay usable; pinch covers the full range.
    final sliderMax = max.clamp(min, 10.0);
    if (sliderMax <= min) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Text(
            '${zoom.toStringAsFixed(1)}×',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Expanded(
            child: Slider(
              value: zoom.clamp(min, sliderMax),
              min: min,
              max: sliderMax,
              semanticFormatterCallback: (value) =>
                  'Zoom ${value.toStringAsFixed(1)} times',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final EngineError? error;
  final VoidCallback onRetry;

  String get _message => switch (error?.code) {
    EngineErrorCode.cameraInUse => 'Another app is using the camera.',
    EngineErrorCode.cameraUnavailable => 'The camera is unavailable right now.',
    EngineErrorCode.unsupported =>
      'This camera is not available on your phone.',
    _ => 'Something went wrong with the camera.',
  };

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            size: 56,
            color: AppColors.stateError,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
