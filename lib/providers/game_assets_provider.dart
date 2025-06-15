import 'package:riverpod/riverpod.dart';
import '../services/assets_service.dart';

/// Provider for the assets service
final assetsServiceProvider = Provider<AssetsService>((ref) {
  return AssetsService();
});

/// Provider for tracking if assets are loaded
final assetsLoadedProvider = FutureProvider<bool>((ref) async {
  final assetsService = ref.watch(assetsServiceProvider);
  
  if (!assetsService.assetsLoaded) {
    await assetsService.preloadAssets();
  }
  
  return assetsService.assetsLoaded;
});

/// Provider for toggling between simple shapes and artwork
final useAssetsProvider = StateProvider<bool>((ref) {
  final assetsLoaded = ref.watch(assetsLoadedProvider);
  // Default to false until assets are loaded
  return assetsLoaded.maybeWhen(
    data: (loaded) => loaded,
    orElse: () => false,
  );
});