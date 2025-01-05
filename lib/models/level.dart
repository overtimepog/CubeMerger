class Level {
  final int number;
  final int gridSize;

  Level({
    required this.number,
    this.gridSize = 5,
  });

  Level copyWith({
    int? number,
    int? gridSize,
  }) {
    return Level(
      number: number ?? this.number,
      gridSize: gridSize ?? this.gridSize,
    );
  }

  int getNumObstacles() {
    return (number ~/ 5) + 1;
  }

  int getNumCubePairs() {
    return (number ~/ 3) + 2;
  }

  List<int> getPossibleValues() {
    List<int> values = [2, 4];
    if (number > 10) values.add(8);
    if (number > 20) values.add(16);
    if (number > 30) values.add(32);
    return values;
  }
}
