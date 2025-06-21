import 'package:flutter/material.dart';

/// A screen that allows a player to join a game using an invite code.
class JoinScreen extends StatelessWidget {
  /// The invite code passed via deep link.
  final String inviteCode;

  const JoinScreen({Key? key, required this.inviteCode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Game'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite Code:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              inviteCode,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Add game join logic here, e.g. Firestore transaction or signaling
              },
              child: const Text('Join Game'),
            ),
          ],
        ),
      ),
    );
  }
}
