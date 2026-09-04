import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class ScaleBackfill {
  static Future<void> runBackfill(DatabaseService dbService) async {
    final connection = dbService.connection;
    final rand = Random();

    debugPrint('Starting backfill for 500 vehicles...');
    // await connection.execute('DELETE FROM telemetry');
    // await connection.execute('DELETE FROM alerts');
    // await connection.execute('DELETE FROM trips');
    // await connection.execute('DELETE FROM geofences');
    // await connection.execute('DELETE FROM vehicles');

    // 1. Generate 500 vehicles
    final vIds = <String>[];
    for (int i = 0; i < 500; i++) {
      final id = 'vh_$i';
      vIds.add(id);
      await connection.query('''
        INSERT INTO vehicles (id, reg_number, model) 
        VALUES ('$id', 'REG-${i.toString().padLeft(4, '0')}', 'Scale Model $i')
      ''');
    }

    debugPrint('Vehicles created. Generating 2,000,000 signal rows...');

    // 2. Generate 2 million signal rows
    // To avoid out of memory, we should batch inserts or use a DuckDB appender if available.
    // Given the dart_duckdb wrapper, Appender is available but we'll stick to batched INSERTs or an Appender if we can import it.
    // For simplicity in a script, let's just do bulk inserts in blocks of 50,000.
    final totalRows = 2000000;
    final batchSize = 10000;
    int generated = 0;

    final signals = [
      'soc',
      'range',
      'speed',
      'ignition',
      'battery_temp',
      'odometer',
      'lat',
      'lng'
    ];

    while (generated < totalRows) {
      final buffer = StringBuffer();
      buffer.write(
          "INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES ");

      for (int i = 0; i < batchSize; i++) {
        final vId = vIds[rand.nextInt(vIds.length)];
        final sig = signals[rand.nextInt(signals.length)];
        final val = rand.nextDouble() * 100;
        final t = DateTime.now()
            .subtract(Duration(minutes: rand.nextInt(10000)))
            .toIso8601String();

        buffer.write("('$t', '$vId', '$sig', $val, '$t')");
        if (i < batchSize - 1) buffer.write(", ");
      }

      await connection.query(buffer.toString());
      generated += batchSize;
      debugPrint('Inserted $generated / $totalRows rows');
    }

    debugPrint('Backfill complete!');
  }
}
