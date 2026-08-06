import 'cube_face.dart';

class CubeState {
  CubeState._(this._stickers);

  factory CubeState(List<CubeFace> stickers) {
    if (stickers.length != 54) {
      throw ArgumentError.value(stickers.length, 'stickers.length', '必须为 54');
    }

    final copy = List<CubeFace>.unmodifiable(stickers);
    for (final face in CubeFace.values) {
      if (copy[face.centerIndex] != face) {
        throw ArgumentError('六个中心贴纸必须与 URFDLB 面定义一致');
      }
    }
    return CubeState._(copy);
  }

  factory CubeState.solved() {
    return CubeState([
      for (final face in CubeFace.values)
        for (var index = 0; index < 9; index++) face,
    ]);
  }

  factory CubeState.fromFacelets(String facelets) {
    if (facelets.length != 54) {
      throw const FormatException('魔方状态必须包含 54 个贴纸标记');
    }

    try {
      return CubeState([
        for (final letter in facelets.split('')) CubeFace.fromLetter(letter),
      ]);
    } on ArgumentError catch (error) {
      throw FormatException(error.message?.toString() ?? '中心贴纸定义无效');
    }
  }

  final List<CubeFace> _stickers;

  List<CubeFace> get stickers => _stickers;

  String toFacelets() => _stickers.map((face) => face.letter).join();

  CubeState replaceSticker(int index, CubeFace face) {
    RangeError.checkValidIndex(index, _stickers, 'index');
    if (isCenterIndex(index)) {
      throw ArgumentError.value(index, 'index', '中心贴纸不可编辑');
    }

    final updated = _stickers.toList();
    updated[index] = face;
    return CubeState(updated);
  }

  Map<CubeFace, int> countByFace() {
    final counts = {for (final face in CubeFace.values) face: 0};
    for (final sticker in _stickers) {
      counts[sticker] = counts[sticker]! + 1;
    }
    return Map.unmodifiable(counts);
  }

  List<CubeFace> stickersFor(CubeFace face) {
    return List.unmodifiable(
      _stickers.sublist(face.startIndex, face.startIndex + 9),
    );
  }

  bool isCenterIndex(int index) => index >= 0 && index < 54 && index % 9 == 4;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! CubeState || other._stickers.length != _stickers.length) {
      return false;
    }
    for (var index = 0; index < _stickers.length; index++) {
      if (other._stickers[index] != _stickers[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_stickers);
}
