import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';

import 'screens/game_screen.dart';
import 'screens/join_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const ProviderScope(child: AtollAttackApp()));
}

class AtollAttackApp extends StatefulWidget {
  const AtollAttackApp({Key? key}) : super(key: key);

  @override
  _AtollAttackAppState createState() => _AtollAttackAppState();
}

class _AtollAttackAppState extends State<AtollAttackApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri?>? _sub;

  @override
  void initState() {
    super.initState();
    // Single subscription catches both cold-start and warm-start links:
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (uri != null) _handleDeepLink(uri);
      },
      onError: (err) {
        // optionally log
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    // matches https://link.atoll-attack.com/join?code=…
    if (uri.host == 'link.atoll-attack.com' && uri.path == '/join') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => JoinScreen(inviteCode: code),
          ),
        );
      }
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
      home: const GameScreen(),
    );
  }
}
