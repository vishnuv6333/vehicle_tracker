import 'package:equatable/equatable.dart';
import '../../models/signal_reading.dart';

class VehicleDetailState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<SignalReading> readings;
  final List<Map<String, dynamic>> socHistory; // For the sparkline

  const VehicleDetailState({
    this.isLoading = false,
    this.error,
    this.readings = const [],
    this.socHistory = const [],
  });

  VehicleDetailState copyWith({
    bool? isLoading,
    String? error,
    List<SignalReading>? readings,
    List<Map<String, dynamic>>? socHistory,
  }) {
    return VehicleDetailState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      readings: readings ?? this.readings,
      socHistory: socHistory ?? this.socHistory,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, readings, socHistory];
}
