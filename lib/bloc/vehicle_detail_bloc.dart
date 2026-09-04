import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/database_service.dart';
import 'vehicle_detail_event.dart';
import 'vehicle_detail_state.dart';
import '../models/signal_reading.dart';

class VehicleDetailBloc extends Bloc<VehicleDetailEvent, VehicleDetailState> {
  final DatabaseService _dbService;

  VehicleDetailBloc(this._dbService) : super(const VehicleDetailState()) {
    on<LoadVehicleDetail>(_onLoadVehicleDetail);
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
          'time': row[0] is DateTime
              ? row[0] as DateTime
              : DateTime.parse(row[0] as String),
          'value': row[1] as double,
        });
      }

      emit(state.copyWith(
        isLoading: false,
        readings: readingsList,
        socHistory: socHistory,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
