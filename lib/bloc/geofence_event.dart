import 'package:equatable/equatable.dart';

abstract class GeofenceEvent extends Equatable {
  const GeofenceEvent();

  @override
  List<Object?> get props => [];
}

class LoadGeofences extends GeofenceEvent {}

class AddGeofence extends GeofenceEvent {
  final String name;
  final double lat;
  final double lng;
  final double radius;

  const AddGeofence(this.name, this.lat, this.lng, this.radius);

  @override
  List<Object?> get props => [name, lat, lng, radius];
}

class ToggleGeofence extends GeofenceEvent {
  final String id;
  final bool active;

  const ToggleGeofence(this.id, this.active);

  @override
  List<Object?> get props => [id, active];
}

class RecalculateAllTrips extends GeofenceEvent {}

class EditGeofence extends GeofenceEvent {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radius;

  const EditGeofence(this.id, this.name, this.lat, this.lng, this.radius);

  @override
  List<Object?> get props => [id, name, lat, lng, radius];
}
