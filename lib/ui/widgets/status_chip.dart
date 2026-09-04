import 'package:flutter/material.dart';
import '../../models/vehicle_status.dart';

class StatusChip extends StatelessWidget {
  final FleetStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    String label;

    switch (status) {
      case FleetStatus.MOVING:
        chipColor = Colors.green;
        label = 'MOVING';
        break;
      case FleetStatus.IDLE:
        chipColor = Colors.orange;
        label = 'IDLE';
        break;
      case FleetStatus.STOPPED:
        chipColor = Colors.blue;
        label = 'STOPPED';
        break;
      case FleetStatus.OFFLINE:
      default:
        chipColor = Colors.grey;
        label = 'OFFLINE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
