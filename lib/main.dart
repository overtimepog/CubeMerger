import 'package:flutter/material.dart';
import 'dart:math';

extension IntegerExtensions on int {
  bool get isPowerOfTwo => this > 0 && (this & (this - 1)) == 0;
}

void main() => runApp(const CubesControlApp());

class CubesControlApp extends StatelessWidget {
  const CubesControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cubes Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  /// Current level number
  int currentLevel = 1;

  /// Get the current grid size based on level
  int get currentGridSize {
    if (currentLevel >= 100) return 10;
    if (currentLevel >= 25) return 7;
    return 5;
  }

  /// The grid holds integers for cube values
  late List<List<int?>> grid;

  /// Marks cells that are obstacles
  late List<List<bool>> obstacles;

  /// Track start positions for animations
  late List<List<Offset>> startPositions;

  /// Track end positions for animations
  late List<List<Offset>> endPositions;

  int moveCount = 0;
  final int maxStars = 3;

  /// Animation controller for cube movements
  late AnimationController _controller;

  /// Track which cells are moving for animation
  late List<List<bool>> isMoving;

  /// Track if we're in the middle of a merge animation
  bool isAnimating = false;

  /// Queue of merge animations to play
  List<Map<String, dynamic>> mergeQueue = [];

  /// For random generation
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Listen for animation completion
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationComplete();
      }
    });

    _initializeGame();
  }

  void _initializeGame() {
    final gs = currentGridSize;
    grid = List.generate(gs, (_) => List.filled(gs, null));
    obstacles = List.generate(gs, (_) => List.filled(gs, false));
    isMoving = List.generate(gs, (_) => List.filled(gs, false));
    startPositions = List.generate(gs, (_) => List.filled(gs, Offset.zero));
    endPositions = List.generate(gs, (_) => List.filled(gs, Offset.zero));
    moveCount = 0;
    _generateSolvableLevel();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generateSolvableLevel() {
    // Clear any existing data
    grid = List.generate(
        currentGridSize, (_) => List.filled(currentGridSize, null));
    obstacles = List.generate(
        currentGridSize, (_) => List.filled(currentGridSize, false));

    // Calculate difficulty parameters based on level
    int numObstacles = min(1 + (currentLevel ~/ 3), currentGridSize - 1);
    int numCubePairs = min(2 + (currentLevel ~/ 2), 4);
    List<int> possibleValues = _getPossibleValuesForLevel();

    // Place obstacles strategically
    _placeObstacles(numObstacles);

    // Place cube pairs
    for (int i = 0; i < numCubePairs; i++) {
      int value = possibleValues[random.nextInt(possibleValues.length)];
      if (!_placeRandomPair(value)) {
        // If we can't place a pair, break to avoid infinite loop
        break;
      }
    }

    // Ensure the level is solvable
    if (!_isLevelSolvable()) {
      // If not solvable, try again with simpler parameters
      currentLevel = max(1, currentLevel - 1);
      _generateSolvableLevel();
      return;
    }

    setState(() {});
  }

  List<int> _getPossibleValuesForLevel() {
    List<int> values = [2];

    // Add higher values as level increases
    if (currentLevel > 3) values.add(4);
    if (currentLevel > 6) values.add(8);

    // Add more 2s for balance
    int numTwos = max(1, 4 - values.length);
    values.addAll(List.filled(numTwos, 2));

    return values;
  }

  void _placeObstacles(int count) {
    // Define possible patterns based on level
    List<List<Point<int>>> patterns = _getObstaclePatterns();

    if (currentLevel > 5 && patterns.isNotEmpty) {
      // Use patterns for higher levels
      List<Point<int>> pattern = patterns[random.nextInt(patterns.length)];
      for (var point in pattern) {
        if (count <= 0) break;
        obstacles[point.x][point.y] = true;
        count--;
      }
    }

    // Fill remaining obstacles randomly
    while (count > 0) {
      int r = random.nextInt(currentGridSize);
      int c = random.nextInt(currentGridSize);
      if (!obstacles[r][c] && !_isCorner(r, c) && !_hasAdjacentObstacle(r, c)) {
        obstacles[r][c] = true;
        count--;
      }
    }
  }

  List<List<Point<int>>> _getObstaclePatterns() {
    // Define interesting obstacle patterns
    return [
      // L shape
      [Point(1, 1), Point(1, 2), Point(2, 1)],
      // Diagonal
      [Point(1, 1), Point(2, 2)],
      // Center block
      [Point(1, 1), Point(1, 2), Point(2, 1), Point(2, 2)],
      // T shape
      [Point(1, 0), Point(1, 1), Point(1, 2), Point(2, 1)],
    ];
  }

  bool _placeRandomPair(int value) {
    List<Point<int>> emptyCells = [];
    for (int r = 0; r < currentGridSize; r++) {
      for (int c = 0; c < currentGridSize; c++) {
        if (grid[r][c] == null && !obstacles[r][c]) {
          emptyCells.add(Point(r, c));
        }
      }
    }

    if (emptyCells.length < 2) return false;

    emptyCells.shuffle(random);
    var pos1 = emptyCells[0];
    var pos2 = emptyCells[1];

    grid[pos1.x][pos1.y] = value;
    grid[pos2.x][pos2.y] = value;
    return true;
  }

  bool _isLevelSolvable() {
    // Count total value of all cubes
    int totalValue = 0;
    for (var row in grid) {
      for (var value in row) {
        if (value != null) totalValue += value;
      }
    }

    // Check if we can merge to a single cube
    if (totalValue.isPowerOfTwo) {
      // Simulate some basic moves to check if cubes can reach each other
      return _canCubesReach();
    }
    return false;
  }

  bool _canCubesReach() {
    // Get all cube positions
    List<Point<int>> cubePositions = [];
    for (int r = 0; r < currentGridSize; r++) {
      for (int c = 0; c < currentGridSize; c++) {
        if (grid[r][c] != null) {
          cubePositions.add(Point(r, c));
        }
      }
    }

    // Check if there's a path between each pair of same-valued cubes
    for (int i = 0; i < cubePositions.length; i++) {
      for (int j = i + 1; j < cubePositions.length; j++) {
        var pos1 = cubePositions[i];
        var pos2 = cubePositions[j];
        if (grid[pos1.x][pos1.y] == grid[pos2.x][pos2.y]) {
          if (!_hasPathBetween(pos1, pos2)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  bool _hasPathBetween(Point<int> start, Point<int> end) {
    // Check if there's a clear path either horizontally or vertically
    bool horizontalPath = true;
    bool verticalPath = true;

    // Check horizontal path
    int minX = min(start.x, end.x);
    int maxX = max(start.x, end.x);
    for (int x = minX; x <= maxX; x++) {
      if (obstacles[x][start.y]) {
        horizontalPath = false;
        break;
      }
    }

    // Check vertical path
    int minY = min(start.y, end.y);
    int maxY = max(start.y, end.y);
    for (int y = minY; y <= maxY; y++) {
      if (obstacles[start.x][y]) {
        verticalPath = false;
        break;
      }
    }

    return horizontalPath || verticalPath;
  }

  void _moveCubes(String direction) {
    if (isAnimating) return; // Prevent new moves while animating

    bool moved = false;
    List<List<int?>> oldGrid = List.generate(
      currentGridSize,
      (i) => List.from(grid[i]),
    );

    // Clear any existing merge queue
    mergeQueue.clear();

    // Reset states
    isMoving = List.generate(
        currentGridSize, (_) => List.filled(currentGridSize, false));
    startPositions = List.generate(
        currentGridSize, (_) => List.filled(currentGridSize, Offset.zero));
    endPositions = List.generate(
        currentGridSize, (_) => List.filled(currentGridSize, Offset.zero));

    // Calculate base movement unit
    Offset baseMove;
    switch (direction) {
      case "left":
        baseMove = const Offset(-1, 0);
        break;
      case "right":
        baseMove = const Offset(1, 0);
        break;
      case "up":
        baseMove = const Offset(0, -1);
        break;
      case "down":
        baseMove = const Offset(0, 1);
        break;
      default:
        baseMove = Offset.zero;
    }

    // Store original grid for calculating distances
    List<List<int?>> originalGrid = List.generate(
      currentGridSize,
      (i) => List.from(grid[i]),
    );

    // Move cubes
    for (int i = 0; i < currentGridSize; i++) {
      List<int?> line = _getLine(i, direction);
      List<bool> obstacleLine = _getObstacleLine(i, direction);
      List<int?> newLine = _moveAndMergeLine(line, obstacleLine);
      _putLine(i, direction, newLine);
    }

    // Calculate movement distances and mark moving cells
    for (int r = 0; r < currentGridSize; r++) {
      for (int c = 0; c < currentGridSize; c++) {
        if (grid[r][c] != oldGrid[r][c]) {
          moved = true;
          if (grid[r][c] != null) {
            isMoving[r][c] = true;

            // Find original position of this number
            int cells = 0;
            switch (direction) {
              case "left":
                for (int x = c + 1; x < currentGridSize; x++) {
                  if (originalGrid[r][x] == grid[r][c]) {
                    cells = x - c;
                    break;
                  }
                }
                startPositions[r][c] = baseMove * cells.toDouble();
                endPositions[r][c] = Offset.zero;
                break;
              case "right":
                for (int x = c - 1; x >= 0; x--) {
                  if (originalGrid[r][x] == grid[r][c]) {
                    cells = c - x;
                    break;
                  }
                }
                startPositions[r][c] = baseMove * cells.toDouble();
                endPositions[r][c] = Offset.zero;
                break;
              case "up":
                for (int y = r + 1; y < currentGridSize; y++) {
                  if (originalGrid[y][c] == grid[r][c]) {
                    cells = y - r;
                    break;
                  }
                }
                startPositions[r][c] = baseMove * cells.toDouble();
                endPositions[r][c] = Offset.zero;
                break;
              case "down":
                for (int y = r - 1; y >= 0; y--) {
                  if (originalGrid[y][c] == grid[r][c]) {
                    cells = r - y;
                    break;
                  }
                }
                startPositions[r][c] = baseMove * cells.toDouble();
                endPositions[r][c] = Offset.zero;
                break;
            }
          }
        }
      }
    }

    if (moved) {
      isAnimating = true;
      setState(() {
        moveCount++;
      });

      _controller.forward(from: 0);
    }
  }

  List<int?> _getLine(int index, String direction) {
    List<int?> line = [];
    switch (direction) {
      case "left":
      case "right":
        line = List<int?>.from(grid[index]);
        break;
      case "up":
      case "down":
        for (int r = 0; r < currentGridSize; r++) {
          line.add(grid[r][index]);
        }
        break;
    }
    if (direction == "right" || direction == "down") {
      line = line.reversed.toList();
    }
    return line;
  }

  List<bool> _getObstacleLine(int index, String direction) {
    List<bool> line = [];
    switch (direction) {
      case "left":
      case "right":
        line = List<bool>.from(obstacles[index]);
        break;
      case "up":
      case "down":
        for (int r = 0; r < currentGridSize; r++) {
          line.add(obstacles[r][index]);
        }
        break;
    }
    if (direction == "right" || direction == "down") {
      line = line.reversed.toList();
    }
    return line;
  }

  void _putLine(int index, String direction, List<int?> newLine) {
    if (direction == "right" || direction == "down") {
      newLine = newLine.reversed.toList();
    }
    switch (direction) {
      case "left":
      case "right":
        grid[index] = newLine;
        break;
      case "up":
      case "down":
        for (int r = 0; r < currentGridSize; r++) {
          grid[r][index] = newLine[r];
        }
        break;
    }
  }

  List<int?> _moveAndMergeLine(List<int?> line, List<bool> obstacleLine) {
    List<int?> result = List<int?>.from(line);
    result = _compressLine(result, obstacleLine);

    // First pass: identify all possible merges
    List<Map<String, dynamic>> merges = [];
    for (int i = 0; i < result.length - 1; i++) {
      if (result[i] != null &&
          result[i] == result[i + 1] &&
          !obstacleLine[i] &&
          !obstacleLine[i + 1]) {
        merges.add({
          'index': i,
          'value': result[i]! * 2,
        });
        i++; // Skip next cell as it's part of this merge
      }
    }

    // If we have multiple merges, we need to animate them sequentially
    if (merges.length > 1) {
      // Create intermediate states for each merge
      for (var merge in merges) {
        int index = merge['index'];
        int value = merge['value'];

        List<List<int?>> intermediateGrid = List.generate(
          currentGridSize,
          (r) => List.from(grid[r]),
        );

        List<List<bool>> intermediateMoving = List.generate(
          currentGridSize,
          (_) => List.filled(currentGridSize, false),
        );

        List<List<Offset>> intermediateStartPositions = List.generate(
          currentGridSize,
          (_) => List.filled(currentGridSize, Offset.zero),
        );

        List<List<Offset>> intermediateEndPositions = List.generate(
          currentGridSize,
          (_) => List.filled(currentGridSize, Offset.zero),
        );

        // Update the grid for this merge
        if (result[index] != null) {
          int row = index ~/ currentGridSize;
          int col = index % currentGridSize;
          intermediateGrid[row][col] = value;
          intermediateGrid[row][col + 1] = null;
          intermediateMoving[row][col] = true;
          intermediateStartPositions[row][col] = Offset.zero;
          intermediateEndPositions[row][col] = const Offset(1, 0);
        }

        // Add to merge queue
        mergeQueue.add({
          'grid': intermediateGrid,
          'isMoving': intermediateMoving,
          'startPositions': intermediateStartPositions,
          'endPositions': intermediateEndPositions,
        });
      }
    }

    // Apply merges to the result
    for (var merge in merges) {
      int index = merge['index'];
      result[index] = merge['value'];
      result[index + 1] = null;
    }

    return _compressLine(result, obstacleLine);
  }

  List<int?> _compressLine(List<int?> line, List<bool> obstacleLine) {
    List<int?> compressed = List.filled(line.length, null);
    int fillIndex = 0;

    // Process each cell from left to right
    for (int i = 0; i < line.length; i++) {
      if (obstacleLine[i]) {
        // Keep obstacles in place and reset fillIndex to next position
        compressed[i] = null;
        fillIndex = i + 1;
      } else if (line[i] != null) {
        // Look for the next valid position to place the cube
        while (fillIndex < line.length && obstacleLine[fillIndex]) {
          fillIndex++;
        }
        // Only move the cube if we found a valid position and haven't hit an obstacle
        if (fillIndex < line.length) {
          // Check if there's an obstacle between current position and destination
          bool hasObstacleBetween = false;
          for (int j = min(i, fillIndex); j < max(i, fillIndex); j++) {
            if (obstacleLine[j]) {
              hasObstacleBetween = true;
              break;
            }
          }

          if (hasObstacleBetween) {
            // If there's an obstacle in the path, find the closest valid position before it
            int newFillIndex = fillIndex;
            for (int j = i; j < line.length; j++) {
              if (obstacleLine[j]) break;
              newFillIndex = j;
            }
            compressed[newFillIndex] = line[i];
            fillIndex = newFillIndex + 1;
          } else {
            // No obstacle in the path, proceed normally
            compressed[fillIndex] = line[i];
            fillIndex++;
          }
        } else {
          // If we can't move forward, stay in place
          compressed[i] = line[i];
        }
      }
    }
    return compressed;
  }

  void _checkWinCondition() {
    int cubeCount = 0;
    for (int r = 0; r < currentGridSize; r++) {
      for (int c = 0; c < currentGridSize; c++) {
        if (grid[r][c] != null) {
          cubeCount++;
        }
      }
    }

    if (cubeCount == 1) {
      int starsEarned = _calculateStars();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Level Completed!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Level $currentLevel Completed!"),
              Text(
                  "You earned $starsEarned star${starsEarned > 1 ? 's' : ''}!"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxStars, (index) {
                  return Icon(
                    index < starsEarned ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 30,
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  currentLevel++;
                  _initializeGame();
                });
              },
              child: const Text("Next Level"),
            ),
          ],
        ),
      );
    }
  }

  int _calculateStars() {
    // Make star thresholds more lenient as levels progress
    int baseThreshold = 4 + (currentLevel ~/ 2);
    if (moveCount <= baseThreshold) return 3;
    if (moveCount <= baseThreshold + 2) return 2;
    return 1;
  }

  Color _getCubeColor(int? value) {
    if (value == null) return Colors.grey[300]!;

    final hue = (value.toDouble() * 25) % 360;
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
  }

  bool _isCorner(int row, int col) {
    return (row == 0 || row == currentGridSize - 1) &&
        (col == 0 || col == currentGridSize - 1);
  }

  bool _hasAdjacentObstacle(int row, int col) {
    for (var adj in [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ]) {
      int newRow = row + adj[0];
      int newCol = col + adj[1];
      if (newRow >= 0 &&
          newRow < currentGridSize &&
          newCol >= 0 &&
          newCol < currentGridSize) {
        if (obstacles[newRow][newCol]) return true;
      }
    }
    return false;
  }

  void _onAnimationComplete() {
    if (mergeQueue.isNotEmpty) {
      // Apply the next merge in the queue
      setState(() {
        var merge = mergeQueue.removeAt(0);
        grid = merge['grid'];
        isMoving = merge['isMoving'];
        startPositions = merge['startPositions'];
        endPositions = merge['endPositions'];
      });
      _controller.forward(from: 0);
    } else {
      setState(() {
        isAnimating = false;
        isMoving = List.generate(
            currentGridSize, (_) => List.filled(currentGridSize, false));
        startPositions = List.generate(
            currentGridSize, (_) => List.filled(currentGridSize, Offset.zero));
        endPositions = List.generate(
            currentGridSize, (_) => List.filled(currentGridSize, Offset.zero));
      });
      _checkWinCondition();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Count remaining cubes
    int remainingCubes = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (cell != null) remainingCubes++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cubes Control"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeGame,
            tooltip: 'Restart Level',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Level display
            const SizedBox(height: 8),
            Text(
              "Level $currentLevel",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Moves and cubes counter
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      "Moves: $moveCount",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      "Cubes: $remainingCubes",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    _moveCubes("right");
                  } else {
                    _moveCubes("left");
                  }
                },
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    _moveCubes("down");
                  } else {
                    _moveCubes("up");
                  }
                },
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentGridSize * currentGridSize,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: currentGridSize,
                        childAspectRatio: 1,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemBuilder: (context, index) {
                        int row = index ~/ currentGridSize;
                        int col = index % currentGridSize;
                        bool isObstacle = obstacles[row][col];
                        int? value = grid[row][col];
                        bool shouldAnimate = isMoving[row][col];

                        Widget cellContent = Container(
                          decoration: BoxDecoration(
                            color: isObstacle
                                ? Colors.black87
                                : _getCubeColor(value),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(26),
                                blurRadius: 2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isObstacle ? "X" : (value?.toString() ?? ""),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isObstacle || value == null
                                    ? Colors.white
                                    : Colors.white.withAlpha(230),
                              ),
                            ),
                          ),
                        );

                        return shouldAnimate
                            ? SlideTransition(
                                position: Tween<Offset>(
                                  begin: startPositions[row][col],
                                  end: endPositions[row][col],
                                ).animate(CurvedAnimation(
                                  parent: _controller,
                                  curve: Curves.easeInOut,
                                )),
                                child: cellContent,
                              )
                            : cellContent;
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxStars, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(
                      index < _calculateStars()
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 30,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
