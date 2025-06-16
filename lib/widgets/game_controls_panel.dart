// Step 1: Update lib/widgets/game_controls_panel.dart
// Replace your current GameControlsPanel with this responsive version:

import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import '../providers/game_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Add this import
import '../models/unit_model.dart';
import '../constants/game_config.dart';

class GameControlsPanel extends ConsumerWidget {
  final VoidCallback? onClose;
  const GameControlsPanel({Key? key, this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final unitCounts = ref.watch(unitCountsProvider);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          // Responsive sizing using ScreenUtil
          maxWidth: ScreenUtil().orientation == Orientation.landscape
              ? 600.w // 60% of design width in landscape
              : 350.w, // Responsive width in portrait
          minWidth: 320.w, // Minimum responsive width
          maxHeight: ScreenUtil().orientation == Orientation.landscape
              ? 400.h // Responsive height in landscape
              : 220.h, // Smaller responsive height in portrait
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12.r), // Responsive border radius
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.w, // Responsive border width
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 12.h, // Responsive vertical padding
            horizontal: 16.w, // Responsive horizontal padding
          ),
          child: ScreenUtil().orientation == Orientation.landscape
              ? _buildLandscapeLayout(context, unitCounts, game)
              : _buildPortraitLayout(context, unitCounts, game),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(
      BuildContext context, Map<String, int> unitCounts, game) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with close button - responsive
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spawn Units',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp, // Responsive font size
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              width: 24.w, // Responsive button size
              height: 24.h,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white70, size: 16.sp),
                onPressed: onClose,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),

        SizedBox(height: 8.h), // Responsive spacing

        // Compact unit count display - responsive
        _buildCompactUnitCountDisplay(unitCounts),

        SizedBox(height: 8.h), // Responsive spacing

        // Spawn buttons in horizontal layout - responsive
        _buildResponsiveSpawnButtons(unitCounts, game),

        SizedBox(height: 4.h), // Responsive spacing

        // Instructions - responsive
        Text(
          'Drag to select • Click to move • Tap to spawn',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 9.sp, // Responsive font size
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(
      BuildContext context, Map<String, int> unitCounts, game) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with close button - responsive
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spawn Units',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp, // Larger responsive font in landscape
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              width: 28.w, // Responsive button size
              height: 28.h,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white70, size: 20.sp),
                onPressed: onClose,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),

        SizedBox(height: 12.h), // Responsive spacing

        // Extended unit count display for landscape - responsive
        _buildExtendedUnitCountDisplay(unitCounts),

        SizedBox(height: 16.h), // Responsive spacing

        // Larger spawn buttons for landscape - responsive
        _buildLandscapeSpawnButtons(unitCounts, game),

        SizedBox(height: 8.h), // Responsive spacing

        // Instructions - responsive
        Text(
          'Drag to select units • Click to move selected units • Tap buttons to spawn units',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11.sp, // Responsive font size
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCompactUnitCountDisplay(Map<String, int> unitCounts) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 8.w, vertical: 4.h), // Responsive padding
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6.r), // Responsive border radius
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTeamInfo('Blue', unitCounts, Colors.blue, true),
          Container(
            height: 35.h, // Responsive height
            width: 1.w, // Responsive width
            color: Colors.white.withOpacity(0.3),
          ),
          _buildTeamInfo('Red', unitCounts, Colors.red, false),
          Container(
            height: 35.h, // Responsive height
            width: 1.w, // Responsive width
            color: Colors.white.withOpacity(0.3),
          ),
          _buildCompactLegend(),
        ],
      ),
    );
  }

  Widget _buildExtendedUnitCountDisplay(Map<String, int> unitCounts) {
    return Container(
      padding: EdgeInsets.all(12.w), // Responsive padding
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8.r), // Responsive border radius
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildDetailedTeamInfo(
                  'Blue Team', unitCounts, Colors.blue, true)),
          SizedBox(width: 20.w), // Responsive spacing
          Container(
              height: 60.h, // Responsive height
              width: 1.w, // Responsive width
              color: Colors.white.withOpacity(0.3)),
          SizedBox(width: 20.w), // Responsive spacing
          Expanded(
              child: _buildDetailedTeamInfo(
                  'Red Team', unitCounts, Colors.red, false)),
        ],
      ),
    );
  }

  Widget _buildTeamInfo(
      String team, Map<String, int> unitCounts, Color color, bool isBlue) {
    String prefix = isBlue ? 'blue' : 'red';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.w, // Responsive width
              height: 6.h, // Responsive height
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 3.w), // Responsive spacing
            Text(
              team,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp, // Responsive font size
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h), // Responsive spacing
        Text(
          'C:${unitCounts['${prefix}CaptainsRemaining']} A:${unitCounts['${prefix}ArchersRemaining']} S:${unitCounts['${prefix}SwordsmenRemaining']}',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 8.sp, // Responsive font size
            fontFamily: 'monospace',
          ),
        ),
        Text(
          'Total: ${unitCounts['${prefix}Remaining']}',
          style: TextStyle(
            color: color,
            fontSize: 9.sp, // Responsive font size
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedTeamInfo(
      String teamName, Map<String, int> unitCounts, Color color, bool isBlue) {
    String prefix = isBlue ? 'blue' : 'red';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12.w, // Responsive width
              height: 12.h, // Responsive height
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8.w), // Responsive spacing
            Text(
              teamName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp, // Responsive font size
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h), // Responsive spacing
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Captains:', style: _labelStyle),
            Text('${unitCounts['${prefix}CaptainsRemaining']}',
                style: _valueStyle),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Archers:', style: _labelStyle),
            Text('${unitCounts['${prefix}ArchersRemaining']}',
                style: _valueStyle),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Swordsmen:', style: _labelStyle),
            Text('${unitCounts['${prefix}SwordsmenRemaining']}',
                style: _valueStyle),
          ],
        ),
      ],
    );
  }

  // Responsive text styles
  TextStyle get _labelStyle =>
      TextStyle(color: Colors.white70, fontSize: 12.sp // Responsive font size
          );

  TextStyle get _valueStyle => TextStyle(
      color: Colors.white,
      fontSize: 12.sp, // Responsive font size
      fontWeight: FontWeight.w600);

  Widget _buildCompactLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Legend',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9.sp, // Responsive font size
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'C=Captain($kMaxCaptainsPerTeam)',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 7.sp, // Responsive font size
          ),
        ),
        Text(
          'A=Archer($kMaxArchersPerTeam)',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 7.sp, // Responsive font size
          ),
        ),
        Text(
          'S=Swords($kMaxSwordsmenPerTeam)',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 7.sp, // Responsive font size
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveSpawnButtons(Map<String, int> unitCounts, game) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Blue Team:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp, // Responsive font size
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h), // Responsive spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactUnitButton(
                    'C',
                    Icons.star,
                    Colors.blue.shade700,
                    () => game.spawnSingleUnit(UnitType.captain, Team.blue),
                    unitCounts['blueCaptainsRemaining']! > 0,
                    '${unitCounts['blueCaptainsRemaining']}',
                  ),
                  _buildCompactUnitButton(
                    'A',
                    Icons.sports_esports,
                    Colors.blue.shade500,
                    () => game.spawnSingleUnit(UnitType.archer, Team.blue),
                    unitCounts['blueArchersRemaining']! > 0,
                    '${unitCounts['blueArchersRemaining']}',
                  ),
                  _buildCompactUnitButton(
                    'S',
                    Icons.shield,
                    Colors.blue.shade300,
                    () => game.spawnSingleUnit(UnitType.swordsman, Team.blue),
                    unitCounts['blueSwordsmenRemaining']! > 0,
                    '${unitCounts['blueSwordsmenRemaining']}',
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w), // Responsive spacing
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Red Team:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp, // Responsive font size
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h), // Responsive spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactUnitButton(
                    'C',
                    Icons.star,
                    Colors.red.shade700,
                    () => game.spawnSingleUnit(UnitType.captain, Team.red),
                    unitCounts['redCaptainsRemaining']! > 0,
                    '${unitCounts['redCaptainsRemaining']}',
                  ),
                  _buildCompactUnitButton(
                    'A',
                    Icons.sports_esports,
                    Colors.red.shade500,
                    () => game.spawnSingleUnit(UnitType.archer, Team.red),
                    unitCounts['redArchersRemaining']! > 0,
                    '${unitCounts['redArchersRemaining']}',
                  ),
                  _buildCompactUnitButton(
                    'S',
                    Icons.shield,
                    Colors.red.shade300,
                    () => game.spawnSingleUnit(UnitType.swordsman, Team.red),
                    unitCounts['redSwordsmenRemaining']! > 0,
                    '${unitCounts['redSwordsmenRemaining']}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeSpawnButtons(Map<String, int> unitCounts, game) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                'Blue Team',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp, // Responsive font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h), // Responsive spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLargeUnitButton(
                    'Captain',
                    Icons.star,
                    Colors.blue.shade700,
                    () => game.spawnSingleUnit(UnitType.captain, Team.blue),
                    unitCounts['blueCaptainsRemaining']! > 0,
                    '${unitCounts['blueCaptainsRemaining']}',
                  ),
                  _buildLargeUnitButton(
                    'Archer',
                    Icons.sports_esports,
                    Colors.blue.shade500,
                    () => game.spawnSingleUnit(UnitType.archer, Team.blue),
                    unitCounts['blueArchersRemaining']! > 0,
                    '${unitCounts['blueArchersRemaining']}',
                  ),
                  _buildLargeUnitButton(
                    'Swordsman',
                    Icons.shield,
                    Colors.blue.shade300,
                    () => game.spawnSingleUnit(UnitType.swordsman, Team.blue),
                    unitCounts['blueSwordsmenRemaining']! > 0,
                    '${unitCounts['blueSwordsmenRemaining']}',
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 24.w), // Responsive spacing
        Expanded(
          child: Column(
            children: [
              Text(
                'Red Team',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp, // Responsive font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h), // Responsive spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLargeUnitButton(
                    'Captain',
                    Icons.star,
                    Colors.red.shade700,
                    () => game.spawnSingleUnit(UnitType.captain, Team.red),
                    unitCounts['redCaptainsRemaining']! > 0,
                    '${unitCounts['redCaptainsRemaining']}',
                  ),
                  _buildLargeUnitButton(
                    'Archer',
                    Icons.sports_esports,
                    Colors.red.shade500,
                    () => game.spawnSingleUnit(UnitType.archer, Team.red),
                    unitCounts['redArchersRemaining']! > 0,
                    '${unitCounts['redArchersRemaining']}',
                  ),
                  _buildLargeUnitButton(
                    'Swordsman',
                    Icons.shield,
                    Colors.red.shade300,
                    () => game.spawnSingleUnit(UnitType.swordsman, Team.red),
                    unitCounts['redSwordsmenRemaining']! > 0,
                    '${unitCounts['redSwordsmenRemaining']}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactUnitButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool enabled,
    String count,
  ) {
    return SizedBox(
      width: 45.w, // Responsive width
      height: 40.h, // Responsive height
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: 1.w, vertical: 1.h), // Responsive padding
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 7.sp, // Responsive font size
          ),
          elevation: enabled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(6.r), // Responsive border radius
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 10.sp), // Responsive icon size
            Text(label,
                style: TextStyle(fontSize: 7.sp)), // Responsive font size
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 2.w, vertical: 1.h), // Responsive padding
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius:
                    BorderRadius.circular(4.r), // Responsive border radius
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 7.sp, // Responsive font size
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeUnitButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool enabled,
    String count,
  ) {
    return SizedBox(
      width: 80.w, // Responsive width
      height: 60.h, // Responsive height
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: 4.w, vertical: 4.h), // Responsive padding
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10.sp, // Responsive font size
          ),
          elevation: enabled ? 3 : 0,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8.r), // Responsive border radius
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16.sp), // Responsive icon size
            Text(label,
                style: TextStyle(fontSize: 10.sp)), // Responsive font size
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 4.w, vertical: 2.h), // Responsive padding
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius:
                    BorderRadius.circular(8.r), // Responsive border radius
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 10.sp, // Responsive font size
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
