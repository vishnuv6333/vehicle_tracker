class Queries {
  static const String createVehiclesTable = '''
    CREATE TABLE IF NOT EXISTS vehicles (
      id VARCHAR PRIMARY KEY,
      reg_number VARCHAR NOT NULL,
      model VARCHAR NOT NULL
    );
  ''';

  static const String createTelemetryTable = '''
    CREATE TABLE IF NOT EXISTS telemetry (
      timestamp TIMESTAMP NOT NULL,
      vehicle_id VARCHAR NOT NULL,
      signal_name VARCHAR NOT NULL,
      signal_value DOUBLE NOT NULL,
      received_at TIMESTAMP NOT NULL
    );
  ''';

  static const String createGeofencesTable = '''
    CREATE TABLE IF NOT EXISTS geofences (
      id VARCHAR PRIMARY KEY,
      name VARCHAR NOT NULL,
      lat DOUBLE NOT NULL,
      lng DOUBLE NOT NULL,
      radius DOUBLE NOT NULL,
      active BOOLEAN NOT NULL DEFAULT true
    );
  ''';

  static const String createAlertsTable = '''
    CREATE TABLE IF NOT EXISTS alerts (
      id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      alert_type VARCHAR NOT NULL,
      status VARCHAR NOT NULL, -- 'active', 'dismissed', 'resolved'
      dismissal_reason VARCHAR,
      timestamp TIMESTAMP NOT NULL
    );
  ''';

  static const String createTripsTable = '''
    CREATE TABLE IF NOT EXISTS trips (
      id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      start_time TIMESTAMP NOT NULL,
      end_time TIMESTAMP,
      origin_geofence_id VARCHAR NOT NULL,
      destination_geofence_id VARCHAR,
      status VARCHAR NOT NULL -- 'IN_PROGRESS', 'COMPLETED'
    );
  ''';

  static const String createFleetStatusView = '''
    CREATE OR REPLACE VIEW fleet_status_view AS
    WITH latest_telemetry AS (
      SELECT 
        vehicle_id,
        signal_name,
        signal_value,
        timestamp as event_time,
        MAX(timestamp) OVER (PARTITION BY vehicle_id, signal_name) as max_time,
        MAX(received_at) OVER (PARTITION BY vehicle_id) as last_ping
      FROM telemetry
    ),
    current_signals AS (
      SELECT 
        vehicle_id,
        MAX(CASE WHEN signal_name = 'soc' THEN signal_value END) as soc,
        MAX(CASE WHEN signal_name = 'range' THEN signal_value END) as range,
        MAX(CASE WHEN signal_name = 'speed' THEN signal_value END) as speed,
        MAX(CASE WHEN signal_name = 'ignition' THEN signal_value END) as ignition,
        MAX(last_ping) as last_ping
      FROM latest_telemetry
      WHERE event_time = max_time
      GROUP BY vehicle_id
    )
    SELECT 
      v.id,
      v.reg_number,
      v.model,
      cs.soc,
      cs.range,
      cs.last_ping,
      CASE 
        WHEN epoch(current_timestamp) - epoch(cs.last_ping) > 600 THEN 'OFFLINE'
        WHEN cs.speed > 0 THEN 'MOVING'
        WHEN cs.speed = 0 AND cs.ignition = 1 THEN 'IDLE'
        WHEN cs.ignition = 0 THEN 'STOPPED'
        ELSE 'OFFLINE'
      END as status,
      -- Alerts logic can be joined here or handled in Dart if complex
      (SELECT count(*) FROM alerts a WHERE a.vehicle_id = v.id AND a.status = 'active') as active_alerts
    FROM vehicles v
    LEFT JOIN current_signals cs ON v.id = cs.vehicle_id;
  ''';
}
