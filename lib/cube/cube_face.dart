enum CubeFace {
  up('U'),
  right('R'),
  front('F'),
  down('D'),
  left('L'),
  back('B');

  const CubeFace(this.letter);

  final String letter;

  int get startIndex => index * 9;

  int get centerIndex => startIndex + 4;

  static CubeFace fromLetter(String letter) {
    final normalized = letter.toUpperCase();
    for (final face in values) {
      if (face.letter == normalized) {
        return face;
      }
    }
    throw FormatException('不支持的魔方面标记：$letter');
  }
}
