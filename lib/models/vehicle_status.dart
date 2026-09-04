import 'package:equatable/equatable.dart';

// ignore: constant_identifier_names
enum FleetStatus { ALL, OFFLINE, MOVING, IDLE, STOPPED }

class VehicleStatus extends Equatable {
  final String id;
  final String regNumber;
  final String model;
  final double? soc;
  final double? range;
  final DateTime? lastPing;
  final FleetStatus status;
  final int activeAlerts;

  const VehicleStatus({
    required this.id,
    required this.regNumber,
    required this.model,
    this.soc,
    this.range,
    this.lastPing,
    required this.status,
    this.activeAlerts = 0,
  });

  factory VehicleStatus.fromMap(Map<String, dynamic> map) {
    FleetStatus mapStatus(String? statusStr) {
      switch (statusStr) {
        case 'OFFLINE':
          return FleetStatus.OFFLINE;
        case 'MOVING':
          return FleetStatus.MOVING;
        case 'IDLE':
          return FleetStatus.IDLE;
        case 'STOPPED':
          return FleetStatus.STOPPED;
        default:
          return FleetStatus.OFFLINE;
      }
    }

    return VehicleStatus(
      id: map['id'],
      regNumber: map['reg_number'],
      model: map['model'],
      soc: map['soc'],
      range: map['range'],
      lastPing: map['last_ping'] is DateTime
          ? map['last_ping']
          : (map['last_ping'] != null
              ? DateTime.parse(map['last_ping'])
              : null),
      status: mapStatus(map['status']),
      activeAlerts: map['active_alerts'] ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [id, regNumber, model, soc, range, lastPing, status, activeAlerts];
}
