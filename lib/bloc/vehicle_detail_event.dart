import 'package:equatable/equatable.dart';

abstract class VehicleDetailEvent extends Equatable {
  const VehicleDetailEvent();

  @override
  List<Object?> get props => [];
}

class LoadVehicleDetail extends VehicleDetailEvent {
  final String vehicleId;
  const LoadVehicleDetail(this.vehicleId);

  @override
  List<Object?> get props => [vehicleId];
}

class DismissAlert extends VehicleDetailEvent {
  final String alertId;
  final String reason;
  const DismissAlert(this.alertId, this.reason);

  @override
  List<Object?> get props => [alertId, reason];
}

class UndoDismissAlert extends VehicleDetailEvent {
  final String alertId;
  const UndoDismissAlert(this.alertId);

  @override
  List<Object?> get props => [alertId];
}

class RecalculateVehicleTrips extends VehicleDetailEvent {
  final String vehicleId;
  const RecalculateVehicleTrips(this.vehicleId);

  @override
  List<Object?> get props => [vehicleId];
}
