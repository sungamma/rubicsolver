import 'package:flutter/material.dart';

import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import '../cube/cube_state.dart';

class CubeNet extends StatelessWidget {
  const CubeNet({
    super.key,
    required this.state,
    this.onStickerTap,
    this.highlightedStickerIndices = const [],
  });

  final CubeState state;
  final ValueChanged<int>? onStickerTap;
  final Iterable<int> highlightedStickerIndices;

  @override
  Widget build(BuildContext context) {
    final highlighted = highlightedStickerIndices.toSet();
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const Spacer(),
                Expanded(
                  child: _FaceGrid(
                    face: CubeFace.up,
                    state: state,
                    highlightedIndices: highlighted,
                    onStickerTap: onStickerTap,
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                for (final face in const [
                  CubeFace.left,
                  CubeFace.front,
                  CubeFace.right,
                  CubeFace.back,
                ])
                  Expanded(
                    child: _FaceGrid(
                      face: face,
                      state: state,
                      highlightedIndices: highlighted,
                      onStickerTap: onStickerTap,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Spacer(),
                Expanded(
                  child: _FaceGrid(
                    face: CubeFace.down,
                    state: state,
                    highlightedIndices: highlighted,
                    onStickerTap: onStickerTap,
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceGrid extends StatelessWidget {
  const _FaceGrid({
    required this.face,
    required this.state,
    required this.highlightedIndices,
    required this.onStickerTap,
  });

  final CubeFace face;
  final CubeState state;
  final Set<int> highlightedIndices;
  final ValueChanged<int>? onStickerTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 9,
      itemBuilder: (context, localIndex) {
        final stickerIndex = face.startIndex + localIndex;
        final stickerFace = state.stickers[stickerIndex];
        final isCenter = localIndex == 4;
        final borderColor = highlightedIndices.contains(stickerIndex)
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.outline;

        return Material(
          key: ValueKey('sticker-$stickerIndex'),
          color: CubePalette.colorFor(stickerFace),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: borderColor,
              width: highlightedIndices.contains(stickerIndex) ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onStickerTap == null
                ? null
                : () => onStickerTap!(stickerIndex),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isCenter)
                  Icon(
                    Icons.lock_outline,
                    size: 15,
                    color: CubePalette.foregroundFor(stickerFace),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
