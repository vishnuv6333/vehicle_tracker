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
