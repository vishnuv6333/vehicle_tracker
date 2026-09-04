import 'package:flutter/material.dart';
import 'package:vechicle_tracker/data/database_service.dart';
import 'package:vechicle_tracker/utils/trip_calculator.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  double _distanceTraveled = 0.0;
  double _maxSpeed = 0.0;
  double _batteryConsumed = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTripMetrics();
  }

  Future<void> _loadTripMetrics() async {
    try {
      final startTime = (widget.trip['start_time'] as DateTime).toIso8601String();
      final endTimeObj = widget.trip['end_time'] as DateTime?;
      final endTime = endTimeObj?.toIso8601String() ?? DateTime.now().toIso8601String();
      final vehicleId = widget.trip['vehicle_id'] as String;

      final connection = _dbService.connection;

      // Calculate max speed
      final speedQuery = await connection.query('''
        SELECT MAX(signal_value) FROM telemetry 
        WHERE vehicle_id = '$vehicleId' AND signal_name = 'speed' 
        AND timestamp >= '$startTime' AND timestamp <= '$endTime'
      ''');
      _maxSpeed = (speedQuery.fetchAll().firstOrNull?.firstOrNull as double?) ?? 0.0;

      // Calculate battery consumed (max - min during window)
      final socQuery = await connection.query('''
        SELECT MAX(signal_value) - MIN(signal_value) FROM telemetry 
        WHERE vehicle_id = '$vehicleId' AND signal_name = 'soc' 
        AND timestamp >= '$startTime' AND timestamp <= '$endTime'
      ''');
      _batteryConsumed = (socQuery.fetchAll().firstOrNull?.firstOrNull as double?) ?? 0.0;

      // Calculate distance traveled
      final locQuery = await connection.query('''
        SELECT timestamp, signal_name, signal_value FROM telemetry
        WHERE vehicle_id = '$vehicleId' AND signal_name IN ('lat', 'lng')
        AND timestamp >= '$startTime' AND timestamp <= '$endTime'
        ORDER BY timestamp ASC
      ''');

      final locs = locQuery.fetchAll();
      final Map<String, Map<String, double>> groupedLocs = {};
      for (var row in locs) {
        final t = (row[0] as DateTime).toIso8601String();
        final name = row[1] as String;
        final val = row[2] as double;
        groupedLocs.putIfAbsent(t, () => {});
        groupedLocs[t]![name] = val;
      }

      double? lastLat;
      double? lastLng;
      double dist = 0.0;

      for (var entry in groupedLocs.values) {
        final lat = entry['lat'];
        final lng = entry['lng'];
        if (lat == null || lng == null) continue;
        
        if (lastLat != null && lastLng != null) {
          dist += TripCalculator.distance(lastLat, lastLng, lat, lng);
        }
        lastLat = lat;
        lastLng = lng;
      }
      
      _distanceTraveled = dist / 1000; // Convert to km

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = widget.trip['origin_geofence_name'] ?? 'Unknown Geofence';
    final destination = widget.trip['destination_geofence_name'] ?? (widget.trip['status'] == 'IN_PROGRESS' ? 'In Progress' : 'Unknown Geofence');

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text('Error: $_error'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$origin ➔ $destination', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.speed, color: Colors.blue),
                      title: const Text('Max Speed'),
                      trailing: Text('${_maxSpeed.toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.route, color: Colors.green),
                      title: const Text('Distance Traveled'),
                      trailing: Text('${_distanceTraveled.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.battery_alert, color: Colors.orange),
                      title: const Text('Battery Consumed'),
                      trailing: Text('${_batteryConsumed.toStringAsFixed(1)} %', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
