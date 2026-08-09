import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app/app_info.dart';
import '../update/update_dialog.dart';
import '../update/update_service.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.updateService});

  final UpdateService? updateService;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final UpdateService _updateService;
  late final bool _ownsUpdateService;
  PackageInfo? _packageInfo;
  String _updateNotes = '正在加载更新说明…';
  String? _feedback;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _ownsUpdateService = widget.updateService == null;
    _updateService = widget.updateService ?? UpdateService();
    unawaited(_loadPackageInfo());
    unawaited(_loadUpdateNotes());
  }

  @override
  void dispose() {
    if (_ownsUpdateService) {
      _updateService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于与更新')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Icon(Icons.view_in_ar, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              AppInfo.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '版本 $_versionLabel',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('作者信息', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    const _DetailRow(label: '作者', value: AppInfo.author),
                    const _DetailRow(label: '邮箱', value: AppInfo.email),
                    const SizedBox(height: 4),
                    Text(
                      '本应用复用 heat ex 项目的发布配置与作者信息。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('求解算法', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      '使用 Kociemba 两阶段算法，在较短时间内给出实用解法。'
                      '解法追求速度与稳定性，不保证数学意义上的最短步数。',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '核心库：cuber 0.4.0（tiagohm/cuber，MIT License）。'
                      '许可证全文见 LICENSES/cuber.txt。',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('隐私说明', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      '照片仅在本机处理，用于完成采样、颜色识别和校验，不会上传到服务器。'
                      '网络仅用于可选的版本检查和 APK 下载。',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _checking ? null : _checkForUpdates,
              icon: _checking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_outlined),
              label: Text(_checking ? '检查中…' : '手动检查更新'),
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 8),
              Text(
                _feedback!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 20),
            Text('更新说明', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(_updateNotes),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _versionLabel {
    final info = _packageInfo;
    if (info == null) return '读取中…';
    final build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version}+$build';
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } catch (_) {
      if (mounted) setState(() => _packageInfo = null);
    }
  }

  Future<void> _loadUpdateNotes() async {
    try {
      final notes = await rootBundle.loadString('assets/docs/update_notes.md');
      if (mounted) setState(() => _updateNotes = notes);
    } catch (_) {
      if (mounted) {
        setState(() => _updateNotes = '# 更新说明\n\n当前版本包含扫描、校验和逐步播放功能。');
      }
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
      _feedback = null;
    });
    final result = await _updateService.checkForUpdates(force: true);
    if (!mounted) return;
    setState(() => _checking = false);

    switch (result.status) {
      case UpdateCheckStatus.updateAvailable:
        await showUpdateDialog(
          context: context,
          service: _updateService,
          update: result.update!,
        );
      case UpdateCheckStatus.upToDate:
        setState(() => _feedback = '当前已是最新版本');
      case UpdateCheckStatus.throttled:
        setState(() => _feedback = '近期已经检查过更新');
      case UpdateCheckStatus.failed:
        setState(() => _feedback = result.errorMessage ?? '检查更新失败');
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text(label)),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
