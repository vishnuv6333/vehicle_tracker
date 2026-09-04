import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class ScaleBackfill {
  static Future<void> runBackfill(DatabaseService dbService) async {
    final connection = dbService.connection;
    final rand = Random();

    debugPrint('Starting backfill for 500 vehicles...');

    // Clear existing data for clean backfill
    await connection.query('DELETE FROM telemetry');
    await connection.query('DELETE FROM alerts');
    await connection.query('DELETE FROM trips');
    await connection.query('DELETE FROM geofences');
    await connection.query('DELETE FROM vehicles');

    // 1. Generate 500 vehicles in bulk
    final vIds = <String>[];
    final vehicleBuffer = StringBuffer();
    vehicleBuffer.write('INSERT INTO vehicles (id, reg_number, model) VALUES ');

    for (int i = 0; i < 500; i++) {
      final id = 'vh_$i';
      vIds.add(id);
      final regNumber = 'REG-${i.toString().padLeft(4, '0')}';
      final model = 'Scale Model ${i % 5 + 1}';
      vehicleBuffer.write("('$id', '$regNumber', '$model')");
      if (i < 499) vehicleBuffer.write(', ');
    }
    await connection.query(vehicleBuffer.toString());

    debugPrint('500 vehicles created. Seeding demo geofences & telemetry...');

    // 2. Seed default demo geofences
    await connection.query('''
      INSERT INTO geofences (id, name, lat, lng, radius, active) VALUES
      ('gf_hq_1', 'Headquarters', 12.9716, 77.5946, 500.0, true),
      ('gf_wh_1', 'Warehouse A', 13.0000, 77.6000, 300.0, true),
      ('gf_md_1', 'Maintenance Depot', 12.9500, 77.5800, 200.0, false)
    ''');

    // 3. Generate initial telemetry entries for the 500 vehicles
    final telemetryBuffer = StringBuffer();
    telemetryBuffer.write(
        "INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES ");

    final now = DateTime.now();
    final telemetryEntries = <String>[];

    for (int i = 0; i < vIds.length; i++) {
      final vId = vIds[i];
      final timeStr =
          now.subtract(Duration(seconds: rand.nextInt(300))).toIso8601String();
      final soc = 20.0 + rand.nextDouble() * 80.0;
      final range = soc * 1.5;
      final speed = rand.nextBool() ? (rand.nextDouble() * 60.0) : 0.0;
      final ignition = speed > 0 ? 1.0 : (rand.nextBool() ? 1.0 : 0.0);
      final batteryTemp = 25.0 + rand.nextDouble() * 20.0;
      final odometer = 1000.0 + rand.nextDouble() * 50000.0;
      final lat = 12.9716 + (rand.nextDouble() - 0.5) * 0.1;
      final lng = 77.5946 + (rand.nextDouble() - 0.5) * 0.1;

      telemetryEntries.add("('$timeStr', '$vId', 'soc', $soc, '$timeStr')");
      telemetryEntries.add("('$timeStr', '$vId', 'range', $range, '$timeStr')");
      telemetryEntries.add("('$timeStr', '$vId', 'speed', $speed, '$timeStr')");
      telemetryEntries
          .add("('$timeStr', '$vId', 'ignition', $ignition, '$timeStr')");
      telemetryEntries.add(
          "('$timeStr', '$vId', 'battery_temp', $batteryTemp, '$timeStr')");
      telemetryEntries
          .add("('$timeStr', '$vId', 'odometer', $odometer, '$timeStr')");
      telemetryEntries.add("('$timeStr', '$vId', 'lat', $lat, '$timeStr')");
      telemetryEntries.add("('$timeStr', '$vId', 'lng', $lng, '$timeStr')");
    }

    // Add structured location trajectory for vh_0 to demonstrate automatic trip building
    final t0 = now.subtract(const Duration(minutes: 40)).toIso8601String();
    final t1 = now.subtract(const Duration(minutes: 30)).toIso8601String();
    final t2 = now.subtract(const Duration(minutes: 20)).toIso8601String();
    final t3 = now.subtract(const Duration(minutes: 10)).toIso8601String();

    telemetryEntries.add("('$t0', 'vh_0', 'lat', 12.9716, '$t0')");
    telemetryEntries.add("('$t0', 'vh_0', 'lng', 77.5946, '$t0')");

    telemetryEntries.add("('$t1', 'vh_0', 'lat', 12.9850, '$t1')");
    telemetryEntries.add("('$t1', 'vh_0', 'lng', 77.5970, '$t1')");

    telemetryEntries.add("('$t2', 'vh_0', 'lat', 13.0000, '$t2')");
    telemetryEntries.add("('$t2', 'vh_0', 'lng', 77.6000, '$t2')");

    telemetryEntries.add("('$t3', 'vh_0', 'lat', 12.9860, '$t3')");
    telemetryEntries.add("('$t3', 'vh_0', 'lng', 77.5975, '$t3')");

    telemetryBuffer.write(telemetryEntries.join(', '));
    await connection.query(telemetryBuffer.toString());

    // Calculate automatic trips for vh_0

    debugPrint('Backfill & trip calculation complete for 500 vehicles!');
  }
}
