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
  }

  Future<void> _onLoadGeofences(
      LoadGeofences event, Emitter<GeofenceState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final connection = _dbService.connection;

      final result = await connection.query('SELECT * FROM geofences');
      final geofences = <Geofence>[];
      final rows = result.fetchAll();
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
      // (Their latest trip might not exist, or their ONLY trip is IN_PROGRESS but they haven't left... wait, if they haven't left, they don't have a trip.
      // If we strictly rely on trips, vehicles that never left their origin geofence wouldn't be counted if they have 0 trips.
      // But for this assignment's scope, counting based on latest trip is sufficient.
      // Let's refine it to include vehicles with no trips but their initial telemetry was in a geofence.
      // Actually, if we just want a simple live count, let's just do it in Dart using the latest telemetry!

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
}
