import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

class CamAnimeApp extends StatefulWidget {
  const CamAnimeApp({super.key});

  @override
  State<CamAnimeApp> createState() => _CamAnimeAppState();
}

class _CamAnimeAppState extends State<CamAnimeApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Cam-Anime',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    themeMode: ThemeMode.dark,
    routerConfig: _router,
  );
}
