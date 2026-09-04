import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/database_service.dart';
import 'vehicle_detail_event.dart';
import 'vehicle_detail_state.dart';
import '../models/signal_reading.dart';

class VehicleDetailBloc extends Bloc<VehicleDetailEvent, VehicleDetailState> {
  final DatabaseService _dbService;

  VehicleDetailBloc(this._dbService) : super(const VehicleDetailState()) {
    on<LoadVehicleDetail>(_onLoadVehicleDetail);
    on<DismissAlert>(_onDismissAlert);
    on<UndoDismissAlert>(_onUndoDismissAlert);
  }

  Future<void> _onLoadVehicleDetail(
      LoadVehicleDetail event, Emitter<VehicleDetailState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final connection = _dbService.connection;
      final now = DateTime.now();

      // Get latest readings for each signal
      final readingsQuery = '''
        SELECT signal_name, signal_value, received_at
        FROM telemetry
        WHERE vehicle_id = '${event.vehicleId}'
        AND timestamp = (
          SELECT MAX(timestamp) 
          FROM telemetry t2 
          WHERE t2.vehicle_id = telemetry.vehicle_id 
          AND t2.signal_name = telemetry.signal_name
        )
      ''';

      final readingsResult = await connection.query(readingsQuery);
      final List<SignalReading> readingsList = [];

      for (var row in readingsResult.fetchAll()) {
        final signalName = row[0] as String;
        final value = row[1] as double;
        final receivedAt = row[2] is DateTime
            ? row[2] as DateTime
            : DateTime.parse(row[2] as String);
        final age = now.difference(receivedAt);

        // Define STALE threshold (e.g. 5 minutes)
        final isStale = age.inMinutes > 5;
        Verdict verdict = isStale ? Verdict.STALE : Verdict.NORMAL;
        String unit = '';

        if (!isStale) {
          if (signalName == 'soc') {
            unit = '%';
            if (value < 10) {
              verdict = Verdict.ALERT;
              // ignore: curly_braces_in_flow_control_structures
            } else if (value < 20) verdict = Verdict.ALERT;
          } else if (signalName == 'battery_temp') {
            unit = '°C';
            if (value > 45) verdict = Verdict.ALERT;
          } else if (signalName == 'range') {
            unit = 'km';
          } else if (signalName == 'speed') {
            unit = 'km/h';
          } else if (signalName == 'odometer') {
            unit = 'km';
          }
        }

        readingsList.add(SignalReading(
          label: signalName.toUpperCase(),
          value: value,
          age: age,
          verdict: verdict,
          unit: unit,
        ));
      }

      // If a signal is missing, add it with NONE verdict
      final requiredSignals = [
        'soc',
        'range',
        'speed',
        'battery_temp',
        'odometer',
        'ignition'
      ];
      for (final sig in requiredSignals) {
        if (!readingsList.any((r) => r.label.toLowerCase() == sig)) {
          readingsList.add(SignalReading(
            label: sig.toUpperCase(),
            age: const Duration(days: 9999), // arbitrary large
            verdict: Verdict.NONE,
          ));
        }
      }

      // Fetch SOC history (e.g., last 50 readings for this vehicle)
      final historyQuery = '''
        SELECT timestamp, signal_value
        FROM telemetry
        WHERE vehicle_id = '${event.vehicleId}' AND signal_name = 'soc'
        ORDER BY timestamp ASC
        LIMIT 50
      ''';
      final historyResult = await connection.query(historyQuery);
      final List<Map<String, dynamic>> socHistory = [];
      for (var row in historyResult.fetchAll()) {
        socHistory.add({
          'time': row[0] is DateTime ? row[0] as DateTime : DateTime.parse(row[0] as String),
          'value': row[1] as double,
        });
      }

      // Check and update Alerts in DB based on current readings
      final activeAlertsResult = await connection.query("SELECT id, alert_type, status, dismissal_reason FROM alerts WHERE vehicle_id = '${event.vehicleId}' AND status IN ('active', 'dismissed')");
      final dbAlerts = activeAlertsResult.fetchAll();
      
      bool hasSocAlert = false;
      bool hasTempAlert = false;
      double? latestSoc;
      double? latestTemp;
      
      for(var r in readingsList) {
        if (r.label == 'SOC' && r.value != null && r.verdict != Verdict.STALE) {
          latestSoc = r.value;
          if (r.value! < 20.0) hasSocAlert = true;
        }
        if (r.label == 'BATTERY_TEMP' && r.value != null && r.verdict != Verdict.STALE) {
          latestTemp = r.value;
          if (r.value! > 45.0) hasTempAlert = true;
        }
      }

      // Sync SOC alert
      final socAlertRow = dbAlerts.where((row) => (row[1] as String) == 'soc').firstOrNull;
      if (hasSocAlert) {
        final severity = latestSoc! < 10.0 ? 'Critical' : 'Warning'; // escalating
        if (socAlertRow == null) {
          final aid = '${event.vehicleId}_soc_${now.millisecondsSinceEpoch}';
          await connection.query("INSERT INTO alerts (id, vehicle_id, alert_type, status, timestamp) VALUES ('$aid', '${event.vehicleId}', 'soc', 'active', '${now.toIso8601String()}')");
        }
      } else {
        if (socAlertRow != null) {
          await connection.query("UPDATE alerts SET status = 'resolved' WHERE id = '${socAlertRow[0] as String}'");
        }
      }

      // Sync Temp alert
      final tempAlertRow = dbAlerts.where((row) => (row[1] as String) == 'temp').firstOrNull;
      if (hasTempAlert) {
        if (tempAlertRow == null) {
          final aid = '${event.vehicleId}_temp_${now.millisecondsSinceEpoch}';
          await connection.query("INSERT INTO alerts (id, vehicle_id, alert_type, status, timestamp) VALUES ('$aid', '${event.vehicleId}', 'temp', 'active', '${now.toIso8601String()}')");
        }
      } else {
        if (tempAlertRow != null) {
          await connection.query("UPDATE alerts SET status = 'resolved' WHERE id = '${tempAlertRow[0] as String}'");
        }
      }

      // Refetch active/dismissed alerts for UI
      final alertsQuery = await connection.query("SELECT id, alert_type, status, dismissal_reason FROM alerts WHERE vehicle_id = '${event.vehicleId}' AND status IN ('active', 'dismissed')");
      final List<Map<String, dynamic>> activeAlerts = [];
      for (var row in alertsQuery.fetchAll()) {
        activeAlerts.add({
          'id': row[0] as String,
          'alert_type': row[1] as String,
          'status': row[2] as String,
          'dismissal_reason': row[3] as String?,
          'severity': (row[1] as String) == 'soc' ? (latestSoc != null && latestSoc < 10.0 ? 'Critical' : 'Warning') : 'Critical',
        });
      }

      emit(state.copyWith(
        isLoading: false,
        readings: readingsList,
        socHistory: socHistory,
        activeAlerts: activeAlerts,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onDismissAlert(DismissAlert event, Emitter<VehicleDetailState> emit) async {
    try {
      await _dbService.connection.query("UPDATE alerts SET status = 'dismissed', dismissal_reason = '${event.reason}' WHERE id = '${event.alertId}'");
      // Trigger a reload to refresh alerts
      if (state.readings.isNotEmpty) {
        final vehicleId = state.activeAlerts.firstWhere((a) => a['id'] == event.alertId, orElse: () => {'vehicle_id': ''})['vehicle_id'] as String?;
        // Just refetch alerts manually
        final alertsQuery = await _dbService.connection.query("SELECT id, alert_type, status, dismissal_reason, vehicle_id FROM alerts WHERE id = '${event.alertId}'");
        final row = alertsQuery.fetchAll().firstOrNull;
        if(row != null) {
           add(LoadVehicleDetail(row[4] as String));
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _onUndoDismissAlert(UndoDismissAlert event, Emitter<VehicleDetailState> emit) async {
    try {
      await _dbService.connection.query("UPDATE alerts SET status = 'active', dismissal_reason = NULL WHERE id = '${event.alertId}'");
       if (state.readings.isNotEmpty) {
        final alertsQuery = await _dbService.connection.query("SELECT id, alert_type, status, dismissal_reason, vehicle_id FROM alerts WHERE id = '${event.alertId}'");
        final row = alertsQuery.fetchAll().firstOrNull;
        if(row != null) {
           add(LoadVehicleDetail(row[4] as String));
        }
      }
    } catch (e) {
      print(e);
    }
  }
}
