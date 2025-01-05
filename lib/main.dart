import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'views/screens/main_menu_screen.dart';

void main() {
  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late Future<SharedPreferences> _prefsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    _prefsFuture = SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _prefsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error initializing app: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return Provider<SharedPreferences>.value(
          value: snapshot.data!,
          child: CubesControlApp(prefs: snapshot.data!),
        );
      },
    );
  }
}

class CubesControlApp extends StatelessWidget {
  final SharedPreferences prefs;

  const CubesControlApp({
    super.key,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cubes Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainMenuScreen(prefs: prefs),
    );
  }
}
