import 'package:a_star/a_star.dart';
import 'dart:ui';
import 'island_model.dart';

class IslandCoordinatesState extends AStarState<IslandCoordinatesState> {
  final int x;
  final int y;
  final IslandGridModel island;
  final Offset? targetPosition;

  const IslandCoordinatesState(this.x, this.y, this.island, this.targetPosition,
      {super.depth = 0});

  @override
  Iterable<IslandCoordinatesState> expand() {
    final List<IslandCoordinatesState> neighbors = [];
    final directions = [
      [0, 1], // down
      [0, -1], // up
      [1, 0], // right
      [-1, 0], // left
      [1, 1], // diagonal down-right
      [-1, 1], // diagonal down-left
      [1, -1], // diagonal up-right
      [-1, -1] // diagonal up-left
    ];

    for (final dir in directions) {
      final newX = x + dir[0];
      final newY = y + dir[1];

      // Check if within grid bounds
      if (newX < 0 ||
          newY < 0 ||
          newX > island.gridSteps ||
          newY > island.gridSteps) {
        continue;
      }

      // Find the grid cell at this position
      GridCell? cell;
      try {
        cell = island.grid.firstWhere(
          (cell) => cell.gridX == newX && cell.gridY == newY,
        );
      } catch (e) {
        cell = null;
      }

      // Skip if cell doesn't exist or is water
      if (cell == null || !cell.isLand) {
        continue;
      }

      // Add valid neighbor with appropriate cost (depth)
      // Diagonal movement costs more
      final bool isDiagonal = dir[0] != 0 && dir[1] != 0;
      final double moveCost = isDiagonal ? 1.4 : 1.0;

      // Terrain difficulty increases cost
      final double terrainCost = 1.0 + (cell.elevation * 2.0);

      neighbors.add(IslandCoordinatesState(newX, newY, island, targetPosition,
          depth: depth + (moveCost * terrainCost)));
    }

    return neighbors;
  }

  @override
  double heuristic() {
    if (targetPosition == null) return 0;

    // Find the grid cell that corresponds to our position
    GridCell? cell;
    try {
      cell = island.grid.firstWhere(
        (cell) => cell.gridX == x && cell.gridY == y,
      );
    } catch (e) {
      cell = null;
    }

    if (cell == null) return double.infinity;

    // Calculate distance to target
    return cell.center.distanceTo(targetPosition!);
  }

  @override
  String hash() => "($x, $y)";

  @override
  bool isGoal() {
    if (targetPosition == null) return false;

    // Find the grid cell that corresponds to our position
    GridCell? cell;
    try {
      cell = island.grid.firstWhere(
        (cell) => cell.gridX == x && cell.gridY == y,
      );
    } catch (e) {
      cell = null;
    }

    if (cell == null) return false;

    // Check if we're close enough to the target
    return cell.center.distanceTo(targetPosition!) < 10.0;
  }
}

// Extension method for Offset to calculate distance to another Offset
extension OffsetExtension on Offset {
  double distanceTo(Offset other) {
    return (this - other).distance;
  }
}
