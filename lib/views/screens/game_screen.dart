import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/game_viewmodel.dart';
import '../widgets/cube_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/level_service.dart';
import '../../models/level.dart';

class GameScreen extends StatefulWidget {
  final int initialLevel;

  const GameScreen({
    super.key,
    required this.initialLevel,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final LevelService _levelService;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _levelService =
        LevelService(Provider.of<SharedPreferences>(context, listen: false));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameViewModel(
        controller: _controller,
        levelService: _levelService,
        initialLevel: Level(number: widget.initialLevel),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: 'Home',
          ),
          title: const Text("Cubes Control"),
          actions: [
            Consumer<GameViewModel>(
              builder: (context, viewModel, _) => IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => viewModel.restartLevel(),
                tooltip: 'Reset Level',
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Consumer<GameViewModel>(
                builder: (context, viewModel, _) => Text(
                  "Level ${viewModel.level.number}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(child: CubeGrid()),
            ],
          ),
        ),
      ),
    );
  }
}
