import 'dart:async';

import 'package:flutter/material.dart';

import '../update/update_dialog.dart';
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
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final UpdateService _updateService;
  late final bool _ownsUpdateService;

  @override
  void initState() {
    super.initState();
    _ownsUpdateService = widget.updateService == null;
    _updateService = widget.updateService ?? UpdateService();
    if (widget.enableStartupUpdateCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runStartupUpdateCheck());
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

  Future<void> _runStartupUpdateCheck() async {
    try {
      final result = await _updateService.checkForUpdates();
      if (!mounted || result.status != UpdateCheckStatus.updateAvailable) {
        return;
      }
      final dialogContext = _navigatorKey.currentState?.overlay?.context;
      if (dialogContext == null || !dialogContext.mounted) return;
      await showUpdateDialog(
        context: dialogContext,
        service: _updateService,
        update: result.update!,
      );
    } catch (_) {
      // Startup checks are intentionally best-effort and never block the app.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
