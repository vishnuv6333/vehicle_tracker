import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/database_service.dart';
import 'geofence_event.dart';
import 'geofence_state.dart';
import '../models/geofence.dart';
import '../utils/trip_calculator.dart';
import 'package:uuid/uuid.dart';

class GeofenceBloc extends Bloc<GeofenceEvent, GeofenceState> {
  final DatabaseService _dbService;
  final _uuid = const Uuid();

  GeofenceBloc(this._dbService) : super(const GeofenceState()) {
    on<LoadGeofences>(_onLoadGeofences);
    on<AddGeofence>(_onAddGeofence);
    on<ToggleGeofence>(_onToggleGeofence);
    on<RecalculateAllTrips>(_onRecalculateAllTrips);
    on<EditGeofence>(_onEditGeofence);
    on<AddDemoGeofenceWithTrips>(_onAddDemoGeofenceWithTrips);
  }

  Future<void> _onLoadGeofences(
      LoadGeofences event, Emitter<GeofenceState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final connection = _dbService.connection;

      var result = await connection.query('SELECT * FROM geofences');
      var rows = result.fetchAll();

      if (rows.isEmpty) {
        await connection.query('''
          INSERT INTO geofences (id, name, lat, lng, radius, active) VALUES
          ('gf_hq_1', 'Headquarters', 12.9716, 77.5946, 500.0, true),
          ('gf_wh_1', 'Warehouse A', 13.0000, 77.6000, 300.0, true),
          ('gf_md_1', 'Maintenance Depot', 12.9500, 77.5800, 200.0, false)
        ''');
        result = await connection.query('SELECT * FROM geofences');
        rows = result.fetchAll();
      }

      final geofences = <Geofence>[];
      for (var row in rows) {
        geofences.add(Geofence(
          id: row[0] as String,
          name: row[1] as String,
          lat: row[2] as double,
          lng: row[3] as double,
          radius: row[4] as double,
          active: row[5] == true || row[5] == 1,
        ));
      }

      // Calculate active vehicle counts inside geofences
      // A vehicle is inside a geofence if its latest trip is COMPLETED
      final countsQuery = await connection.query('''
        SELECT t.destination_geofence_id, COUNT(*)
        FROM trips t
        INNER JOIN (
          SELECT vehicle_id, MAX(start_time) as max_time 
          FROM trips 
          GROUP BY vehicle_id
        ) latest ON t.vehicle_id = latest.vehicle_id AND t.start_time = latest.max_time
        WHERE t.status = 'COMPLETED' AND t.destination_geofence_id IS NOT NULL
        GROUP BY t.destination_geofence_id
      ''');

      final Map<String, int> counts = {};
      for (var row in countsQuery.fetchAll()) {
        counts[row[0] as String] = row[1] as int;
      }

      // Also account for vehicles that started inside a geofence and never left
      final latestLocQuery = await connection.query('''
        SELECT vehicle_id, 
          MAX(CASE WHEN signal_name = 'lat' THEN signal_value END) as lat,
          MAX(CASE WHEN signal_name = 'lng' THEN signal_value END) as lng
        FROM (
          SELECT vehicle_id, signal_name, signal_value,
            ROW_NUMBER() OVER (PARTITION BY vehicle_id, signal_name ORDER BY timestamp DESC) as rn
          FROM telemetry
          WHERE signal_name IN ('lat', 'lng')
        )
        WHERE rn = 1
        GROUP BY vehicle_id
      ''');

      counts.clear(); // Reset and calculate accurately via distance
      for (var row in latestLocQuery.fetchAll()) {
        final lat = row[1] as double?;
        final lng = row[2] as double?;
        if (lat == null || lng == null) continue;

        for (var gf in geofences) {
          if (!gf.active) continue;
          final dist = TripCalculator.distance(lat, lng, gf.lat, gf.lng);
          if (dist <= gf.radius) {
            counts[gf.id] = (counts[gf.id] ?? 0) + 1;
            break; // A vehicle can only be in one geofence at a time for this count
          }
        }
      }

      emit(state.copyWith(
        isLoading: false,
        geofences: geofences,
        activeVehicleCounts: counts,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddGeofence(
      AddGeofence event, Emitter<GeofenceState> emit) async {
    try {
      final id = _uuid.v4();
      await _dbService.connection.query('''
        INSERT INTO geofences (id, name, lat, lng, radius, active)
        VALUES ('$id', '${event.name}', ${event.lat}, ${event.lng}, ${event.radius}, true)
      ''');
      add(LoadGeofences());
    } catch (e) {
      print(e);
    }
  }

  Future<void> _onToggleGeofence(
      ToggleGeofence event, Emitter<GeofenceState> emit) async {
    try {
      await _dbService.connection.query('''
        UPDATE geofences SET active = ${event.active} WHERE id = '${event.id}'
      ''');
      add(LoadGeofences());
    } catch (e) {}
  }

  Future<void> _onRecalculateAllTrips(
      RecalculateAllTrips event, Emitter<GeofenceState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await _dbService.connection.query("SELECT id FROM vehicles");
      for (var row in res.fetchAll()) {
        await TripCalculator.processTelemetry(_dbService, row[0] as String);
      }
      add(LoadGeofences()); // refresh the active counts
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onEditGeofence(
      EditGeofence event, Emitter<GeofenceState> emit) async {
    try {
      await _dbService.connection.query('''
        UPDATE geofences 
        SET name = '${event.name}', lat = ${event.lat}, lng = ${event.lng}, radius = ${event.radius}
        WHERE id = '${event.id}'
      ''');
      add(LoadGeofences());
    } catch (e) {
      print(e);
    }
  }

  Future<void> _onAddDemoGeofenceWithTrips(
      AddDemoGeofenceWithTrips event, Emitter<GeofenceState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final connection = _dbService.connection;

      final hqId = 'gf_hq_1';
      final whId = 'gf_wh_1';
      final testHubId = 'gf_test_hub_${DateTime.now().millisecondsSinceEpoch}';

      await connection.query('''
        INSERT INTO geofences (id, name, lat, lng, radius, active) VALUES
        ('$hqId', 'Headquarters', 12.9716, 77.5946, 500.0, true),
        ('$whId', 'Warehouse A', 13.0000, 77.6000, 300.0, true),
        ('$testHubId', 'Demo Logistics Hub', 12.9300, 77.5500, 450.0, true)
        ON CONFLICT DO NOTHING
      ''');

      final vRes = await connection.query("SELECT id FROM vehicles LIMIT 1");
      final vRows = vRes.fetchAll();
      final targetVehicleId =
          vRows.isNotEmpty ? (vRows.first[0] as String) : 'vh_0';

      await connection.query('''
        INSERT INTO vehicles (id, reg_number, model) VALUES
        ('$targetVehicleId', 'DEMO-REG-001', 'Tata Ace EV')
        ON CONFLICT DO NOTHING
      ''');

      final now = DateTime.now();
      final t0 = now.subtract(const Duration(minutes: 40)).toIso8601String();
      final t1 = now.subtract(const Duration(minutes: 30)).toIso8601String();
      final t2 = now.subtract(const Duration(minutes: 20)).toIso8601String();
      final t3 = now.subtract(const Duration(minutes: 10)).toIso8601String();
      final t4 = now.subtract(const Duration(minutes: 2)).toIso8601String();

      await connection.query('''
        INSERT INTO telemetry (timestamp, vehicle_id, signal_name, signal_value, received_at) VALUES 
        ('$t0', '$targetVehicleId', 'lat', 12.9716, '$t0'),
        ('$t0', '$targetVehicleId', 'lng', 77.5946, '$t0'),

        ('$t1', '$targetVehicleId', 'lat', 12.9850, '$t1'),
        ('$t1', '$targetVehicleId', 'lng', 77.5970, '$t1'),

        ('$t2', '$targetVehicleId', 'lat', 13.0000, '$t2'),
        ('$t2', '$targetVehicleId', 'lng', 77.6000, '$t2'),

        ('$t3', '$targetVehicleId', 'lat', 12.9600, '$t3'),
        ('$t3', '$targetVehicleId', 'lng', 77.5800, '$t3'),

        ('$t4', '$targetVehicleId', 'lat', 12.9300, '$t4'),
        ('$t4', '$targetVehicleId', 'lng', 77.5500, '$t4');
      ''');

      await TripCalculator.processTelemetry(_dbService, targetVehicleId);

      add(LoadGeofences());
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
