import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../cube/cube_face.dart';
import '../cube/cube_palette.dart';
import '../cube/cube_state.dart';
import '../solver/solution_move.dart';

/// Standard view angles, in radians. They are public so widget tests and
/// callers can use the same reset target as the painter.
const double defaultCubeYaw = -0.62;
const double defaultCubePitch = 0.48;

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
  var _yaw = defaultCubeYaw;
  var _pitch = defaultCubePitch;

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

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _yaw += details.delta.dx * 0.012;
      _pitch = (_pitch - details.delta.dy * 0.012)
          .clamp(-1.15, 1.15)
          .toDouble();
    });
  }

  void _resetView() {
    setState(() {
      _yaw = defaultCubeYaw;
      _pitch = defaultCubePitch;
    });
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
      label: '三维魔方，$moveLabel；可拖动查看，支持复位标准视角',
      child: AspectRatio(
        aspectRatio: 1.2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: _handlePanUpdate,
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
                      signedQuarterTurns: move?.signedQuarterTurns ?? 1,
                      accentColor: Theme.of(context).colorScheme.primary,
                      yaw: _yaw,
                      pitch: _pitch,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: const ValueKey('reset-cube-view'),
                        tooltip: '复位标准视角',
                        onPressed: _resetView,
                        icon: const Icon(Icons.threesixty),
                      ),
                    ),
                  ),
                  if (move != null) _TurnIndicator(move: move),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 6,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          child: Text(
                            '拖动查看 · 点击左上角复位',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
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

class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({required this.move});

  final SolutionMove move;

  @override
  Widget build(BuildContext context) {
    final (icon, keyName, label) = switch (move.notation) {
      final notation when notation.endsWith('2') => (
        Icons.sync,
        'turn-arrow-half-turn',
        '转 180°',
      ),
      final notation when notation.endsWith("'") => (
        Icons.rotate_left,
        'turn-arrow-counter-clockwise',
        '逆时针 90°',
      ),
      _ => (Icons.rotate_right, 'turn-arrow-clockwise', '顺时针 90°'),
    };
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 58,
      right: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(key: ValueKey(keyName), icon, color: scheme.primary),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class Cube3DPainter extends CustomPainter {
  const Cube3DPainter({
    required this.previousState,
    required this.state,
    required this.animationValue,
    required this.activeFace,
    required this.accentColor,
    this.signedQuarterTurns = 1,
    this.yaw = defaultCubeYaw,
    this.pitch = defaultCubePitch,
  });

  final CubeState previousState;
  final CubeState state;
  final double animationValue;
  final CubeFace? activeFace;
  final Color accentColor;
  final int signedQuarterTurns;
  final double yaw;
  final double pitch;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= 0) {
      return;
    }

    final progress = animationValue.clamp(0.0, 1.0).toDouble();
    final eased = Curves.easeInOutCubic.transform(progress);
    final basisByFace = {
      for (final face in CubeFace.values) face: _faceBasis(face),
    };

    _drawCubeBody(canvas, size, basisByFace);

    final stickers = <_ProjectedSticker>[];
    for (final face in CubeFace.values) {
      final basis = basisByFace[face]!;
      for (var row = 0; row < 3; row++) {
        for (var column = 0; column < 3; column++) {
          final index = face.startIndex + row * 3 + column;
          final geometry = _stickerGeometry(face, row, column, basis);
          final inActiveLayer =
              activeFace != null &&
              _isInActiveLayer(geometry.center, basisByFace[activeFace!]!);
          final transformed = inActiveLayer && activeFace != null
              ? _rotateSticker(
                  geometry,
                  basisByFace[activeFace!]!.normal,
                  -signedQuarterTurns * math.pi / 2 * eased,
                )
              : geometry;
          final targetIndex = inActiveLayer && activeFace != null
              ? _indexForGeometry(
                  _rotateSticker(
                    geometry,
                    basisByFace[activeFace!]!.normal,
                    -signedQuarterTurns * math.pi / 2,
                  ),
                  basisByFace,
                )
              : index;
          final previousColor = CubePalette.colorFor(
            previousState.stickers[index],
          );
          final currentColor = CubePalette.colorFor(
            state.stickers[targetIndex],
          );
          final color = activeFace == null
              ? currentColor
              : Color.lerp(previousColor, currentColor, eased)!;
          final projectedCorners = [
            for (final corner in _stickerCorners(transformed))
              _project(corner, size),
          ];
          final depth = _averageDepth(_stickerCorners(transformed));
          stickers.add(
            _ProjectedSticker(
              corners: _inset2D(projectedCorners, 0.075),
              depth: depth,
              color: color,
              highlighted: inActiveLayer,
            ),
          );
        }
      }
    }

    stickers.sort((left, right) => left.depth.compareTo(right.depth));
    for (final sticker in stickers) {
      final path = _path(sticker.corners);
      canvas.drawPath(path, Paint()..color = sticker.color);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sticker.highlighted ? 2.2 : 1.0
          ..strokeJoin = StrokeJoin.round
          ..color = sticker.highlighted ? accentColor : const Color(0xFF090A0D),
      );
    }
  }

  void _drawCubeBody(
    Canvas canvas,
    Size size,
    Map<CubeFace, _FaceBasis> basisByFace,
  ) {
    final bodyFaces = <_ProjectedBodyFace>[];
    for (final face in CubeFace.values) {
      final basis = basisByFace[face]!;
      final center = basis.normal * 1.0;
      final corners = [
        center - basis.u * 1.03 - basis.v * 1.03,
        center + basis.u * 1.03 - basis.v * 1.03,
        center + basis.u * 1.03 + basis.v * 1.03,
        center - basis.u * 1.03 + basis.v * 1.03,
      ];
      bodyFaces.add(
        _ProjectedBodyFace(
          corners: [for (final corner in corners) _project(corner, size)],
          depth: _averageDepth(corners),
        ),
      );
    }
    bodyFaces.sort((left, right) => left.depth.compareTo(right.depth));
    for (final face in bodyFaces) {
      final path = _path(face.corners);
      canvas.drawPath(path, Paint()..color = const Color(0xFF111318));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF050608),
      );
    }
  }

  _StickerGeometry _stickerGeometry(
    CubeFace face,
    int row,
    int column,
    _FaceBasis basis,
  ) {
    const cell = 2 / 3;
    final center =
        basis.normal * 1.025 +
        basis.u * ((column - 1) * cell) +
        basis.v * ((row - 1) * cell);
    return _StickerGeometry(
      center: center,
      normal: basis.normal,
      u: basis.u,
      v: basis.v,
    );
  }

  List<_Vec3> _stickerCorners(_StickerGeometry geometry) {
    const half = (2 / 3) * 0.46;
    return [
      geometry.center - geometry.u * half - geometry.v * half,
      geometry.center + geometry.u * half - geometry.v * half,
      geometry.center + geometry.u * half + geometry.v * half,
      geometry.center - geometry.u * half + geometry.v * half,
    ];
  }

  _StickerGeometry _rotateSticker(
    _StickerGeometry geometry,
    _Vec3 axis,
    double angle,
  ) {
    return _StickerGeometry(
      center: _rotateVector(geometry.center, axis, angle),
      normal: _rotateVector(geometry.normal, axis, angle),
      u: _rotateVector(geometry.u, axis, angle),
      v: _rotateVector(geometry.v, axis, angle),
    );
  }

  int _indexForGeometry(
    _StickerGeometry geometry,
    Map<CubeFace, _FaceBasis> basisByFace,
  ) {
    CubeFace? closestFace;
    var closestDot = -double.infinity;
    for (final entry in basisByFace.entries) {
      final dot = geometry.normal.dot(entry.value.normal);
      if (dot > closestDot) {
        closestDot = dot;
        closestFace = entry.key;
      }
    }
    if (closestFace == null || closestDot < 0.65) {
      return 0;
    }
    final basis = basisByFace[closestFace]!;
    final column = ((geometry.center.dot(basis.u) / (2 / 3)) + 1).round();
    final row = ((geometry.center.dot(basis.v) / (2 / 3)) + 1).round();
    if (row < 0 || row > 2 || column < 0 || column > 2) {
      return closestFace.startIndex + 4;
    }
    return closestFace.startIndex + row * 3 + column;
  }

  bool _isInActiveLayer(_Vec3 center, _FaceBasis activeBasis) {
    return center.dot(activeBasis.normal) > 0.45;
  }

  _Vec3 _viewTransform(_Vec3 point) {
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final yawX = point.x * cosYaw + point.z * sinYaw;
    final yawZ = -point.x * sinYaw + point.z * cosYaw;
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    return _Vec3(
      yawX,
      point.y * cosPitch - yawZ * sinPitch,
      point.y * sinPitch + yawZ * cosPitch,
    );
  }

  Offset _project(_Vec3 point, Size size) {
    final view = _viewTransform(point);
    final perspective = 1 / (1 - view.z * 0.12);
    final scale = size.shortestSide * 0.37;
    return Offset(
      size.width / 2 + view.x * scale * perspective,
      size.height / 2 - view.y * scale * perspective,
    );
  }

  double _averageDepth(List<_Vec3> points) {
    var total = 0.0;
    for (final point in points) {
      total += _viewTransform(point).z;
    }
    return total / points.length;
  }

  _FaceBasis _faceBasis(CubeFace face) {
    return switch (face) {
      CubeFace.up => const _FaceBasis(
        normal: _Vec3(0, 1, 0),
        u: _Vec3(1, 0, 0),
        v: _Vec3(0, 0, 1),
      ),
      CubeFace.right => const _FaceBasis(
        normal: _Vec3(1, 0, 0),
        u: _Vec3(0, 0, -1),
        v: _Vec3(0, -1, 0),
      ),
      CubeFace.front => const _FaceBasis(
        normal: _Vec3(0, 0, 1),
        u: _Vec3(1, 0, 0),
        v: _Vec3(0, -1, 0),
      ),
      CubeFace.down => const _FaceBasis(
        normal: _Vec3(0, -1, 0),
        u: _Vec3(1, 0, 0),
        v: _Vec3(0, 0, -1),
      ),
      CubeFace.left => const _FaceBasis(
        normal: _Vec3(-1, 0, 0),
        u: _Vec3(0, 0, 1),
        v: _Vec3(0, -1, 0),
      ),
      CubeFace.back => const _FaceBasis(
        normal: _Vec3(0, 0, -1),
        u: _Vec3(-1, 0, 0),
        v: _Vec3(0, -1, 0),
      ),
    };
  }

  _Vec3 _rotateVector(_Vec3 vector, _Vec3 axis, double angle) {
    final normalizedAxis = axis.normalized;
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    return vector * cosine +
        normalizedAxis.cross(vector) * sine +
        normalizedAxis * (normalizedAxis.dot(vector) * (1 - cosine));
  }

  List<Offset> _inset2D(List<Offset> corners, double fraction) {
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
        oldDelegate.signedQuarterTurns != signedQuarterTurns ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch;
  }
}

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _Vec3 operator +(_Vec3 other) => _Vec3(x + other.x, y + other.y, z + other.z);
  _Vec3 operator -(_Vec3 other) => _Vec3(x - other.x, y - other.y, z - other.z);
  _Vec3 operator *(double scalar) => _Vec3(x * scalar, y * scalar, z * scalar);

  double dot(_Vec3 other) => x * other.x + y * other.y + z * other.z;

  _Vec3 cross(_Vec3 other) => _Vec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  _Vec3 get normalized {
    final length = math.sqrt(dot(this));
    return length == 0 ? const _Vec3(0, 0, 0) : this * (1 / length);
  }
}

class _FaceBasis {
  const _FaceBasis({required this.normal, required this.u, required this.v});

  final _Vec3 normal;
  final _Vec3 u;
  final _Vec3 v;
}

class _StickerGeometry {
  const _StickerGeometry({
    required this.center,
    required this.normal,
    required this.u,
    required this.v,
  });

  final _Vec3 center;
  final _Vec3 normal;
  final _Vec3 u;
  final _Vec3 v;
}

class _ProjectedSticker {
  const _ProjectedSticker({
    required this.corners,
    required this.depth,
    required this.color,
    required this.highlighted,
  });

  final List<Offset> corners;
  final double depth;
  final Color color;
  final bool highlighted;
}

class _ProjectedBodyFace {
  const _ProjectedBodyFace({required this.corners, required this.depth});

  final List<Offset> corners;
  final double depth;
}
