import 'database_service.dart';

class MockDataGenerator {
  static Future<void> seedMockData(DatabaseService dbService) async {
    final connection = dbService.connection;

    // Wipe existing data to ensure a clean slate for testing our newest changes
    // await connection.execute('DELETE FROM telemetry');
    // await connection.execute('DELETE FROM alerts');
    // await connection.execute('DELETE FROM trips');
    // await connection.execute('DELETE FROM geofences');
    // await connection.execute('DELETE FROM vehicles');

    // Insert 5 mock vehicles
    await connection.query('''
      INSERT INTO vehicles (id, reg_number, model) VALUES 
      ('v1', 'KA-01-HH-1234', 'Tata Ace EV'),
      ('v2', 'MH-12-AB-5678', 'Mahindra Treo'),
      ('v3', 'DL-04-CC-9012', 'Euler HiLoad'),
      ('v4', 'TN-09-DD-3456', 'Tata Ace EV'),
      ('v5', 'TS-07-EE-7890', 'Mahindra Treo');
    ''');

    // Insert 3 mock Geofences
    final hqId = 'gf_hq_1';
    final hqLat = 12.9716;
    final hqLng = 77.5946;
    await connection.query('''
      INSERT INTO geofences (id, name, lat, lng, radius, active) VALUES
      ('$hqId', 'Headquarters', $hqLat, $hqLng, 500.0, true),
      ('gf_wh_1', 'Warehouse A', 13.0, 77.6, 300.0, true),
      ('gf_md_1', 'Maintenance Depot', 12.95, 77.58, 200.0, false)
    ''');

    // Insert some mock telemetry for each
    // V1: COMPLETED TRIP (Inside HQ -> Outside -> Inside HQ)
    final past10m =
        DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String();
    final past5m =
        DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
    final now = DateTime.now().toIso8601String();

    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      -- 10 mins ago: Inside HQ
      ('$past10m', 'v1', 'lat', $hqLat, '$past10m'),
      ('$past10m', 'v1', 'lng', $hqLng, '$past10m'),
      
      -- 5 mins ago: Outside HQ (Starts trip)
      ('$past5m', 'v1', 'lat', 12.9780, '$past5m'),
      ('$past5m', 'v1', 'lng', 77.5950, '$past5m'),

      -- Now: Back inside HQ (Completes trip)
      ('$now', 'v1', 'soc', 85.0, '$now'),
      ('$now', 'v1', 'range', 120.0, '$now'),
      ('$now', 'v1', 'speed', 0.0, '$now'),
      ('$now', 'v1', 'ignition', 0.0, '$now'),
      ('$now', 'v1', 'lat', $hqLat, '$now'), 
      ('$now', 'v1', 'lng', $hqLng, '$now');
    ''');

    // V2: IDLE (Alert: SOC < 20, Inside HQ)
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$now', 'v2', 'soc', 15.0, '$now'),
      ('$now', 'v2', 'speed', 0.0, '$now'),
      ('$now', 'v2', 'ignition', 1.0, '$now'),
      ('$now', 'v2', 'lat', $hqLat, '$now'),
      ('$now', 'v2', 'lng', $hqLng, '$now');
    ''');

    // V3: STOPPED (Alert: SOC < 10, Inside HQ)
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$now', 'v3', 'soc', 8.0, '$now'),
      ('$now', 'v3', 'speed', 0.0, '$now'),
      ('$now', 'v3', 'ignition', 0.0, '$now'),
      ('$now', 'v3', 'lat', $hqLat, '$now'),
      ('$now', 'v3', 'lng', $hqLng, '$now');
    ''');

    // V4: OFFLINE (last ping > 10 mins ago, Outside HQ)
    final past =
        DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String();
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$past', 'v4', 'soc', 50.0, '$past'),
      ('$past', 'v4', 'ignition', 0.0, '$past'),
      ('$past', 'v4', 'lat', 12.9800, '$past'),
      ('$past', 'v4', 'lng', 77.6000, '$past');
    ''');

    // V5: Alert overheating (Outside HQ)
    await connection.query('''
      INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
      ('$now', 'v5', 'soc', 90.0, '$now'),
      ('$now', 'v5', 'battery_temp', 48.0, '$now'),
      ('$now', 'v5', 'speed', 60.0, '$now'),
      ('$now', 'v5', 'ignition', 1.0, '$now'),
      ('$now', 'v5', 'lat', 13.0000, '$now'),
      ('$now', 'v5', 'lng', 77.6100, '$now');
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

    // Process trips for mock vehicles to prepopulate active trip counts
  }
}
