import 'package:equatable/equatable.dart';
import '../models/vehicle_status.dart';

class FleetState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<VehicleStatus> vehicles;
  final Map<FleetStatus, int> counts;
  final FleetStatus currentFilter;

  const FleetState({
    this.isLoading = false,
    this.error,
    this.vehicles = const [],
    this.counts = const {},
    this.currentFilter = FleetStatus.ALL,
  });

  FleetState copyWith({
    bool? isLoading,
    String? error,
    List<VehicleStatus>? vehicles,
    Map<FleetStatus, int>? counts,
    FleetStatus? currentFilter,
  }) {
    return FleetState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      vehicles: vehicles ?? this.vehicles,
      counts: counts ?? this.counts,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, vehicles, counts, currentFilter];
}
