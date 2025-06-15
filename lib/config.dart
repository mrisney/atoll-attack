import 'package:flame/components.dart';

// Default island settings
const double kDefaultAmplitude = 1.9;
const double kDefaultWavelength = 0.22;
const double kDefaultBias = -0.56;
const double kDefaultIslandRadius = 1.11;
const int kDefaultSeed = 12345;

// Default game size (you can override with MediaQuery if needed)
final Vector2 kDefaultGameSize = Vector2(400, 900);

// Total units per team
const int kTotalUnitsPerTeam = 25;

// Unit limits per team (captain is still limited to 1)
const int kMaxCaptainsPerTeam = 1;
const int kMaxArchersPerTeam = kTotalUnitsPerTeam - 1; // Allow all units to be archers except captain
const int kMaxSwordsmenPerTeam = kTotalUnitsPerTeam - 1; // Allow all units to be swordsmen except captain

// Unit speed settings
const double kCaptainSpeed = 5.0; // Slower captain speed
const double kArcherSpeed = 12.0;
const double kSwordsmanSpeed = 10.0;

// Spawn locations - these are fallbacks if coastline detection fails
const double kNorthSpawnY = 100.0;  // Y position for north spawn
const double kSouthSpawnY = 800.0;  // Y position for south spawn

// Fallback spawn locations if coastline detection fails
final Vector2 kBlueSpawnLocation = Vector2(200, 100);  // Blue team spawns at north
final Vector2 kRedSpawnLocation = Vector2(200, 800);   // Red team spawns at south

// Visual settings
const bool kShowGrid = false;  // Don't show grid by default
const bool kSmoothContours = true;  // Use smooth contours for topographic map
const int kContourSmoothingLevel = 5;  // Higher value = smoother contours
const bool kShowElevationLabels = true;  // Show elevation numbers on contours

// Game balance settings
const double kRulesUpdateInterval = 0.1; // Update rules 10 times per second
const double kDeathAnimationDuration = 0.8; // Death animation duration in seconds
const double kVictoryAnimationDuration = 0.5; // Victory animation duration in seconds