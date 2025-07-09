# 🚢 Ship Boarding and Healing System

## Overview

The Ship Boarding and Healing System allows units with low health to automatically retreat to friendly ships for healing, then return to battle when fully recovered.

## 🎯 Problem Solved

**Before**: Units with low health would continue fighting until death, with no way to recover health during battle.

**After**: Units automatically retreat to ships when health drops below 50%, heal over time, and return to battle when fully healed.

## 🔧 How It Works

### 1. **Automatic Health Monitoring**
- Units continuously monitor their health percentage
- When health drops below 50% (`lowHealthThreshold`), they seek nearby ships
- Only triggers when not in active combat or under player control

### 2. **Ship Seeking Logic**
```dart
bool shouldSeekShip() {
  return health / maxHealth <= lowHealthThreshold &&  // Health below 50%
      !isInCombat &&                                  // Not currently fighting
      !forceRedirect &&                               // Not under player command
      targetShipId == null;                           // Not already seeking ship
}
```

### 3. **Ship Finding Algorithm**
- Searches for nearest friendly ship (same team)
- Checks if ship can accept boarding (`canBoardUnit()`)
- Calculates distance to find closest available ship
- Sets target ship and begins movement

### 4. **Movement and Boarding**
- Unit moves toward ship's boarding position
- When within boarding range (radius + 10), unit boards ship
- Unit becomes `isBoarded = true` and stops normal movement
- Ship adds unit to its `boardedUnitIds` list

### 5. **Healing Process**
- While boarded, unit heals at `healingRate` (10 HP/second)
- Health increases each frame: `health += healingRate * deltaTime`
- Unit remains on ship until fully healed

### 6. **Automatic Disembarking**
- When health reaches maximum, unit automatically disembarks
- Unit is positioned at ship's boarding position
- Ship removes unit from `boardedUnitIds`
- Unit returns to normal behavior (can engage in combat, follow orders)

## 🎮 Gameplay Features

### **Smart Retreat Behavior**
- ✅ Units retreat only when safe (not in active combat)
- ✅ Respects player commands (won't retreat if given direct orders)
- ✅ Finds nearest friendly ship automatically
- ✅ Won't retreat if no ships available

### **Balanced Healing**
- ✅ Healing rate: 10 HP/second (balanced for gameplay)
- ✅ Full healing takes 6-12 seconds depending on unit type
- ✅ Units return to battle automatically when healed
- ✅ Ships have limited boarding capacity (5 units max)

### **Visual Feedback**
- ✅ Debug logs show retreat and healing progress
- ✅ Units change state to `UnitState.moving` when seeking ship
- ✅ Clear boarding/disembarking notifications

## 🔧 Configuration

### **Adjustable Parameters**
```dart
// In UnitModel
double healingRate = 10.0;           // Health per second while on ship
double lowHealthThreshold = 0.5;     // 50% health triggers retreat

// In ShipModel  
int maxBoardingCapacity = 5;         // Max units that can board for healing
```

### **Health Thresholds by Unit Type**
- **Swordsman**: 120 HP → Retreats at 60 HP
- **Archer**: 100 HP → Retreats at 50 HP  
- **Captain**: 80 HP → Retreats at 40 HP

## 🧪 Testing

### **Comprehensive Test Suite**
- ✅ Health threshold detection
- ✅ Combat state prevention
- ✅ Healing rate calculation
- ✅ Automatic disembarking
- ✅ Ship finding logic

### **Test Results**
```
✓ Unit should seek ship when health is low
✓ Unit should not seek ship when in combat  
✓ Unit should heal while on ship
✓ Unit should disembark when fully healed
```

## 🎯 Expected Behavior

### **Low Health Unit Scenario**
1. **Unit takes damage** → Health drops to 45%
2. **Automatic detection** → `shouldSeekShip()` returns true
3. **Ship search** → Finds nearest friendly ship
4. **Movement** → Unit moves toward ship's boarding position
5. **Boarding** → Unit boards ship when in range
6. **Healing** → Health increases 10 HP/second
7. **Disembarking** → Unit leaves ship when fully healed
8. **Return to battle** → Unit resumes normal behavior

### **Debug Log Example**
```
🐛 Unit unit_blue_swordsman_2 seeking ship ship_blue_1 for healing (health: 54/120)
🐛 Unit unit_blue_swordsman_2 boarded ship ship_blue_1
🐛 Unit unit_blue_swordsman_2 fully healed, disembarking ship
```

## 🚀 Performance Impact

- **Minimal CPU usage**: Only active for low-health units
- **Smart triggering**: Doesn't interfere with normal gameplay
- **Efficient pathfinding**: Direct movement to ship boarding positions
- **Memory efficient**: No additional data structures required

## 🎮 Strategic Implications

### **Tactical Advantages**
- **Sustained battles**: Units can recover and return to fight
- **Ship positioning**: Ships become strategic healing points
- **Resource management**: Damaged units don't need to be replaced
- **Dynamic gameplay**: Battles can have multiple phases

### **Balancing Considerations**
- **Healing time**: 6-12 seconds prevents instant recovery
- **Boarding capacity**: Limited ship space creates strategic choices
- **Retreat conditions**: Units won't abandon critical fights
- **Ship vulnerability**: Healing ships become valuable targets

## 🔮 Future Enhancements

Potential improvements:
- **Healing upgrades**: Ship modifications to heal faster
- **Medical units**: Specialized healing units on ships
- **Healing costs**: Resource cost for ship healing
- **Visual effects**: Healing animations and ship activity indicators

The ship boarding and healing system adds strategic depth while maintaining balanced gameplay, giving players more tactical options and making battles more dynamic and engaging.
