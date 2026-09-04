import 'package:flutter/material.dart';
import '../../models/vehicle_status.dart';
import '../../bloc/fleet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/fleet_state.dart';
import '../../bloc/fleet_event.dart';

class FleetFilterChips extends StatelessWidget {
  const FleetFilterChips({super.key});

  String _statusLabel(FleetStatus status) {
    switch (status) {
      case FleetStatus.ALL:
        return 'All';
      case FleetStatus.MOVING:
        return 'Moving';
      case FleetStatus.IDLE:
        return 'Idle';
      case FleetStatus.STOPPED:
        return 'Stopped';
      case FleetStatus.OFFLINE:
        return 'Offline';
    }
  }

  Color _statusColor(FleetStatus status, BuildContext context) {
    switch (status) {
      case FleetStatus.ALL:
        return Theme.of(context).colorScheme.primary;
      case FleetStatus.MOVING:
        return const Color(0xFF10B981);
      case FleetStatus.IDLE:
        return const Color(0xFFF59E0B);
      case FleetStatus.STOPPED:
        return const Color(0xFF3B82F6);
      case FleetStatus.OFFLINE:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FleetBloc, FleetState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: FleetStatus.values.map((status) {
              final isSelected = state.currentFilter == status;
              final count = state.counts[status] ?? 0;
              final color = _statusColor(status, context);

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: FilterChip(
                    showCheckmark: false,
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    avatar: status != FleetStatus.ALL
                        ? CircleAvatar(
                            radius: 4,
                            backgroundColor: isSelected ? Colors.white : color,
                          )
                        : null,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 13,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    side: BorderSide(
                      color: isSelected
                          ? color
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.2),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        context.read<FleetBloc>().add(FilterChanged(status));
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

