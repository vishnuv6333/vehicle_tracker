import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/fleet_bloc.dart';
import '../../bloc/fleet_state.dart';
import '../../bloc/fleet_event.dart';
import '../../models/vehicle_status.dart';
import '../widgets/filter_chips.dart';
import '../widgets/status_chip.dart';
import 'vehicle_detail_screen.dart';

class FleetHomeScreen extends StatefulWidget {
  const FleetHomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FleetHomeScreenState createState() => _FleetHomeScreenState();
}

class _FleetHomeScreenState extends State<FleetHomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FleetBloc>().add(LoadFleetData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FleetBloc>().add(LoadFleetData()),
          )
        ],
      ),
      body: Column(
        children: [
          const FleetFilterChips(),
          Expanded(
            child: BlocBuilder<FleetBloc, FleetState>(
              builder: (context, state) {
                if (state.isLoading && state.vehicles.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.error != null) {
                  return Center(child: Text('Error: ${state.error}'));
                }

                final filteredVehicles = state.currentFilter == FleetStatus.ALL
                    ? state.vehicles
                    : state.vehicles
                        .where((v) => v.status == state.currentFilter)
                        .toList();

                if (filteredVehicles.isEmpty) {
                  return const Center(
                      child: Text('No vehicles found for this status.'));
                }

                return ListView.builder(
                  itemCount: filteredVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = filteredVehicles[index];
                    return _VehicleListItem(vehicle: vehicle);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleListItem extends StatelessWidget {
  final VehicleStatus vehicle;

  const _VehicleListItem({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text('${vehicle.regNumber} - ${vehicle.model}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
                'SOC: ${vehicle.soc?.toStringAsFixed(1) ?? '--'}% | Range: ${vehicle.range?.toStringAsFixed(0) ?? '--'} km'),
            if (vehicle.activeAlerts > 0)
              Text(
                '${vehicle.activeAlerts} Active Alerts',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: StatusChip(status: vehicle.status),
        isThreeLine: vehicle.activeAlerts > 0,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VehicleDetailScreen(vehicle: vehicle),
            ),
          );
        },
      ),
    );
  }
}
