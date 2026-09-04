import 'package:flutter/material.dart';
import '../../models/vehicle_status.dart';

class StatusChip extends StatelessWidget {
  final FleetStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    String label;
    IconData icon;

    switch (status) {
      case FleetStatus.MOVING:
        chipColor = const Color(0xFF10B981); // Emerald Green
        label = 'MOVING';
        icon = Icons.navigation_rounded;
        break;
      case FleetStatus.IDLE:
        chipColor = const Color(0xFFF59E0B); // Amber/Gold
        label = 'IDLE';
        icon = Icons.access_time_filled_rounded;
        break;
      case FleetStatus.STOPPED:
        chipColor = const Color(0xFF3B82F6); // Royal Blue
        label = 'STOPPED';
        icon = Icons.pause_circle_filled_rounded;
        break;
      case FleetStatus.OFFLINE:
      default:
        chipColor = const Color(0xFF64748B); // Slate Grey
        label = 'OFFLINE';
        icon = Icons.wifi_off_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

