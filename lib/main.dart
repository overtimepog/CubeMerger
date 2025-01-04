import 'package:flutter/material.dart';
import 'dart:math';

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
  final int gridSize = 4;
  final Random random = Random();

  /// The grid holds integers for cube values (e.g., 2, 4, 8, etc.) or null if empty
  late List<List<int?>> grid;

  /// A parallel 2D list that marks which cells are obstacles (true = obstacle)
  late List<List<bool>> obstacles;

  /// Track how many moves the player has made
  int moveCount = 0;

  /// Maximum stars the player can earn in a level
  final int maxStars = 3;

  /// Animation controller for cube movements
  late AnimationController _controller;

  /// Slide animation for cube movements
  late Animation<Offset> _slideAnimation;

  /// Track which cells are moving for animation
  late List<List<bool>> isMoving;

  /// Track the distance each cube needs to move
  late List<List<Offset>> moveDistances;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _initializeGame();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeGame() {
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    obstacles = List.generate(gridSize, (_) => List.filled(gridSize, false));
    isMoving = List.generate(gridSize, (_) => List.filled(gridSize, false));
    moveDistances = List.generate(
      gridSize,
      (_) => List.filled(gridSize, Offset.zero),
    );
    moveCount = 0;
    _generateSolvableLevel();
  }

  void _generateSolvableLevel() {
    // Clear any existing data
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    obstacles = List.generate(gridSize, (_) => List.filled(gridSize, false));

    // First place obstacles (max 2 to ensure solvability)
    int maxObstacles = 2;
    int obstacleCount = 0;
    while (obstacleCount < maxObstacles) {
      int r = random.nextInt(gridSize);
      int c = random.nextInt(gridSize);
      // Don't place obstacles in corners or adjacent cells
      if (!obstacles[r][c] && !_isCorner(r, c) && !_hasAdjacentObstacle(r, c)) {
        obstacles[r][c] = true;
        obstacleCount++;
      }
    }

    // Place exactly 4 cubes with value 2
    for (int i = 0; i < 2; i++) {
      _placeRandomPair(2);
    }

    setState(() {});
  }

  bool _isCorner(int row, int col) {
    return (row == 0 || row == gridSize - 1) &&
        (col == 0 || col == gridSize - 1);
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
          newRow < gridSize &&
          newCol >= 0 &&
          newCol < gridSize) {
        if (obstacles[newRow][newCol]) return true;
      }
    }
    return false;
  }

  void _placeRandomPair(int value) {
    List<Point<int>> emptyCells = [];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c] == null && !obstacles[r][c]) {
          emptyCells.add(Point(r, c));
        }
      }
    }

    if (emptyCells.length < 2) return;

    emptyCells.shuffle(random);
    var pos1 = emptyCells[0];
    var pos2 = emptyCells[1];

    grid[pos1.x][pos1.y] = value;
    grid[pos2.x][pos2.y] = value;
  }

  void _moveCubes(String direction) {
    bool moved = false;
    List<List<int?>> oldGrid = List.generate(
      gridSize,
      (i) => List.from(grid[i]),
    );

    // Reset states
    isMoving = List.generate(gridSize, (_) => List.filled(gridSize, false));
    moveDistances = List.generate(
      gridSize,
      (_) => List.filled(gridSize, Offset.zero),
    );

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
      gridSize,
      (i) => List.from(grid[i]),
    );

    // Move cubes
    for (int i = 0; i < gridSize; i++) {
      List<int?> line = _getLine(i, direction);
      List<bool> obstacleLine = _getObstacleLine(i, direction);
      List<int?> newLine = _moveAndMergeLine(line, obstacleLine);
      _putLine(i, direction, newLine);
    }

    // Calculate movement distances and mark moving cells
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c] != oldGrid[r][c]) {
          moved = true;
          if (grid[r][c] != null) {
            isMoving[r][c] = true;

            // Find original position of this number
            int cells = 0;
            switch (direction) {
              case "left":
                for (int x = c + 1; x < gridSize; x++) {
                  if (originalGrid[r][x] == grid[r][c]) {
                    cells = x - c;
                    break;
                  }
                }
                moveDistances[r][c] = baseMove * cells.toDouble();
                break;
              case "right":
                for (int x = c - 1; x >= 0; x--) {
                  if (originalGrid[r][x] == grid[r][c]) {
                    cells = c - x;
                    break;
                  }
                }
                moveDistances[r][c] = baseMove * cells.toDouble();
                break;
              case "up":
                for (int y = r + 1; y < gridSize; y++) {
                  if (originalGrid[y][c] == grid[r][c]) {
                    cells = y - r;
                    break;
                  }
                }
                moveDistances[r][c] = baseMove * cells.toDouble();
                break;
              case "down":
                for (int y = r - 1; y >= 0; y--) {
                  if (originalGrid[y][c] == grid[r][c]) {
                    cells = r - y;
                    break;
                  }
                }
                moveDistances[r][c] = baseMove * cells.toDouble();
                break;
            }
          }
        }
      }
    }

    if (moved) {
      setState(() {
        moveCount++;
      });

      // Animate the movement
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          if (isMoving[r][c]) {
            _slideAnimation = Tween<Offset>(
              begin: moveDistances[r][c],
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeInOut,
            ));
          }
        }
      }

      _controller.forward(from: 0).then((_) {
        setState(() {
          isMoving =
              List.generate(gridSize, (_) => List.filled(gridSize, false));
        });
        _checkWinCondition();
      });
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
        for (int r = 0; r < gridSize; r++) {
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
        for (int r = 0; r < gridSize; r++) {
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
        for (int r = 0; r < gridSize; r++) {
          grid[r][index] = newLine[r];
        }
        break;
    }
  }

  List<int?> _moveAndMergeLine(List<int?> line, List<bool> obstacleLine) {
    line = _compressLine(line, obstacleLine);

    for (int i = 0; i < line.length - 1; i++) {
      if (line[i] != null &&
          line[i] == line[i + 1] &&
          !obstacleLine[i] &&
          !obstacleLine[i + 1]) {
        line[i] = line[i]! * 2;
        line[i + 1] = null;
        i++;
      }
    }

    return _compressLine(line, obstacleLine);
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
    // Count non-null cells (excluding obstacles)
    int cubeCount = 0;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c] != null) {
          cubeCount++;
        }
      }
    }

    // Win when there's exactly one cube left
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
    if (moveCount <= 4) return 3;
    if (moveCount <= 6) return 2;
    return 1;
  }

  Color _getCubeColor(int? value) {
    if (value == null) return Colors.grey[300]!;

    final hue = (value.toDouble() * 25) % 360;
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
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
                      itemCount: gridSize * gridSize,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                        childAspectRatio: 1,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemBuilder: (context, index) {
                        int row = index ~/ gridSize;
                        int col = index % gridSize;
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
                                position: _slideAnimation,
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
