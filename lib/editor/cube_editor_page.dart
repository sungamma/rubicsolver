import 'dart:async';

import 'package:flutter/material.dart';

import '../cube/cube_color_scheme.dart';
import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import '../cube/cube_state.dart';
import '../cube/cube_validation.dart';
import '../scan/color_classifier.dart';
import '../scan/color_math.dart';
import 'cube_display_colors.dart';
import 'cube_net.dart';
import '../playback/solution_page.dart';
import '../solver/cube_solver.dart';

class CubeEditorPage extends StatefulWidget {
  const CubeEditorPage({
    super.key,
    required this.initialState,
    this.onSolve,
    this.recognitionHints = const [],
    this.uncertainStickerIndices = const [],
    this.classificationIssues = const [],
    this.centerColors = const {},
    this.onRescanFace,
    this.solver = const CubeSolver(),
    this.colorScheme = CubeColorScheme.standard,
  });

  final CubeState initialState;
  final ValueChanged<CubeState>? onSolve;
  final List<RecognitionHint> recognitionHints;
  final List<int> uncertainStickerIndices;
  final List<ClassificationIssue> classificationIssues;
  final Map<CubeFace, RgbColor> centerColors;
  final ValueChanged<CubeFace>? onRescanFace;
  final CubeSolver solver;
  final CubeColorScheme colorScheme;

  @override
  State<CubeEditorPage> createState() => _CubeEditorPageState();
}

class _CubeEditorPageState extends State<CubeEditorPage> {
  static const _validator = CubeValidator();

