import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assets_service.dart';
import 'game_state_service.dart';
import 'network_service.dart';
import 'pathfinding_service.dart';
import '../models/island_model.dart';

/// Global providers for core services
final assetsServiceProvider = Provider<AssetsService>((ref) => AssetsService());
final gameStateServiceProvider =
    Provider<GameStateService>((ref) => GameStateService());
final networkServiceProvider =
    Provider<NetworkService>((ref) => NetworkService());

/// PathfindingService provider that requires an island parameter
/// This should be created with a specific island instance when needed
Provider<PathfindingService> pathfindingServiceProvider(
    IslandGridModel island) {
  return Provider<PathfindingService>((ref) => PathfindingService(island));
}

/// Initialize all services that require async initialization
Future<void> initializeServices() async {
  // Add any async service initialization here
  // For example:
  // await assetsService.initialize();
}
