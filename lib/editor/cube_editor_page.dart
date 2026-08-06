import 'package:flutter/material.dart';

import '../cube/cube_face.dart';
import '../cube/cube_state.dart';
import '../cube/cube_validation.dart';
import '../scan/color_classifier.dart';
import '../scan/color_math.dart';
import 'cube_display_colors.dart';
import 'cube_net.dart';

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
  });

  final CubeState initialState;
  final ValueChanged<CubeState>? onSolve;
  final List<RecognitionHint> recognitionHints;
  final List<int> uncertainStickerIndices;
  final List<ClassificationIssue> classificationIssues;
  final Map<CubeFace, RgbColor> centerColors;
  final ValueChanged<CubeFace>? onRescanFace;

  @override
  State<CubeEditorPage> createState() => _CubeEditorPageState();
}

class _CubeEditorPageState extends State<CubeEditorPage> {
  static const _validator = CubeValidator();

  late CubeState _state;
  late List<RecognitionHint> _recognitionHints;
  late Set<int> _uncertainStickerIndices;
  late ValidationResult _validation;

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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择贴纸颜色', style: Theme.of(context).textTheme.titleMedium),
            for (final face in CubeFace.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: CubeDisplayColors.colorFor(
                    face,
                    centerColors: widget.centerColors,
                  ),
                  foregroundColor: CubeDisplayColors.foregroundFor(
                    face,
                    centerColors: widget.centerColors,
                  ),
                  child: Text(face.letter),
                ),
                title: Text(_colorOptionLabel(face)),
                trailing: _state.stickers[index] == face
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(face),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == _state.stickers[index]) {
      return;
    }

    setState(() {
      _state = _state.replaceSticker(index, selected);
      _recognitionHints.removeWhere((hint) => hint.stickerIndex == index);
      _uncertainStickerIndices.remove(index);
      _validate();
    });
  }

  void _resetSolved() {
    setState(() {
      _state = CubeState.solved();
      _recognitionHints = [];
      _uncertainStickerIndices = {};
      _validate();
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择要重新扫描的面', style: Theme.of(context).textTheme.titleMedium),
            for (final candidate in CubeFace.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: CubeDisplayColors.colorFor(
                    candidate,
                    centerColors: widget.centerColors,
                  ),
                  foregroundColor: CubeDisplayColors.foregroundFor(
                    candidate,
                    centerColors: widget.centerColors,
                  ),
                  child: Text(candidate.letter),
                ),
                title: Text('${_faceName(candidate)}（${candidate.letter}）'),
                onTap: () => Navigator.of(context).pop(candidate),
              ),
          ],
        ),
      ),
    );
    if (mounted && face != null) {
      callback(face);
    }
  }

  void _startSolve() {
    final callback = widget.onSolve;
    if (callback != null) {
      callback(_state);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('魔方状态已就绪。')));
  }

  @override
  Widget build(BuildContext context) {
    final counts = _state.countByFace();
    final highlighted = {
      ..._uncertainStickerIndices,
      ..._validation.suspectStickerIndices,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('校验与纠错'),
        actions: [
          IconButton(
            tooltip: '重置为复原状态',
            onPressed: _resetSolved,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
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
                            ),
                          ),
                          label: Text('${face.letter} ${counts[face]}/9'),
                        ),
                    ],
                  ),
                  if (widget.classificationIssues.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MessageCard(
                      icon: Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                      message: '扫描质量问题尚未解决，请重新扫描对应面后再求解。',
                    ),
                    for (final issue in widget.classificationIssues)
                      _MessageCard(
                        icon: Icons.camera_alt_outlined,
                        color: Theme.of(context).colorScheme.tertiary,
                        message: issue.message,
                      ),
                  ],
                  const SizedBox(height: 16),
                  if (_validation.isValid &&
                      widget.classificationIssues.isEmpty)
                    _MessageCard(
                      icon: Icons.check_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                      message: '状态合法，可以开始求解。',
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
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _validation.isValid && widget.classificationIssues.isEmpty
              ? _startSolve
              : null,
          child: const Text('开始求解'),
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
