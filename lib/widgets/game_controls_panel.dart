// lib/widgets/game_controls_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../providers/game_provider.dart';
import '../models/unit_model.dart';
import '../constants/game_config.dart';

// Use WebRTC service for multiplayer communication
import '../services/webrtc_game_service.dart';

final _log = Logger();

class GameControlsPanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  /// if false, still shows the test section but grayed out
  final bool useMultiplayer;

  const GameControlsPanel({
    Key? key,
    this.onClose,
    this.useMultiplayer = true,
  }) : super(key: key);

  @override
  ConsumerState<GameControlsPanel> createState() => _GameControlsPanelState();
}

class _GameControlsPanelState extends ConsumerState<GameControlsPanel> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final unitCounts = ref.watch(unitCountsProvider);

    final screen = MediaQuery.of(context).size;
    final isLandscape = screen.width > screen.height;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 600 : 350,
          minWidth: 280,
          maxHeight: isLandscape ? screen.height * 0.6 : 400,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            children: [
              if (isLandscape)
                _buildCompactLandscape(context, unitCounts, game)
              else
                _buildPortrait(context, unitCounts, game),

              // divider + WebRTC status section
              const Divider(color: Colors.white24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WebRTC Status',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final webrtcService = WebRTCGameService.instance;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection: ${webrtcService.connectionState}',
                              style: TextStyle(
                                color: webrtcService.isConnected ? Colors.green : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                            if (webrtcService.roomCode != null)
                              Text(
                                'Room: ${webrtcService.roomCode}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            if (webrtcService.averageLatency > 0)
                              Text(
                                'Latency: ${webrtcService.averageLatency.toStringAsFixed(0)}ms',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            if (webrtcService.roomCode != null) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await webrtcService.leaveRoom();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('🚪 Left room successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('❌ Error leaving room: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text(
                                    '🚪 Leave Room',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortrait(BuildContext c, Map<String, int> uc, game) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        _buildCompactUnitCountDisplay(uc),
        const SizedBox(height: 8),
        _buildPortraitSpawn(c, uc, game),
        const SizedBox(height: 4),
        _buildInstructions(9),
      ],
    );
  }

  Widget _buildCompactLandscape(BuildContext c, Map<String, int> uc, game) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildHeader()),
            _buildLandscapeCounts(uc),
          ],
        ),
        const SizedBox(height: 8),
        _buildLandscapeSpawn(c, uc, game),
        const SizedBox(height: 4),
        _buildInstructions(10),
      ],
    );
  }

  Widget _buildHeader() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Spawn Units',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          if (widget.onClose != null)
            GestureDetector(
                onTap: widget.onClose,
                child: const Icon(Icons.close, color: Colors.white70)),
        ],
      );

  Widget _buildLandscapeCounts(Map<String, int> uc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mini('B', Colors.blue, uc, true),
          const SizedBox(width: 12),
          _mini('R', Colors.red, uc, false),
        ],
      ),
    );
  }

  Widget _mini(String label, Color color, Map<String, int> uc, bool blue) {
    final p = blue ? 'blue' : 'red';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 2),
        Text('${uc['${p}Remaining']}',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCompactUnitCountDisplay(Map<String, int> uc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.25),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _team('Blue', uc, Colors.blue, true),
          Container(height: 35, width: 1, color: Colors.white.withOpacity(0.3)),
          _team('Red', uc, Colors.red, false),
        ],
      ),
    );
  }

  Widget _team(String name, Map<String, int> uc, Color color, bool blue) {
    final p = blue ? 'blue' : 'red';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 2),
        Text(
          'C:${uc['${p}CaptainsRemaining']} '
          'A:${uc['${p}ArchersRemaining']} '
          'S:${uc['${p}SwordsmenRemaining']}',
          style: const TextStyle(color: Colors.white70, fontSize: 8),
        ),
        Text('Total: ${uc['${p}Remaining']}',
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPortraitSpawn(BuildContext c, Map<String, int> uc, game) {
    return Row(
      children: [
        Expanded(child: _teamColumn('Blue', uc, game, Team.blue)),
        const SizedBox(width: 8),
        Expanded(child: _teamColumn('Red', uc, game, Team.red)),
      ],
    );
  }

  Widget _teamColumn(String label, Map<String, int> uc, game, Team team) {
    final base = team == Team.blue ? Colors.blue.shade400 : Colors.red.shade400;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: base, fontSize: 10)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _unitButtons(uc, game, team, false),
        ),
      ],
    );
  }

  Widget _buildLandscapeSpawn(BuildContext c, Map<String, int> uc, game) {
    return Row(
      children: [
        Expanded(
            child: _spawnRow(
                uc, game, Team.blue, true, Colors.blue.withOpacity(0.1))),
        const SizedBox(width: 8),
        Expanded(
            child: _spawnRow(
                uc, game, Team.red, true, Colors.red.withOpacity(0.1))),
      ],
    );
  }

  Widget _spawnRow(Map<String, int> uc, game, Team team, bool land, Color bg) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _unitButtons(uc, game, team, land)),
    );
  }

  List<Widget> _unitButtons(
      Map<String, int> uc, game, Team team, bool landscape) {
    final p = team == Team.blue ? 'blue' : 'red';
    final c = team == Team.blue ? Colors.blue : Colors.red;
    return [
      _btn(
          'C',
          Icons.star,
          c.shade700,
          () => game.spawnSingleUnit(UnitType.captain, team),
          uc['${p}CaptainsRemaining']! > 0,
          uc['${p}CaptainsRemaining']!,
          landscape),
      _btn(
          'A',
          Icons.sports_esports,
          c.shade500,
          () => game.spawnSingleUnit(UnitType.archer, team),
          uc['${p}ArchersRemaining']! > 0,
          uc['${p}ArchersRemaining']!,
          landscape),
      _btn(
          'S',
          Icons.shield,
          c.shade300,
          () => game.spawnSingleUnit(UnitType.swordsman, team),
          uc['${p}SwordsmenRemaining']! > 0,
          uc['${p}SwordsmenRemaining']!,
          landscape),
    ];
  }

  Widget _btn(String lbl, IconData ic, Color col, VoidCallback onTap, bool ok,
      int cnt, bool landscape) {
    final s = landscape ? 50.0 : 45.0, isz = landscape ? 14.0 : 12.0;
    return SizedBox(
      width: s,
      height: s,
      child: ElevatedButton(
        onPressed: ok ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ok ? col : Colors.grey.shade600,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ic, size: isz, color: Colors.white),
          Text(lbl,
              style:
                  TextStyle(fontSize: landscape ? 9 : 8, color: Colors.white)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3)),
            child: Text('$cnt',
                style: TextStyle(
                    fontSize: landscape ? 8 : 7,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          )
        ]),
      ),
    );
  }

  Widget _buildInstructions(double sz) => Text(
        'Drag to select • Tap to move • Tap buttons to spawn',
        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: sz),
        textAlign: TextAlign.center,
      );
}