  late CubeState _state;
  late List<RecognitionHint> _recognitionHints;
  late Set<int> _uncertainStickerIndices;
  late ValidationResult _validation;
  var _solving = false;
  var _recognitionWarningsAcknowledged = false;
  var _solveGeneration = 0;
  String? _solveError;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _recognitionHints = List.of(widget.recognitionHints);
    _uncertainStickerIndices = widget.uncertainStickerIndices.toSet();
    _validate();
  }

  void _validate() {
    _validation = _validator.validate(
      _state,
      recognitionHints: _recognitionHints,
    );
  }

  Future<void> _editSticker(int index) async {
    if (_state.isCenterIndex(index)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('中心贴纸不可编辑，中心颜色用于确定面的方向。')));
      return;
    }

    final selected = await showModalBottomSheet<CubeFace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ScrollableSheet(
        title: '选择贴纸颜色',
        children: [
          for (final face in CubeFace.values)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: CubeDisplayColors.colorFor(
                  face,
                  centerColors: widget.centerColors,
                  colorScheme: widget.colorScheme,
                ),
                foregroundColor: CubeDisplayColors.foregroundFor(
                  face,
                  centerColors: widget.centerColors,
                  colorScheme: widget.colorScheme,
                ),
                child: Text(face.letter),
              ),
              title: Text(_colorOptionLabel(face)),
              subtitle: Text(
                '实际颜色：${CubePalette.nameFor(widget.colorScheme.colorIdentityFor(face))}',
              ),
              trailing: _state.stickers[index] == face
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(face),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      if (selected != _state.stickers[index]) {
        _state = _state.replaceSticker(index, selected);
      }
      _recognitionHints.removeWhere((hint) => hint.stickerIndex == index);
      _uncertainStickerIndices.remove(index);
      _recognitionWarningsAcknowledged = false;
      _solveError = null;
      _validate();
    });
  }

  void _resetSolved() {
    setState(() {
      _state = CubeState.solved();
      _recognitionHints = [];
      _uncertainStickerIndices = {};
      _recognitionWarningsAcknowledged = false;
      _solveError = null;
      _validate();
    });
  }

  void _acknowledgeRecognitionWarnings() {
    setState(() {
      _recognitionWarningsAcknowledged = true;
      _solveError = null;
    });
  }

  Future<void> _chooseFaceToRescan() async {
    final callback = widget.onRescanFace;
    if (callback == null) {
      return;
    }
    final face = await showModalBottomSheet<CubeFace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ScrollableSheet(
        title: '选择要重新扫描的面',
        children: [
          for (final candidate in CubeFace.values)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: CubeDisplayColors.colorFor(
                  candidate,
                  centerColors: widget.centerColors,
                  colorScheme: widget.colorScheme,
                ),
                foregroundColor: CubeDisplayColors.foregroundFor(
                  candidate,
                  centerColors: widget.centerColors,
                  colorScheme: widget.colorScheme,
                ),
                child: Text(candidate.letter),
              ),
              title: Text('${_faceName(candidate)}（${candidate.letter}）'),
              onTap: () => Navigator.of(context).pop(candidate),
            ),
        ],
      ),
    );
    if (mounted && face != null) {
      callback(face);
    }
  }

  Future<void> _startSolve() async {
    final callback = widget.onSolve;
    if (callback != null) {
      callback(_state);
      return;
    }
    if (_solving) {
      return;
    }
    final solveState = _state;
    final generation = ++_solveGeneration;
    setState(() {
      _solving = true;
      _solveError = null;
    });
    try {
      final moves = await widget.solver.solve(solveState);
      if (!mounted || generation != _solveGeneration) {
        return;
      }
      setState(() => _solving = false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SolutionPage(
            initialState: solveState,
            moves: moves,
            centerColors: widget.centerColors,
            colorScheme: widget.colorScheme,
          ),
        ),
      );
    } on InvalidCubeException catch (error) {
      if (!mounted || generation != _solveGeneration) {
        return;
      }
      setState(() {
        _solving = false;
        _solveError = error.message;
      });
    } on SolveTimeoutException {
      if (!mounted || generation != _solveGeneration) {
        return;
      }
      setState(() {
        _solving = false;
        _solveError = '求解超时，请稍后重试或返回检查。';
      });
    } catch (error) {
      if (!mounted || generation != _solveGeneration) {
        return;
      }
      setState(() {
        _solving = false;
        _solveError = '求解失败：$error';
      });
    }
  }

  void _cancelSolve() {
    if (!_solving) {
      return;
    }
    _solveGeneration++;
    setState(() {
      _solving = false;
      _solveError = '已取消求解。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = _state.countByFace();
    final hasUnconfirmedStickers = _uncertainStickerIndices.any(
      (index) => index >= 0 && index < 54 && !_state.isCenterIndex(index),
    );
    final hasRecognitionWarnings =
        widget.classificationIssues.isNotEmpty || hasUnconfirmedStickers;
    final recognitionWarningsConfirmed =
        !hasRecognitionWarnings || _recognitionWarningsAcknowledged;
    final highlighted = {
      ..._validation.suspectStickerIndices,
      if (!_recognitionWarningsAcknowledged) ..._uncertainStickerIndices,
    };
    final canSolve = _validation.isValid && recognitionWarningsConfirmed;

    final body = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CubeNet(
                  state: _state,
                  highlightedStickerIndices: highlighted,
                  centerColors: widget.centerColors,
                  colorScheme: widget.colorScheme,
                  onStickerTap: _editSticker,
                ),
                const SizedBox(height: 16),
                Text('颜色计数', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final face in CubeFace.values)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: CubeDisplayColors.colorFor(
                            face,
                            centerColors: widget.centerColors,
                            colorScheme: widget.colorScheme,
                          ),
                        ),
                        label: Text('${face.letter} ${counts[face]}/9'),
                      ),
                  ],
                ),
                if (widget.classificationIssues.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _RecognitionWarningCard(
                    acknowledged: _recognitionWarningsAcknowledged,
                    uncertainCount: hasUnconfirmedStickers
                        ? _uncertainStickerIndices.length
                        : 0,
                    onAcknowledge: _acknowledgeRecognitionWarnings,
                  ),
                  for (final issue in widget.classificationIssues)
                    _MessageCard(
                      icon: Icons.camera_alt_outlined,
                      color: Theme.of(context).colorScheme.tertiary,
                      message: issue.message,
                    ),
                ] else if (hasUnconfirmedStickers) ...[
                  const SizedBox(height: 16),
                  _RecognitionWarningCard(
                    acknowledged: _recognitionWarningsAcknowledged,
                    uncertainCount: _uncertainStickerIndices.length,
                    onAcknowledge: _acknowledgeRecognitionWarnings,
                  ),
                ],
                if (_solveError != null) ...[
                  const SizedBox(height: 16),
                  _MessageCard(
                    icon: Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    message: _solveError!,
                  ),
                ],
                const SizedBox(height: 16),
                if (canSolve)
                  _MessageCard(
                    icon: Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                    message: hasRecognitionWarnings
                        ? '已使用当前颜色，物理校验通过，可以开始求解。'
                        : '状态合法，可以开始求解。',
                  )
                else if (!_validation.isValid)
                  for (final issue in _validation.issues)
                    _MessageCard(
                      icon: Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      message: issue.message,
                    ),
                if (widget.onRescanFace != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _chooseFaceToRescan,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('重新扫描某一面'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('校验与纠错'),
        actions: [
          IconButton(
            tooltip: '重置为复原状态',
            onPressed: _solving ? null : _resetSolved,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Stack(
        children: [
          body,
          if (_solving) _SolveProgressOverlay(onCancel: _cancelSolve),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: canSolve && !_solving
              ? () => unawaited(_startSolve())
              : null,
          child: const Text('开始求解'),
        ),
      ),
    );
  }
}

class _RecognitionWarningCard extends StatelessWidget {
  const _RecognitionWarningCard({
    required this.acknowledged,
    required this.uncertainCount,
    required this.onAcknowledge,
  });

  final bool acknowledged;
  final int uncertainCount;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('recognition-warning-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  acknowledged
                      ? Icons.check_circle_outline
                      : Icons.help_outline,
                  color: acknowledged
                      ? colorScheme.primary
                      : colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    acknowledged
                        ? '已使用当前颜色；后续只按魔方物理合法性判断。'
                        : uncertainCount > 0
                        ? '有 $uncertainCount 枚贴纸识别置信度较低。请核对颜色；这只是提醒，不会替代物理校验。'
                        : '识别到图像质量提示。请核对颜色；这只是提醒，不会替代物理校验。',
                  ),
                ),
              ],
            ),
            if (!acknowledged) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  key: const ValueKey('acknowledge-recognition-warnings'),
                  onPressed: onAcknowledge,
                  child: const Text('我已核对，使用当前颜色'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _SolveProgressOverlay extends StatelessWidget {
  const _SolveProgressOverlay({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.black26),
          ),
          Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('正在求解…'),
                    const SizedBox(height: 4),
                    const Text('请保持页面打开，求解在本机后台运行。'),
                    const SizedBox(height: 12),
                    TextButton(onPressed: onCancel, child: const Text('取消求解')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableSheet extends StatelessWidget {
  const _ScrollableSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: SizedBox(
        height: height * .75,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

String _colorOptionLabel(CubeFace face) => '${_faceName(face)}颜色';

String _faceName(CubeFace face) {
  return switch (face) {
    CubeFace.up => '上面',
    CubeFace.right => '右面',
    CubeFace.front => '前面',
    CubeFace.down => '下面',
    CubeFace.left => '左面',
    CubeFace.back => '后面',
  };
}
