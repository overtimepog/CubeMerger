import 'cube.dart';

class Grid {
  final List<List<Cube>> cells;
  final int size;
  final bool isAnimating;

  const Grid({
    required this.cells,
    required this.size,
    this.isAnimating = false,
  });

  factory Grid.empty(int size) {
    return Grid(
      cells: List.generate(
        size,
        (i) => List.generate(
          size,
          (j) => const Cube(),
        ),
      ),
      size: size,
    );
  }

  Grid copyWith({
    List<List<Cube>>? cells,
    bool? isAnimating,
  }) {
    return Grid(
      cells: cells ?? this.cells,
      size: size,
      isAnimating: isAnimating ?? this.isAnimating,
    );
  }

  List<Cube> getLine(int index, String direction) {
    switch (direction) {
      case "left":
      case "right":
        return cells[index];
      case "up":
      case "down":
        return List.generate(size, (i) => cells[i][index]);
      default:
        throw ArgumentError("Invalid direction: $direction");
    }
  }

  int get remainingCubes {
    int count = 0;
    for (var row in cells) {
      for (var cube in row) {
        if (cube.value != null && !cube.isOutOfShape) count++;
      }
    }
    return count;
  }

  bool get hasWon => remainingCubes <= 1;

  Grid updateCube(int row, int col, Cube Function(Cube) update) {
    final newCells = List<List<Cube>>.from(
      cells.map((row) => List<Cube>.from(row)),
    );
    newCells[row][col] = update(cells[row][col]);
    return copyWith(cells: newCells);
  }

  bool isValidPosition(int row, int col) {
    return row >= 0 &&
        row < size &&
        col >= 0 &&
        col < size &&
        !cells[row][col].isObstacle &&
        !cells[row][col].isOutOfShape;
  }

  bool canConnect(int row1, int col1, int row2, int col2) {
    // Check if in same row
    if (row1 == row2) {
      int start = col1 < col2 ? col1 : col2;
      int end = col1 < col2 ? col2 : col1;
      for (int col = start + 1; col < end; col++) {
        if (cells[row1][col].isObstacle ||
            cells[row1][col].isOutOfShape ||
            cells[row1][col].value != null) {
          return false;
        }
      }
      return true;
    }
    // Check if in same column
    if (col1 == col2) {
      int start = row1 < row2 ? row1 : row2;
      int end = row1 < row2 ? row2 : row1;
      for (int row = start + 1; row < end; row++) {
        if (cells[row][col1].isObstacle ||
            cells[row][col1].isOutOfShape ||
            cells[row][col1].value != null) {
          return false;
        }
      }
      return true;
    }
    return false;
  }
}
