import 'package:flutter/material.dart';

import '../cube/cube_color_scheme.dart';
import '../cube/cube_state.dart';
import '../editor/cube_net.dart';
import '../playback/solution_page.dart';
import 'cube_pattern.dart';
import 'cube_pattern_catalog.dart';

class PatternGalleryPage extends StatelessWidget {
  const PatternGalleryPage({
    super.key,
    this.colorScheme = CubeColorScheme.standard,
  });

  final CubeColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final patterns = CubePatternCatalog.classics.patterns;
    return Scaffold(
      appBar: AppBar(title: const Text('花式魔方')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PatternGuideCard(),
                      const SizedBox(height: 16),
                      if (wide)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: patterns.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 448,
                              ),
                          itemBuilder: (context, index) => _PatternCard(
                            pattern: patterns[index],
                            colorScheme: colorScheme,
                            onPressed: () =>
                                _openPattern(context, patterns[index]),
                          ),
                        )
                      else
                        for (
                          var index = 0;
                          index < patterns.length;
                          index++
                        ) ...[
                          _PatternCard(
                            pattern: patterns[index],
                            colorScheme: colorScheme,
                            onPressed: () =>
                                _openPattern(context, patterns[index]),
                          ),
                          if (index != patterns.length - 1)
                            const SizedBox(height: 12),
                        ],
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

  void _openPattern(BuildContext context, CubePattern pattern) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SolutionPage(
          initialState: CubeState.solved(),
          moves: pattern.moves,
          colorScheme: colorScheme,
          title: '${pattern.name}演示',
          completionText: '花式完成',
          formulaTitle: '完整拼法',
        ),
      ),
    );
  }
}

class _PatternGuideCard extends StatelessWidget {
  const _PatternGuideCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '请先将魔方完整复原，让 U 面朝上、F 面朝前。'
                '执行公式时保持这个方向，过程中不要整体转动魔方。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({
    required this.pattern,
    required this.colorScheme,
    required this.onPressed,
  });

  final CubePattern pattern;
  final CubeColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('pattern-card-${pattern.id}'),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: '演示${pattern.name}',
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CubeNet(
                  key: ValueKey('pattern-preview-${pattern.id}'),
                  state: pattern.targetState,
                  showCenterLocks: false,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pattern.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        child: Text(
                          pattern.difficulty.label,
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${pattern.moveCount} 步',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  pattern.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始演示'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
