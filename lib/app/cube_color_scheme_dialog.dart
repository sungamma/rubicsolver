import 'package:flutter/material.dart';

import '../cube/cube_color_scheme.dart';
import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';

Future<CubeColorScheme?> showCubeColorSchemeDialog(
  BuildContext context, {
  required CubeColorScheme initialScheme,
}) {
  return showDialog<CubeColorScheme>(
    context: context,
    builder: (_) => _CubeColorSchemeDialog(initialScheme: initialScheme),
  );
}

class _CubeColorSchemeDialog extends StatefulWidget {
  const _CubeColorSchemeDialog({required this.initialScheme});

  final CubeColorScheme initialScheme;

  @override
  State<_CubeColorSchemeDialog> createState() => _CubeColorSchemeDialogState();
}

class _CubeColorSchemeDialogState extends State<_CubeColorSchemeDialog> {
  late CubeColorScheme _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialScheme;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('配置六面配色'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final face in CubeFace.values) _buildFaceRow(face)],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _draft = CubeColorScheme.standard;
          }),
          child: const Text('恢复默认'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_draft),
          child: const Text('应用'),
        ),
      ],
    );
  }

  Widget _buildFaceRow(CubeFace face) {
    final colorIdentity = _draft.colorIdentityFor(face);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              face.letter,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          CircleAvatar(
            key: ValueKey('scheme-swatch-${face.letter}'),
            radius: 10,
            backgroundColor: CubePalette.colorFor(colorIdentity),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<CubeFace>(
              key: ValueKey('scheme-face-${face.letter}'),
              value: colorIdentity,
              isExpanded: true,
              items: [
                for (final identity in CubeFace.values)
                  DropdownMenuItem(
                    value: identity,
                    child: Text(CubePalette.nameFor(identity)),
                  ),
              ],
              onChanged: (identity) {
                if (identity == null) return;
                setState(() {
                  _draft = _draft.swapColor(face, identity);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
