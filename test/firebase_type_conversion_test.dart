// test/firebase_type_conversion_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Type Conversion Tests', () {
    test('Convert Firebase Map<Object?, Object?> to Map<String, dynamic>', () {
      // Simulate Firebase data structure
      final firebaseData = <Object?, Object?>{
        'units': [
          <Object?, Object?>{
            'id': 'unit_blue_swordsman_1',
            'health': 100.0,
            'position': <Object?, Object?>{
              'x': 150.5,
              'y': 200.3,
            },
            'state': 'idle',
          }
        ],
        'ships': [
          <Object?, Object?>{
            'id': 'ship_blue_1',
            'position': <Object?, Object?>{
              'x': 100.0,
              'y': 150.0,
            },
            'cargo': <Object?, Object?>{
              'captain': 1,
              'swordsman': 5,
              'archer': 3,
            },
          }
        ],
        'timestamp': 1234567890,
      };

      // Test conversion function
      final converted = _convertToStringDynamicMap(firebaseData);
      
      // Verify structure
      expect(converted, isA<Map<String, dynamic>>());
      expect(converted['units'], isA<List>());
      expect(converted['ships'], isA<List>());
      expect(converted['timestamp'], equals(1234567890));
      
      // Verify nested structures
      final units = converted['units'] as List;
      expect(units.length, equals(1));
      
      final unit = units[0] as Map<String, dynamic>;
      expect(unit['id'], equals('unit_blue_swordsman_1'));
      expect(unit['health'], equals(100.0));
      
      final position = unit['position'] as Map<String, dynamic>;
      expect(position['x'], equals(150.5));
      expect(position['y'], equals(200.3));
    });
    
    test('Handle null and empty data', () {
      expect(_convertToStringDynamicMap(null), equals(<String, dynamic>{'data': null}));
      expect(_convertToStringDynamicMap({}), equals(<String, dynamic>{}));
      expect(_convertToStringDynamicMap('string'), equals(<String, dynamic>{'data': 'string'}));
    });
  });
}

/// Helper function to test type conversion
Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  } else if (data is Map) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      final stringKey = key.toString();
      if (value is Map) {
        result[stringKey] = _convertToStringDynamicMap(value);
      } else if (value is List) {
        result[stringKey] = value.map((item) => 
          item is Map ? _convertToStringDynamicMap(item) : item).toList();
      } else {
        result[stringKey] = value;
      }
    });
    return result;
  }
  return <String, dynamic>{'data': data};
}
