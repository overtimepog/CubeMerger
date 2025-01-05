import 'package:flutter/material.dart';
import 'views/screens/game_screen.dart';

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
