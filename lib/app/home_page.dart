import 'package:flutter/material.dart';

import '../cube/cube_color_scheme.dart';
import '../cube/cube_state.dart';
import '../editor/cube_editor_page.dart';
import '../scan/scan_page.dart';
import '../settings/about_page.dart';
import '../solver/cube_scrambler.dart';
import '../update/update_service.dart';
import 'app_info.dart';
import 'cube_color_scheme_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.updateService, this.scrambler});

  final UpdateService? updateService;
  final CubeScrambler? scrambler;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CubeColorScheme _colorScheme = CubeColorScheme.standard;
  late final CubeScrambler _scrambler;

  @override
  void initState() {
    super.initState();
    _scrambler = widget.scrambler ?? CubeScrambler();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppInfo.name),
        actions: [
          IconButton(
            tooltip: '设置与关于',
            onPressed: () => _showAbout(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final actions = [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ScanPage(colorScheme: _colorScheme),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('开始扫描'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openRandomCube(context),
                icon: const Icon(Icons.shuffle),
                label: const Text('随机魔方'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CubeEditorPage(
                      initialState: CubeState.solved(),
                      colorScheme: _colorScheme,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('手动录入'),
              ),
            ];

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.view_in_ar,
                        size: 88,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '拍下六个面，跟着步骤复原魔方',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '按 U、R、F、D、L、B 顺序采集，识别后可校验和修改每一枚贴纸。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      TextButton.icon(
                        onPressed: () => _configureColorScheme(context),
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('配置六面配色'),
                      ),
                      const SizedBox(height: 12),
                      if (wide)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(child: actions[0]),
                            const SizedBox(width: 12),
                            Expanded(child: actions[1]),
                            const SizedBox(width: 12),
                            Expanded(child: actions[2]),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            actions[0],
                            const SizedBox(height: 12),
                            actions[1],
                            const SizedBox(height: 12),
                            actions[2],
                          ],
                        ),
                      const SizedBox(height: 24),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _InfoLabel(
                            icon: Icons.shield_outlined,
                            text: '照片仅在本机处理，不会上传',
                          ),
                          _InfoLabel(
                            icon: Icons.offline_bolt_outlined,
                            text: 'Kociemba 两阶段算法',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AboutPage(updateService: widget.updateService),
      ),
    );
  }

  Future<void> _configureColorScheme(BuildContext context) async {
    final result = await showCubeColorSchemeDialog(
      context,
      initialScheme: _colorScheme,
    );
    if (!mounted || result == null) return;
    setState(() {
      _colorScheme = result;
    });
  }

  void _openRandomCube(BuildContext context) {
    final scramble = _scrambler.generate();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CubeEditorPage(
          initialState: scramble.state,
          scrambleMoves: scramble.moves,
          colorScheme: _colorScheme,
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}
