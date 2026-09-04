import 'package:equatable/equatable.dart';
import '../models/vehicle_status.dart';

abstract class FleetEvent extends Equatable {
  const FleetEvent();

  @override
  List<Object?> get props => [];
}

class LoadFleetData extends FleetEvent {}

class FilterChanged extends FleetEvent {
  final FleetStatus filter;
  const FilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}
