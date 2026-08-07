import 'dart:async';

import 'package:flutter/material.dart';

import '../update/update_service.dart';
import 'app_info.dart';
import 'home_page.dart';

class RubikSolverApp extends StatefulWidget {
  const RubikSolverApp({
    super.key,
    this.updateService,
    this.enableStartupUpdateCheck = true,
  });

  final UpdateService? updateService;
  final bool enableStartupUpdateCheck;

  @override
  State<RubikSolverApp> createState() => _RubikSolverAppState();
}

class _RubikSolverAppState extends State<RubikSolverApp> {
  late final UpdateService _updateService;
  late final bool _ownsUpdateService;

  @override
  void initState() {
    super.initState();
    _ownsUpdateService = widget.updateService == null;
    _updateService = widget.updateService ?? UpdateService();
    if (widget.enableStartupUpdateCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runSilentUpdateCheck());
      });
    }
  }

  @override
  void dispose() {
    if (_ownsUpdateService) {
      _updateService.dispose();
    }
    super.dispose();
  }

  Future<void> _runSilentUpdateCheck() async {
    try {
      await _updateService.checkForUpdates();
    } catch (_) {
      // Startup checks are intentionally best-effort and never block the app.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2457C5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HomePage(updateService: _updateService),
    );
  }
}
