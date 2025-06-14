import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const ProviderScope(child: AtollWarsApp()));
}

class AtollWarsApp extends StatelessWidget {
  const AtollWarsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atoll Wars',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}
