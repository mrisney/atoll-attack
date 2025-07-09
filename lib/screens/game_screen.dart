// lib/screens/game_screen.dart

import 'dart:async' as async;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:flame/components.dart';

import '../models/game_doc.dart';
import '../models/unit_model.dart';
import '../game/ship_component.dart';
import '../services/webrtc_game_service.dart';
import '../widgets/ship_spawn_controls.dart';
// import '../services/share_service.dart'; // TODO: Re-enable for multiplayer
import '../services/rtdb_service.dart';

import '../providers/game_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';
import '../widgets/game_hud.dart';
import '../widgets/draggable_selected_units_panel.dart';
import 'package:flame/game.dart';

final _log = Logger();

class GameScreen extends ConsumerStatefulWidget {
  final String? gameCode;
  const GameScreen({Key? key, this.gameCode}) : super(key: key);

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  async.StreamSubscription<GameDoc>? _joinSub;

  async.Timer? _rttTimer;

  bool showPanel = false;
  bool showHUD = true;
  bool showSelectedUnitsPanel = true;
  bool isSettingsMode = true;

  bool _opponentJoined = false;
  String? _joinedPlayerId;

  @override
  void initState() {
    super.initState();
    final code = widget.gameCode;
    if (code != null) {
      _persistGameCode(code);
      _initializeFirebaseRTDB(code);
      
      // TODO: Re-enable ShareService for multiplayer
      /*
      ShareService.instance.listenForJoin(code, (GameDoc doc) {
        setState(() {
          _opponentJoined = true;
          _joinedPlayerId = doc.players.isNotEmpty ? doc.players.last : null;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            _opponentJoined = false;
            _joinedPlayerId = null;
          });
        });
      }).then((sub) => _joinSub = sub);
      */
    }

    // refresh RTT display every second
    _rttTimer = async.Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }



  void _showStatus(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: c,
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _persistGameCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastGameCode', code);
  }

