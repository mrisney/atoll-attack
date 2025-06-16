import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Add this import
import 'screens/game_screen.dart';

void main() {
  runApp(const ProviderScope(child: AtollWarsApp()));
}

class AtollWarsApp extends StatelessWidget {
  const AtollWarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap MaterialApp with ScreenUtilInit
    return ScreenUtilInit(
      // Set your design size - this should match your primary development device
      // Common options:
      // iPhone 14 Pro: Size(393, 852)
      // iPhone SE: Size(375, 667)
      // Pixel 7: Size(393, 851)
      designSize: const Size(393, 852),

      // These settings help with text scaling and split screen
      minTextAdapt: true,
      splitScreenMode: true,

      // The builder provides your app
      builder: (context, child) {
        return MaterialApp(
          title: 'Atoll Wars',
          theme: ThemeData.dark(),
          home: const GameScreen(),
        );
      },
    );
  }
}
