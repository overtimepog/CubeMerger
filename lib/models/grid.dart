import 'dart:math';
import 'cube.dart';

class Grid {
  final int size;
  final List<List<Cube>> cells;
  final bool isAnimating;

  const Grid({
    required this.size,
    required this.cells,
    this.isAnimating = false,
  });

  factory Grid.empty(int size) {
    return Grid(
      size: size,
      cells: List.generate(
        size,
        (row) => List.generate(
          size,
          (col) => const Cube(),
        ),
      ),
    );
  }

  Grid copyWith({
    int? size,
    List<List<Cube>>? cells,
    bool? isAnimating,
  }) {
    return Grid(
      size: size ?? this.size,
      cells: cells ?? this.cells,
      isAnimating: isAnimating ?? this.isAnimating,
    );
  }

  bool get isFull {
    for (var row in cells) {
      for (var cube in row) {
        if (cube.isEmpty) return false;
      }
    }
    return true;
  }

  int get remainingCubes {
    int count = 0;
    for (var row in cells) {
      for (var cube in row) {
        if (cube.value != null) count++;
      }
    }
    return count;
  }

  bool get hasWon => remainingCubes == 1;

  Grid updateCube(int row, int col, Cube Function(Cube) update) {
    final newCells = List<List<Cube>>.from(
      cells.map((row) => List<Cube>.from(row)),
    );
    newCells[row][col] = update(cells[row][col]);
    return copyWith(cells: newCells);
  }

  Grid updateAllCubes(Cube Function(Cube, int, int) update) {
    final newCells = List<List<Cube>>.generate(
      size,
      (row) => List<Cube>.generate(
        size,
        (col) => update(cells[row][col], row, col),
      ),
    );
    return copyWith(cells: newCells);
  }

  bool isValidPosition(int row, int col) {
    return row >= 0 && row < size && col >= 0 && col < size;
  }

  bool canMove(String direction) {
    for (int i = 0; i < size; i++) {
      var line = getLine(i, direction);
      var compressed = compressLine(line);
      if (!listEquals(line, compressed)) return true;
    }
    return false;
  }

  List<Cube> getLine(int index, String direction) {
    switch (direction) {
      case "left":
      case "right":
        var line = cells[index];
        return direction == "right" ? line.reversed.toList() : line;
      case "up":
      case "down":
        var line = List<Cube>.generate(size, (i) => cells[i][index]);
        return direction == "down" ? line.reversed.toList() : line;
      default:
        return [];
    }
  }

  List<Cube> compressLine(List<Cube> line) {
    var result = List<Cube>.filled(size, const Cube());
    int fillIndex = 0;

    for (int i = 0; i < line.length; i++) {
      if (line[i].isObstacle) {
        result[i] = line[i];
        fillIndex = i + 1;
      } else if (line[i].value != null) {
        if (fillIndex >= line.length) {
          result[i] = line[i];
        } else {
          result[fillIndex] = line[i];
          fillIndex++;
        }
      }
    }

    return result;
  }
}

bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
