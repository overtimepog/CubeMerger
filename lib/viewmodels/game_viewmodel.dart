import 'dart:math';
import 'package:flutter/material.dart';
import '../models/cube.dart';
import '../models/grid.dart';
import '../models/level.dart';
import 'dart:collection';

class GameViewModel extends ChangeNotifier {
  Level _level;
  Grid _grid;
  final AnimationController animationController;
  final Random _random = Random();
  List<Map<String, dynamic>> _mergeQueue = [];

  GameViewModel({
    required AnimationController controller,
    Level? initialLevel,
  })  : _level = initialLevel ?? Level(number: 1),
        _grid = Grid.empty(_calculateGridSize(1)),
        animationController = controller {
    _initializeLevel();

    animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationComplete();
      }
    });
  }

  // Getters
  Level get level => _level;
  Grid get grid => _grid;
  bool get isAnimating => _grid.isAnimating;
  int get remainingCubes => _grid.remainingCubes;
  bool get hasWon => _grid.hasWon;

  static int _calculateGridSize(int level) {
    if (level >= 100) return 10;
    if (level >= 25) return 7;
    return 5;
  }

  void _initializeLevel() {
    final size = _calculateGridSize(_level.number);
    _grid = Grid.empty(size);
    _generateSolvableLevel();
    notifyListeners();
  }

  void _initializeGrid() {
    _grid = Grid.empty(_grid.size);
  }

  void _generateSolvableLevel() {
    int maxAttempts = 10;
    int attempts = 0;
    bool levelGenerated = false;

    while (!levelGenerated && attempts < maxAttempts) {
      _initializeGrid();
      _placeObstacles();
      _placeCubes();

      if (_isLevelSolvable()) {
        levelGenerated = true;
      } else {
        attempts++;
      }
    }

    // If we couldn't generate a solvable level, try with fewer obstacles or cube pairs
    if (!levelGenerated) {
      _level =
          _level.copyWith(gridSize: _level.gridSize, number: _level.number);
      _generateSimplifiedLevel();
    }

    notifyListeners();
  }

  void _generateSimplifiedLevel() {
    bool levelGenerated = false;
    int obstacleReduction = 1;
    int maxReductions = 3;

    while (!levelGenerated && obstacleReduction <= maxReductions) {
      _initializeGrid();
      // Place fewer obstacles
      _placeObstacles(reduction: obstacleReduction);
      // Place fewer cube pairs
      _placeCubes(reduction: obstacleReduction);

      if (_isLevelSolvable()) {
        levelGenerated = true;
      } else {
        obstacleReduction++;
      }
    }

    // If still not solvable, create a very simple level
    if (!levelGenerated) {
      _createFallbackLevel();
    }

    notifyListeners();
  }

  void _placeObstacles({int reduction = 0}) {
    int numObstacles = max(0, _level.getNumObstacles() - reduction);
    List<Point<int>> availablePositions = _getAvailablePositions();

    for (int i = 0; i < numObstacles && availablePositions.isNotEmpty; i++) {
      int randomIndex = _random.nextInt(availablePositions.length);
      Point<int> position = availablePositions[randomIndex];
      _grid = _grid.updateCube(
          position.x, position.y, (cube) => const Cube(isObstacle: true));
      availablePositions.removeAt(randomIndex);
    }
  }

  void _placeCubes({int reduction = 0}) {
    int numPairs = max(1, _level.getNumCubePairs() - reduction);
    List<Point<int>> availablePositions = _getAvailablePositions();
    List<int> possibleValues = _level.getPossibleValues();

    for (int i = 0; i < numPairs && availablePositions.length >= 2; i++) {
      int value = possibleValues[_random.nextInt(possibleValues.length)];

      // Place pair of cubes
      for (int j = 0; j < 2; j++) {
        int randomIndex = _random.nextInt(availablePositions.length);
        Point<int> position = availablePositions[randomIndex];
        _grid = _grid.updateCube(
            position.x, position.y, (cube) => Cube(value: value));
        availablePositions.removeAt(randomIndex);
      }
    }
  }

  void _createFallbackLevel() {
    _initializeGrid();
    // Place just two 2s next to each other for guaranteed solvability
    _grid = _grid.updateCube(0, 0, (cube) => const Cube(value: 2));
    _grid = _grid.updateCube(0, 1, (cube) => const Cube(value: 2));
    notifyListeners();
  }

  List<Point<int>> _getAvailablePositions() {
    List<Point<int>> positions = [];
    for (int i = 0; i < _grid.size; i++) {
      for (int j = 0; j < _grid.size; j++) {
        if (!_grid.cells[i][j].isObstacle && _grid.cells[i][j].value == null) {
          positions.add(Point(i, j));
        }
      }
    }
    return positions;
  }

  bool _isLevelSolvable() {
    // First check: Total value should be a power of 2
    int totalValue = 0;
    Map<int, int> valueCounts = {};

    for (var row in _grid.cells) {
      for (var cube in row) {
        if (cube.value != null) {
          totalValue += cube.value!;
          valueCounts[cube.value!] = (valueCounts[cube.value!] ?? 0) + 1;
        }
      }
    }

    if (!_isPowerOfTwo(totalValue)) return false;

    // Second check: Each value should appear in pairs (except possibly the highest value)
    int maxValue = valueCounts.keys.reduce(max);
    for (var entry in valueCounts.entries) {
      if (entry.key != maxValue && entry.value % 2 != 0) return false;
    }

    // Third check: Verify that cubes can reach their pairs
    List<Point<int>> cubePositions = [];
    for (int r = 0; r < _grid.size; r++) {
      for (int c = 0; c < _grid.size; c++) {
        if (_grid.cells[r][c].value != null) {
          cubePositions.add(Point(r, c));
        }
      }
    }

    // Group cubes by value
    Map<int, List<Point<int>>> cubeGroups = {};
    for (var pos in cubePositions) {
      int value = _grid.cells[pos.x][pos.y].value!;
      cubeGroups[value] = (cubeGroups[value] ?? [])..add(pos);
    }

    // Check if each group can be merged
    for (var group in cubeGroups.values) {
      if (!_canGroupBeMerged(group)) return false;
    }

    return true;
  }

  bool _canGroupBeMerged(List<Point<int>> positions) {
    if (positions.length <= 1) return true;

    // Try to find at least one mergeable pair
    bool foundMergeablePair = false;
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        if (_hasPathBetween(positions[i], positions[j])) {
          foundMergeablePair = true;
          // Create new group without the merged pair
          var remainingPositions = positions.toList()
            ..removeAt(j)
            ..removeAt(i);
          // Recursively check if remaining cubes can be merged
          if (_canGroupBeMerged(remainingPositions)) {
            return true;
          }
        }
      }
    }

    return positions.isEmpty;
  }

  bool _hasPathBetween(Point<int> start, Point<int> end) {
    // Check direct paths first
    if (_hasDirectPath(start, end)) return true;

    // If no direct path, check for indirect paths through empty cells
    return _hasIndirectPath(start, end);
  }

  bool _hasDirectPath(Point<int> start, Point<int> end) {
    bool horizontalPath = true;
    bool verticalPath = true;

    // Check horizontal path
    if (start.y == end.y) {
      int minX = min(start.x, end.x);
      int maxX = max(start.x, end.x);
      for (int x = minX + 1; x < maxX; x++) {
        if (_grid.cells[x][start.y].isObstacle ||
            _grid.cells[x][start.y].value != null) {
          horizontalPath = false;
          break;
        }
      }
    } else {
      horizontalPath = false;
    }

    // Check vertical path
    if (start.x == end.x) {
      int minY = min(start.y, end.y);
      int maxY = max(start.y, end.y);
      for (int y = minY + 1; y < maxY; y++) {
        if (_grid.cells[start.x][y].isObstacle ||
            _grid.cells[start.x][y].value != null) {
          verticalPath = false;
          break;
        }
      }
    } else {
      verticalPath = false;
    }

    return horizontalPath || verticalPath;
  }

  bool _hasIndirectPath(Point<int> start, Point<int> end) {
    // Simple BFS to find any path between start and end
    Set<String> visited = {};
    Queue<Point<int>> queue = Queue();
    queue.add(start);
    visited.add('${start.x},${start.y}');

    while (queue.isNotEmpty) {
      var current = queue.removeFirst();
      if (current.x == end.x && current.y == end.y) return true;

      // Try all four directions
      for (var dir in [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1]
      ]) {
        int newX = current.x + dir[0];
        int newY = current.y + dir[1];
        String key = '$newX,$newY';

        if (newX >= 0 &&
            newX < _grid.size &&
            newY >= 0 &&
            newY < _grid.size &&
            !visited.contains(key) &&
            !_grid.cells[newX][newY].isObstacle) {
          queue.add(Point(newX, newY));
          visited.add(key);
        }
      }
    }

    return false;
  }

  bool _isPowerOfTwo(int value) => value > 0 && (value & (value - 1)) == 0;

  void moveCubes(String direction) {
    if (isAnimating) return;

    bool moved = false;
    List<List<Cube>> newCells = List.generate(
      _grid.size,
      (r) => List.generate(_grid.size, (c) => _grid.cells[r][c]),
    );

    // Process each line based on direction
    for (int i = 0; i < _grid.size; i++) {
      var line = _grid.getLine(i, direction);
      var processedLine = _processLine(line);

      // Update the grid with processed line
      for (int j = 0; j < _grid.size; j++) {
        int r, c;
        switch (direction) {
          case "left":
            r = i;
            c = j;
            break;
          case "right":
            r = i;
            c = _grid.size - 1 - j;
            break;
          case "up":
            r = j;
            c = i;
            break;
          case "down":
            r = _grid.size - 1 - j;
            c = i;
            break;
          default:
            continue;
        }

        if (newCells[r][c] != processedLine[j]) {
          moved = true;
          newCells[r][c] = processedLine[j];
        }
      }
    }

    if (moved) {
      _grid = _grid.copyWith(
        cells: newCells,
        isAnimating: true,
      );
      notifyListeners();
      animationController.forward(from: 0);
    }
  }

  List<Cube> _processLine(List<Cube> line) {
    // Create result line with obstacles in their original positions
    List<Cube> result = List.generate(line.length, (i) {
      return line[i].isObstacle ? line[i] : const Cube();
    });

    // Split the line into sections divided by obstacles
    List<List<int>> sections = [];
    List<int> currentSection = [];

    for (int i = 0; i < line.length; i++) {
      if (line[i].isObstacle) {
        if (currentSection.isNotEmpty) {
          sections.add(currentSection);
          currentSection = [];
        }
      } else {
        currentSection.add(i);
      }
    }
    if (currentSection.isNotEmpty) {
      sections.add(currentSection);
    }

    // Process each section independently
    for (var section in sections) {
      // Collect movable cubes in this section
      List<Cube> movableCubes = [];
      for (var index in section) {
        if (line[index].value != null) {
          movableCubes.add(line[index]);
        }
      }

      // Keep merging until no more merges are possible
      bool mergedAny;
      do {
        mergedAny = false;
        for (int i = 0; i < movableCubes.length - 1; i++) {
          if (movableCubes[i].value == movableCubes[i + 1].value) {
            movableCubes[i] = Cube(
              value: movableCubes[i].value! * 2,
              isMerging: true,
            );
            movableCubes.removeAt(i + 1);
            mergedAny = true;
            i--; // Recheck the merged cube with the next one
          }
        }
      } while (mergedAny);

      // Place merged cubes back into their section
      for (int i = 0; i < movableCubes.length; i++) {
        result[section[i]] = movableCubes[i];
      }
    }

    return result;
  }

  void _onAnimationComplete() {
    if (_mergeQueue.isNotEmpty) {
      var merge = _mergeQueue.removeAt(0);
      _grid = _grid.copyWith(
        cells: merge['cells'],
        isAnimating: true,
      );
      notifyListeners();
      animationController.forward(from: 0);
    } else {
      _grid = _grid.copyWith(isAnimating: false);
      notifyListeners();

      if (hasWon) {
        _level = _level.copyWith(number: _level.number + 1);
        _initializeLevel();
      }
    }
  }

  void restartLevel() {
    _initializeLevel();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }
}

class Point<T> {
  final T x;
  final T y;
  Point(this.x, this.y);
}
