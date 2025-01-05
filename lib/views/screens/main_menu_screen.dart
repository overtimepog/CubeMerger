import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import '../../services/level_service.dart';

class MainMenuScreen extends StatelessWidget {
  final SharedPreferences prefs;

  const MainMenuScreen({
    super.key,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Cubes Control',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(fontSize: 24),
                  ),
                  onPressed: () {
                    final levelService = LevelService(prefs);
                    final savedLevel = levelService.getCurrentLevel();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GameScreen(
                          initialLevel: savedLevel,
                        ),
                      ),
                    );
                  },
                  child: const Text('Play'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
