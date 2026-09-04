import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:vechicle_tracker/bloc/fleet_bloc.dart';
import 'package:vechicle_tracker/bloc/fleet_event.dart';
import 'package:vechicle_tracker/bloc/fleet_state.dart';
import 'package:vechicle_tracker/data/database_service.dart';
import 'package:vechicle_tracker/models/vehicle_status.dart';

class MockDatabaseService extends Mock implements DatabaseService {}
class MockConnection extends Mock implements Connection {}
class MockResult extends Mock implements ResultSet {}

void main() {
  group('FleetBloc', () {
    late MockDatabaseService mockDbService;
    late MockConnection mockConnection;

    setUp(() {
      mockDbService = MockDatabaseService();
      mockConnection = MockConnection();
      when(() => mockDbService.connection).thenReturn(mockConnection);
    });

    blocTest<FleetBloc, FleetState>(
      'emits [isLoading: true] then data when LoadFleetData is added',
      build: () {
        final mockResult = MockResult();
        final mockCountResult = MockResult();

        when(() => mockConnection.query(any(that: contains('SELECT * FROM fleet_status_view'))))
            .thenAnswer((_) async => mockResult);
            
        when(() => mockConnection.query(any(that: contains('GROUP BY status'))))
            .thenAnswer((_) async => mockCountResult);

        // Mock empty fleet for simplicity
        when(() => mockResult.fetchAll()).thenReturn([]);
        when(() => mockCountResult.fetchAll()).thenReturn([]);

        return FleetBloc(mockDbService);
      },
      act: (bloc) => bloc.add(LoadFleetData()),
      expect: () => [
        const FleetState(isLoading: true),
        const FleetState(isLoading: false, vehicles: [], counts: {FleetStatus.ALL: 0}),
      ],
    );
    
    blocTest<FleetBloc, FleetState>(
      'emits new currentFilter when FilterChanged is added',
      build: () => FleetBloc(mockDbService),
      act: (bloc) => bloc.add(const FilterChanged(FleetStatus.MOVING)),
      expect: () => [
        const FleetState(currentFilter: FleetStatus.MOVING),
      ],
    );
  });
}
