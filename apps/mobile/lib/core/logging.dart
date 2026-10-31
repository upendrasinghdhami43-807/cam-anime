import 'dart:developer' as developer;

/// Single logging entry point. No pixel data, media paths or user content may be logged.
void logInfo(String message, {String name = 'CamAnime'}) {
  developer.log(message, name: name);
}

void logError(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String name = 'CamAnime',
}) {
  developer.log(
    message,
    name: name,
    error: error,
    stackTrace: stackTrace,
    level: 1000,
  );
}
