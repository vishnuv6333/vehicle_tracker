import 'package:equatable/equatable.dart';
import '../../models/signal_reading.dart';

class VehicleDetailState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<SignalReading> readings;
  final List<Map<String, dynamic>> socHistory; // For the sparkline
  final List<Map<String, dynamic>> activeAlerts;

  const VehicleDetailState({
    this.isLoading = false,
    this.error,
    this.readings = const [],
    this.socHistory = const [],
    this.activeAlerts = const [],
  });

  VehicleDetailState copyWith({
    bool? isLoading,
    String? error,
    List<SignalReading>? readings,
    List<Map<String, dynamic>>? socHistory,
    List<Map<String, dynamic>>? activeAlerts,
  }) {
    return VehicleDetailState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      readings: readings ?? this.readings,
      socHistory: socHistory ?? this.socHistory,
      activeAlerts: activeAlerts ?? this.activeAlerts,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, readings, socHistory, activeAlerts];
}
