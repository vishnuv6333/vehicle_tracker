import 'package:flutter/material.dart';
import '../../models/vehicle_status.dart';
import '../../bloc/fleet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/fleet_state.dart';
import '../../bloc/fleet_event.dart';

class FleetFilterChips extends StatelessWidget {
  const FleetFilterChips({Key? key}) : super(key: key);

  String _statusLabel(FleetStatus status) {
    switch (status) {
      case FleetStatus.ALL: return 'All';
      case FleetStatus.MOVING: return 'Moving';
      case FleetStatus.IDLE: return 'Idle';
      case FleetStatus.STOPPED: return 'Stopped';
      case FleetStatus.OFFLINE: return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FleetBloc, FleetState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: FleetStatus.values.map((status) {
              final isSelected = state.currentFilter == status;
              final count = state.counts[status] ?? 0;
              
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text('${_statusLabel(status)} ($count)'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      context.read<FleetBloc>().add(FilterChanged(status));
                    }
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
