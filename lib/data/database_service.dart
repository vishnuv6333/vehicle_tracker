import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'queries.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Database _db;
  late Connection _connection;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(appDir.path, 'fleet_console.db');

    _db = await duckdb.open(dbPath);
    _connection = await duckdb.connect(_db);

    await _setupSchema();
    _isInitialized = true;
  }

  Future<void> _setupSchema() async {
    // Execute all table creations and views
    _connection.execute(Queries.createVehiclesTable);
    _connection.execute(Queries.createTelemetryTable);
    _connection.execute(Queries.createGeofencesTable);
    _connection.execute(Queries.createAlertsTable);
    _connection.execute(Queries.createTripsTable);

    // Create the fleet status view
    _connection.execute(Queries.createFleetStatusView);
  }

  Connection get connection {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call init() first.');
    }
    return _connection;
  }

  void close() {
    if (_isInitialized) {
      // _connection.close();
      // _db.close();
      _isInitialized = false;
    }
  }
}
