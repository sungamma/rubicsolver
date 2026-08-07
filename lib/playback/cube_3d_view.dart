import 'package:flutter/material.dart';

import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import '../cube/cube_state.dart';
import '../solver/solution_move.dart';

class Cube3DView extends StatefulWidget {
  const Cube3DView({
    super.key,
    required this.state,
    this.move,
    this.animationDuration = const Duration(milliseconds: 320),
  });

  final CubeState state;
  final SolutionMove? move;
  final Duration animationDuration;

  @override
  State<Cube3DView> createState() => _Cube3DViewState();
}

class _Cube3DViewState extends State<Cube3DView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CubeState _previousState;

  @override
  void initState() {
    super.initState();
    _previousState = widget.state;
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant Cube3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.animationDuration;
    if (oldWidget.state != widget.state) {
      _previousState = oldWidget.state;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = widget.move;
    final moveLabel = move == null
        ? '当前无旋转动作'
        : '当前动作${_positionName(move.face)} ${move.notation}';
    return Semantics(
      container: true,
      image: true,
      label: '三维魔方，$moveLabel',
      child: AspectRatio(
        aspectRatio: 1.2,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: const ValueKey('cube-3d-canvas'),
                  painter: Cube3DPainter(
                    previousState: _previousState,
                    state: widget.state,
                    animationValue: _controller.value,
                    activeFace: move?.face,
                    accentColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (move != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Text(
                            '正在执行 · ${move.notation}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _positionName(CubeFace face) {
    return switch (face) {
      CubeFace.up => '上面',
      CubeFace.right => '右面',
      CubeFace.front => '前面',
      CubeFace.down => '下面',
      CubeFace.left => '左面',
      CubeFace.back => '后面',
    };
  }
}

class Cube3DPainter extends CustomPainter {
  const Cube3DPainter({
    required this.previousState,
    required this.state,
    required this.animationValue,
    required this.activeFace,
    required this.accentColor,
  });

  final CubeState previousState;
  final CubeState state;
  final double animationValue;
  final CubeFace? activeFace;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final top = Offset(size.width * 0.5, size.height * 0.035);
    final rearRight = Offset(size.width * 0.93, size.height * 0.245);
    final center = Offset(size.width * 0.5, size.height * 0.455);
    final rearLeft = Offset(size.width * 0.07, size.height * 0.245);
    final frontLeft = Offset(size.width * 0.07, size.height * 0.73);
    final bottom = Offset(size.width * 0.5, size.height * 0.955);
    final frontRight = Offset(size.width * 0.93, size.height * 0.73);

    final silhouette = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(rearRight.dx, rearRight.dy)
      ..lineTo(frontRight.dx, frontRight.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(frontLeft.dx, frontLeft.dy)
      ..lineTo(rearLeft.dx, rearLeft.dy)
      ..close();
    canvas.drawShadow(silhouette, const Color(0xAA000000), 12, true);

    _drawFace(canvas, CubeFace.up, [top, rearRight, center, rearLeft]);
    _drawFace(canvas, CubeFace.front, [rearLeft, center, bottom, frontLeft]);
    _drawFace(canvas, CubeFace.right, [center, rearRight, frontRight, bottom]);
  }

  void _drawFace(Canvas canvas, CubeFace face, List<Offset> corners) {
    final facePath = _path(corners);
    canvas.drawPath(facePath, Paint()..color = const Color(0xFF111318));

    final easedAnimation = Curves.easeInOutCubic.transform(animationValue);
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final left = column / 3;
        final right = (column + 1) / 3;
        final top = row / 3;
        final bottom = (row + 1) / 3;
        final stickerCorners = [
          _bilinear(corners, left, top),
          _bilinear(corners, right, top),
          _bilinear(corners, right, bottom),
          _bilinear(corners, left, bottom),
        ];
        final insetCorners = _inset(stickerCorners, 0.075);
        final localIndex = row * 3 + column;
        final stickerIndex = face.startIndex + localIndex;
        final previousColor = CubePalette.colorFor(
          previousState.stickers[stickerIndex],
        );
        final currentColor = CubePalette.colorFor(state.stickers[stickerIndex]);
        canvas.drawPath(
          _path(insetCorners),
          Paint()
            ..color = Color.lerp(previousColor, currentColor, easedAnimation)!,
        );
      }
    }

    canvas.drawPath(
      facePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = activeFace == face ? 4 : 2
        ..color = activeFace == face ? accentColor : const Color(0xFF050608),
    );
  }

  Offset _bilinear(List<Offset> corners, double x, double y) {
    final top = Offset.lerp(corners[0], corners[1], x)!;
    final bottom = Offset.lerp(corners[3], corners[2], x)!;
    return Offset.lerp(top, bottom, y)!;
  }

  List<Offset> _inset(List<Offset> corners, double fraction) {
    final center = corners.reduce((first, second) => first + second) / 4;
    return [
      for (final corner in corners) Offset.lerp(corner, center, fraction)!,
    ];
  }

  Path _path(List<Offset> corners) {
    return Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant Cube3DPainter oldDelegate) {
    return oldDelegate.previousState != previousState ||
        oldDelegate.state != state ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.activeFace != activeFace ||
        oldDelegate.accentColor != accentColor;
  }
}
