import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/database_service.dart';
import 'fleet_event.dart';
import 'fleet_state.dart';
import '../models/vehicle_status.dart';

class FleetBloc extends Bloc<FleetEvent, FleetState> {
  final DatabaseService _dbService;

  FleetBloc(this._dbService) : super(const FleetState()) {
    on<LoadFleetData>(_onLoadFleetData);
    on<FilterChanged>(_onFilterChanged);
  }

  Future<void> _onLoadFleetData(LoadFleetData event, Emitter<FleetState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final connection = _dbService.connection;
      
      final stopwatch = Stopwatch()..start();
      
      // Query to get all vehicles
      final result = await connection.query('SELECT * FROM fleet_status_view');
      final vehicles = <VehicleStatus>[];
      final rows = result.fetchAll();
      for (var row in rows) {
        final map = <String, dynamic>{};
        for (var i = 0; i < result.columnNames.length; i++) {
          map[result.columnNames[i]] = row[i];
        }
        vehicles.add(VehicleStatus.fromMap(map));
      }

      // Query to get counts
      final countsResult = await connection.query('''
        SELECT status, count(*) as count 
        FROM fleet_status_view 
        GROUP BY status
      ''');
      
      stopwatch.stop();
      print('Fleet data query took: ${stopwatch.elapsedMilliseconds} ms');

      final counts = <FleetStatus, int>{FleetStatus.ALL: vehicles.length};
      final countRows = countsResult.fetchAll();
      for (var row in countRows) {
        final statusStr = row[0] as String;
        final count = row[1] as int;
        
        FleetStatus status;
        switch (statusStr) {
          case 'OFFLINE': status = FleetStatus.OFFLINE; break;
          case 'MOVING': status = FleetStatus.MOVING; break;
          case 'IDLE': status = FleetStatus.IDLE; break;
          case 'STOPPED': status = FleetStatus.STOPPED; break;
          default: status = FleetStatus.OFFLINE;
        }
        counts[status] = count;
      }

      emit(state.copyWith(
        isLoading: false,
        vehicles: vehicles,
        counts: counts,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onFilterChanged(FilterChanged event, Emitter<FleetState> emit) {
    emit(state.copyWith(currentFilter: event.filter));
  }
}
