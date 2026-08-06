import '../cube/cube_face.dart';
import 'color_classifier.dart';
import 'sticker_sample.dart';

final class ScanSession {
  ScanSession({ColorClassifier classifier = const ColorClassifier()})
    : _classifier = classifier;

  final ColorClassifier _classifier;
  final Map<CubeFace, List<StickerSample>> _samplesByFace = {};

  CubeFace? get currentFace =>
      isComplete ? null : CubeFace.values[_samplesByFace.length];

  int get completedFaceCount => _samplesByFace.length;

  double get progress => completedFaceCount / CubeFace.values.length;

  bool get isComplete => completedFaceCount == CubeFace.values.length;

  Map<CubeFace, List<StickerSample>> get samplesByFace =>
      Map.unmodifiable(_samplesByFace);

  void acceptCurrent(List<StickerSample> samples) {
    final face = currentFace;
    if (face == null) {
      throw StateError('六个面均已采集完成');
    }
    if (samples.length != 9) {
      throw ArgumentError.value(samples.length, 'samples.length', '必须为 9');
    }

    _samplesByFace[face] = List.unmodifiable(samples);
  }

  void restartFrom(CubeFace face) {
    if (face.index > completedFaceCount) {
      throw ArgumentError.value(face, 'face', '该面尚未采集');
    }

    _samplesByFace.removeWhere(
      (capturedFace, _) => capturedFace.index >= face.index,
    );
  }

  ColorClassificationResult classify() {
    if (!isComplete) {
      throw StateError('请先完成六个面的采集');
    }
    return _classifier.classify(samplesByFace: _samplesByFace);
  }
}
