import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../camera/presentation/camera_providers.dart';
import '../data/backend_client.dart';

final backendClientProvider = Provider<BackendClient>((ref) {
  final client = BackendClient();
  ref.onDispose(client.close);
  return client;
});

/// Developer-only screen (debug/profile builds): engine info and optional test-backend connectivity.
class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  String _engine = 'not checked';
  String _health = 'not checked';
  List<CartoonStyleInfo> _styles = const [];
  String _feedback = '';
  bool _busy = false;
  final _feedbackController = TextEditingController(
    text: 'Hello from the Cam-Anime test build',
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final engine = ref.read(cameraEngineProvider);
    final backend = ref.read(backendClientProvider);

    String engineText;
    try {
      final info = await engine.getInfo();
      engineText =
          'API ${info.apiVersion} · engine ${info.engineVersion} · Android SDK ${info.androidSdk}';
    } on Object catch (e) {
      engineText = 'error: $e';
    }

    String healthText;
    var styles = const <CartoonStyleInfo>[];
    try {
      final health = await backend.health();
      healthText = health.healthy
          ? 'OK (gateway → api → database)'
          : 'degraded: gateway=${health.gateway} api=${health.api} db=${health.database}';
      styles = await backend.styles();
    } on BackendException catch (e) {
      healthText = '$e (is the backend running? see backend/README.md)';
    }

    if (!mounted) return;
    setState(() {
      _engine = engineText;
      _health = healthText;
      _styles = styles;
      _busy = false;
    });
  }

  Future<void> _sendFeedback() async {
    setState(() => _busy = true);
    String result;
    try {
      final id = await ref
          .read(backendClientProvider)
          .sendFeedback(
            message: _feedbackController.text,
            appVersion: '1.0.0-dev',
          );
      result = 'Saved feedback $id';
    } on BackendException catch (e) {
      result = 'Failed: $e';
    }
    if (!mounted) return;
    setState(() {
      _feedback = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Developer tools')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Native engine', style: text.titleMedium),
          Text(_engine),
          const SizedBox(height: AppSpacing.md),
          Text('Test backend ($backendBaseUrl)', style: text.titleMedium),
          Text(_health),
          const SizedBox(height: AppSpacing.sm),
          for (final style in _styles)
            Text('• ${style.name} (${style.id} v${style.version})'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _feedbackController,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Test feedback message',
            ),
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _refresh,
                child: const Text('Refresh'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _busy ? null : _sendFeedback,
                child: const Text('Send feedback'),
              ),
            ],
          ),
          if (_feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_feedback),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'The app works fully offline. This backend is optional and only reachable in debug/profile builds.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
