import 'package:equatable/equatable.dart';

class Geofence extends Equatable {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radius;
  final bool active;

  const Geofence({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
    this.active = true,
  });

  factory Geofence.fromMap(Map<String, dynamic> map) {
    return Geofence(
      id: map['id'],
      name: map['name'],
      lat: map['lat'],
      lng: map['lng'],
      radius: map['radius'],
      active: map['active'] == 1 || map['active'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, lat, lng, radius, active];
}