  Future<void> _initializeFirebaseRTDB(String code) async {
    try {
      await FirebaseRTDBService.instance.initialize(code);
      _log.i('🔥 Firebase RTDB initialized for game: $code');
    } catch (e) {
      _log.e('❌ Firebase RTDB initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _rttTimer?.cancel();
    _joinSub?.cancel();
    FirebaseRTDBService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.gameCode;
    final game = ref.watch(gameProvider);
    final gameStats = ref.watch(gameStatsProvider);
    final media = MediaQuery.of(context);

    // unit-counts callback
    if (game.onUnitCountsChanged == null) {
      game.onUnitCountsChanged = () {
        ref.read(gameProvider.notifier).notifyUnitCountsChanged();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => mounted ? setState(() {}) : null);
      };
    }

    // Firebase RTDB status for testing
    final rtdb = FirebaseRTDBService.instance;
    final conn = rtdb.isConnected;
    final last = rtdb.lastRtt;
    final avg = rtdb.avgRtt;

    return Scaffold(
      body: Stack(children: [
        GameWidget(game: game),

        // Multiplayer Controls (top-right)
        Positioned(
          top: media.padding.top + 8,
          right: 16,
          child: _buildMultiplayerControls(),
        ),

        // Ship Spawn Controls (contextual)
        if (game.activeSpawnShip != null)
          Positioned(
            top: media.padding.top + 100,
            right: 16,
            child: ShipSpawnControls(
              ship: game.activeSpawnShip!,
              onSpawnUnit: (unitType) => _spawnUnitFromShip(game.activeSpawnShip!, unitType),
              onClose: () => game.hideShipSpawnControls(),
            ),
          ),

        if (showHUD)
          Positioned(
            top: media.padding.top + 8,
            left: 16,
            child: GameHUD(
              blueUnits: gameStats['blueUnits'] ?? 0,
              redUnits: gameStats['redUnits'] ?? 0,
              blueHealthPercent: gameStats['blueHealth'] ?? 0.0,
              redHealthPercent: gameStats['redHealth'] ?? 0.0,
              isVisible: showHUD,
              onToggleVisibility: () => setState(() => showHUD = !showHUD),
              blueUnitsRemaining: gameStats['blueRemaining'] ?? 0,
              redUnitsRemaining: gameStats['redRemaining'] ?? 0,
            ),
          ),

        // Network status indicator
        if (code != null)
          Positioned(
            top: media.padding.top + 60,
            left: 16,
            child: _buildNetworkStatus(conn, last, avg),
          ),



        // settings / controls toggle (unchanged)
        Positioned(
          top: media.padding.top + 8,
          right: 16,
          child: GestureDetector(
            onTap: () => setState(() => showPanel = !showPanel),
            onLongPress: () => setState(() {
              showPanel = true;
              isSettingsMode = !isSettingsMode;
            }),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: showPanel
                    ? (isSettingsMode ? Colors.blueGrey : Colors.orange)
                    : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: Icon(
                isSettingsMode ? Icons.tune : Icons.sports_esports,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),

        if (showPanel)
          Positioned(
            bottom: media.padding.bottom + 12,
            left: 12,
            right: 12,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _tab('Settings', Icons.tune, true),
                  _tab('Controls', Icons.sports_esports, false),
                ]),
              ),
              Container(
                constraints: BoxConstraints(maxHeight: media.size.height * 0.4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: isSettingsMode
                    ? IslandSettingsPanel(
                        onClose: () => setState(() => showPanel = false))
                    : GameControlsPanel(
                        onClose: () => setState(() => showPanel = false)),
              ),
            ]),
          ),

        if (game.selectedUnits.isNotEmpty && showSelectedUnitsPanel)
          DraggableSelectedUnitsPanel(
            unitsInfo: game.getSelectedUnitsInfo(),
            onClose: () {
              game.clearSelection();
              setState(() {});
            },
          ),

        if (gameStats['isVictoryAchieved'] == true)
          Positioned(
            top: media.size.height * 0.3,
            left: 50,
            right: 50,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.yellow.shade700, width: 2),
              ),
              child: const Text(
                '🎉 VICTORY! 🎉',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Firebase testing FAB buttons
        if (code != null && conn)
          Positioned(
            bottom: media.padding.bottom + 70,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: () {
                    FirebaseRTDBService.instance
                        .sendCommand('test', {'msg': 'Quick test!'});
                  },
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.send, size: 16),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: () {
                    FirebaseRTDBService.instance.sendPing();
                  },
                  backgroundColor: Colors.cyan,
                  child: const Icon(Icons.network_ping, size: 16),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: () {
                    final rtdbStatus = FirebaseRTDBService.instance;
                    final status = 'Connected: ${rtdbStatus.isConnected}\n'
                        'Last RTT: ${rtdbStatus.lastRtt ?? "--"}ms\n'
                        'Avg RTT: ${rtdbStatus.avgRtt.toStringAsFixed(1)}ms';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Firebase Status:\n$status'),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  },
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.info, size: 16),
                ),
              ],
            ),
          ),




      ]),
    );
  }

  Widget _buildNetworkStatus(bool conn, int? last, double avg) {
    final color = conn ? Colors.green : Colors.red;
    final rttColor = (last ?? 999) < 100 ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud, color: color, size: 16),
        const SizedBox(width: 4),
        Text('Network',
            style: TextStyle(
                color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: rttColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: rttColor, width: 1),
          ),
          child: Text(
            last != null ? '${last}ms' : '--',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  GestureDetector _tab(String label, IconData icon, bool settings) =>
      GestureDetector(
        onTap: () => setState(() => isSettingsMode = settings),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSettingsMode == settings
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: isSettingsMode == settings
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ]),
        ),
      );

  /// Build multiplayer controls
  Widget _buildMultiplayerControls() {
    final webrtcService = WebRTCGameService.instance;
    final isConnected = webrtcService.isConnected;
    final roomCode = webrtcService.roomCode;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (roomCode != null) ...[
            Text(
              'Room: $roomCode',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              isConnected ? '🟢 Connected' : '🔴 Waiting...',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _leaveRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(80, 32),
              ),
              child: const Text('Leave', style: TextStyle(fontSize: 12)),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: _hostGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(80, 32),
              ),
              child: const Text('Host', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: _joinGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(80, 32),
              ),
              child: const Text('Join', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  /// Host a new game
  Future<void> _hostGame() async {
    try {
      final webrtcService = WebRTCGameService.instance;
      await webrtcService.initialize();
      
      final roomCode = await webrtcService.createRoom();
      if (roomCode != null) {
        // Initialize multiplayer with blue team for host
        final game = ref.read(gameProvider);
        await game.initializeMultiplayerWithRoom('blue', roomCode);
        
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🏠 Hosting room: $roomCode')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to host: $e')),
      );
    }
  }

  /// Join an existing game
  Future<void> _joinGame() async {
    final controller = TextEditingController();
    
    final roomCode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Game'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter room code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (roomCode != null && roomCode.isNotEmpty) {
      try {
        final webrtcService = WebRTCGameService.instance;
        await webrtcService.initialize();
        
        final success = await webrtcService.joinRoom(roomCode);
        if (success) {
          // Initialize multiplayer with red team for guest
          final game = ref.read(gameProvider);
          await game.initializeMultiplayerWithRoom('red', roomCode);
          
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🚪 Joined room: $roomCode')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Failed to join room')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error joining: $e')),
        );
      }
    }
  }

  /// Spawn a unit from the specified ship
  void _spawnUnitFromShip(ShipComponent ship, UnitType unitType) {
    final game = ref.read(gameProvider);
    
    // Check if ship can deploy units
    if (!ship.model.canDeployUnits()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Ship cannot deploy units: ${ship.model.getStatusText()}')),
      );
      return;
    }
    
    // Check if ship has the requested unit type
    final availableUnits = ship.model.getAvailableUnits();
    final unitCount = availableUnits[unitType] ?? 0;
    if (unitCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ No ${unitType.name} units available')),
      );
      return;
    }
    
    print('🆕 DEBUG: Spawning ${unitType.name} from ${ship.model.team.name} ship');
    
    // Select the ship first (required by unit selection manager)
    game.unitSelectionManager.clearSelection();
    game.unitSelectionManager.handleShipTap(ship);
    
    // Deploy the unit using the existing system
    final success = game.unitSelectionManager.deployUnitFromShip(unitType);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Deployed ${unitType.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
      
      // Keep the spawn controls open for multiple deployments
      // User can close manually or tap elsewhere
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to deploy ${unitType.name}')),
      );
    }
  }
  Future<void> _leaveRoom() async {
    final webrtcService = WebRTCGameService.instance;
    await webrtcService.leaveRoom();
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('👋 Left room')),
    );
  }
}
