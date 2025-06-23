// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // ← your generated options

// Supabase
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:logger/logger.dart';

import 'constants/game_config.dart';
import 'screens/game_screen.dart';

final logger = Logger();
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.signInAnonymously();

  // 2) Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 40),
  );

  // 3) Load last game code
  final prefs = await SharedPreferences.getInstance();
  final lastCode = prefs.getString('lastGameCode');

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
      home: GameScreen(gameCode: widget.initialInviteCode),
    );
  }
}
