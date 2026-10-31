import 'package:flutter/widgets.dart';

import '../domain/camera_models.dart';

/// Shows the native texture upright. Until the GL pipeline (M2) exists, rotation and mirroring
/// come from CameraX's transformation info (docs/architecture/CAMERA_PIPELINE.md §3).
class CameraPreviewView extends StatelessWidget {
  const CameraPreviewView({
    required this.textureId,
    required this.transform,
    super.key,
  });

  final int textureId;
  final PreviewTransformEvent transform;

  @override
  Widget build(BuildContext context) {
    final quarterTurns = (transform.rotationDegrees ~/ 90) % 4;
    final bufferAspect = transform.width / transform.height;
    final uprightAspect = quarterTurns.isOdd ? 1 / bufferAspect : bufferAspect;

    return Center(
      child: AspectRatio(
        aspectRatio: uprightAspect,
        child: Transform.flip(
          flipX: transform.mirrored,
          child: RotatedBox(
            quarterTurns: quarterTurns,
            child: AspectRatio(
              aspectRatio: bufferAspect,
              child: Texture(textureId: textureId),
            ),
          ),
        ),
      ),
    );
  }
}
