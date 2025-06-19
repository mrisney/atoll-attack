// lib/commands/command_system.dart
import 'package:flame/components.dart';
import '../models/unit_model.dart';

abstract class GameCommand {
  final String playerId;
  final DateTime timestamp;

  GameCommand({required this.playerId}) : timestamp = DateTime.now();

  bool execute(IslandGame game);
  bool undo(IslandGame game);
  Map<String, dynamic> toJson();
}

class CommandRecorder {
  final List<GameCommand> _history = [];
  final List<GameCommand> _redoStack = [];
  int _currentIndex = -1;

  void record(GameCommand command) {
    // Remove any commands after current index
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
      _redoStack.clear();
    }

    _history.add(command);
    _currentIndex++;
  }

  void undo() {
    if (_currentIndex >= 0) {
      final command = _history[_currentIndex];
      _redoStack.add(command);
      _currentIndex--;
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      final command = _redoStack.removeLast();
      _currentIndex++;
    }
  }

  List<Map<String, dynamic>> serialize() {
    return _history.map((cmd) => cmd.toJson()).toList();
  }
}
