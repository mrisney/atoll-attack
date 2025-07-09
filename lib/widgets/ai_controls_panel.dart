// lib/widgets/ai_controls_panel.dart
import 'package:flutter/material.dart';
import '../ai/ai_player.dart';
import '../ai/ai_service.dart';
import '../constants/game_config.dart';

class AIControlsPanel extends StatefulWidget {
  final AIService aiService;
  final VoidCallback? onAIToggled;

  const AIControlsPanel({
    Key? key,
    required this.aiService,
    this.onAIToggled,
  }) : super(key: key);

  @override
  State<AIControlsPanel> createState() => _AIControlsPanelState();
}

class _AIControlsPanelState extends State<AIControlsPanel> {
  AIDifficulty _selectedDifficulty = AIDifficulty.medium;
  Team _selectedTeam = Team.red;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.smart_toy,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Player',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AI Status
          Row(
            children: [
              Text(
                'Status: ',
                style: TextStyle(color: Colors.white70),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.aiService.isEnabled ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.aiService.isEnabled ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Team Selection
          if (!widget.aiService.isEnabled) ...[
            Text(
              'AI Team:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: Team.values.map((team) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTeam = team),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTeam == team
                            ? (team == Team.blue ? Colors.blue : Colors.red)
                            : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _selectedTeam == team
                              ? Colors.white
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        team.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Difficulty Selection
            Text(
              'Difficulty:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Column(
              children: AIDifficulty.values.map((difficulty) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedDifficulty = difficulty),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedDifficulty == difficulty
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _selectedDifficulty == difficulty
                            ? Colors.blue
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getDifficultyIcon(difficulty),
                          color: _getDifficultyColor(difficulty),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getDifficultyName(difficulty),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _getDifficultyDescription(difficulty),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedDifficulty == difficulty)
                          Icon(
                            Icons.check_circle,
                            color: Colors.blue,
                            size: 16,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Current AI Info (when active)
          if (widget.aiService.isEnabled) ...[
            _buildInfoRow('Team', widget.aiService.aiTeam?.name.toUpperCase() ?? 'Unknown'),
            _buildInfoRow('Difficulty', _getDifficultyName(widget.aiService.difficulty ?? AIDifficulty.medium)),
            const SizedBox(height: 16),
          ],

          // Toggle Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleAI,
              icon: Icon(
                widget.aiService.isEnabled ? Icons.stop : Icons.play_arrow,
                size: 18,
              ),
              label: Text(
                widget.aiService.isEnabled ? 'Disable AI' : 'Enable AI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.aiService.isEnabled ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAI() {
    if (widget.aiService.isEnabled) {
      widget.aiService.disableAI();
    } else {
      widget.aiService.enableAI(
        aiTeam: _selectedTeam,
        difficulty: _selectedDifficulty,
      );
    }
    
    widget.onAIToggled?.call();
    setState(() {});
  }

  IconData _getDifficultyIcon(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.easy:
        return Icons.sentiment_satisfied;
      case AIDifficulty.medium:
        return Icons.sentiment_neutral;
      case AIDifficulty.hard:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  Color _getDifficultyColor(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.easy:
        return Colors.green;
      case AIDifficulty.medium:
        return Colors.orange;
      case AIDifficulty.hard:
        return Colors.red;
    }
  }

  String _getDifficultyName(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.easy:
        return 'Easy';
      case AIDifficulty.medium:
        return 'Medium';
      case AIDifficulty.hard:
        return 'Hard';
    }
  }

  String _getDifficultyDescription(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.easy:
        return 'Slow decisions, basic strategies';
      case AIDifficulty.medium:
        return 'Moderate speed, good tactics';
      case AIDifficulty.hard:
        return 'Fast reactions, advanced AI';
    }
  }
}
