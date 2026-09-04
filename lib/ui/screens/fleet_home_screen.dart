import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/fleet_bloc.dart';
import '../../bloc/fleet_state.dart';
import '../../bloc/fleet_event.dart';
import '../../models/vehicle_status.dart';
import '../widgets/filter_chips.dart';
import '../widgets/status_chip.dart';
import 'vehicle_detail_screen.dart';
import 'geofences_screen.dart';
import '../../data/scale_backfill.dart';
import '../../data/database_service.dart';

class FleetHomeScreen extends StatefulWidget {
  const FleetHomeScreen({super.key});

  @override

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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.directions_bus_filled_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Fleet Console',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: Colors.amber),
            tooltip: 'Run Scale Backfill (500 vehicles)',
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  title: Text('Running Scale Backfill...'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Seeding 500 vehicles & initial telemetry...'),
                    ],
                  ),
                ),
              );

              await ScaleBackfill.runBackfill(DatabaseService());

              if (context.mounted) {
                Navigator.of(context).pop(); // Close dialog
                context.read<FleetBloc>().add(LoadFleetData()); // Refresh
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backfill complete! Loaded 500 vehicles.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Geofences',
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GeofencesScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: () => context.read<FleetBloc>().add(LoadFleetData()),
          ),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('Error loading fleet: ${state.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              context.read<FleetBloc>().add(LoadFleetData()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredVehicles = state.currentFilter == FleetStatus.ALL
                    ? state.vehicles
                    : state.vehicles
                        .where((v) => v.status == state.currentFilter)
                        .toList();

                if (filteredVehicles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Theme.of(context).disabledColor),
                        const SizedBox(height: 12),
                        const Text(
                          'No vehicles found for this status filter.',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 20),
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

  Color _getStatusColor(FleetStatus status) {
    switch (status) {
      case FleetStatus.MOVING:
        return const Color(0xFF10B981);
      case FleetStatus.IDLE:
        return const Color(0xFFF59E0B);
      case FleetStatus.STOPPED:
        return const Color(0xFF3B82F6);
      case FleetStatus.OFFLINE:
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(vehicle.status);
    final soc = vehicle.soc;
    final range = vehicle.range;

    Color socColor = const Color(0xFF10B981);
    if (soc != null) {
      if (soc < 20) {
        socColor = const Color(0xFFEF4444);
      } else if (soc < 40) {
        socColor = const Color(0xFFF59E0B);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Status Bar
              Container(
                width: 5,
                color: statusColor,
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VehicleDetailScreen(vehicle: vehicle),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Registration & Model with Status Chip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    vehicle.regNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      vehicle.model,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(status: vehicle.status),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // SOC Progress Bar & Metrics Row
                        Row(
                          children: [
                            // Battery SOC Metric
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            soc != null && soc < 20
                                                ? Icons.battery_alert_rounded
                                                : Icons
                                                    .battery_charging_full_rounded,
                                            size: 16,
                                            color: socColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'SOC',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        soc != null
                                            ? '${soc.toStringAsFixed(1)}%'
                                            : '--',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: socColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: soc != null
                                          ? (soc / 100.0).clamp(0.0, 1.0)
                                          : 0,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          socColor),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Range Metric
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.speed_rounded,
                                      size: 16,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Est. Range',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  range != null
                                      ? '${range.toStringAsFixed(0)} km'
                                      : '--',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Active Alerts Tag (if any)
                        if (vehicle.activeAlerts > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: Colors.red),
                                const SizedBox(width: 6),
                                Text(
                                  '${vehicle.activeAlerts} Active Alert${vehicle.activeAlerts > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Chevron Right Icon
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

