import 'package:flutter/material.dart';
import '../game/ship_component.dart';
import '../models/unit_model.dart';

class ShipSpawnControls extends StatelessWidget {
  final ShipComponent ship;
  final Function(UnitType) onSpawnUnit;
  final VoidCallback onClose;

  const ShipSpawnControls({
    Key? key,
    required this.ship,
    required this.onSpawnUnit,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final availableUnits = ship.model.getAvailableUnits();
    final teamColor = ship.model.team == Team.blue ? Colors.blue : Colors.red;
    final teamName = ship.model.team == Team.blue ? 'Blue' : 'Red';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teamColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: teamColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_boat, color: teamColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '$teamName Ship',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Ship status
          Text(
            ship.model.getStatusText(),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          
          const SizedBox(height: 12),
          
          // Unit spawn buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnitButton(
                unitType: UnitType.captain,
                count: availableUnits[UnitType.captain] ?? 0,
                icon: Icons.flag,
                label: 'Captain',
                teamColor: teamColor,
              ),
              const SizedBox(width: 8),
              _buildUnitButton(
                unitType: UnitType.archer,
                count: availableUnits[UnitType.archer] ?? 0,
                icon: Icons.my_location,
                label: 'Archer',
                teamColor: teamColor,
              ),
              const SizedBox(width: 8),
              _buildUnitButton(
                unitType: UnitType.swordsman,
                count: availableUnits[UnitType.swordsman] ?? 0,
                icon: Icons.sports_martial_arts,
                label: 'Swordsman',
                teamColor: teamColor,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Total cargo info
          Text(
            'Total: ${ship.model.cargoCount}/${ship.model.maxCargo}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitButton({
    required UnitType unitType,
    required int count,
    required IconData icon,
    required String label,
    required Color teamColor,
  }) {
    final canSpawn = count > 0 && ship.model.canDeployUnits();
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canSpawn ? () => onSpawnUnit(unitType) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: canSpawn 
                    ? teamColor.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canSpawn ? teamColor : Colors.grey,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: canSpawn ? teamColor : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: canSpawn ? teamColor : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: canSpawn ? Colors.white : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
