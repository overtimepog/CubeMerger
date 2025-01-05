import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/grid.dart';
import '../models/cube.dart';
import 'package:flutter/foundation.dart';

class LevelService {
  final SharedPreferences _prefs;
  static const String _levelKey = 'current_level';
  Map<String, dynamic> _predefinedLevels = {};
  bool _isInitialized = false;

  LevelService(this._prefs) {
    _loadPredefinedLevels();
  }

  Future<void> _loadPredefinedLevels() async {
    if (_isInitialized) return;

    try {
      final String jsonString = await rootBundle.loadString('lib/levels.json');
      _predefinedLevels = json.decode(jsonString);
      _isInitialized = true;
      debugPrint('Loaded predefined levels successfully');
    } catch (e) {
      debugPrint('Error loading predefined levels: $e');
      _predefinedLevels = {};
    }
  }

  Future<Grid?> loadLevel(int levelNumber) async {
    await _loadPredefinedLevels();

    try {
      final levelData = _predefinedLevels[levelNumber.toString()];
      if (levelData == null) {
        debugPrint('Level $levelNumber not found in JSON');
        return null;
      }

      // Convert the 2D array from JSON
      List<List<dynamic>> grid2D = List<List<dynamic>>.from(
          levelData.map((row) => List<dynamic>.from(row)));

      int size = grid2D.length; // Grid is square, so width = height
      return convertGridFrom2DJson(grid2D, size);
    } catch (e) {
      debugPrint('Error loading level $levelNumber: $e');
      return null;
    }
  }

  int getCurrentLevel() {
    return _prefs.getInt(_levelKey) ?? 1;
  }

  Future<void> saveLevel(int level) async {
    await _prefs.setInt(_levelKey, level);
  }

  int _calculateGridSize(int level) {
    if (level > 100) return 10;
    if (level > 50) return 8;
    if (level > 25) return 7;
    return 5;
  }

  Grid convertGridFrom2DJson(List<List<dynamic>> grid2D, int size) {
    List<List<Cube>> cells = List.generate(
      size,
      (i) => List.generate(
        size,
        (j) {
          dynamic cell = grid2D[i][j];
          if (cell == null) return const Cube(isOutOfShape: true);
          if (cell == 'X') return const Cube(isObstacle: true);
          if (cell == '') return const Cube();
          return Cube(value: int.parse(cell));
        },
      ),
    );
    return Grid(cells: cells, size: size);
  }
}
