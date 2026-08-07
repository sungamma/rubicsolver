import 'package:flutter/material.dart';

import '../cube/cube_face.dart';
import '../cube/cube_state.dart';
import '../editor/cube_net.dart';
import '../scan/color_math.dart';
import '../solver/solution_move.dart';
import 'move_player.dart';

/// Result page for a solver run.  The formula remains visible while the
/// two-dimensional net reflects the state at the selected step.
class SolutionPage extends StatefulWidget {
  SolutionPage({
    super.key,
    CubeState? initialState,
    CubeState? initial,
    required Iterable<SolutionMove> moves,
    this.centerColors = const {},
    this.initialSpeed = defaultMoveSpeed,
  }) : assert(initialState != null || initial != null),
       initialState = initialState ?? initial!,
       moves = List.unmodifiable(moves);

  final CubeState initialState;
  final List<SolutionMove> moves;
  final Map<CubeFace, RgbColor> centerColors;
  final Duration initialSpeed;

  @override
  State<SolutionPage> createState() => _SolutionPageState();
}

class _SolutionPageState extends State<SolutionPage> {
  late MovePlayer _player;

  @override
  void initState() {
    super.initState();
    _player = _newPlayer();
  }

  @override
  void didUpdateWidget(covariant SolutionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialState != widget.initialState ||
        !_sameMoves(oldWidget.moves, widget.moves)) {
      _player.dispose();
      _player = _newPlayer();
    }
  }

  MovePlayer _newPlayer() => MovePlayer(
    initial: widget.initialState,
    moves: widget.moves,
    speed: widget.initialSpeed,
  );

  bool _sameMoves(List<SolutionMove> left, List<SolutionMove> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('解法演示')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgress(context),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: CubeNet(
                        state: _player.currentState,
                        centerColors: widget.centerColors,
                        highlightedStickerIndices: _highlightedIndices,
                        highlightColor: Theme.of(context).colorScheme.primary,
                        showCenterLocks: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInstruction(context),
                    const SizedBox(height: 16),
                    _buildControls(context),
                    const SizedBox(height: 20),
                    _buildFormula(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    final total = _player.moves.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                total == 0 ? '魔方已经复原' : '步骤 ${_player.currentIndex}/$total',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (total > 0)
              Text(
                '${(_player.progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _player.progress),
      ],
    );
  }

  Widget _buildInstruction(BuildContext context) {
    final text = _instructionText;
    final move = _player.currentMove;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(
                move == null || _player.isComplete
                    ? Icons.check
                    : Icons.rotate_right,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                key: const ValueKey('current-instruction'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _instructionText {
    if (_player.moves.isEmpty) {
      return '魔方已经复原，无需操作。';
    }
    if (_player.currentIndex == 0) {
      return '准备开始';
    }
    if (_player.isComplete) {
      return '复原完成';
    }
    return _player.currentMove?.instruction ?? '准备下一步';
  }

  Widget _buildControls(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: _player.currentIndex == 0 ? null : _player.previous,
                icon: const Icon(Icons.skip_previous),
                label: const Text('上一步'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: _player.moves.isEmpty ? null : _player.togglePlay,
                icon: Icon(_player.isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_player.isPlaying ? '暂停' : '播放'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: _player.isComplete ? null : _player.next,
                icon: const Icon(Icons.skip_next),
                label: const Text('下一步'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.speed, size: 18),
            const SizedBox(width: 8),
            const Text('速度'),
            const SizedBox(width: 8),
            DropdownButton<Duration>(
              value: _player.speed,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: Duration(milliseconds: 500),
                  child: Text('快 · 0.5 秒'),
                ),
                DropdownMenuItem(
                  value: defaultMoveSpeed,
                  child: Text('标准 · 0.9 秒'),
                ),
                DropdownMenuItem(
                  value: Duration(milliseconds: 1400),
                  child: Text('慢 · 1.4 秒'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _player.speed = value;
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormula(BuildContext context) {
    if (_player.moves.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('完整解法', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var index = 0; index < _player.moves.length; index++)
                  _MoveChip(
                    key: ValueKey('solution-move-$index'),
                    move: _player.moves[index],
                    index: index,
                    currentIndex: _player.currentIndex,
                    onPressed: () => _player.seek(index + 1),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Iterable<int> get _highlightedIndices {
    final face = _player.currentFace;
    if (face == null) {
      return const <int>[];
    }
    return [
      for (var offset = 0; offset < 9; offset++) face.startIndex + offset,
    ];
  }
}

class _MoveChip extends StatelessWidget {
  const _MoveChip({
    super.key,
    required this.move,
    required this.index,
    required this.currentIndex,
    required this.onPressed,
  });

  final SolutionMove move;
  final int index;
  final int currentIndex;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final current = index == currentIndex - 1;
    final completed = index < currentIndex - 1;
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      onPressed: onPressed,
      backgroundColor: current
          ? scheme.primaryContainer
          : completed
          ? scheme.secondaryContainer
          : scheme.surfaceContainerHighest,
      side: current
          ? BorderSide(color: scheme.primary, width: 2)
          : BorderSide.none,
      label: Text(
        move.notation,
        style: TextStyle(
          color: current
              ? scheme.onPrimaryContainer
              : completed
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
          fontWeight: current ? FontWeight.bold : null,
        ),
      ),
    );
  }
}
