// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:logger/logger.dart';

import 'screens/game_screen.dart';
import 'screens/test_menu_screen.dart';
import 'constants/game_config.dart';
import 'firebase_options.dart';

final logger = Logger();
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with optimizations
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Optimize Firebase RTDB for low latency
  final db = FirebaseDatabase.instance;
  db.setPersistenceEnabled(true);
  db.setPersistenceCacheSizeBytes(5000000); // 5MB cache
  
  logger.i("🔥 Firebase initialized successfully with optimizations");

  // 3) Force same game code for all devices
  final prefs = await SharedPreferences.getInstance();
  const lastCode = 'TEST-ROOM';
  await prefs.setString('lastGameCode', lastCode);
  logger.i('🎮 Using game code: $lastCode');

  runApp(
    ProviderScope(
      child: AtollAttackApp(initialInviteCode: lastCode),
    ),
  );
}

class AtollAttackApp extends StatefulWidget {
  final String? initialInviteCode;
  const AtollAttackApp({Key? key, this.initialInviteCode}) : super(key: key);

  @override
  _AtollAttackAppState createState() => _AtollAttackAppState();
}

class _AtollAttackAppState extends State<AtollAttackApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (uri != null) _handleDeepLink(uri);
      },
      onError: (err) => logger.e('Deep link error: $err'),
    );
  }

  void _handleDeepLink(Uri uri) {
    logger.i('Deep link received: $uri');
    String? code;
    if (uri.scheme == 'https' &&
        uri.host == 'link.atoll-attack.com' &&
        uri.path == '/join') {
      code = uri.queryParameters['code'];
    } else if (uri.scheme == 'atoll' && uri.host == 'join') {
      code = uri.queryParameters['code'];
    }
    if (code?.isNotEmpty == true) {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => GameScreen(gameCode: code)),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atoll Attack',
      navigatorKey: navigatorKey,
      theme: ThemeData.dark(),
      home: const TestMenuScreen(), // Use test menu for easy access
    );
  }
}