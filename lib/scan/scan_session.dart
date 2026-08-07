import '../cube/cube_face.dart';
import 'color_classifier.dart';
import 'sticker_sample.dart';

final class ScanSession {
  ScanSession({ColorClassifier classifier = const ColorClassifier()})
    : _classifier = classifier;

  final ColorClassifier _classifier;
  final Map<CubeFace, List<StickerSample>> _samplesByFace = {};
  final Map<CubeFace, Map<int, CubeFace>> _lockedFacesByFace = {};

  CubeFace? get currentFace =>
      isComplete ? null : CubeFace.values[_samplesByFace.length];

  int get completedFaceCount => _samplesByFace.length;

  double get progress => completedFaceCount / CubeFace.values.length;

  bool get isComplete => completedFaceCount == CubeFace.values.length;

  Map<CubeFace, List<StickerSample>> get samplesByFace =>
      Map.unmodifiable(_samplesByFace);

  Map<CubeFace, Map<int, CubeFace>> get lockedFacesByFace =>
      Map<CubeFace, Map<int, CubeFace>>.unmodifiable({
        for (final entry in _lockedFacesByFace.entries)
          entry.key: Map<int, CubeFace>.unmodifiable(entry.value),
      });

  void acceptCurrent(
    List<StickerSample> samples, {
    Map<int, CubeFace> lockedFaces = const {},
  }) {
    final face = currentFace;
    if (face == null) {
      throw StateError('六个面均已采集完成');
    }
    if (samples.length != 9) {
      throw ArgumentError.value(samples.length, 'samples.length', '必须为 9');
    }
    for (final index in lockedFaces.keys) {
      if (index < 0 || index >= 9) {
        throw ArgumentError.value(index, 'lockedFaces', '索引必须为 0 到 8');
      }
    }

    _samplesByFace[face] = List.unmodifiable(samples);
    _lockedFacesByFace[face] = Map.unmodifiable({...lockedFaces, 4: face});
  }

  void restartFrom(CubeFace face) {
    if (face.index > completedFaceCount) {
      throw ArgumentError.value(face, 'face', '该面尚未采集');
    }

    _samplesByFace.removeWhere(
      (capturedFace, _) => capturedFace.index >= face.index,
    );
    _lockedFacesByFace.removeWhere(
      (capturedFace, _) => capturedFace.index >= face.index,
    );
  }

  ColorClassificationResult classify() {
    if (!isComplete) {
      throw StateError('请先完成六个面的采集');
    }
    return _classifier.classify(
      samplesByFace: _samplesByFace,
      lockedFacesByFace: _lockedFacesByFace,
    );
  }
}
