import 'dart:math';
import '../data/database_service.dart';
import 'package:uuid/uuid.dart';

class TripCalculator {
  static const _uuid = Uuid();

  // Haversine distance in meters
  static double distance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  /// Evaluates telemetry and determines geofence entries/exits to create trips.
  /// Must be idempotent and event-time aware.
  static Future<void> processTelemetry(
      DatabaseService dbService, String vehicleId) async {
    final connection = dbService.connection;

    // 1. Get all location telemetry ordered by event time
    final locQuery = await connection.query('''
      SELECT timestamp, signal_value, signal_name 
      FROM telemetry 
      WHERE vehicle_id = '$vehicleId' AND signal_name IN ('lat', 'lng')
      ORDER BY timestamp ASC
    ''');

    // Group into lat/lng pairs by timestamp
    final Map<String, Map<String, double>> locByTime = {};
    for (var row in locQuery.fetchAll()) {
      final t = (row[0] as DateTime).toIso8601String();
      final val = row[1] as double;
      final name = row[2] as String;
      locByTime.putIfAbsent(t, () => {});
      locByTime[t]![name] = val;
    }

    // 2. Get active geofences
    final gfQuery = await connection.query(
        "SELECT id, lat, lng, radius FROM geofences WHERE active = true");
    final geofences = gfQuery
        .fetchAll()
        .map((row) => {
              'id': row[0] as String,
              'lat': row[1] as double,
              'lng': row[2] as double,
              'rad': row[3] as double,
            })
        .toList();
    // 3. Process ordered locations to find transitions deterministically
    // We maintain a "current geofence" state and look for confirmed exits
    // (distance > radius + jitter buffer) and confirmed entries (distance < radius - jitter buffer).
    String? currentGfId;
    bool inProgressTrip = false;
    String? activeTripId;

    // Reset trips for this vehicle to rebuild idempotently (in a real app, only process new data)
    await connection.query("DELETE FROM trips WHERE vehicle_id = '$vehicleId'");

    for (final entry in locByTime.entries) {
      final t = entry.key;
      final lat = entry.value['lat'];
      final lng = entry.value['lng'];

      if (lat == null || lng == null) continue;

      if (currentGfId != null) {
        // Check if we exited the current geofence
        final gf = geofences.firstWhere((g) => g['id'] == currentGfId,
            orElse: () => {});
        if (gf.isNotEmpty) {
          final dist =
              distance(lat, lng, gf['lat'] as double, gf['lng'] as double);
          // Confirm exit: outside radius + 50m jitter buffer
          if (dist > (gf['rad'] as double) + 50.0) {
            currentGfId = null;
            // Start a new trip  g.      f
            activeTripId = _uuid.v4();
            await connection.query(
                "INSERT INTO trips (id, vehicle_id, start_time, origin_geofence_id, status) VALUES ('$activeTripId', '$vehicleId', '$t', '${gf['id']}', 'IN_PROGRESS')");
            inProgressTrip = true;
          }
        } else {
          currentGfId = null; // Geofence was deleted or deactivated
        }
      }

      if (currentGfId == null) {
        // Check if we entered any geofence
        for (final gf in geofences) {
          final dist =
              distance(lat, lng, gf['lat'] as double, gf['lng'] as double);
          // Confirm entry: inside radius - 10m jitter buffer
          if (dist < (gf['rad'] as double) - 10.0) {
            currentGfId = gf['id'] as String;
            if (inProgressTrip && activeTripId != null) {
              // Complete the active trip
              await connection.query(
                  "UPDATE trips SET end_time = '$t', destination_geofence_id = '$currentGfId', status = 'COMPLETED' WHERE id = '$activeTripId'");
              inProgressTrip = false;
              activeTripId = null;
            } else {}
            break;
          }
        }
      }
    }
  }
}
