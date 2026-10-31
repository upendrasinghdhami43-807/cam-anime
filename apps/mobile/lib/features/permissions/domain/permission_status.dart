/// Result of a native permission query (docs/integrations/API.md §3).
class PermissionStatus {
  const PermissionStatus({
    required this.granted,
    required this.shouldShowRationale,
    required this.blocked,
  });

  factory PermissionStatus.fromMap(Map<Object?, Object?> map) =>
      PermissionStatus(
        granted: map['granted'] == true,
        shouldShowRationale: map['shouldShowRationale'] == true,
        blocked: map['blocked'] == true,
      );

  final bool granted;
  final bool shouldShowRationale;
  final bool blocked;
}

/// What the permission screen (S-03) must show.
enum CameraPermissionGate {
  checking,
  needsPermission,
  denied,
  blocked,
  granted,
}

CameraPermissionGate gateFor(PermissionStatus status) {
  if (status.granted) return CameraPermissionGate.granted;
  if (status.blocked) return CameraPermissionGate.blocked;
  if (status.shouldShowRationale) return CameraPermissionGate.denied;
  return CameraPermissionGate.needsPermission;
}
