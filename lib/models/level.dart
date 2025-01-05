class Level {
  final int number;
  final int gridSize;

  Level({
    required this.number,
    int? gridSize,
  }) : gridSize = gridSize ?? _calculateGridSize(number);

  Level copyWith({
    int? number,
    int? gridSize,
  }) {
    return Level(
      number: number ?? this.number,
      gridSize: gridSize ?? this.gridSize,
    );
  }

  static int _calculateGridSize(int level) {
    if (level >= 15) return 10; // Larger grid for higher levels
    if (level >= 5) return 7; // 7x7 grid starting at level 5
    return 5; // Starting grid size
  }

  List<int> getPossibleValues() {
    List<int> values = [];

    // For level 1-2, only use 2s
    if (number <= 2) {
      return List.filled(4, 2);
    }

    // For level 3-4, use 2s and 4s
    if (number <= 4) {
      values.addAll(List.filled(3, 2));
      values.add(4);
      return values;
    }

    // For level 5-7, use more 4s and introduce 8s
    if (number <= 7) {
      values.addAll(List.filled(2, 2));
      values.addAll(List.filled(2, 4));
      values.add(8);
      return values;
    }

    // For level 8-12, reduce 2s, more high numbers
    if (number <= 12) {
      values.add(2);
      values.addAll(List.filled(2, 4));
      values.addAll(List.filled(2, 8));
      return values;
    }

    // For higher levels, use higher numbers more frequently
    values.add(2); // Keep one 2 for balance
    values.add(4);
    values.addAll(List.filled(2, 8));
    if (number > 15) values.add(16);

    return values;
  }

  int getNumObstacles() {
    if (number <= 1) return 0;
    if (number <= 4) return min(1 + (number ~/ 2), gridSize - 1);
    if (number <= 8) return min(2 + (number ~/ 2), gridSize - 1);
    return min(3 + (number ~/ 3), gridSize - 1);
  }

  int getNumCubePairs() {
    if (number <= 3) return 2;
    if (number <= 6) return 3;
    if (number <= 10) return 4;
    return min(5 + (number ~/ 5), 8); // More cubes in higher levels
  }
}

int min(int a, int b) => a < b ? a : b;
