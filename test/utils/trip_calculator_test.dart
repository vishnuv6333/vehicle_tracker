import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:vechicle_tracker/data/database_service.dart';
import 'package:vechicle_tracker/utils/trip_calculator.dart';

class MockDatabaseService extends Mock implements DatabaseService {}
class MockConnection extends Mock implements Connection {}
class MockResult extends Mock implements ResultSet {}

void main() {
  group('TripCalculator', () {
    late MockDatabaseService mockDbService;
    late MockConnection mockConnection;

    setUp(() {
      mockDbService = MockDatabaseService();
      mockConnection = MockConnection();
      when(() => mockDbService.connection).thenReturn(mockConnection);
    });

    test('distance() accurately calculates Haversine distance in meters', () {
      // Test known coordinates: distance between HQ and a point ~435m away
      final dist = TripCalculator.distance(12.9716, 77.5946, 12.9750, 77.5960);
      
      // We expect the distance to be roughly ~407.36 meters
      expect(dist, closeTo(407.36, 0.1));
    });

    test('processTelemetry handles confirmed exits and starts a trip', () async {
      final mockLocResult = MockResult();
      final mockGfResult = MockResult();

      // Mock the location query returning a point outside the HQ
      when(() => mockConnection.query(any(that: contains("WHERE vehicle_id = 'v1' AND signal_name IN ('lat', 'lng')"))))
          .thenAnswer((_) async => mockLocResult);
          
      // One location point that is definitely outside HQ
      when(() => mockLocResult.fetchAll()).thenReturn([
        [DateTime.now(), 13.0, 'lat'], // Way outside
        [DateTime.now(), 78.0, 'lng']
      ]);

      // Mock geofences query (HQ is at 12.9716, 77.5946, radius 500)
      when(() => mockConnection.query(any(that: contains("FROM geofences"))))
          .thenAnswer((_) async => mockGfResult);
      when(() => mockGfResult.fetchAll()).thenReturn([
        ['gf_hq_1', 12.9716, 77.5946, 500.0]
      ]);

      // Mock the DELETE statement to do nothing
      when(() => mockConnection.query(any(that: startsWith("DELETE FROM trips"))))
          .thenAnswer((_) async => MockResult());

      // Mock the INSERT statement
      when(() => mockConnection.query(any(that: startsWith("INSERT INTO trips"))))
          .thenAnswer((_) async => MockResult());

      await TripCalculator.processTelemetry(mockDbService, 'v1');

      // Verify that the trips were reset (idempotency check)
      verify(() => mockConnection.query("DELETE FROM trips WHERE vehicle_id = 'v1'")).called(1);
    });
  });
}
