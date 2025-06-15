import 'dart:ui';
import 'package:a_star/a_star.dart';
import 'package:flame/components.dart';
import '../models/island_model.dart';
import '../models/island_coordinates_state.dart';

class PathfindingService {
  final IslandGridModel island;
  
  PathfindingService(this.island);
  
  /// Find a path from start to target position using A* algorithm
  List<Vector2>? findPath(Vector2 start, Vector2 target) {
    // Convert world positions to grid coordinates
    final startCell = _findNearestGridCell(start);
    final targetCell = _findNearestGridCell(target);
    
    if (startCell == null || targetCell == null) {
      return null;
    }
    
    // Create start state
    final startState = IslandCoordinatesState(
      startCell.gridX, 
      startCell.gridY, 
      island, 
      Offset(target.x, target.y)
    );
    
    // Run A* algorithm
    final result = aStar(startState);
    if (result == null) {
      return null; // No path found
    }
    
    // Convert path to world positions
    final path = result.reconstructPath();
    final worldPath = <Vector2>[];
    
    for (final state in path) {
      final cell = island.grid.firstWhere(
        (cell) => cell.gridX == state.x && cell.gridY == state.y,
        orElse: () => null as GridCell,
      );
      
      if (cell != null) {
        worldPath.add(Vector2(cell.center.dx, cell.center.dy));
      }
    }
    
    // Add the actual target as the final destination
    worldPath.add(target);
    
    return worldPath;
  }
  
  /// Find the nearest grid cell to a world position
  GridCell? _findNearestGridCell(Vector2 position) {
    GridCell? nearest;
    double minDistance = double.infinity;
    
    for (final cell in island.grid) {
      final distance = (Vector2(cell.center.dx, cell.center.dy) - position).length;
      if (distance < minDistance) {
        minDistance = distance;
        nearest = cell;
      }
    }
    
    return nearest;
  }
}