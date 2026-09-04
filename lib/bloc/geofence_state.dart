import 'package:equatable/equatable.dart';
import '../models/geofence.dart';

class GeofenceState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<Geofence> geofences;
  final Map<String, int> activeVehicleCounts; // Geofence ID to vehicle count

  const GeofenceState({
    this.isLoading = false,
    this.error,
    this.geofences = const [],
    this.activeVehicleCounts = const {},
  });

  GeofenceState copyWith({
    bool? isLoading,
    String? error,
    List<Geofence>? geofences,
    Map<String, int>? activeVehicleCounts,
  }) {
    return GeofenceState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      geofences: geofences ?? this.geofences,
      activeVehicleCounts: activeVehicleCounts ?? this.activeVehicleCounts,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, geofences, activeVehicleCounts];
}
