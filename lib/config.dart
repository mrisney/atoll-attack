import 'package:flame/components.dart';

// Default island settings
const double kDefaultAmplitude = 1.9;
const double kDefaultWavelength = 0.22;
const double kDefaultBias = -0.56;
const double kDefaultIslandRadius = 1.11;
const int kDefaultSeed = 12345;

// Default game size (you can override with MediaQuery if needed)
final Vector2 kDefaultGameSize = Vector2(400, 900);

// Game control defaults
const int kDefaultUnitSpawnCount = 12;

// Total units per team
const int kTotalUnitsPerTeam = 25;

// Unit limits per team (captain is still limited to 1)
const int kMaxCaptainsPerTeam = 1;
const int kMaxArchersPerTeam = kTotalUnitsPerTeam - 1; // Allow all units to be archers except captain
const int kMaxSwordsmenPerTeam = kTotalUnitsPerTeam - 1; // Allow all units to be swordsmen except captain

// Game balance settings
const double kRulesUpdateInterval = 0.1; // Update rules 10 times per second
const double kDeathAnimationDuration =
    0.8; // Death animation duration in seconds
const double kVictoryAnimationDuration =
    0.5; // Victory animation duration in seconds
