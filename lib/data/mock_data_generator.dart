import 'database_service.dart';

class MockDataGenerator {
  static Future<void> seedMockData(DatabaseService dbService) async {
    final connection = dbService.connection;

    // Check if vehicles exist
    final check = await connection.query('SELECT COUNT(*) FROM vehicles');
    final count = check.fetchAll()[0][0] as int;
    if (count > 0) return; // Already seeded

    // Insert 5 mock vehicles
    await connection.query('''
      INSERT INTO vehicles (id, reg_number, model) VALUES 
      ('v1', 'KA-01-HH-1234', 'Tata Ace EV'),
      ('v2', 'MH-12-AB-5678', 'Mahindra Treo'),
      ('v3', 'DL-04-CC-9012', 'Euler HiLoad'),
      ('v4', 'TN-09-DD-3456', 'Tata Ace EV'),
      ('v5', 'TS-07-EE-7890', 'Mahindra Treo');
    ''');

    // Insert some mock telemetry for each
    final now = DateTime.now().toIso8601String();
    // V1: MOVING
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$now', 'v1', 'soc', 85.0, '$now'),
      ('$now', 'v1', 'range', 120.0, '$now'),
      ('$now', 'v1', 'speed', 45.0, '$now'),
      ('$now', 'v1', 'ignition', 1.0, '$now');
    ''');

    // V2: IDLE (Alert: SOC < 20)
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$now', 'v2', 'soc', 15.0, '$now'),
      ('$now', 'v2', 'speed', 0.0, '$now'),
      ('$now', 'v2', 'ignition', 1.0, '$now');
    ''');

    // V3: STOPPED (Alert: SOC < 10)
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$now', 'v3', 'soc', 8.0, '$now'),
      ('$now', 'v3', 'speed', 0.0, '$now'),
      ('$now', 'v3', 'ignition', 0.0, '$now');
    ''');

    // V4: OFFLINE (last ping > 10 mins ago)
    final past =
        DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String();
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$past', 'v4', 'soc', 50.0, '$past'),
      ('$past', 'v4', 'ignition', 0.0, '$past');
    ''');

    // V5: Alert overheating
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$now', 'v5', 'soc', 90.0, '$now'),
      ('$now', 'v5', 'battery_temp', 48.0, '$now'),
      ('$now', 'v5', 'speed', 60.0, '$now'),
      ('$now', 'v5', 'ignition', 1.0, '$now');
    ''');

    // Add some SOC history for V1 to see sparkline
    for (int i = 0; i < 50; i++) {
      final t =
          DateTime.now().subtract(Duration(minutes: 50 - i)).toIso8601String();
      final soc = 100.0 - (i * 0.3); // Gradually decreasing
      await connection.query('''
        INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
        ('$t', 'v1', 'soc', $soc, '$t');
      ''');
    }
  }
}
